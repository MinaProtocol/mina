open Mina_base
open Core_kernel
open Async
open Context

(** [mark_done state_hash] assigns a transition corresponding to [state_hash]
  with a [Processing] or [Failed] status new status [Processing (Done ())] and
  returns in-progress context if the transition was in progress of receiving ancestry.
*)
let mark_done ~transition_states state_hash =
  let%bind.Option st = State_hash.Table.find transition_states state_hash in
  let%bind.Option st' =
    match st with
    | Transition_state.Received
        ({ substate = { status = Processing _; _ } as s; _ } as r)
    | Received ({ substate = { status = Failed _; _ } as s; _ } as r) ->
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

(** Take data of a recently received gossip related to a transition already present
    in the catchup state. Preserve useful data of gossip in the catchup state.
    
    Function calls [Gossip.preserve_relevant_gossip] and executes a necessary
    action based on the hint.
    *)
let preserve_relevant_gossip_and_promote ~mark_processed_and_promote
    ~transition_states ?body ?vc ~context ~state_hash ?gossip_type
    ?gossip_header st =
  let st', hint =
    Gossip.preserve_relevant_gossip ?body ?vc ~context ~state_hash ?gossip_type
      ?gossip_header st
  in
  State_hash.Table.set transition_states ~key:state_hash ~data:st' ;
  match hint with
  | `Nop ->
      ()
  | `Mark_verifying_blockchain_proof_processed iv_header ->
      Verifying_blockchain_proof.mark_processed ~context
        ~mark_processed_and_promote ~transition_states iv_header
  | `Start_processing_verifying_complete_works block ->
      Verifying_complete_works.start_processing ~context
        ~mark_processed_and_promote ~transition_states block
  | `Promote_and_interrupt ivar ->
      Ivar.fill_if_empty ivar () ;
      mark_processed_and_promote [ state_hash ]

let pre_validate_header ~context:(module Context : CONTEXT) hh =
  let open Result in
  let open Mina_block.Validation in
  let open Context in
  validate_delta_block_chain (wrap_header hh)
  >>= validate_protocol_versions
  >>= validate_genesis_protocol_state ~genesis_state_hash
  >>| skip_time_received_validation_header
        `This_block_was_not_received_via_gossip

(** Check transition's status in catchup state and frontier *)
let lookup_transition ~transition_states ~frontier state_hash =
  match State_hash.Table.find transition_states state_hash with
  | Some (Transition_state.Invalid _) ->
      `Invalid
  | Some _ ->
      `Present
  | None ->
      if Option.is_some (Transition_frontier.find frontier state_hash) then
        `Present
      else `Not_present

(** Insert invalid transition to transition states and mark
    children of the transition invalid.
    
    Pre-condition: transition doesn't exist in transition states.
*)
let insert_invalid_state_impl ~transition_states ~transition_meta ~children_list
    error =
  Hashtbl.add_exn transition_states ~key:transition_meta.Substate.state_hash
    ~data:(Transition_state.Invalid { transition_meta; error }) ;
  List.iter children_list
    ~f:(Transition_state.mark_invalid ~transition_states ~error)

(** Insert invalid transition to transition states and remove
    corresponding record from orphans.
    
    Pre-condition: transition doesn't exist in transition states.
*)
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

(** Handle an ancestor returned by [retrieve_chain] function.
  
    The ancestor's block is pre-validated and added to transition states
    (if not yet present there).

    In case ancestor is already in transition states and body is available
    from 
*)
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
           ~transition_states:state.transition_states ?body ~context ~state_hash
           st )
  | None, Some hh -> (
      match pre_validate_header ~context hh with
      | Ok vh ->
          add_received ~context ~mark_processed_and_promote ~sender ~state ?body
            (Gossip_types.Pre_initial_valid vh) ;
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
    Gossip_types.header_with_hash_of_received_header received_header
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
           ; gossip_data = Gossip_types.create_gossip_data ?gossip_type vc
           ; substate = { children; status }
           ; aux =
               { received_via_gossip = Option.is_some gossip_type
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
    ~gossip_type ?vc gossip_header =
  let header_with_hash = Mina_block.Validation.header_with_hash gossip_header in
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
  let state_hash = State_hash.With_state_hashes.state_hash header_with_hash in
  let relevance_status =
    Gossip.verify_header_is_relevant ~context ~sender
      ~transition_states:state.transition_states header_with_hash
  in
  match relevance_status with
  | `Irrelevant ->
      ()
  | `Relevant ->
      add_received ~mark_processed_and_promote ~context ~sender ~state
        ~gossip_type ?vc ?body (Initial_valid gossip_header)
  | `Preserve_gossip_data ->
      let f =
        preserve_relevant_gossip_and_promote ~mark_processed_and_promote
          ~transition_states:state.transition_states ?body ?vc ~context
          ~state_hash ~gossip_type ~gossip_header
      in
      Option.iter ~f (State_hash.Table.find state.transition_states state_hash)

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
    header_with_validation

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
    header_with_validation
