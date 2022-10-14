open Mina_base
open Core_kernel
open Async
open Context

(** [verify_heeader_is_relevant] determines if a transition received through
    gossip is relevant.

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

(** [mark_done state_hash] assigns a transition corresponding to [state_hash]
  with a [Processing] or [Failed] status new status [Processing (Done ())] and
  returns in-progress context if the transition was in progress (receiving ancestry).
*)
let mark_done ~transition_states state_hash =
  let%bind.Option st = State_hash.Table.find transition_states state_hash in
  let%bind.Option st' =
    match st with
    | Transition_state.Received
        ({ substate = { status = Processing _; _ } as s; _ } as r)
    | Transition_state.Received
        ({ substate = { status = Failed _; _ } as s; _ } as r) ->
        Some
          (Transition_state.Received
             { r with substate = { s with status = Processing (Done ()) } } )
    | _ ->
        None
  in
  State_hash.Table.set transition_states ~key:state_hash ~data:st' ;
  match st with
  | Transition_state.Received
      { substate = { status = Processing (In_progress ctx); _ }; _ } ->
      Some (ctx.timeout, ctx.interrupt_ivar)
  | _ ->
      None

let create_gossip_data ?gossip_type vc_opt =
  Option.value ~default:Transition_state.Not_a_gossip
  @@ let%bind.Option gt = gossip_type in
     let%map.Option vc = vc_opt in
     match gt with
     | `Header ->
         Transition_state.Gossiped_header vc
     | `Block ->
         Gossiped_block vc

(** Update gossip data kept for a transition to include information
    that became potentially available from a recently received gossip *)
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

(** [preserve_relevant_gossip st] takes data of a recently received gossip related to a
    transition already present in the catchup state and is associated with state [st].
    
    Function returns a pair of a new transition state and an ivar to interrupt processing
    of the transition if one was active and is no longer relevant.
    *)
let preserve_relevant_gossip ?body:body_opt ?vc:vc_opt ~context ~hash
    ?gossip_type st =
  let update_gossip_data =
    Option.value ~default:Fn.id
    @@ let%bind.Option vc = vc_opt in
       let%map.Option gossip_type = gossip_type in
       update_gossip_data ~context ~hash ~vc ~gossip_type
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
  match (st, body_opt) with
  | Transition_state.Invalid _, _ ->
      fire_callback `Reject ;
      (st, None)
  | st, _ when Transition_state.is_failed st ->
      fire_callback `Ignore ;
      (st, None)
  | Received ({ gossip_data; body_opt; _ } as r), _ ->
      ( Received
          { r with
            gossip_data = update_gossip_data gossip_data
          ; body_opt = update_body_opt body_opt
          }
      , None )
  | Verifying_blockchain_proof ({ gossip_data; body_opt; _ } as r), _ ->
      ( Verifying_blockchain_proof
          { r with
            gossip_data = update_gossip_data gossip_data
          ; body_opt = update_body_opt body_opt
          }
      , None )
  | ( Downloading_body
        ( { block_vc
          ; substate = { status = Processing (In_progress ctx); _ } as s
          ; header
          ; _
          } as r )
    , Some body ) ->
      accept_header (consensus_state @@ Mina_block.Validation.header header) ;
      ( Downloading_body
          { r with
            block_vc = update_block_vc block_vc
          ; substate = { s with status = Processing (Done body) }
          }
      , Some ctx.interrupt_ivar )
  | Downloading_body ({ block_vc; header; _ } as r), _ ->
      accept_header (consensus_state @@ Mina_block.Validation.header header) ;
      (Downloading_body { r with block_vc = update_block_vc block_vc }, None)
  | Verifying_complete_works ({ block_vc; block; _ } as r), _ ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      ( Verifying_complete_works { r with block_vc = update_block_vc block_vc }
      , None )
  | Building_breadcrumb ({ block_vc; block; _ } as r), _ ->
      accept_header
        (consensus_state @@ Mina_block.(header @@ Validation.block block)) ;
      (Building_breadcrumb { r with block_vc = update_block_vc block_vc }, None)
  | Waiting_to_be_added_to_frontier { breadcrumb; _ }, _ ->
      let consensus_state =
        consensus_state
        @@ Mina_block.(header @@ Frontier_base.Breadcrumb.block breadcrumb)
      in
      Option.iter vc_opt ~f:(fun valid_cb ->
          accept_gossip ~context ~valid_cb consensus_state ) ;
      (st, None)

let preserve_relevant_gossip_and_promote ~mark_processed_and_promote
    ~transition_states ?body ?vc ~context ~hash ?gossip_type st =
  let st', interrupt_ivar_opt =
    preserve_relevant_gossip ?body ?vc ~context ~hash ?gossip_type st
  in
  State_hash.Table.set transition_states ~key:hash ~data:st' ;
  Option.value ~default:()
  @@ let%map.Option ivar = interrupt_ivar_opt in
     Ivar.fill_if_empty ivar () ;
     mark_processed_and_promote [ hash ]

let pre_validate_header ~context hh =
  let open Result in
  Mina_block.Validation.(
    validate_delta_block_chain (wrap_header hh)
    >>= validate_protocol_versions
    >>= validate_genesis_protocol_state
          ~genesis_state_hash:(genesis_state_hash context)
    >>| skip_time_received_validation_header
          `This_block_was_not_received_via_gossip)

let lookup_transition ~transition_states ~frontier hash =
  match State_hash.Table.find transition_states hash with
  | Some (Transition_state.Invalid _) ->
      `Invalid
  | Some _ ->
      `Present
  | None ->
      if Option.is_some (Transition_frontier.find frontier hash) then `Present
      else `Not_present

let insert_invalid_state_impl ~transition_states ~transition_meta ~children_list
    error =
  Hashtbl.add_exn transition_states ~key:transition_meta.Substate.state_hash
    ~data:(Transition_state.Invalid { transition_meta; error }) ;
  List.iter children_list
    ~f:(Transition_state.mark_invalid ~transition_states ~error)

let insert_invalid_state ~state ~transition_meta error =
  let children_list =
    Option.value ~default:[]
    @@ Hashtbl.find state.orphans transition_meta.Substate.state_hash
  in
  Hashtbl.remove state.orphans transition_meta.state_hash ;
  insert_invalid_state_impl ~transition_states:state.transition_states
    ~transition_meta ~children_list error

let set_received_to_failed error = function
  | Transition_state.Received
      ({ substate = { status = Processing _; _ }; _ } as r) ->
      Transition_state.Received
        { r with substate = { r.substate with status = Failed error } }
  | st ->
      st

let compute_header_hashes =
  With_hash.of_data
    ~hash_data:
      (Fn.compose Mina_state.Protocol_state.hashes
         Mina_block.Header.protocol_state )

let split_retrieve_chain_element = function
  | `Block b ->
      let h = Mina_block.header b in
      let hh = compute_header_hashes h in
      ( Transition_state.transition_meta_of_header_with_hash hh
      , Some hh
      , Some (Mina_block.body b) )
  | `Header h ->
      let hh = compute_header_hashes h in
      (Transition_state.transition_meta_of_header_with_hash hh, Some hh, None)
  | `Meta m ->
      (m, None, None)

let rec handle_retrieved_ancestor ~context ~mark_processed_and_promote ~state
    ~sender el =
  let (module Context : CONTEXT) = context in
  let transition_meta, hh_opt, body = split_retrieve_chain_element el in
  let state_hash = transition_meta.state_hash in
  match (State_hash.Table.find state.transition_states state_hash, hh_opt) with
  | Some (Transition_state.Invalid _), _ ->
      Error (Error.of_string "parent is invalid")
  | Some st, _ ->
      Ok
        (preserve_relevant_gossip_and_promote ~mark_processed_and_promote
           ~transition_states:state.transition_states ?body ~context
           ~hash:state_hash st )
  | None, Some hh -> (
      match pre_validate_header ~context hh with
      | Ok vh ->
          add_received ~context ~mark_processed_and_promote ~sender ~state ?body
            (Transition_state.Pre_initial_valid vh) ;
          Ok ()
      | Error e ->
          (* TODO every time this code is called we probably want to update some metrics
             (see Initial_validator) *)
          let e' =
            Error.of_string
            @@
            match e with
            | `Invalid_genesis_protocol_state ->
                "invalid genesis state"
            | `Invalid_delta_block_chain_proof ->
                "invalid delta transition chain proof"
            | `Mismatched_protocol_version ->
                "protocol version mismatch"
            | `Invalid_protocol_version ->
                "invalid protocol version"
          in
          insert_invalid_state ~state ~transition_meta e' ;
          Error e' )
  | None, None ->
      [%log' warn Context.logger]
        "Unexpected `Meta entry returned by retrieve_chain for $state_hash"
        ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
      Ok ()

(** Launch retrieval of ancestry for a received header.

Pre-condition: header's parent is neither present in transition states nor in transition frontier.
*)
and launch_ancestry_retrieval ~context ~mark_processed_and_promote
    ~child_contexts ~received_at ~sender ~state header_with_hash =
  let (module Context : CONTEXT) = context in
  let state_hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let parent_hash =
    With_hash.data header_with_hash
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let max_timeout =
    Time.add
      (List.fold ~init:received_at child_contexts ~f:(fun t (timeout, _) ->
           Time.max t timeout ) )
      Context.ancestry_download_timeout
  in
  let timeout =
    Time.min max_timeout @@ Time.add received_at
    @@ Time.Span.scale Context.ancestry_download_timeout 2.
  in
  let lookup_transition =
    lookup_transition ~transition_states:state.transition_states
      ~frontier:Context.frontier
  in
  let module I = Interruptible.Make () in
  let retrieve_do () =
    Context.retrieve_chain ~some_ancestors:[] ~target:parent_hash ~sender
      ~parent_cache:state.parents ~lookup_transition
      (module I)
  in
  let ancestry =
    if List.is_empty child_contexts then retrieve_do ()
    else
      (* We rely on one of children to retrieve ancestry and
         launch downloading ourselves only in case children timed out *)
      let%bind.I () = I.lift (after Context.ancestry_download_timeout) in
      match lookup_transition parent_hash with
      | `Not_present ->
          retrieve_do ()
      | _ ->
          I.return @@ Ok []
  in
  let fold_step res (el, sender) =
    if Result.is_ok res then
      handle_retrieved_ancestor ~context ~mark_processed_and_promote ~state
        ~sender el
    else
      let error = Error.of_string "parent is invalid" in
      ( match State_hash.Table.find state.transition_states state_hash with
      | Some (Transition_state.Invalid _) ->
          ()
      | Some _ ->
          Transition_state.mark_invalid
            ~transition_states:state.transition_states ~error state_hash
      | None ->
          let transition_meta, _, _ = split_retrieve_chain_element el in
          insert_invalid_state ~state ~transition_meta error ) ;
      res
  in
  let action =
    match%map.I ancestry with
    | Ok lst ->
        ignore @@ List.fold lst ~init:(Ok ()) ~f:fold_step
    | Error e ->
        State_hash.Table.change state.transition_states state_hash
          ~f:(Option.map ~f:(set_received_to_failed e))
  in
  Interruptible.don't_wait_for
  @@ I.finally action ~f:(fun () ->
         List.iter child_contexts ~f:(fun (_, interrupt_ivar) ->
             Ivar.fill_if_empty interrupt_ivar () ) ;
         Timeout_controller.unregister ~state_hash ~timeout
           Context.timeout_controller ) ;
  (I.interrupt_ivar, timeout)

(** [add_received] adds a gossip to the state.

  Pre-conditions:
  * transition is neither in frontier nor in catchup state
  * [verify_header_is_relevant] returns [`Relevant] for the gossip
*)
and add_received ~context ~mark_processed_and_promote ~sender ~state
    ?gossip_type ?vc ?body:body_opt received_header =
  let (module Context : CONTEXT) = context in
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
  let parent_presence =
    lookup_transition ~transition_states:state.transition_states
      ~frontier:Context.frontier parent_hash
  in
  let children_list =
    Option.value ~default:[] @@ Hashtbl.find state.orphans state_hash
  in
  Hashtbl.remove state.orphans state_hash ;
  let received_at = Time.now () in
  (* [invariant] children.processed = children.waiting_for_parent = empty *)
  let children =
    { Substate.empty_children_sets with
      processing_or_failed = State_hash.Set.of_list children_list
    }
  in
  (* Descedants are marked as Done and responsibility to fetch ancestry is moved to
     the freshly received transition or its ancestors *)
  let child_contexts =
    List.filter_map children_list ~f:(mark_done ~transition_states)
  in
  let add_to_state status =
    Hashtbl.add_exn transition_states ~key:state_hash
      ~data:
        (Received
           { body_opt
           ; header = received_header
           ; gossip_data = create_gossip_data ?gossip_type vc
           ; substate =
               { children
               ; received_via_gossip = Option.is_some gossip_type
               ; status
               ; sender
               ; received_at
               }
           } )
  in
  match parent_presence with
  | `Invalid ->
      let transition_meta =
        Transition_state.transition_meta_of_header_with_hash header_with_hash
      in
      insert_invalid_state_impl ~transition_states:state.transition_states
        ~transition_meta ~children_list
        (Error.of_string "parent is invalid")
  | `Present ->
      (* Children sets of parent are not updated explicitly because [mark_processed_and_promote] call
         will perform the update *)
      add_to_state @@ Substate.Processing (Done ()) ;
      mark_processed_and_promote (state_hash :: children_list)
  | `Not_present ->
      (* Children sets of parent are not updated because parent is not present *)
      let interrupt_ivar, timeout =
        launch_ancestry_retrieval ~mark_processed_and_promote ~context
          ~child_contexts ~sender ~received_at ~state header_with_hash
      in
      add_to_state @@ Processing (In_progress { timeout; interrupt_ivar }) ;
      Timeout_controller.register ~state_functions ~transition_states
        ~state_hash ~timeout Context.timeout_controller ;
      mark_processed_and_promote children_list

(** Add a gossip to catchup state *)
let handle_gossip ~context ~mark_processed_and_promote ~state ~sender ?body
    ~gossip_type ?vc received_header =
  let header_with_hash =
    Transition_state.header_with_hash_of_received_header received_header
  in
  let body =
    if is_some body then body
    else
      let (module Context : CONTEXT) = context in
      Context.check_body_in_storage
        ( With_hash.data header_with_hash
        |> Mina_block.Header.protocol_state
        |> Mina_state.(
             Fn.compose Blockchain_state.body_reference
               Protocol_state.blockchain_state) )
  in
  let hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let relevance_status =
    verify_header_is_relevant ~context ~sender
      ~transition_states:state.transition_states header_with_hash
  in
  match relevance_status with
  | `Irrelevant ->
      ()
  | `Relevant ->
      add_received ~mark_processed_and_promote ~context ~sender ~state
        ~gossip_type ?vc ?body received_header
  | `Preserve_gossip_data ->
      let f =
        preserve_relevant_gossip_and_promote ~mark_processed_and_promote
          ~transition_states:state.transition_states ?body ?vc ~context ~hash
          ~gossip_type
      in
      Option.iter ~f (State_hash.Table.find state.transition_states hash)

(** [handle_collected_transition] adds a transition that was collected during bootstrap
    to the catchup state. *)
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
  (* TODO: is it safe to add this as a gossip? Transition was received
     through gossip, but was potentially sent not within its slot
     as boostrap controller is not able to verify this part.orphans
     Hence maybe it's worth leaving it as non-gossip, a dependent transition. *)
  handle_gossip
    ~context:(module Context)
    ~mark_processed_and_promote ~state ~sender ?vc ?body ~gossip_type
    (Initial_valid header_with_validation)

(** [handle_network_transition] adds a transition that was received through gossip
    to the catchup state. *)
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
