open Core_kernel
open Context

(** [update_status_for_unprocessed ~state_hash status] updates status of a transition
  corresponding to [state_hash] that is in [Downloading_body] state.

  When the new [status] is [Failed].
  
  Pre-condition: new [status] is either [Failed] or [Processing].
*)
let rec update_status_for_unprocessed ~context ~transition_states
    ~mark_processed_and_promote ~state_hash status =
  let (module Context : CONTEXT) = context in
  let f = function
    | Transition_state.Downloading_body
        ({ substate = { status = Failed _; _ }; _ } as r)
    | Transition_state.Downloading_body
        ({ substate = { status = Processing (In_progress _); _ }; _ } as r) -> (
        let block_vc =
          match status with
          | Substate.Failed _ ->
              Option.iter r.block_vc
                ~f:
                  (Fn.flip
                     Mina_net2.Validation_callback.fire_if_not_already_fired
                     `Ignore ) ;
              None
          | _ ->
              r.block_vc
        in
        let parent_hash =
          Mina_block.Validation.header r.header
          |> Mina_block.Header.protocol_state
          |> Mina_state.Protocol_state.previous_state_hash
        in
        if r.baton then
          pass_the_baton ~transition_states ~context ~mark_processed_and_promote
            parent_hash ;
        let st =
          Transition_state.Downloading_body
            { r with
              substate = { r.substate with status }
            ; block_vc
            ; baton = false
            }
        in
        Transition_states.update transition_states st ;
        match (status, r.baton) with
        | Failed _, true ->
            restart_failed ~transition_states ~context
              ~mark_processed_and_promote st
        | _ ->
            () )
    | _ ->
        ()
  in
  Option.value_map ~f
    (Transition_states.find transition_states state_hash)
    ~default:()

(** [upon_f] is a callback to be executed upon completion of downloading
  a body (or a failure).
*)
and upon_f ~context ~transition_states ~state_hash ~mark_processed_and_promote =
  function
  | Result.Error () ->
      update_status_for_unprocessed ~context ~mark_processed_and_promote
        ~transition_states ~state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok body) ->
      update_status_for_unprocessed ~context ~mark_processed_and_promote
        ~transition_states ~state_hash (Processing (Done body)) ;
      mark_processed_and_promote [ state_hash ]
  | Result.Ok (Result.Error e) ->
      update_status_for_unprocessed ~context ~mark_processed_and_promote
        ~transition_states ~state_hash (Failed e)

(** Creates a [Substate.processing_context] for a transition.

  In case of [body_opt] equaling to [Some body], returns [Substate.Done body].

  Otherwise starts downloading body for a transition and returns the
  [Substate.In_progress] context.
*)
and make_download_body_ctx ~body_opt ~header ~transition_states ~context
    ~mark_processed_and_promote =
  let (module Context : CONTEXT) = context in
  let state_hash = state_hash_of_header_with_validation header in
  match body_opt with
  | Some body ->
      Substate.Done body
  | None ->
      let open Context in
      let module I = Interruptible.Make () in
      let action = Context.download_body ~header (module I) in
      Async_kernel.Deferred.upon (I.force action)
        (upon_f ~context ~transition_states ~state_hash
           ~mark_processed_and_promote ) ;
      let span = Time.Span.(bitwap_download_timeout + peer_download_timeout) in
      let timeout = Time.(add @@ now ()) span in
      let downto_ =
        Mina_block.Validation.header header
        |> Mina_block.Header.blockchain_length
      in
      interrupt_after_timeout ~timeout I.interrupt_ivar ;
      Substate.In_progress
        { interrupt_ivar = I.interrupt_ivar
        ; timeout
        ; downto_
        ; holder = ref state_hash
        }

(** Restart a failed ancestor. This function takes a transition state of ancestor and
    restarts the downloading process for it. *)
and restart_failed ~transition_states ~mark_processed_and_promote ~context =
  function
  | Transition_state.Downloading_body
      ({ header; substate = { status = Failed _; _ } as s; _ } as r) ->
      let ctx =
        make_download_body_ctx ~body_opt:None ~header ~transition_states
          ~mark_processed_and_promote ~context
      in
      Transition_states.update transition_states
        (Transition_state.Downloading_body
           { r with substate = { s with status = Processing ctx } } )
      (* We don't need to update parent's childen sets because
         Failed -> Processing status change doesn't require that *)
  | _ ->
      failwith
        "promote_verifying_blockchain_proof: unexpected non-failed ancestor"

(** Set [baton] of the next ancestor in [Transition_state.Downloading_body]
    and [Substate.Processing (Substate.In_progress _)] status to [true]
    and restart all the failed ancestors before the next ancestors. *)
and pass_the_baton ~transition_states ~context ~mark_processed_and_promote
    state_hash =
  let restart_f =
    restart_failed ~transition_states ~mark_processed_and_promote ~context
  in
  let (module Context : CONTEXT) = context in
  match Transition_states.find transition_states state_hash with
  | Some (Transition_state.Downloading_body _ as st) -> (
      let collected =
        Processed_skipping.collect_to_in_progress ~state_functions
          ~transition_states ~dsu:Context.processed_dsu st
      in
      match collected with
      | Downloading_body ({ substate = { status = Processing _; _ }; _ } as r)
        :: rest ->
          Transition_states.update transition_states
            (Downloading_body { r with baton = true }) ;
          List.iter ~f:restart_f rest
      | _ ->
          List.iter ~f:restart_f collected )
  | _ ->
      ()

(** Promote a transition that is in [Transition_state.Verifying_blockchain_proof] state with
    [Substate.Processed] status to [Transition_state.Downloading_body] state.
*)
let promote_to ~context ~mark_processed_and_promote ~transition_states ~substate
    ~gossip_data ~body_opt ~aux =
  let header =
    match substate.Substate.status with
    | Processed h ->
        h
    | _ ->
        failwith "promote_verifying_blockchain_proof: expected processed"
  in
  let protocol_state =
    Mina_block.Validation.header header |> Mina_block.Header.protocol_state
  in
  let consensus_state =
    Mina_state.Protocol_state.consensus_state protocol_state
  in
  let ctx =
    make_download_body_ctx ~body_opt ~header ~transition_states
      ~mark_processed_and_promote ~context
  in
  let substate = { substate with status = Processing ctx } in
  let block_vc =
    match gossip_data with
    | Gossip.No_validation_callback ->
        None
    | Gossiped_header vc ->
        accept_gossip ~context ~valid_cb:vc consensus_state ;
        None
    | Gossiped_block vc ->
        Some vc
    | Gossiped_both { block_vc; header_vc } ->
        accept_gossip ~context ~valid_cb:header_vc consensus_state ;
        Some block_vc
  in
  if aux.Transition_state.received_via_gossip then
    pass_the_baton ~transition_states ~context ~mark_processed_and_promote
      (Mina_state.Protocol_state.previous_state_hash protocol_state) ;
  Transition_state.Downloading_body
    { header; substate; block_vc; baton = false; aux }
