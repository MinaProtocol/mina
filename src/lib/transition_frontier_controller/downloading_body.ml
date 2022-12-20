open Core_kernel
open Mina_base
open Context
open Bit_catchup_state

(** [update_status_for_unprocessed ~state_hash status] updates status of a transition
  corresponding to [state_hash] that is in [Downloading_body] state.

  When the new [status] is [Failed].
  
  Pre-condition: new [status] is either [Failed] or [Processing].
*)
let rec update_status_for_unprocessed ~context ~transition_states ~actions
    ~state_hash status =
  let (module Context : CONTEXT) = context in
  let f = function
    | Transition_state.Downloading_body
        ({ substate = { status = Failed _ as old_status; _ }; _ } as r)
    | Transition_state.Downloading_body
        ( { substate = { status = Processing (In_progress _) as old_status; _ }
          ; _
          } as r ) -> (
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
          pass_the_baton ~transition_states ~context ~actions parent_hash ;
        let st =
          Transition_state.Downloading_body
            { r with
              substate = { r.substate with status }
            ; block_vc
            ; baton = false
            }
        in
        let metadata =
          Substate.add_error_if_failed ~tag:"old_status_error" old_status
          @@ Substate.add_error_if_failed ~tag:"new_status_error" status
          @@ [ ("state_hash", State_hash.to_yojson state_hash) ]
        in
        [%log' debug Context.logger]
          "Updating status of $state_hash from %s to %s (state: downloading \
           body)"
          (Substate.name_of_status old_status)
          (Substate.name_of_status status)
          ~metadata ;
        Transition_states.update transition_states st ;
        match (status, r.baton) with
        | Failed _, true ->
            restart_failed ~transition_states ~context ~actions st
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
and upon_f ~context ~transition_states ~state_hash (actions_undeferred, res) =
  let actions = Async_kernel.Deferred.return actions_undeferred in
  match res with
  | Result.Error () ->
      update_status_for_unprocessed ~context ~actions ~transition_states
        ~state_hash
        (Failed (Error.of_string "interrupted"))
  | Result.Ok (Result.Ok body) ->
      update_status_for_unprocessed ~context ~actions ~transition_states
        ~state_hash (Processing (Done body)) ;
      actions_undeferred.Misc.mark_processed_and_promote
        ~reason:"downloaded body" [ state_hash ]
  | Result.Ok (Error `Late_to_start) ->
      ()
  | Result.Ok (Error (`Download_error e)) ->
      update_status_for_unprocessed ~context ~actions ~transition_states
        ~state_hash (Failed e)

(** Creates a [Substate.processing_context] for a transition.

  In case of [body_opt] equaling to [Some body], returns [Substate.Done body].

  Otherwise starts downloading body for a transition and returns the
  [Substate.In_progress] context.
*)
and make_download_body_ctx ~preferred_peers ~body_opt ~header ~transition_states
    ~context ~actions =
  let (module Context : CONTEXT) = context in
  let state_hash = state_hash_of_header_with_validation header in
  let wrap_error = Result.map_error ~f:(fun e -> `Download_error e) in
  match body_opt with
  | Some body ->
      Substate.Done body
  | None ->
      let open Context in
      let module I = Interruptible.Make () in
      let upon_f = upon_f ~context ~transition_states ~state_hash in
      let process_f () =
        ( I.map ~f:wrap_error
          @@ Context.download_body
               ~header:(Mina_block.Validation.header_with_hash header)
               ~preferred_peers
               (module I)
        , Time.Span.(bitwap_download_timeout + peer_download_timeout) )
      in
      let downto_ =
        Mina_block.Validation.header header
        |> Mina_block.Header.blockchain_length
      in
      let processing_status =
        controlling_bandwidth ~resource:`Download ~context ~actions
          ~transition_states ~state_hash ~process_f ~upon_f
          (module I)
      in
      Substate.In_progress
        { interrupt_ivar = I.interrupt_ivar
        ; processing_status
        ; downto_
        ; holder = ref state_hash
        }

(** Restart a failed ancestor. This function takes a transition state of ancestor and
    restarts the downloading process for it. *)
and restart_failed ~transition_states ~actions
    ~context:(module Context : CONTEXT) = function
  | Transition_state.Downloading_body
      ( { header
        ; substate = { status = Failed _; _ } as s
        ; aux = { received; _ }
        ; _
        } as r ) ->
      let preferred_peers =
        List.map received ~f:(fun { sender; _ } -> sender)
      in
      let status =
        Substate.Processing
          (make_download_body_ctx ~preferred_peers ~body_opt:None ~header
             ~transition_states ~actions
             ~context:(module Context) )
      in
      let state_hash = state_hash_of_header_with_validation header in
      let metadata =
        Substate.add_error_if_failed ~tag:"old_status_error" s.status
        @@ Substate.add_error_if_failed ~tag:"new_status_error" status
        @@ [ ("state_hash", State_hash.to_yojson state_hash) ]
      in
      [%log' debug Context.logger]
        "Updating status of $state_hash from failed to %s (state: downloading \
         body)"
        (Substate.name_of_status status)
        ~metadata ;
      Transition_states.update transition_states
        (Downloading_body { r with substate = { s with status } })
      (* We don't need to update parent's childen sets because
         Failed -> Processing status change doesn't require that *)
  | st ->
      let viewer Substate.{ status; _ } = Substate.name_of_status status in
      let status_name =
        Option.value ~default:""
        @@ Substate.view ~state_functions ~f:{ viewer } st
      in
      [%log' error Context.logger]
        "unexpected non-failed ancestor for restart: state %s, status %s"
        (Transition_state.State_functions.name st)
        status_name

(** Set [baton] of the next ancestor in [Transition_state.Downloading_body]
    and [Substate.Processing (Substate.In_progress _)] status to [true]
    and restart all the failed ancestors before the next ancestors. *)
and pass_the_baton ~transition_states ~context ~actions =
  let (module Context : CONTEXT) = context in
  let restart_f = restart_failed ~transition_states ~actions ~context in
  let handle_collected = function
    | Transition_state.Downloading_body
        ({ substate = { status = Processing _; _ }; _ } as r)
      :: rest ->
        if not r.baton then (
          let state_hash = state_hash_of_header_with_validation r.header in
          [%log' debug Context.logger]
            "Pass the baton for $state_hash with status %s (state: downloading \
             body)"
            (Substate.name_of_status r.substate.status)
            ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
          Transition_states.update transition_states
            (Downloading_body { r with baton = true }) ) ;
        List.iter ~f:restart_f rest
    | collected ->
        List.iter ~f:restart_f collected
  in
  let handle_state = function
    | Some (Transition_state.Downloading_body _ as st) ->
        Processed_skipping.collect_to_in_progress ~logger:Context.logger
          ~state_functions ~transition_states ~dsu:Context.processed_dsu st
        |> handle_collected
    | _ ->
        ()
  in
  Fn.compose handle_state (Transition_states.find transition_states)

(** Promote a transition that is in [Transition_state.Verifying_blockchain_proof] state with
    [Substate.Processed] status to [Transition_state.Downloading_body] state.
*)
let promote_to ~context ~actions ~transition_states ~substate ~gossip_data
    ~body_opt ~aux =
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
  let { Transition_state.received; _ } = aux in
  let preferred_peers = List.map received ~f:(fun { sender; _ } -> sender) in
  let ctx =
    make_download_body_ctx ~preferred_peers ~body_opt ~header ~transition_states
      ~actions ~context
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
    pass_the_baton ~transition_states ~context ~actions
      (Mina_state.Protocol_state.previous_state_hash protocol_state) ;
  Transition_state.Downloading_body
    { header; substate; block_vc; baton = false; aux }
