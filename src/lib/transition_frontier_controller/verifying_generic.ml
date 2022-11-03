open Mina_base
open Core_kernel
open Context

type 'a data = { substate : 'a Substate_types.t; baton : bool }

module Make (F : sig
  type proceessing_result

  val ignore_gossip : Transition_state.t -> Transition_state.t

  val to_data : Transition_state.t -> proceessing_result data option

  val update :
    proceessing_result data -> Transition_state.t -> Transition_state.t
end) =
struct
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
               let key =
                 (Transition_state.State_functions.transition_meta ancestor)
                   .state_hash
               in
               State_hash.Table.set transition_states ~key
                 ~data:(F.update { substate; baton = true } ancestor) ;
               rest
           | _ ->
               ancestor :: rest )
    | _ ->
        []

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
          State_hash.Table.set transition_states ~key:meta.state_hash
            ~data:
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

  let collect_dependent_and_pass_the_baton_by_hash ~dsu ~transition_states
      state_hash =
    Option.value ~default:[]
    @@ let%bind.Option p = State_hash.Table.find transition_states state_hash in
       let%map.Option _ = F.to_data p in
       collect_dependent_and_pass_the_baton ~dsu ~transition_states p

  let pass_ctx_to_next_unprocessed ~transition_states ~dsu parent_hash ctx_opt =
    Option.iter ~f:Fn.id
    @@ let%bind.Option ctx = ctx_opt in
       let%bind.Option parent =
         State_hash.Table.find transition_states parent_hash
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
           State_hash.Table.set transition_states ~key:parent_hash
             ~data:
               (F.update
                  { substate = { substate with status = Processing ctx }
                  ; baton = false
                  }
                  next )
       | _ ->
           ()

  let update_to_processing_done ~transition_states ~state_hash ~dsu
      ?(reuse_ctx = false) ?(force_baton = false) res =
    let%bind.Option st = State_hash.Table.find transition_states state_hash in
    let%bind.Option { substate; baton = prev_baton } = F.to_data st in
    let baton = force_baton || prev_baton in
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
    State_hash.Table.set transition_states ~key:state_hash
      ~data:(F.update { substate; baton = false } st) ;
    if baton then
      let deps =
        collect_dependent_and_pass_the_baton_by_hash ~dsu ~transition_states
          meta.parent_state_hash
      in
      Option.value_map
        ~f:(try_to_reuse ~transition_states deps)
        ~default:deps ctx_opt
    else (
      (* TODO Formal proof why we pass context to next unprocessed and if it
         isn't possible, then context is useless *)
      pass_ctx_to_next_unprocessed ~transition_states ~dsu
        meta.parent_state_hash ctx_opt ;
      [] )

  let update_to_failed ~transition_states ~state_hash ~dsu error =
    let%bind.Option st = State_hash.Table.find transition_states state_hash in
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
    State_hash.Table.set transition_states ~key:state_hash ~data:st ;
    if baton then
      collect_dependent_and_pass_the_baton ~dsu ~transition_states st
    else []
end
