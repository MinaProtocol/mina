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

(** Preserve body in the transition's state.
    
    Function is called when a gossip with a body is received or
    when a transition is retrieved through ancestry retrieval with a body
    (i.e. via using old RPCs).

    In case of [Transition_state.Downloading_body] state in [Substate.Failed] or
    [Substate.Processing (Substate.In_progress _)] statuses, status is changed
    to [Substate.Processing (Substate.Done _)] and [`Mark_downloading_body_processed]
    hint is returned. Returned hint is [`Nop] otherwise.
*)
let preserve_body ~body = function
  | Transition_state.Received r ->
      (Transition_state.Received { r with body_opt = Some body }, `Nop)
  | Verifying_blockchain_proof r ->
      (Verifying_blockchain_proof { r with body_opt = Some body }, `Nop)
  | Downloading_body
      ({ substate = { status = Processing (In_progress ctx); _ } as s; _ } as r)
    ->
      ( Downloading_body
          { r with substate = { s with status = Processing (Done body) } }
      , `Mark_downloading_body_processed (Some ctx.interrupt_ivar) )
  | Downloading_body ({ substate = { status = Failed _; _ } as s; _ } as r) ->
      ( Downloading_body
          { r with substate = { s with status = Processing (Done body) } }
      , `Mark_downloading_body_processed None )
  | st ->
      (st, `Nop)

(** [preserve_relevant_gossip] takes data of a recently received gossip related to a
    transition already present in the catchup state. It preserves useful data of gossip
    in the catchup state.
    
    Function returns a pair of a new transition state and a hint of further action to be
    performed in case the gossiped data triggering a change of state.
    *)
let preserve_relevant_gossip ?body:body_opt ?vc:vc_opt ~context ~gossip_type
    ~gossip_header st =
  let (module Ctx : CONTEXT) = context in
  let state_hash =
    (Transition_state.State_functions.transition_meta st).state_hash
  in
  let consensus_state =
    Fn.compose Mina_state.Protocol_state.consensus_state
      Mina_block.Header.protocol_state
  in
  let fire_callback =
    Option.value_map ~f:Mina_net2.Validation_callback.fire_if_not_already_fired
      ~default:ignore vc_opt
  in
  let update_gossip_data =
    match vc_opt with
    | Some _ when Transition_state.is_failed st ->
        fire_callback `Ignore ;
        Fn.id
    | None ->
        Fn.id
    | Some vc ->
        update_gossip_data ~logger:Ctx.logger ~state_hash ~vc ~gossip_type
  in
  let update_block_vc =
    match gossip_type with
    | `Block when Transition_state.is_failed st ->
        fire_callback `Ignore ;
        ident
    | `Block ->
        Option.first_some vc_opt
    | _ ->
        ident
  in
  let accept_header consensus_state =
    match gossip_type with
    | `Block ->
        ()
    | `Header ->
        Option.iter vc_opt ~f:(fun valid_cb ->
            Context.accept_gossip ~context ~valid_cb consensus_state )
  in
  let st =
    Transition_state.modify_aux_data st ~f:(fun d ->
        { d with received_via_gossip = true } )
  in
  let st, pre_decision =
    Option.value_map
      ~default:(st, `Nop)
      ~f:(fun body -> preserve_body ~body st)
      body_opt
  in
  match (st, pre_decision) with
  | Transition_state.Invalid _, `Nop ->
      fire_callback `Reject ;
      (st, `Nop)
  | Received ({ gossip_data; _ } as r), `Nop ->
      ( Received
          { r with
            gossip_data = update_gossip_data gossip_data
          ; header = Initial_valid gossip_header
          }
      , `Nop )
  | ( Verifying_blockchain_proof
        ({ gossip_data; substate = { status = Failed _; _ }; _ } as r)
    , `Nop )
  | ( Verifying_blockchain_proof
        ({ gossip_data; substate = { status = Processing _; _ }; _ } as r)
    , `Nop ) ->
      ( Verifying_blockchain_proof
          { r with gossip_data = update_gossip_data gossip_data; baton = true }
      , `Mark_verifying_blockchain_proof_processed gossip_header )
  | Verifying_blockchain_proof ({ gossip_data; _ } as r), `Nop ->
      ( Verifying_blockchain_proof
          { r with gossip_data = update_gossip_data gossip_data; baton = true }
      , `Nop )
  | Downloading_body ({ block_vc; header; _ } as r), _ ->
      accept_header (consensus_state @@ Mina_block.Validation.header header) ;
      ( Transition_state.Downloading_body
          { r with block_vc = update_block_vc block_vc; baton = true }
      , pre_decision )
  | ( Verifying_complete_works
        ( { block_vc; block; substate = { status = Processing Dependent; _ }; _ }
        as r )
    , `Nop )
  | ( Verifying_complete_works
        ({ block_vc; block; substate = { status = Failed _; _ }; _ } as r)
    , `Nop ) ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      ( Verifying_complete_works
          { r with block_vc = update_block_vc block_vc; baton = true }
      , `Start_processing_verifying_complete_works
          (State_hash.With_state_hashes.state_hash
             (Mina_block.Validation.block_with_hash block) ) )
  | Verifying_complete_works ({ block_vc; block; _ } as r), `Nop ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      ( Verifying_complete_works
          { r with block_vc = update_block_vc block_vc; baton = true }
      , `Nop )
  | Building_breadcrumb ({ block_vc; block; _ } as r), `Nop ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      (Building_breadcrumb { r with block_vc = update_block_vc block_vc }, `Nop)
  | Waiting_to_be_added_to_frontier { breadcrumb; _ }, `Nop ->
      let consensus_state =
        consensus_state
        @@ Mina_block.(header @@ Frontier_base.Breadcrumb.block breadcrumb)
      in
      Option.iter vc_opt ~f:(fun valid_cb ->
          accept_gossip ~context ~valid_cb consensus_state ) ;
      (st, `Nop)
  | _, `Mark_downloading_body_processed _ ->
      failwith "Mark_downloading_body_processed: unexpected case"
