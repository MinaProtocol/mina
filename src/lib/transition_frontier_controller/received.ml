open Mina_base
open Core_kernel
open Async
open Context

let ancestry_download_timeout = Time.Span.of_sec 30.

let verify_header_is_relevant ~context:(module Context : CONTEXT) ~sender ~state
    header_with_hash =
  let open Transition_handler.Validator in
  let hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let relevance_result =
    let%bind.Result () =
      Option.value_map (Hashtbl.find state.transition_states hash)
        ~default:(Ok ()) ~f:(fun st -> Error (`In_process st))
    in
    verify_header_is_relevant
      ~context:(module Context)
      ~frontier:Context.frontier header_with_hash
  in
  let open Context in
  let record_irrelevant error =
    don't_wait_for
    @@ record_transition_is_irrelevant ~logger ~trust_system ~sender ~error
         header_with_hash
  in
  (* This action is deferred because it may potentially trigger change of ban status
     of a peer which requires writing to a synchonous pipe. *)
  (* Although it's not evident from types, banning may be triiggered only for irrelevant
     case, hence it's safe to do don't_wait_for *)
  match relevance_result with
  | Ok () ->
      don't_wait_for
        (record_transition_is_relevant ~logger ~trust_system ~sender
           ~time_controller header_with_hash ) ;
      `Relevant
  | Error (`In_process (Transition_state.Invalid _) as error) ->
      record_irrelevant error ; `Irrelevant
  | Error (`In_process _ as error) ->
      record_irrelevant error ; `Preserve_gossip_data
  | Error error ->
      record_irrelevant error ; `Irrelevant

let mark_child_done ~transition_states child_hash =
  let%bind.Option child = State_hash.Table.find transition_states child_hash in
  let%bind.Option child' =
    match child with
    | Transition_state.Received
        ({ substate = { status = Processing _; _ } as s; _ } as r) ->
        Some
          (Transition_state.Received
             { r with substate = { s with status = Processing (Done ()) } } )
    | _ ->
        None
  in
  State_hash.Table.set transition_states ~key:child_hash ~data:child' ;
  match child with
  | Transition_state.Received
      { substate = { status = Processing (In_progress ctx); _ }; _ } ->
      Some (ctx.timeout, ctx.interrupt_ivar)
  | _ ->
      None

let to_gossip_data ?gossip_type vc_opt =
  Option.value ~default:Transition_state.Not_a_gossip
  @@ let%bind.Option gt = gossip_type in
     let%map.Option vc = vc_opt in
     match gt with
     | `Header ->
         Transition_state.Gossiped_header vc
     | `Block ->
         Gossiped_block vc

(* Pre-condition: state transition is neither in frontier nor in state *)
let add_received ~context:(module Context : CONTEXT) ~mark_processed_and_promote
    ~sender ~state ?gossip_type ?vc ?body:body_opt received_header =
  let transition_states = state.transition_states in
  let header_with_hash =
    Transition_state.header_with_hash_of_received_header received_header
  in
  let header = With_hash.data header_with_hash in
  let state_hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let parent_hash =
    Mina_block.Header.protocol_state header
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let parent_opt = State_hash.Table.find state.transition_states parent_hash in
  let children_list =
    Option.value ~default:[] @@ Hashtbl.find state.orphans state_hash
  in
  let received_at = Time.now () in
  (* [invariant] children.processed = children.waiting_for_parent = empty *)
  let children =
    { Substate.empty_children_sets with
      processing_or_failed = State_hash.Set.of_list children_list
    }
  in
  let child_contexts =
    List.filter_map children_list ~f:(mark_child_done ~transition_states)
  in
  let max_timeout =
    Time.add
      (List.fold ~init:received_at child_contexts ~f:(fun t (timeout, _) ->
           Time.max t timeout ) )
      ancestry_download_timeout
  in
  let timeout =
    Time.min max_timeout @@ Time.add received_at
    @@ Time.Span.scale ancestry_download_timeout 2.
  in
  let interrupt_ivar =
    let module I = Interruptible.Make () in
    let action =
      if List.is_empty child_contexts then
        (* TODO Launch retrieval of ancestry  *)
        I.return ()
      else
        (* We rely on one of children to retrieve ancestry and
           launch downloading ourselves only in case children timed out *)
        let%bind.I () = I.lift (after ancestry_download_timeout) in
        (* TODO check if parent is present in state and shortcircuit if it does *)
        (* TODO Launch retrieval of ancestry  *)
        (* TODO cancel child contexts after successful retrieval *)
        I.return ()
    in
    Interruptible.don't_wait_for
    @@ I.finally action ~f:(fun () ->
           List.iter child_contexts ~f:(fun (_, interrupt_ivar) ->
               Ivar.fill_if_empty interrupt_ivar () ) ;
           Timeout_controller.unregister ~state_hash ~timeout
             Context.timeout_controller ) ;
    I.interrupt_ivar
  in
  let status =
    if Option.is_some parent_opt then Substate.Processed ()
    else Processing (In_progress { timeout; interrupt_ivar })
  in
  Hashtbl.remove state.orphans state_hash ;
  Hashtbl.add_exn transition_states ~key:state_hash
    ~data:
      (Received
         { body_opt
         ; header = received_header
         ; gossip_data = to_gossip_data ?gossip_type vc
         ; substate =
             { children
             ; received_via_gossip = Option.is_some gossip_type
             ; status
             ; sender
             ; received_at
             }
         } ) ;
  Timeout_controller.register ~state_functions ~transition_states ~state_hash
    ~timeout Context.timeout_controller ;
  mark_processed_and_promote children_list

let update_gossip_data ~context:(module Context : Context.CONTEXT) ~hash ~vc
    ~gossip_type old =
  let log_duplicate () =
    [%log' warn Context.logger] "Duplicate %s gossip for $state_hash"
      (match gossip_type with `Block -> "block" | `Header -> "header")
      ~metadata:[ ("state_hash", State_hash.to_yojson hash) ]
  in
  match (gossip_type, old) with
  | `Block, Transition_state.Gossiped_header header_vc ->
      Transition_state.Gossiped_both { block_vc = vc; header_vc }
  | `Header, Transition_state.Gossiped_block block_vc ->
      Gossiped_both { block_vc; header_vc = vc }
  | `Block, Transition_state.Not_a_gossip ->
      Gossiped_block vc
  | `Header, Transition_state.Not_a_gossip ->
      Gossiped_header vc
  | `Header, Transition_state.Gossiped_header _ ->
      log_duplicate () ; old
  | `Header, Transition_state.Gossiped_both _ ->
      log_duplicate () ; old
  | `Block, Transition_state.Gossiped_block _ ->
      log_duplicate () ; old
  | `Block, Transition_state.Gossiped_both _ ->
      log_duplicate () ; old

let preserve_relevant_gossip ?body:body_opt ?vc:vc_opt ~context ~hash
    ~gossip_type st =
  let update_gossip_data =
    Option.value_map ~default:ident
      ~f:(fun vc -> update_gossip_data ~context ~hash ~vc ~gossip_type)
      vc_opt
  in
  let consensus_state =
    Transition_state.State_functions.header_with_hash st
    |> With_hash.data |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.consensus_state
  in
  let update_body_opt = Option.first_some body_opt in
  let update_block_vc =
    match (gossip_type, vc_opt) with
    | `Block, Some vc ->
        Option.(Fn.compose some @@ value ~default:vc)
    | _ ->
        ident
  in
  let fire_callback =
    Option.value_map ~f:Mina_net2.Validation_callback.fire_if_not_already_fired
      ~default:ignore vc_opt
  in
  let accept_header () =
    match gossip_type with
    | `Block ->
        ()
    | `Header ->
        Option.iter vc_opt ~f:(fun valid_cb ->
            Context.accept_gossip ~context ~valid_cb consensus_state )
  in
  match st with
  | Invalid _ ->
      fire_callback `Reject ;
      st
  | st when Transition_state.is_failed st ->
      fire_callback `Ignore ;
      st
  | Received ({ gossip_data; body_opt; _ } as r) ->
      Received
        { r with
          gossip_data = update_gossip_data gossip_data
        ; body_opt = update_body_opt body_opt
        }
  | Verifying_blockchain_proof ({ gossip_data; body_opt; _ } as r) ->
      Verifying_blockchain_proof
        { r with
          gossip_data = update_gossip_data gossip_data
        ; body_opt = update_body_opt body_opt
        }
  | Downloading_body ({ block_vc; _ } as r) ->
      accept_header () ;
      Downloading_body { r with block_vc = update_block_vc block_vc }
  | Verifying_complete_works ({ block_vc; _ } as r) ->
      accept_header () ;
      Verifying_complete_works { r with block_vc = update_block_vc block_vc }
  | Building_breadcrumb ({ block_vc; _ } as r) ->
      accept_header () ;
      Building_breadcrumb { r with block_vc = update_block_vc block_vc }
  | Waiting_to_be_added_to_frontier _ ->
      Option.iter vc_opt ~f:(fun valid_cb ->
          accept_gossip ~context ~valid_cb consensus_state ) ;
      st

let handle_gossip ~context ~mark_processed_and_promote ~state ~sender ?body
    ~gossip_type ?vc received_header =
  (* TODO try to retrieve body from DB *)
  let header_with_hash =
    Transition_state.header_with_hash_of_received_header received_header
  in
  let hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let relevance_status =
    verify_header_is_relevant ~context ~sender ~state header_with_hash
  in
  match relevance_status with
  | `Relevant ->
      add_received ~mark_processed_and_promote ~context ~sender ~state
        ~gossip_type ?vc ?body received_header
  | `Preserve_gossip_data ->
      Hashtbl.change state.transition_states hash
        ~f:
          (Option.map ~f:(fun st ->
               (* TODO Potentially mark processed *)
               preserve_relevant_gossip ?body ?vc ~context ~hash ~gossip_type st )
          )
  | `Irrelevant ->
      ()

let handle_collected_transition ~context:(module Context : CONTEXT)
    ~mark_processed_and_promote ~state (b_or_h_env, vc) =
  let sender = Network_peer.Envelope.Incoming.sender b_or_h_env in
  let header_with_validation, body, gossip_type =
    match Network_peer.Envelope.Incoming.data b_or_h_env with
    | Bootstrap_controller.Transition_cache.Block block ->
        ( Mina_block.Validation.to_header block
        , Some (Mina_block.body @@ Mina_block.Validation.block block)
        , `Block )
    | Bootstrap_controller.Transition_cache.Header header ->
        (header, None, `Header)
  in
  handle_gossip
    ~context:(module Context)
    ~mark_processed_and_promote ~state ~sender ?vc ?body ~gossip_type
    (Initial_valid header_with_validation)

let handle_network_transition ~context:(module Context : CONTEXT)
    ~mark_processed_and_promote ~state (b_or_h, `Valid_cb vc) =
  let sender, header_with_validation, body, gossip_type =
    match b_or_h with
    | `Block b_env ->
        let block = Network_peer.Envelope.Incoming.data b_env in
        ( Network_peer.Envelope.Incoming.sender b_env
        , Mina_block.Validation.to_header block
        , Some (Mina_block.body @@ Mina_block.Validation.block block)
        , `Block )
    | `Header h_env ->
        let header = Network_peer.Envelope.Incoming.data h_env in
        (Network_peer.Envelope.Incoming.sender h_env, header, None, `Header)
  in
  handle_gossip
    ~context:(module Context)
    ~mark_processed_and_promote ~state ~sender ?body ?vc ~gossip_type
    (Initial_valid header_with_validation)
