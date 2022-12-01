open Core_kernel
open Mina_base
open Bit_catchup_state
open Context
include Verifying_generic_types

let get_state_hash st =
  (Transition_state.State_functions.transition_meta st).state_hash

module Make (F : F) = struct
  (** Collect transitions that are either in [Substate.Processing Substate.Dependent]
      or in [Substate.Failed] statuses and set [baton] to [true] for the next
      ancestor in [Substate.Processing (Substate.In_progress _)] status.
      
      Traversal starts with a transition represented by its state and the state is also
      included into result (or has [baton] set to [true]) if it satisfies the conditions.
        
      Function does nothing and returns [[]] if [F.to_data] returns [Nothing] on provided state.
      *)
  let collect_dependent_and_pass_the_baton ~transition_states ~dsu top_state =
    let ts =
      Processed_skipping.collect_to_in_progress ~state_functions
        ~transition_states ~dsu top_state
    in
    match ts with
    | ancestor :: rest ->
        Option.value ~default:[]
          (let%map.Option { substate; _ } = F.to_data ancestor in
           match substate.status with
           | Processing (In_progress _) ->
               Transition_states.update transition_states
                 (F.update { substate; baton = true } ancestor) ;
               rest
           | _ ->
               ancestor :: rest )
    | _ ->
        []

  (** Try to reuse processing context to handle some of 
      ancestors due for restart.
      
      Function takes a list of ancestors due to restart (in parent-first order)
      and returns a prefix of it with transitions that can't be covered
      by the processing context provided.

      If some transitions can be handled with given context, top transition
      will be assigned to this context and
      [Substate.Processing (Substate.In_progress ctx)] status.
      *)
  let try_to_reuse ~transition_states ts ctx =
    match ctx with
    | Substate.In_progress { downto_; timeout = _; interrupt_ivar; holder } ->
        let for_restart, for_reuse =
          List.split_while ts ~f:(fun st ->
              let meta = Transition_state.State_functions.transition_meta st in
              Mina_numbers.Length.(meta.blockchain_length < downto_) )
        in
        let res_opt =
          let%bind.Option st = List.last for_reuse in
          let meta = Transition_state.State_functions.transition_meta st in
          let%map.Option { substate; _ } = F.to_data st in
          holder := meta.state_hash ;
          Transition_states.update transition_states
            (F.update
               { substate = { substate with status = Processing ctx }
               ; baton = false
               }
               st )
        in
        if Option.is_none res_opt then
          Async_kernel.Ivar.fill_if_empty interrupt_ivar () ;
        for_restart
    | _ ->
        ts

  (** Collect transitions that are either in [Substate.Processing Substate.Dependent]
      or in [Substate.Failed] statuses and set [baton] to [true] for the next
      ancestor in [Substate.Processing (Substate.In_progress _)] status.
      
      Traversal starts with a transition represented by its state hash and the state is also
      included into result (or has [baton] set to [true]) if it satisfies the conditions.
        
      Function does nothing and returns [[]] if [F.to_data] returns [Nothing] on provided state.
      *)
  let collect_dependent_and_pass_the_baton_by_hash ~dsu ~transition_states
      state_hash =
    Option.value ~default:[]
    @@ let%bind.Option p =
         Transition_states.find transition_states state_hash
       in
       let%map.Option _ = F.to_data p in
       collect_dependent_and_pass_the_baton ~dsu ~transition_states p

  (* TODO Formal proof why we pass context to next unprocessed and if it
     isn't possible, then context is useless *)

  (** Pass processing context to the next unprocessed state.
      If the next unprocessed state is in [Substate.Processing (Substate.In_progress )]
      status or if it's below context's [downto_] field, context is canceled
      and no transition gets updated.
  *)
  let pass_ctx_to_next_unprocessed ~transition_states ~dsu parent_hash ctx_opt =
    Option.iter ~f:Fn.id
    @@ let%bind.Option ctx = ctx_opt in
       let%bind.Option parent =
         Transition_states.find transition_states parent_hash
       in
       let%bind.Option next =
         Processed_skipping.next_unprocessed ~state_functions ~transition_states
           ~dsu parent
       in
       let%map.Option { substate; _ } = F.to_data next in
       let next_meta = Transition_state.State_functions.transition_meta next in
       match (ctx, substate.status) with
       | Substate.In_progress { interrupt_ivar; _ }, Processing (In_progress _)
         ->
           Async_kernel.Ivar.fill_if_empty interrupt_ivar ()
       | In_progress { downto_; _ }, _
         when Mina_numbers.Length.(next_meta.blockchain_length >= downto_) ->
           Transition_states.update transition_states
             (F.update
                { substate = { substate with status = Processing ctx }
                ; baton = false
                }
                next )
       | _ ->
           ()

  (** Update status to [Substate.Processing (Substate.Done _)]. 
      
      If [reuse_ctx] is [true], if there is an [Substate.In_progress] context and
      there is an unprocessed ancestor covered by this active progress, action won't
      be interrupted and it will be assigned to the first unprocessed ancestor.

      If [baton] is set to [true] in the transition being updated, the baton will
      be passed to the next transition with [Substate.Processing (Substate.In_progress _)]
      and transitions in between will get restarted.  *)
  let update_to_processing_done ~transition_states ~state_hash ~dsu
      ?(reuse_ctx = false) res =
    let%bind.Option st = Transition_states.find transition_states state_hash in
    let%bind.Option { substate; baton } = F.to_data st in
    let meta = Transition_state.State_functions.transition_meta st in
    let%map.Option ctx_opt =
      match substate.status with
      | Processing ctx when reuse_ctx ->
          Some (Some ctx)
      | Processing _ | Failed _ ->
          Some None
      | _ ->
          None
    in
    let substate = { substate with status = Processing (Done res) } in
    Transition_states.update transition_states
      (F.update { substate; baton = false } st) ;
    if baton then
      let deps =
        collect_dependent_and_pass_the_baton_by_hash ~dsu ~transition_states
          meta.parent_state_hash
      in
      Option.value_map
        ~f:(try_to_reuse ~transition_states deps)
        ~default:deps ctx_opt
    else (
      pass_ctx_to_next_unprocessed ~transition_states ~dsu
        meta.parent_state_hash ctx_opt ;
      [] )

  (** Update status to [Substate.Failed].

      If [baton] is set to [true] in the transition being updated the baton
      will be passed to the next transition with
      [Substate.Processing (Substate.In_progress _)] and transitions in between will
      get restarted.  *)
  let update_to_failed ~transition_states ~state_hash ~dsu error =
    let%bind.Option st = Transition_states.find transition_states state_hash in
    let%bind.Option { substate; baton } = F.to_data st in
    let%map.Option () =
      match substate.status with
      | Processing (In_progress _) | Failed _ ->
          Some ()
      | _ ->
          None
    in
    let substate = { substate with status = Failed error } in
    let st = F.ignore_gossip @@ F.update { substate; baton = false } st in
    Transition_states.update transition_states st ;
    if baton then
      collect_dependent_and_pass_the_baton ~dsu ~transition_states st
    else []

  (** [upon_f] is a callback to be executed upon completion of
  blockchain proof verification (or a failure).
*)
  let rec upon_f ~context ~actions ~transition_states ~state_hashes ~holder res
      =
    let (module Context : CONTEXT) = context in
    let top_state_hash = !holder in
    let fail e =
      (* Top state hash will be set to Failed only if it was Processing/Failed before this point *)
      update_to_failed ~dsu:Context.processed_dsu ~transition_states
        ~state_hash:top_state_hash e
      |> Option.iter ~f:(start ~context ~actions ~transition_states)
    in
    let fail_if_unequal_lengths = function
      | List.Or_unequal_lengths.Ok a ->
          a
      | Unequal_lengths ->
          fail
            (Error.of_string "result length is unequal to state hashes length")
    in
    match res with
    | Result.Error () ->
        fail (Error.of_string "interrupted")
    | Result.Ok (Result.Ok lst) ->
        List.iter2 state_hashes lst ~f:(fun state_hash res ->
            let for_restart_opt =
              update_to_processing_done ~transition_states ~state_hash
                ~dsu:Context.processed_dsu
                ~reuse_ctx:State_hash.(state_hash <> top_state_hash)
                res
            in
            Option.iter for_restart_opt ~f:(fun for_restart ->
                start ~context ~actions ~transition_states for_restart ;
                actions.Misc.mark_processed_and_promote [ state_hash ]
                  ~reason:("verified " ^ F.data_name) ) )
        |> fail_if_unequal_lengths
    | Result.Ok (Result.Error (`Invalid_proof e)) ->
        (* We mark invalid only the top header because it is the only one for which
           we can be sure it's invalid. *)
        actions.Misc.mark_invalid
          ~error:(Error.tag ~tag:("invalid " ^ F.data_name) e)
          top_state_hash
    | Result.Ok (Result.Error (`Verifier_error e)) ->
        fail e

  and launch_in_progress ~context ~actions ~transition_states states =
    let top_state = List.last_exn states in
    let top_state_hash =
      (Transition_state.State_functions.transition_meta top_state).state_hash
    in
    let holder = ref top_state_hash in
    let state_hashes = List.map ~f:get_state_hash states in
    let ctx, action = F.create_in_progress_context ~context ~holder states in
    Async_kernel.Deferred.upon action
    @@ upon_f ~context ~actions ~transition_states ~state_hashes ~holder ;
    ctx

  and start ~context ~actions ~transition_states states =
    Option.value ~default:()
    @@ let%map.Option top_state = List.last states in
       let top_state_hash =
         (Transition_state.State_functions.transition_meta top_state).state_hash
       in
       match F.to_data top_state with
       | Some
           ( { substate = { status = Processing Dependent; _ } as substate; _ }
           as r )
       | Some ({ substate = { status = Failed _; _ } as substate; _ } as r) ->
           let ctx =
             launch_in_progress ~context ~actions ~transition_states states
           in
           Transition_states.update transition_states
             (F.update
                { r with substate = { substate with status = Processing ctx } }
                top_state )
       | Some { substate = { status; _ }; _ } ->
           let (module Context : CONTEXT) = context in
           [%log' error Context.logger]
             "Unexpected status %s (Verifying_blockchain_proof) for \
              $state_hash in Verifying_blockchain_proof.start"
             (Substate.name_of_status status)
             ~metadata:[ ("state_hash", State_hash.to_yojson top_state_hash) ]
       | None ->
           let (module Context : CONTEXT) = context in
           [%log' error Context.logger]
             "Unexpected state %s for $state_hash in \
              Verifying_blockchain_proof.start"
             (Transition_state.name top_state)
             ~metadata:[ ("state_hash", State_hash.to_yojson top_state_hash) ]
end
