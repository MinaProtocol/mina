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
  let collect_dependent_and_pass_the_baton ~logger ~transition_states ~dsu
      top_state =
    let state_hash_json st =
      State_hash.to_yojson
        (Transition_state.State_functions.transition_meta st).state_hash
    in
    let collected =
      Processed_skipping.collect_to_in_progress ~logger ~state_functions
        ~transition_states ~dsu top_state
    in
    let data_opt = Option.bind ~f:F.to_data (List.hd collected) in
    match (collected, data_opt) with
    | ancestor :: _, None ->
        [%log error]
          "collect_to_in_progress returned ancestor $ancestor_hash of state %s \
           for top state $state_hash of state %s (verifying %s)"
          (Transition_state.State_functions.name ancestor)
          (Transition_state.State_functions.name top_state)
          F.data_name
          ~metadata:
            [ ("state_hash", state_hash_json top_state)
            ; ("ancestor_hash", state_hash_json ancestor)
            ] ;
        []
    | ( ancestor :: rest
      , Some
          { substate = { status = Processing (In_progress _); _ } as substate
          ; baton
          } ) ->
        if not baton then (
          [%log debug]
            "Pass the baton for $state_hash with status processing (in \
             progress) (state: %s)"
            (Transition_state.State_functions.name ancestor)
            ~metadata:[ ("state_hash", state_hash_json ancestor) ] ;
          Transition_states.update transition_states
            (F.update { substate; baton = true } ancestor) ) ;
        rest
    | _ ->
        collected

  (** Try to reuse processing context to handle some of 
      ancestors due for restart.
      
      Function takes a list of ancestors due to restart (in parent-first order)
      and returns a prefix of it with transitions that can't be covered
      by the processing context provided.

      If some transitions can be handled with given context, top transition
      will be assigned to this context and
      [Substate.Processing (Substate.In_progress ctx)] status.
      *)
  let try_to_reuse ~logger ~transition_states ts ctx =
    match ctx with
    | Substate.In_progress { downto_; interrupt_ivar; holder; _ } ->
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
          let status = Substate.Processing ctx in
          let metadata =
            Substate.add_error_if_failed ~tag:"old_status_error" substate.status
            @@ Substate.add_error_if_failed ~tag:"new_status_error" status
            @@ [ ("state_hash", State_hash.to_yojson meta.state_hash) ]
          in
          [%log debug]
            "Updating status of $state_hash from %s to %s (state: %s), setting \
             baton to false"
            (Substate.name_of_status substate.status)
            (Substate.name_of_status status)
            (Transition_state.State_functions.name st)
            ~metadata ;
          Transition_states.update transition_states
            (F.update
               { substate = { substate with status }; baton = false }
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
  let collect_dependent_and_pass_the_baton_by_hash ~logger ~dsu
      ~transition_states state_hash =
    Option.value ~default:[]
    @@ let%bind.Option p =
         Transition_states.find transition_states state_hash
       in
       let%map.Option _ = F.to_data p in
       collect_dependent_and_pass_the_baton ~dsu ~transition_states ~logger p

  (* TODO Formal proof why we pass context to next unprocessed and if it
     isn't possible, then context is useless *)

  (** Pass processing context to the next unprocessed state.
      If the next unprocessed state is in [Substate.Processing (Substate.In_progress )]
      status or if it's below context's [downto_] field, context is canceled
      and no transition gets updated.
  *)
  let pass_ctx_to_next_unprocessed ~logger ~transition_states ~dsu parent_hash
      ctx_opt =
    Option.iter ~f:Fn.id
    @@ let%bind.Option ctx = ctx_opt in
       let%bind.Option parent =
         Transition_states.find transition_states parent_hash
       in
       let%bind.Option next =
         Processed_skipping.next_unprocessed ~logger ~state_functions
           ~transition_states ~dsu parent
       in
       let%map.Option { substate; _ } = F.to_data next in
       let next_meta = Transition_state.State_functions.transition_meta next in
       match (ctx, substate.status) with
       | Substate.In_progress { interrupt_ivar; _ }, Processing (In_progress _)
         ->
           Async_kernel.Ivar.fill_if_empty interrupt_ivar ()
       | In_progress { downto_; _ }, _
         when Mina_numbers.Length.(next_meta.blockchain_length >= downto_) ->
           let status = Substate.Processing ctx in
           let metadata =
             Substate.add_error_if_failed ~tag:"old_status_error"
               substate.status
             @@ Substate.add_error_if_failed ~tag:"new_status_error" status
             @@ [ ("state_hash", State_hash.to_yojson next_meta.state_hash) ]
           in
           [%log debug]
             "Updating status of $state_hash from %s to %s (state: %s), \
              setting baton to false"
             (Substate.name_of_status substate.status)
             (Substate.name_of_status status)
             (Transition_state.State_functions.name next)
             ~metadata ;
           Transition_states.update transition_states
             (F.update
                { substate = { substate with status }; baton = false }
                next )
       | _ ->
           ()

  (** Update status to [Substate.Processing (Substate.Done _)]. 
      
      If [reuse_ctx] is [true], if there is an [Substate.In_progress] context and
      there is an unprocessed ancestor covered by this active progress, action won't
      be interrupted and it will be assigned to the first unprocessed ancestor.

      If [reuse_ctx] is [false] and [Substate.In_progress] context exists, it will be ignored.

      If [baton] is set to [true] in the transition being updated, the baton will
      be passed to the next transition with [Substate.Processing (Substate.In_progress _)]
      and transitions in between will get restarted.  *)
  let update_to_processing_done ~logger ~transition_states ~state_hash ~dsu
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
    let status = Substate.Processing (Done res) in
    let metadata =
      Substate.add_error_if_failed ~tag:"old_status_error" substate.status
      @@ Substate.add_error_if_failed ~tag:"new_status_error" status
      @@ [ ("state_hash", State_hash.to_yojson state_hash) ]
    in
    [%log debug]
      "Updating status of $state_hash from %s to %s (state: %s), setting baton \
       to false"
      (Substate.name_of_status substate.status)
      (Substate.name_of_status status)
      (Transition_state.State_functions.name st)
      ~metadata ;
    Transition_states.update transition_states
      (F.update { substate = { substate with status }; baton = false } st) ;
    if baton then
      let deps =
        collect_dependent_and_pass_the_baton_by_hash ~logger ~dsu
          ~transition_states meta.parent_state_hash
      in
      Option.value_map
        ~f:(try_to_reuse ~logger ~transition_states deps)
        ~default:deps ctx_opt
    else (
      pass_ctx_to_next_unprocessed ~logger ~transition_states ~dsu
        meta.parent_state_hash ctx_opt ;
      [] )

  (** Update status to [Substate.Failed].

      If [baton] is set to [true] in the transition being updated the baton
      will be passed to the next transition with
      [Substate.Processing (Substate.In_progress _)] and transitions in between will
      get restarted.  *)
  let update_to_failed ~logger ~transition_states ~state_hash ~dsu error =
    let%bind.Option st = Transition_states.find transition_states state_hash in
    let%bind.Option { substate; baton } = F.to_data st in
    let%map.Option () =
      match substate.status with
      | Processing (In_progress _) | Failed _ ->
          Some ()
      | _ ->
          None
    in
    let status = Substate.Failed error in
    let metadata =
      Substate.add_error_if_failed ~tag:"old_status_error" substate.status
      @@ Substate.add_error_if_failed ~tag:"new_status_error" status
      @@ [ ("state_hash", State_hash.to_yojson state_hash) ]
    in
    [%log debug] "Updating status of $state_hash from %s to %s (state: %s)"
      (Substate.name_of_status substate.status)
      (Substate.name_of_status status)
      (Transition_state.State_functions.name st)
      ~metadata ;
    let substate = { substate with status } in
    let st = F.ignore_gossip @@ F.update { substate; baton = false } st in
    Transition_states.update transition_states st ;
    if baton then
      collect_dependent_and_pass_the_baton ~logger ~dsu ~transition_states st
    else []

  (** [upon_f] is a callback to be executed upon completion of
  blockchain proof verification (or a failure).
*)
  let rec upon_f ~context ~transition_states ~state_hashes ~holder (actions, res)
      =
    let (module Context : CONTEXT) = context in
    let top_state_hash = !holder in
    let fail e =
      (* Top state hash will be set to Failed only if it was Processing/Failed before this point *)
      update_to_failed ~logger:Context.logger ~dsu:Context.processed_dsu
        ~transition_states ~state_hash:top_state_hash e
      |> Option.iter
           ~f:
             (start ~context
                ~actions:(Async_kernel.Deferred.return actions)
                ~transition_states )
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
        List.iter2 (Mina_stdlib.Nonempty_list.to_list state_hashes) lst
          ~f:(fun state_hash res ->
            let for_restart_opt =
              update_to_processing_done ~logger:Context.logger
                ~transition_states ~state_hash ~dsu:Context.processed_dsu
                ~reuse_ctx:State_hash.(state_hash <> top_state_hash)
                res
            in
            Option.iter for_restart_opt ~f:(fun for_restart ->
                start ~context
                  ~actions:(Async_kernel.Deferred.return actions)
                  ~transition_states for_restart ;
                actions.Misc.mark_processed_and_promote [ state_hash ]
                  ~reason:("verified " ^ F.data_name) ) )
        |> fail_if_unequal_lengths
    | Ok (Error (`Invalid_proof e)) ->
        (* We mark invalid only the top header because it is the only one for which
           we can be sure it's invalid. *)
        actions.Misc.mark_invalid
          ~error:(Error.tag ~tag:("invalid " ^ F.data_name) e)
          top_state_hash
    | Ok (Error (`Verifier_error e)) ->
        fail e
    | Ok (Error `Late_to_start) ->
        ()

  and launch_in_progress ~context ~actions ~transition_states states =
    let top_state = Mina_stdlib.Nonempty_list.last states in
    let top_state_hash =
      (Transition_state.State_functions.transition_meta top_state).state_hash
    in
    let holder = ref top_state_hash in
    let state_hashes = Mina_stdlib.Nonempty_list.map ~f:get_state_hash states in
    let bottom_state = Mina_stdlib.Nonempty_list.head states in
    let downto_ =
      (Transition_state.State_functions.transition_meta bottom_state)
        .blockchain_length
    in
    let module I = Interruptible.Make () in
    let process_f () = F.verify ~context (module I) states in
    let upon_f = upon_f ~context ~transition_states ~state_hashes ~holder in
    let processing_status =
      controlling_bandwidth ~resource:`Verifier ~context ~actions
        ~transition_states ~state_hash:top_state_hash ~process_f ~upon_f
        ~same_state_level:(Fn.compose Option.is_some F.to_data)
        (module I)
    in
    Substate.In_progress
      { interrupt_ivar = I.interrupt_ivar; processing_status; downto_; holder }

  and start_batch ~context ~actions ~transition_states states =
    let (module Context : CONTEXT) = context in
    let top_state = Mina_stdlib.Nonempty_list.last states in
    let top_state_hash =
      (Transition_state.State_functions.transition_meta top_state).state_hash
    in
    match F.to_data top_state with
    | Some
        ( { substate = { status = Processing Dependent as old_status; _ } as s
          ; _
          } as r )
    | Some ({ substate = { status = Failed _ as old_status; _ } as s; _ } as r)
      ->
        let ctx =
          launch_in_progress ~context ~actions ~transition_states states
        in
        let status = Substate.Processing ctx in
        let metadata =
          Substate.add_error_if_failed ~tag:"old_status_error" old_status
          @@ Substate.add_error_if_failed ~tag:"new_status_error" status
          @@ [ ("state_hash", State_hash.to_yojson top_state_hash) ]
        in
        [%log' debug Context.logger]
          "Updating status of $state_hash from %s to %s (state: %s)"
          (Substate.name_of_status old_status)
          (Substate.name_of_status status)
          (Transition_state.State_functions.name top_state)
          ~metadata ;
        let r' = { r with substate = { s with status } } in
        Transition_states.update transition_states (F.update r' top_state)
    | Some { substate = { status; _ }; _ } ->
        [%log' error Context.logger]
          "Unexpected status %s (verifying %s) for $state_hash"
          (Substate.name_of_status status)
          F.data_name
          ~metadata:[ ("state_hash", State_hash.to_yojson top_state_hash) ]
    | None ->
        [%log' error Context.logger] "Unexpected state %s for $state_hash"
          (Transition_state.State_functions.name top_state)
          ~metadata:[ ("state_hash", State_hash.to_yojson top_state_hash) ]

  and start_impl ~context ~actions ~transition_states =
    let f = start_batch ~context ~actions ~transition_states in
    Fn.compose (Mina_stdlib.Nonempty_list.iter ~f) (F.split_to_batches ~context)

  and start ~context ~actions ~transition_states =
    Fn.compose
      (Option.value_map ~default:()
         ~f:(start_impl ~context ~actions ~transition_states) )
      Mina_stdlib.Nonempty_list.of_list_opt
end
