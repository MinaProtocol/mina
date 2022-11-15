open Mina_base
open Core_kernel
open Async
open Context

(** [mark_done state_hash] assigns a transition corresponding to [state_hash]
  with a [Processing] or [Failed] status new status [Processing (Done ())] and
  returns in-progress context if the transition was in progress of receiving ancestry.
*)
let mark_done ~transition_states state_hash =
  let%bind.Option st = Transition_states.find transition_states state_hash in
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
  Transition_states.update transition_states st' ;
  match st with
  | Transition_state.Received
      { substate = { status = Processing (In_progress ctx); _ }; _ } ->
      Some (ctx.timeout, ctx.interrupt_ivar)
  | _ ->
      None

(** Save new transition state and process the hint.

    When state is [Transition_state.Downloading_body], pass the baton
    to ancestor (and restart failed) if [baton] is [true]. 
*)
let handle_preserve_hint ~mark_processed_and_promote ~transition_states ~context
    (st, hint) =
  Transition_states.update transition_states st ;
  match hint with
  | `Nop ->
      ()
  | `Mark_verifying_blockchain_proof_processed iv_header ->
      Verifying_blockchain_proof.make_processed ~context
        ~mark_processed_and_promote ~transition_states iv_header
  | `Start_processing_verifying_complete_works state_hash ->
      Verifying_complete_works.make_independent ~context
        ~mark_processed_and_promote ~transition_states state_hash
  | `Mark_downloading_body_processed ivar_opt ->
      let meta = Transition_state.State_functions.transition_meta st in
      ( match st with
      | Downloading_body { baton = true; _ } ->
          Downloading_body.pass_the_baton ~transition_states ~context
            ~mark_processed_and_promote meta.parent_state_hash
      | _ ->
          () ) ;
      Option.iter ivar_opt ~f:(Fn.flip Ivar.fill_if_empty ()) ;
      mark_processed_and_promote [ meta.state_hash ]

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
  match Transition_states.find transition_states state_hash with
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
  Transition_states.add_new transition_states
    (Transition_state.Invalid { transition_meta; error }) ;
  List.iter children_list ~f:(fun state_hash ->
      Transition_states.mark_invalid ~state_hash transition_states ~error )

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

let set_processing_to_failed error = function
  | Transition_state.Received
      ( { substate = { status = Processing (In_progress _); _ }; gossip_data; _ }
      as r ) ->
      Gossip.drop_gossip_data `Ignore gossip_data ;
      Some
        (Transition_state.Received
           { r with
             substate = { r.substate with status = Failed error }
           ; gossip_data = Gossip.No_validation_callback
           } )
  | st ->
      Some st

let split_retrieve_chain_element = function
  | `Block bh ->
      let hh = With_hash.map ~f:Mina_block.header bh in
      ( Substate.transition_meta_of_header_with_hash hh
      , Some hh
      , Some (Mina_block.body @@ With_hash.data bh) )
  | `Header hh ->
      (Substate.transition_meta_of_header_with_hash hh, Some hh, None)
  | `Meta m ->
      (m, None, None)

let is_received = function Transition_state.Received _ -> true | _ -> false

let rec pre_validate_and_add ~context ~mark_processed_and_promote ~sender ~state
    ?body hh =
  match pre_validate_header ~context hh with
  | Ok vh ->
      add_received ~context ~mark_processed_and_promote ~sender ~state ?body
        (Gossip.Pre_initial_valid vh) ;
      Ok ()
  | Error e ->
      let header = With_hash.data hh in
      let (module Context : CONTEXT) = context in
      Context.record_event (`Pre_validate_header_invalid (sender, header, e)) ;
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
      let transition_meta = Substate.transition_meta_of_header_with_hash hh in
      insert_invalid_state ~state ~transition_meta e' ;
      Error e'

(** Handle an ancestor returned by [retrieve_chain] function.
  
    The ancestor's block is pre-validated and added to transition states
    (if not yet present there).

    In case ancestor is already in transition states and body is available
    from.

    Returns error iff the ancestor is invalid. *)
and handle_retrieved_ancestor ~context ~mark_processed_and_promote ~state
    ~sender el =
  let (module Context : CONTEXT) = context in
  let extend_aux aux =
    { aux with
      Transition_state.received =
        { received_at = Time.now (); gossip = false; sender }
        :: aux.Transition_state.received
    }
  in
  let transition_meta, hh_opt, body = split_retrieve_chain_element el in
  let state_hash = transition_meta.state_hash in
  match (Transition_states.find state.transition_states state_hash, hh_opt) with
  | Some (Transition_state.Invalid _), _ ->
      Error (Error.of_string "parent is invalid")
  | Some st, _ ->
      let st' = Transition_state.modify_aux_data ~f:extend_aux st in
      let hint =
        Option.value_map
          ~f:(fun body -> Gossip.preserve_body ~body st')
          ~default:(st', `Nop)
          body
      in
      handle_preserve_hint ~mark_processed_and_promote
        ~transition_states:state.transition_states ~context hint ;
      Ok ()
  | None, Some hh ->
      pre_validate_and_add ~context ~mark_processed_and_promote ~sender ~state
        ?body hh
  | None, None ->
      ignore
        ( State_hash.Table.add state.parents ~key:state_hash
            ~data:transition_meta.parent_state_hash
          : [ `Duplicate | `Ok ] ) ;
      Ok ()

(** Launch retrieval of ancestry for a received header.

Pre-condition: header's parent is neither present in transition states nor in transition frontier.
*)
and launch_ancestry_retrieval ~context ~mark_processed_and_promote
    ~retrieve_immediately ~cancel_child_contexts ~timeout ~preferred_peers
    ~state header_with_hash =
  let (module Context : CONTEXT) = context in
  let parent_hash =
    With_hash.data header_with_hash
    |> Mina_block.Header.protocol_state
    |> Mina_state.Protocol_state.previous_state_hash
  in
  let parent_length =
    Mina_block.Header.blockchain_length (With_hash.data header_with_hash)
    |> Mina_numbers.Length.pred
  in
  let lookup_transition =
    lookup_transition ~transition_states:state.transition_states
      ~frontier:Context.frontier
  in
  let some_ancestors =
    let rec impl lst h =
      Option.value_map (State_hash.Table.find state.parents h) ~default:lst
        ~f:(fun p -> impl (p :: lst) p)
    in
    impl []
  in
  let module I = Interruptible.Make () in
  let retrieve_do () =
    Context.retrieve_chain
      ~some_ancestors:(some_ancestors parent_hash)
      ~target_length:parent_length ~target_hash:parent_hash ~preferred_peers
      ~lookup_transition
      (module I)
  in
  let ancestry =
    if retrieve_immediately then retrieve_do ()
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
  let top_state_hash =
    State_hash.With_state_hashes.state_hash header_with_hash
  in
  upon (I.force ancestry)
    (upon_f ~top_state_hash ~mark_processed_and_promote ~context ~state
       ~cancel_child_contexts ) ;
  interrupt_after_timeout ~timeout I.interrupt_ivar ;
  I.interrupt_ivar

(** [upon_f] is a callback to be executed upon completion of retrieving ancestry
    (or a failure). *)
and upon_f ~top_state_hash ~mark_processed_and_promote ~context ~state
    ~cancel_child_contexts =
  let f res (el, sender) =
    if Result.is_ok res then
      handle_retrieved_ancestor ~context ~mark_processed_and_promote ~state
        ~sender el
    else
      let error = Error.of_string "parent is invalid" in
      let transition_meta, _, _ = split_retrieve_chain_element el in
      ( match
          Transition_states.find state.transition_states
            transition_meta.state_hash
        with
      | Some (Transition_state.Invalid _) ->
          ()
      | Some _ ->
          Transition_states.mark_invalid state.transition_states ~error
            ~state_hash:transition_meta.state_hash
      | None ->
          insert_invalid_state ~state ~transition_meta error ) ;
      res
  in
  let on_error e =
    cancel_child_contexts () ;
    Transition_states.update' state.transition_states top_state_hash
      ~f:(set_processing_to_failed e)
  in
  function
  | Result.Error () ->
      on_error (Error.of_string "interrupted")
  | Ok (Result.Ok lst) ->
      cancel_child_contexts () ;
      ignore (List.fold lst ~init:(Ok ()) ~f : unit Or_error.t) ;
      (* This will trigger only is the top state hash remained in Processing state
         after handling all of the fetched ancestors *)
      Transition_states.update' state.transition_states top_state_hash
        ~f:
          ( set_processing_to_failed
          @@ Error.of_string "failed to retrieve ancestors" )
  | Ok (Error e) ->
      on_error e

and restart_failed_ancestor ~state ~mark_processed_and_promote ~context
    top_state_hash =
  let (module Context : CONTEXT) = context in
  let transition_states = state.transition_states in
  let handle_unprocessed ~preferred_peers header =
    let timeout = Time.add (Time.now ()) Context.ancestry_download_timeout in
    let hh = Gossip.header_with_hash_of_received_header header in
    let interrupt_ivar =
      launch_ancestry_retrieval ~mark_processed_and_promote ~context
        ~cancel_child_contexts:Fn.id ~retrieve_immediately:true ~preferred_peers
        ~timeout ~state hh
    in
    let state_hash = State_hash.With_state_hashes.state_hash hh in
    let downto_ = Mina_numbers.Length.zero in
    Substate.Processing
      (In_progress { timeout; interrupt_ivar; downto_; holder = ref state_hash })
  in
  let f st =
    if is_received st then
      let unprocessed_opt =
        Processed_skipping.next_unprocessed ~state_functions ~transition_states
          ~dsu:Context.processed_dsu st
      in
      match unprocessed_opt with
      | Some
          (Received
            ( { header
              ; substate = { status = Failed _; _ }
              ; aux = { received; _ }
              ; _
              } as r ) ) ->
          let status =
            handle_unprocessed
              ~preferred_peers:
                (List.map received ~f:(fun { sender; _ } -> sender))
              header
          in
          Transition_states.update transition_states
            (Received { r with substate = { r.substate with status } })
      | _ ->
          ()
  in
  Option.iter (Transition_states.find transition_states top_state_hash) ~f

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
    Gossip.header_with_hash_of_received_header received_header
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
  Hashtbl.remove state.parents state_hash ;
  let received_at = Time.now () in
  (* [invariant] children.processed = children.waiting_for_parent = empty *)
  let children =
    { Substate.empty_children_sets with
      processing_or_failed = State_hash.Set.of_list children_list
    }
  in
  (* descendants are marked as Done and responsibility to fetch ancestry is moved to
     the freshly received transition or its ancestors *)
  let child_contexts =
    List.filter_map children_list ~f:(mark_done ~transition_states)
  in
  let gossip = Option.is_some gossip_type in
  let add_to_state status =
    Transition_states.add_new transition_states
      (Received
         { body_opt
         ; header = received_header
         ; gossip_data = Gossip.create_gossip_data ?gossip_type vc
         ; substate = { children; status }
         ; aux =
             { received_via_gossip = gossip
             ; received = [ { gossip; sender; received_at } ]
             }
         } )
  in
  let cancel_child_contexts () =
    List.iter child_contexts ~f:(fun (_, interrupt_ivar) ->
        Ivar.fill_if_empty interrupt_ivar () )
  in
  match parent_presence with
  | `Invalid ->
      cancel_child_contexts () ;
      let transition_meta =
        Substate.transition_meta_of_header_with_hash header_with_hash
      in
      insert_invalid_state_impl ~transition_states:state.transition_states
        ~transition_meta ~children_list
        (Error.of_string "parent is invalid")
  | `Present ->
      cancel_child_contexts () ;
      (* Children sets of parent are not updated explicitly because [mark_processed_and_promote] call
         will perform the update *)
      add_to_state @@ Substate.Processing (Done ()) ;
      mark_processed_and_promote (state_hash :: children_list) ;
      restart_failed_ancestor ~state ~mark_processed_and_promote ~context
        parent_hash
  | `Not_present ->
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
      (* Children sets of parent are not updated because parent is not present *)
      let interrupt_ivar =
        launch_ancestry_retrieval ~mark_processed_and_promote ~context
          ~cancel_child_contexts
          ~retrieve_immediately:(List.is_empty child_contexts)
          ~preferred_peers:[ sender ] ~timeout ~state header_with_hash
      in
      add_to_state
      @@ Processing
           (In_progress
              { timeout
              ; interrupt_ivar
              ; downto_ = Mina_numbers.Length.zero
              ; holder = ref state_hash
              } ) ;
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
        Fn.compose
          (handle_preserve_hint ~mark_processed_and_promote
             ~transition_states:state.transition_states ~context )
          (Gossip.preserve_relevant_gossip ?body ?vc ~context ~gossip_type
             ~gossip_header ~sender )
      in
      Option.iter ~f (Transition_states.find state.transition_states state_hash)

(** [handle_collected_transition] adds a transition that was collected during bootstrap
    to the catchup state. *)
let handle_collected_transition ~context:(module Context : CONTEXT)
    ~mark_processed_and_promote ~state (b_or_h_env, vc) =
  let header_with_validation, body, gossip_type =
    match Network_peer.Envelope.Incoming.data b_or_h_env with
    | Bootstrap_controller.Transition_cache.Block block ->
        ( Mina_block.Validation.to_header block
        , Some (Mina_block.body @@ Mina_block.Validation.block block)
        , `Block )
    | Bootstrap_controller.Transition_cache.Header header ->
        (header, None, `Header)
  in
  match Network_peer.Envelope.Incoming.sender b_or_h_env with
  | Local ->
      [%log' warn Context.logger]
        "handle_collected_transition: called for a transition with local sender"
        ~metadata:
          [ ( "state_hash"
            , State_hash.to_yojson
                (state_hash_of_header_with_validation header_with_validation) )
          ]
  | Remote sender ->
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
  Option.value ~default:()
  @@ let%map.Option sender, header_with_validation, body, gossip_type =
       let log_local_header hh =
         [%log' warn Context.logger]
           "handle_network_transition: called for a transition with local \
            sender"
           ~metadata:
             [ ( "state_hash"
               , State_hash.to_yojson
                   (State_hash.With_state_hashes.state_hash hh) )
             ]
       in
       let open Network_peer.Envelope.Incoming in
       match b_or_h with
       | `Block { sender = Remote sender; data = block; _ } ->
           Some
             ( sender
             , Mina_block.Validation.to_header block
             , Some (Mina_block.body @@ Mina_block.Validation.block block)
             , `Block )
       | `Block { data = block; _ } ->
           log_local_header
             ( Mina_block.Validation.block_with_hash block
             |> With_hash.map ~f:Mina_block.header ) ;
           None
       | `Header { sender = Remote sender; data = header; _ } ->
           Some (sender, header, None, `Header)
       | `Header { data = header; _ } ->
           log_local_header (Mina_block.Validation.header_with_hash header) ;
           None
     in
     handle_gossip
       ~context:(module Context)
       ~mark_processed_and_promote ~state ~sender ?body ?vc ~gossip_type
       header_with_validation
