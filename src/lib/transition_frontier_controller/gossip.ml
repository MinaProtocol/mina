open Mina_base
open Core_kernel
open Context
open Bit_catchup_state
include Gossip_types

(** Determine if the header received via gossip is relevant
    (to be added to catchup state), irrelevant (to be ignored)
    or contains some useful data to be preserved 
    (in case transition is already in catchup state).
  
    Depending on relevance status, metrics are updated for the peer who sent the transition.
*)
let verify_header_is_relevant ?record_event_for_senders
    ~context:(module Context : CONTEXT) ~transition_states header_with_hash =
  let hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let relevance_result =
    let%bind.Result () =
      Option.value_map (Transition_states.find transition_states hash)
        ~default:(Ok ()) ~f:(fun st -> Error (`In_process st))
    in
    Transition_handler.Validator.verify_header_is_relevant
      ~context:(module Context)
      ~frontier:Context.frontier header_with_hash
  in
  Option.iter record_event_for_senders ~f:(fun senders ->
      Context.record_event
        (`Verified_header_relevance
          (relevance_result, header_with_hash, senders) ) ) ;
  match relevance_result with
  | Ok () ->
      `Relevant
  | Error (`In_process (Transition_state.Invalid _)) ->
      `Irrelevant
  | Error (`In_process _) ->
      `Preserve_gossip_data
  | _ ->
      `Irrelevant

(** Preserve body in the transition's state.
    
    Function is called when a gossip with a body is received or
    when a transition is retrieved through ancestry retrieval with a body
    (i.e. via using old RPCs).

    In case of [Transition_state.Downloading_body] state in [Substate.Failed] or
    [Substate.Processing (Substate.In_progress _)] statuses, status is changed
    to [Substate.Processing (Substate.Done _)] and [`Mark_downloading_body_processed]
    hint is returned. Returned hint is [`Nop] otherwise.
*)
let preserve_body st body =
  match st with
  | Transition_state.Received ({ body_opt = None; _ } as r) ->
      let body_ref =
        With_hash.data (header_with_hash_of_received_header r.header)
        |> Mina_block.Header.body_reference
      in
      ( Transition_state.Received { r with body_opt = Some body }
      , `Nop (`Preserved_body (body_ref, body)) )
  | Verifying_blockchain_proof ({ body_opt = None; _ } as r) ->
      let body_ref =
        Mina_block.Validation.header r.header
        |> Mina_block.Header.body_reference
      in
      ( Verifying_blockchain_proof { r with body_opt = Some body }
      , `Nop (`Preserved_body (body_ref, body)) )
  | Downloading_body
      ({ substate = { status = Processing (In_progress ctx); _ } as s; _ } as r)
    ->
      let body_ref =
        Mina_block.Validation.header r.header
        |> Mina_block.Header.body_reference
      in
      ( Downloading_body
          { r with substate = { s with status = Processing (Done body) } }
      , `Mark_downloading_body_processed
          (Some ctx.interrupt_ivar, body_ref, body) )
  | Downloading_body ({ substate = { status = Failed _; _ } as s; _ } as r) ->
      let body_ref =
        Mina_block.Validation.header r.header
        |> Mina_block.Header.body_reference
      in
      ( Downloading_body
          { r with substate = { s with status = Processing (Done body) } }
      , `Mark_downloading_body_processed (None, body_ref, body) )
  | _ ->
      (st, `Nop `No_body_preserved)

(** [preserve_relevant_gossip] takes data of a recently received gossip related to a
    transition already present in the catchup state. It preserves useful data of gossip
    in the catchup state.
    
    Function returns a pair of a new transition state and a hint of further action to be
    performed in case the gossiped data triggering a change of state.
    *)
let preserve_relevant_gossip ?body:body_opt ~gd_map ~context ~gossip_header st =
  let (module Ctx : CONTEXT) = context in
  let state_hash =
    (Transition_state.State_functions.transition_meta st).state_hash
  in
  let consensus_state =
    Fn.compose Mina_state.Protocol_state.consensus_state
      Mina_block.Header.protocol_state
  in
  let fire_callback verdict =
    List.iter
      ~f:
        (Fn.flip Mina_net2.Validation_callback.fire_if_not_already_fired verdict)
      (Transition_frontier.Gossip.valid_cbs gd_map)
  in
  let update_gossip_data init =
    if Transition_state.is_failed st then (
      fire_callback `Ignore ;
      init )
    else
      List.fold ~init (String.Map.data gd_map)
        ~f:
          (Fn.flip (function
            | { Transition_frontier.Gossip.type_ = gossip_type
              ; valid_cb = Some vc
              ; _
              } ->
                update_gossip_data ~logger:Ctx.logger ~state_hash ~vc
                  ~gossip_type
            | _ ->
                Fn.id ) )
  in
  let update_block_vc =
    let vcs =
      List.filter_map (String.Map.data gd_map) ~f:(function
        | { type_ = `Block; valid_cb; _ } ->
            valid_cb
        | _ ->
            None )
    in
    if Transition_state.is_failed st then (
      List.iter vcs
        ~f:
          (Fn.flip Mina_net2.Validation_callback.fire_if_not_already_fired
             `Ignore ) ;
      ident )
    else function
      | None ->
          List.hd vcs
      | Some p when List.is_empty vcs ->
          Some p
      | Some p ->
          [%log' warn Ctx.logger] "Duplicate block gossip for $state_hash"
            ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
          Some p
  in
  let accept_header consensus_state =
    let valid_cbs =
      List.filter_map (String.Map.data gd_map) ~f:(function
        | { type_ = `Header; valid_cb; _ } ->
            valid_cb
        | _ ->
            None )
    in
    ignore (Context.accept_gossip ~context ~valid_cbs consensus_state : bool)
  in
  let received =
    List.filter_map (String.Map.to_alist gd_map) ~f:(function
      | topic, { received_at; sender = Remote sender; _ } ->
          Some
            { Transition_state.received_at; sender; gossip_topic = Some topic }
      | _ ->
          None )
  in
  let st =
    Transition_state.modify_aux_data st ~f:(fun d ->
        { received_via_gossip = true; received = received @ d.received } )
  in
  let st, pre_decision =
    Option.value_map
      ~default:(st, `Nop `No_body_preserved)
      ~f:(preserve_body st) body_opt
  in
  match (st, pre_decision) with
  | Transition_state.Invalid _, `Nop bp ->
      fire_callback `Reject ;
      (st, `Nop bp)
  | Received ({ gossip_data; _ } as r), `Nop bp ->
      ( Received
          { r with
            gossip_data = update_gossip_data gossip_data
          ; header = Initial_valid gossip_header
          }
      , `Nop bp )
  | ( Verifying_blockchain_proof
        ({ gossip_data; substate = { status = Failed _; _ }; _ } as r)
    , `Nop bp )
  | ( Verifying_blockchain_proof
        ({ gossip_data; substate = { status = Processing _; _ }; _ } as r)
    , `Nop bp ) ->
      ( Verifying_blockchain_proof
          { r with gossip_data = update_gossip_data gossip_data; baton = true }
      , `Mark_verifying_blockchain_proof_processed (bp, gossip_header) )
  | Verifying_blockchain_proof ({ gossip_data; _ } as r), `Nop bp ->
      ( Verifying_blockchain_proof
          { r with gossip_data = update_gossip_data gossip_data; baton = true }
      , `Nop bp )
  | Downloading_body ({ block_vc; header; _ } as r), _ ->
      accept_header (consensus_state @@ Mina_block.Validation.header header) ;
      ( Transition_state.Downloading_body
          { r with block_vc = update_block_vc block_vc; baton = true }
      , pre_decision )
  | ( Verifying_complete_works
        ( { block_vc; block; substate = { status = Processing Dependent; _ }; _ }
        as r )
    , `Nop bp )
  | ( Verifying_complete_works
        ({ block_vc; block; substate = { status = Failed _; _ }; _ } as r)
    , `Nop bp ) ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      ( Verifying_complete_works
          { r with block_vc = update_block_vc block_vc; baton = true }
      , `Start_processing_verifying_complete_works
          ( bp
          , State_hash.With_state_hashes.state_hash
              (Mina_block.Validation.block_with_hash block) ) )
  | Verifying_complete_works ({ block_vc; block; _ } as r), `Nop bp ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      ( Verifying_complete_works
          { r with block_vc = update_block_vc block_vc; baton = true }
      , `Nop bp )
  | Building_breadcrumb ({ block_vc; block; _ } as r), `Nop bp ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      ( Building_breadcrumb { r with block_vc = update_block_vc block_vc }
      , `Nop bp )
  | Waiting_to_be_added_to_frontier { breadcrumb; _ }, `Nop bp ->
      let consensus_state =
        consensus_state
        @@ Mina_block.(header @@ Frontier_base.Breadcrumb.block breadcrumb)
      in
      ignore
        ( accept_gossip ~context consensus_state
            ~valid_cbs:(Transition_frontier.Gossip.valid_cbs gd_map)
          : bool ) ;
      (st, `Nop bp)
  | _, `Mark_downloading_body_processed _ ->
      failwith "Mark_downloading_body_processed: unexpected case"
