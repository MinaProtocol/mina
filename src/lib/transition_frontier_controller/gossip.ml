open Mina_base
open Core_kernel
open Async
open Context
include Gossip_types

(** Determine if the header received via gossip is relevant
    (to be added to catchup state), irrelevant (to be ignored)
    or contains some useful data to be preserved 
    (in case transition is already in catchup state).
  
    Depending on relevance status, metrics are updated for the peer who sent the transition.
*)
let verify_header_is_relevant ~context:(module Context : CONTEXT) ~sender
    ~transition_states header_with_hash =
  let open Transition_handler.Validator in
  let hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let relevance_result =
    let%bind.Result () =
      Option.value_map (Hashtbl.find transition_states hash) ~default:(Ok ())
        ~f:(fun st -> Error (`In_process st))
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

(** [preserve_relevant_gossip] takes data of a recently received gossip related to a
    transition already present in the catchup state. It preserves useful data of gossip
    in the catchup state.
    
    Function returns a pair of a new transition state and a hint of further action to be
    performed in case the gossiped data triggering a change of state.
    *)
let preserve_relevant_gossip ?body:body_opt ?vc:vc_opt ~context ~state_hash
    ?gossip_type ?gossip_header st_orig =
  let (module Ctx : CONTEXT) = context in
  let update_gossip_data =
    Option.value ~default:Fn.id
    @@ let%bind.Option vc = vc_opt in
       let%map.Option gossip_type = gossip_type in
       update_gossip_data ~logger:Ctx.logger ~state_hash ~vc ~gossip_type
  in
  let consensus_state =
    Fn.compose Mina_state.Protocol_state.consensus_state
      Mina_block.Header.protocol_state
  in
  let update_body_opt = Option.first_some body_opt in
  let update_block_vc =
    match (gossip_type, vc_opt) with
    | Some `Block, Some vc ->
        Option.(Fn.compose some @@ value ~default:vc)
    | _ ->
        ident
  in
  let fire_callback =
    Option.value_map ~f:Mina_net2.Validation_callback.fire_if_not_already_fired
      ~default:ignore vc_opt
  in
  let accept_header consensus_state =
    match gossip_type with
    | Some `Block | None ->
        ()
    | Some `Header ->
        Option.iter vc_opt ~f:(fun valid_cb ->
            Context.accept_gossip ~context ~valid_cb consensus_state )
  in
  let st =
    Transition_state.modify_aux_data st_orig ~f:(fun d ->
        { d with received_via_gossip = true } )
  in
  match (st, body_opt, gossip_header) with
  | Transition_state.Invalid _, _, _ ->
      fire_callback `Reject ;
      (st, `Nop)
  | st, _, _ when Transition_state.is_failed st ->
      fire_callback `Ignore ;
      (st, `Nop)
  | Received ({ gossip_data; body_opt; _ } as r), _, _ ->
      ( Received
          { r with
            gossip_data = update_gossip_data gossip_data
          ; body_opt = update_body_opt body_opt
          ; header =
              Option.value_map ~default:r.header
                ~f:(fun h -> Initial_valid h)
                gossip_header
          }
      , `Nop )
  | ( Verifying_blockchain_proof
        ( { gossip_data; body_opt; substate = { status = Processing _; _ }; _ }
        as r )
    , _
    , Some iv_header ) ->
      ( Verifying_blockchain_proof
          { r with
            gossip_data = update_gossip_data gossip_data
          ; body_opt = update_body_opt body_opt
          }
      , `Mark_verifying_blockchain_proof_processed iv_header )
  | Verifying_blockchain_proof ({ gossip_data; body_opt; _ } as r), _, _ ->
      ( Verifying_blockchain_proof
          { r with
            gossip_data = update_gossip_data gossip_data
          ; body_opt = update_body_opt body_opt
          }
      , `Nop )
  | ( Downloading_body
        ( { block_vc
          ; substate = { status = Processing (In_progress ctx); _ } as s
          ; header
          ; _
          } as r )
    , Some body
    , _ ) ->
      accept_header (consensus_state @@ Mina_block.Validation.header header) ;
      ( Downloading_body
          { r with
            block_vc = update_block_vc block_vc
          ; substate = { s with status = Processing (Done body) }
          }
      , `Promote_and_interrupt ctx.interrupt_ivar )
  | Downloading_body ({ block_vc; header; _ } as r), _, _ ->
      accept_header (consensus_state @@ Mina_block.Validation.header header) ;
      (Downloading_body { r with block_vc = update_block_vc block_vc }, `Nop)
  | ( Verifying_complete_works
        ( { block_vc; block; substate = { status = Processing Dependent; _ }; _ }
        as r )
    , _
    , Some _ ) ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      ( Verifying_complete_works { r with block_vc = update_block_vc block_vc }
      , `Start_processing_verifying_complete_works block )
  | Verifying_complete_works ({ block_vc; block; _ } as r), _, _ ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      ( Verifying_complete_works { r with block_vc = update_block_vc block_vc }
      , `Nop )
  | Building_breadcrumb ({ block_vc; block; _ } as r), _, _ ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      (Building_breadcrumb { r with block_vc = update_block_vc block_vc }, `Nop)
  | Waiting_to_be_added_to_frontier { breadcrumb; _ }, _, _ ->
      let consensus_state =
        consensus_state
        @@ Mina_block.(header @@ Frontier_base.Breadcrumb.block breadcrumb)
      in
      Option.iter vc_opt ~f:(fun valid_cb ->
          accept_gossip ~context ~valid_cb consensus_state ) ;
      (st, `Nop)
