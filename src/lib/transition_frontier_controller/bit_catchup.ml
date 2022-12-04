open Mina_base
open Core_kernel
open Async
open Context
open Bit_catchup_state

type write_actions =
  { write_verified_transition :
         [ `Transition of Mina_block.Validated.t ] * [ `Source of source_t ]
      -> unit
        (** Callback to write verified transitions after they're added to the frontier. *)
  ; write_breadcrumb : source_t -> Frontier_base.Breadcrumb.t -> unit
        (** Callback to write built breadcrumbs so that they can be added to frontier *)
  }

let retrieve_hash_chain_max_jobs = 5

let sec_per_block =
  Option.value_map
    (Sys.getenv "MINA_EXPECTED_PER_BLOCK_DOWNLOAD_TIME")
    ~default:15. ~f:Float.of_string

let convert_breadcrumb_error =
  let invalid str = `Invalid (Error.of_string @@ "invalid " ^ str, `Other) in
  let open Staged_ledger.Staged_ledger_error in
  function
  | `Invalid_body_reference ->
      invalid "body reference"
  | `Invalid_staged_ledger_diff `Incorrect_target_snarked_ledger_hash ->
      invalid "snarked ledger hash"
  | `Invalid_staged_ledger_diff
      `Incorrect_target_staged_and_snarked_ledger_hashes ->
      invalid "snarked ledger hash && staged ledger hash"
  | `Invalid_staged_ledger_diff `Incorrect_target_staged_ledger_hash ->
      invalid "staged ledger hash"
  | `Staged_ledger_application_failed (Couldn't_reach_verifier _ as e)
  | `Staged_ledger_application_failed (Pre_diff (Unexpected _) as e) ->
      `Verifier_error (to_error e)
  | `Staged_ledger_application_failed (Invalid_proofs _ as e) ->
      `Invalid (to_error e, `Proof)
  | `Staged_ledger_application_failed (Pre_diff (Verification_failed _) as e) ->
      `Invalid (to_error e, `Signature_or_proof)
  | `Staged_ledger_application_failed (Pre_diff _ as e)
  | `Staged_ledger_application_failed (Non_zero_fee_excess _ as e)
  | `Staged_ledger_application_failed (Insufficient_work _ as e)
  | `Staged_ledger_application_failed (Mismatched_statuses _ as e)
  | `Staged_ledger_application_failed (Invalid_public_key _ as e)
  | `Staged_ledger_application_failed (Unexpected _ as e) ->
      `Invalid (to_error e, `Other)

(** Take non-empty list of ancestors, target hash and target length
    and return the non-empty list (of the same size as list of ancestors)
    of [Substate.transition_meta] values.  *)
let hash_chain_to_metas ~target_length ~target_hash ancestors =
  let next_state ~to_ne_list ~state_hash ~blockchain_length parent_state_hash =
    ( to_ne_list Substate.{ state_hash; blockchain_length; parent_state_hash }
    , Mina_numbers.Length.pred blockchain_length
    , parent_state_hash )
  in
  let step (res, blockchain_length, state_hash) =
    next_state ~state_hash ~blockchain_length
      ~to_ne_list:(Fn.flip Mina_stdlib.Nonempty_list.cons res)
  in
  let init =
    next_state ~to_ne_list:Mina_stdlib.Nonempty_list.singleton
      ~state_hash:target_hash ~blockchain_length:target_length
  in
  Tuple3.get1
  @@ Mina_stdlib.Nonempty_list.fold_right ancestors ~init ~f:(Fn.flip step)

(** Tries to find an ancestor of target hash for which
    [lookup_transition] doesn't return [`Not_present].
    
    Returned non-empty list is in parent-first and contains no target hash. *)
let try_to_connect_hash_chain ~lookup_transition ~target_length ~root_length =
  let open Mina_numbers.Length in
  List.fold_until
    ~init:(pred target_length, [])
    ~f:(fun (blockchain_length, acc) hash ->
      match lookup_transition hash with
      | `Present | `Invalid ->
          Continue_or_stop.Stop (Ok (Mina_stdlib.Nonempty_list.init hash acc))
      | `Not_present ->
          Continue (Mina_numbers.Length.pred blockchain_length, hash :: acc) )
    ~finish:(fun (blockchain_length, _) ->
      if Mina_numbers.Length.(blockchain_length <= root_length) then
        Result.fail `No_common_ancestor
      else Result.fail `Peer_moves_too_fast )

let of_multipeer_error ~f =
  Fn.compose Error.of_string
  @@ Fn.compose (String.concat ~sep:", ") (List.map ~f)

let of_download_error =
  of_multipeer_error ~f:(fun (peer, e) ->
      Network_peer.Peer.to_string peer ^ " " ^ Error.to_string_hum e )

let of_hash_chain_error =
  of_multipeer_error ~f:(fun (peer, e) ->
      let str =
        match e with
        | `Failed_to_download_transition_chain_proof ->
            " failed to download transition chain proof"
        | `Invalid_transition_chain_proof ->
            " invalid transition chain proof"
        | `No_common_ancestor ->
            " no common ancestor"
        | `Peer_moves_too_fast ->
            " peer moves too fast"
      in
      Network_peer.Peer.to_string peer ^ str )

let result_pair_both a =
  Fn.compose
    (Result.map ~f:(fun x -> (a, x)))
    (Result.map_error ~f:(fun x -> (a, x)))

let retrieve_hash_chain_from_peer ~network ~trust_system ~logger ~root_length
    ~peer ~target_hash ~target_length ~lookup_transition
    (module I : Interruptible.F) =
  let%bind.I.Result transition_chain_proof =
    I.map
      ~f:
        (Result.map_error
           ~f:(const `Failed_to_download_transition_chain_proof) )
    @@ I.lift
    @@ Mina_networking.get_transition_chain_proof
         ~timeout:(Time.Span.of_sec 10.) network peer target_hash
  in
  (* a list of state_hashes from new to old *)
  let%bind.I.Result hashes =
    match
      Transition_chain_verifier.verify ~target_hash ~transition_chain_proof
    with
    | Some hs ->
        I.Result.return hs
    | None ->
        let error_msg =
          sprintf !"Peer %{sexp:Network_peer.Peer.t} sent us bad proof" peer
        in
        let%bind.I () =
          I.lift
          @@ Trust_system.(
               record trust_system logger peer
                 Actions.
                   ( Sent_invalid_transition_chain_merkle_proof
                   , Some (error_msg, []) ))
        in
        I.return (Result.Error `Invalid_transition_chain_proof)
  in
  let hashes_without_target_hash = Mina_stdlib.Nonempty_list.tail hashes in
  I.return
    (try_to_connect_hash_chain ~lookup_transition ~target_length ~root_length
       hashes_without_target_hash )

let remove_duplicate_peers peers =
  let open Network_peer.Peer in
  List.stable_sort peers ~compare
  |> List.remove_consecutive_duplicates ~which_to_keep:`First ~equal

let get_peers ~preferred_peers network =
  Deferred.map ~f:(fun x -> remove_duplicate_peers @@ preferred_peers @ x)
  @@ Mina_networking.peers network

let retrieve_hash_chain ~network ~trust_system ~logger ~root_length
    ~preferred_peers ~target_hash ~target_length ~lookup_transition
    (module I : Interruptible.F) =
  let%bind.I peers = I.lift (get_peers ~preferred_peers network) in
  let f peer =
    I.map ~f:(result_pair_both peer)
    @@ retrieve_hash_chain_from_peer ~network ~trust_system ~logger ~root_length
         ~peer ~target_hash ~target_length ~lookup_transition
         (module I)
  in
  let%map.I res =
    I.Result.find_map ~how:(`Max_concurrent_jobs retrieve_hash_chain_max_jobs)
      peers ~f
  in
  Result.map_error ~f:of_hash_chain_error res

let download_ancestors ~preferred_peers ~lookup_transition ~network metas
    (module I : Interruptible.F) =
  let%bind.I peers = I.lift (get_peers ~preferred_peers network) in
  let target, rev_metas = Mina_stdlib.Nonempty_list.(uncons @@ rev metas) in
  let target_hash = target.Substate.state_hash in
  (* let max_ = Transition_frontier.max_catchup_chunk_length in *)
  let max_ = 5 in
  let downloaded = State_hash.Table.create () in
  let need_transition state_hash =
    if State_hash.Table.mem downloaded state_hash then false
    else
      match lookup_transition state_hash with
      | `Not_present ->
          true
      | _ ->
          false
  in
  let hash_data block =
    Mina_block.(header block |> Header.protocol_state)
    |> Mina_state.Protocol_state.hashes
  in
  let map_res ~peer res =
    let continue = need_transition target_hash in
    match res with
    | Result.Error _ when not continue ->
        Result.Ok ()
    | Error e ->
        Error (peer, e)
    | Ok blocks ->
        List.iter blocks ~f:(fun b ->
            let bh = With_hash.of_data ~hash_data b in
            ignore
              ( State_hash.Table.add downloaded
                  ~key:(State_hash.With_state_hashes.state_hash bh)
                  ~data:(peer, bh)
                : [ `Duplicate | `Ok ] ) ) ;
        if continue then
          Error (peer, Error.of_string "target hash not retrieved")
        else Ok ()
  in
  let try_peer_iter (n, acc) { Substate.state_hash; _ } =
    let need = need_transition state_hash in
    if need && n + 1 = max_ then Continue_or_stop.Stop (max_, state_hash :: acc)
    else if need then Continue (n + 1, state_hash :: acc)
    else Continue (n, acc)
  in
  let try_peer peer =
    let n, request =
      List.fold_until rev_metas
        ~init:(1, [ target_hash ])
        ~finish:Fn.id ~f:try_peer_iter
    in
    let timeout = Float.of_int n *. sec_per_block in
    I.lift
    @@ Deferred.map ~f:(map_res ~peer)
    @@ Mina_networking.get_transition_chain
         ~heartbeat_timeout:(Time_ns.Span.of_sec timeout)
         ~timeout:(Time.Span.of_sec timeout) network peer request
  in
  let%map.I.Result () =
    I.Result.find_map ~how:`Sequential peers ~f:try_peer
    |> I.map ~f:(Result.map_error ~f:of_download_error)
  in
  Mina_stdlib.Nonempty_list.map metas ~f:(fun meta ->
      Option.value_map
        (State_hash.Table.find downloaded meta.state_hash)
        ~default:(`Meta meta, None)
        ~f:(fun (peer, block) -> (`Block block, Some peer)) )

(** [promote_to_higher_state_impl] takes state with [Processed] status and
    returns the next state with [Processing] status or [None] if the transition
    exits the catchup state.
    
    If needed, this function launches deferred action related to the new state.

    Note that some other states may be restarted (transitioned from [Failed] to [In_progress])
    on the course.
    *)
let promote_to_higher_state_impl ~write_actions ~actions ~context
    ~(transition_states : Transition_states.t) state =
  match state with
  | Transition_state.Received { header; substate; gossip_data; body_opt; aux }
    ->
      Option.some
      @@ Verifying_blockchain_proof.promote_to ~actions ~context
           ~transition_states ~header ~substate ~gossip_data ~body_opt ~aux
  | Verifying_blockchain_proof
      { header = _; substate; gossip_data; body_opt; aux; baton = _ } ->
      Option.some
      @@ Downloading_body.promote_to ~actions ~context ~transition_states
           ~substate ~gossip_data ~body_opt ~aux
  | Downloading_body { header; substate; block_vc; baton = _; aux } ->
      Option.some
      @@ Verifying_complete_works.promote_to ~actions ~context
           ~transition_states ~header ~substate ~block_vc ~aux
  | Verifying_complete_works { block; substate; block_vc; aux; baton = _ } ->
      Option.some
      @@ Building_breadcrumb.promote_to ~actions ~context ~transition_states
           ~block ~substate ~block_vc ~aux
  | Building_breadcrumb { block = _; substate; block_vc; aux; ancestors = _ } ->
      Option.some
      @@ Waiting_to_be_added_to_frontier.promote_to ~context ~substate ~block_vc
           ~aux
  | Waiting_to_be_added_to_frontier { breadcrumb; source; children = _ } ->
      let (module Context : CONTEXT) = context in
      write_actions.write_verified_transition
        ( `Transition (Frontier_base.Breadcrumb.validated_transition breadcrumb)
        , `Source source ) ;
      (* Just remove the state, it should be in frontier by now *)
      None
  | Invalid _ as e ->
      Some e

let pre_validate_header_invalid_action ~header = function
  | `Invalid_delta_block_chain_proof ->
      ( Trust_system.Actions.Gossiped_invalid_transition
      , Some ("invalid delta transition chain witness", []) )
  | `Invalid_genesis_protocol_state ->
      ( Trust_system.Actions.Gossiped_invalid_transition
      , Some ("invalid genesis protocol state", []) )
  | `Invalid_protocol_version ->
      ( Trust_system.Actions.Sent_invalid_protocol_version
      , Some
          ( "Invalid current or proposed protocol version in catchup block"
          , [ ( "current_protocol_version"
              , `String
                  ( Mina_block.Header.current_protocol_version header
                  |> Protocol_version.to_string ) )
            ; ( "proposed_protocol_version"
              , `String
                  ( Mina_block.Header.proposed_protocol_version_opt header
                  |> Option.value_map ~default:"<None>"
                       ~f:Protocol_version.to_string ) )
            ] ) )
  | `Mismatched_protocol_version ->
      ( Trust_system.Actions.Sent_mismatched_protocol_version
      , Some
          ( "Current protocol version in catchup block does not match daemon \
             protocol version"
          , [ ( "block_current_protocol_version"
              , `String
                  ( Mina_block.Header.current_protocol_version header
                  |> Protocol_version.to_string ) )
            ; ( "daemon_current_protocol_version"
              , `String Protocol_version.(current |> to_string) )
            ] ) )

let handle_invalid ~children =
  List.iter ~f:(fun meta ->
      State_hash.Table.change children meta.Substate.parent_state_hash
        ~f:(function
        | Some (`Invalid_children, lst) ->
            Some (`Invalid_children, meta.state_hash :: lst)
        | other ->
            other ) )

let get_status_name =
  Substate.view
    ~f:{ viewer = (fun { status; _ } -> Substate.name_of_status status) }
    ~state_functions

let mark_invalid ~state ?reason ~error state_hash =
  Transition_states.mark_invalid ?reason ~error ~state_hash
    state.transition_states
  |> handle_invalid ~children:state.children

(** [promote_to_higher_state] takes state hash of a transition with [Processed] status
    and updates it.
    
    The transition is updated to the highest state possible (given the available data).
    E.g. a transition with block body available from the gossip will be
    updated from [Verifying_blockchain_proof] to [Verifying_complete_works] without
    launching action to download body.

    Some other states may also be updated (promoted) if promotion of the transition
    triggers their subsequent update (promotion).

    Pre-condition: state transition is in transition states and has [Processed] status.*)
let rec promote_to_higher_state ~write_actions
    ~context:(module Context : CONTEXT) ~state state_hash =
  let context = (module Context : CONTEXT) in
  let transition_states = state.transition_states in
  let old_state =
    Option.value_exn @@ Transition_states.find transition_states state_hash
  in
  let actions = actions ~context ~state ~write_actions in
  let state_opt =
    promote_to_higher_state_impl ~context ~transition_states ~write_actions
      ~actions old_state
  in
  [%log' info Context.logger]
    "Promoting transition from state %s to state %s, status %s"
    (Transition_state.name old_state)
    (Option.value_map ~default:"(none)" ~f:Transition_state.name state_opt)
    Option.(value ~default:"(none)" @@ bind ~f:get_status_name state_opt) ;
  ( match state_opt with
  | None ->
      State_hash.Table.change state.children state_hash
        ~f:(Option.map ~f:(Tuple2.map_fst ~f:(const `Parent_in_frontier))) ;
      Transition_states.remove transition_states state_hash
  | Some st ->
      Transition_states.update transition_states st ) ;
  ( match state_opt with
  | Some (Waiting_to_be_added_to_frontier { source; breadcrumb; _ } as st) ->
      Misc.add_to_children_of_parent_in_frontier ~state
        (Transition_state.State_functions.transition_meta st) ;
      (* This needs to be done after update of the state *)
      write_actions.write_breadcrumb source breadcrumb
  | _ ->
      () ) ;
  let parent_hash =
    (Transition_state.State_functions.transition_meta old_state)
      .parent_state_hash
  in
  Substate.update_children_on_promotion ~state_functions ~transition_states
    ~parent_hash ~state_hash state_opt ;
  Option.iter state_opt ~f:(fun state ->
      if Substate.is_processing_done ~state_functions state then
        actions.mark_processed_and_promote ~reason:"promoted to Processing Done"
          [ state_hash ] )

and actions ~context ~state ~write_actions =
  { Misc.mark_processed_and_promote =
      (fun ?reason hashes ->
        if List.is_empty hashes then ()
        else
          mark_processed_and_promote ?reason ~context ~state ~write_actions
            hashes )
  ; mark_invalid = mark_invalid ~state
  }

(** [mark_processed_and_promote] takes a list of state hashes and marks corresponding
transitions processed. Then it promotes all of the transitions that can be promoted
as the result of [mark_processed].

  Pre-conditions:
   1. Order of [state_hashes] respects parent-child relationship and parent always comes first
   2. Respective substates for states from [processed] are in [Processing (Done _)] status

  Post-condition: list returned respects parent-child relationship and parent always comes first 

This is a recursive function that is called recursively when a transition
is promoted multiple times or upon completion of deferred action.
*)
and mark_processed_and_promote ?(reason = "(reason not specified)")
    ~write_actions ~context:(module Context : CONTEXT) ~state state_hashes =
  let transition_states = state.transition_states in
  let higher_state_promotees =
    Substate.mark_processed ~logger:Context.logger ~state_functions
      ~transition_states state_hashes
  in
  let transition_json h =
    let h_json = State_hash.to_yojson h in
    Option.value ~default:h_json
    @@ let%map.Option s = Transition_states.find state.transition_states h in
       `Tuple
         [ h_json
         ; `String (Transition_state.name s)
         ; `String (Option.value ~default:"" @@ get_status_name s)
         ]
  in
  [%log' info Context.logger] "Marking $transitions processed: %s" reason
    ~metadata:
      [ ("transitions", `List (List.map ~f:transition_json state_hashes)) ] ;
  let open State_hash.Set in
  let processed = of_list state_hashes in
  let promoted = of_list higher_state_promotees in
  iter (diff processed promoted) ~f:(fun key ->
      Option.iter (Transition_states.find transition_states key) ~f:(fun st ->
          let data = Transition_state.State_functions.transition_meta st in
          let open Processed_skipping.Dsu in
          add_exn ~key ~data Context.processed_dsu ;
          union ~a:key ~b:data.parent_state_hash Context.processed_dsu ;
          let children = Transition_state.children st in
          iter children.processed ~f:(fun b ->
              union ~a:key ~b Context.processed_dsu ) ) ) ;
  iter (diff promoted processed) ~f:(fun key ->
      Processed_skipping.Dsu.remove ~key Context.processed_dsu ) ;
  List.iter
    ~f:(promote_to_higher_state ~write_actions ~context:(module Context) ~state)
    higher_state_promotees

let make_context ~frontier ~time_controller ~verifier ~trust_system ~network
    ~block_storage ~get_completed_work
    ~context:(module Context_ : Transition_handler.Validator.CONTEXT) =
  let outdated_root_cache =
    Transition_handler.Core_extended_cache.Lru.create ~destruct:None 1000
  in
  let module Context = struct
    include Context_

    let frontier = frontier

    let time_controller = time_controller

    let verifier = verifier

    let trust_system = trust_system

    let check_body_in_storage = Block_storage.read_body block_storage

    (* TODO Timeouts are for now set to these values, but we want them in config *)

    let building_breadcrumb_timeout = Time.Span.of_min 2.

    let bitwap_download_timeout = Time.Span.of_min 2.

    let peer_download_timeout = Time.Span.of_min 2.

    let ancestry_verification_timeout = Time.Span.of_sec 30.

    let ancestry_download_timeout = Time.Span.of_sec 300.

    let transaction_snark_verification_timeout = Time.Span.of_sec 30.

    let download_body ~header ~preferred_peers (module I : Interruptible.F) =
      let meta = Substate.transition_meta_of_header_with_hash header in
      let%bind.I.Result res =
        download_ancestors ~preferred_peers
          ~lookup_transition:(const `Not_present)
          ~network
          (Mina_stdlib.Nonempty_list.singleton meta)
          (module I)
      in
      match Mina_stdlib.Nonempty_list.head res with
      | `Block bh, _ ->
          I.Result.return (With_hash.data bh |> Mina_block.body)
      | _ ->
          I.return
            ( Result.fail
            @@ Error.of_string "unexpected return of download_ancestors" )

    let build_breadcrumb ~received_at ~parent ~transition
        (module I : Interruptible.F) =
      I.lift
        ( Frontier_base.Breadcrumb.build_no_reporting
            ~skip_staged_ledger_verification:`Proofs ~logger ~precomputed_values
            ~get_completed_work ~verifier ~parent ~transition
            ~transition_receipt_time:(Some received_at) ()
        |> Deferred.Result.map_error ~f:convert_breadcrumb_error )

    let retrieve_chain ~some_ancestors ~target_hash ~target_length
        ~preferred_peers ~lookup_transition (module I : Interruptible.F) =
      match
        ( lookup_transition target_hash
        , Mina_stdlib.Nonempty_list.of_list_opt some_ancestors )
      with
      | `Invalid, _ | `Present, _ ->
          I.return (Or_error.error_string "target transition is present")
      | `Not_present, None -> (
          let root_length =
            Transition_frontier.root frontier
            |> Frontier_base.Breadcrumb.consensus_state
            |> Consensus.Data.Consensus_state.blockchain_length
          in
          let%bind.I.Result peer, hashes =
            retrieve_hash_chain ~network ~trust_system ~logger ~root_length
              ~preferred_peers ~target_hash ~target_length ~lookup_transition
              (module I)
          in
          let metas = hash_chain_to_metas ~target_length ~target_hash hashes in
          match lookup_transition (Mina_stdlib.Nonempty_list.head hashes) with
          | `Invalid ->
              I.Result.return
                (Mina_stdlib.Nonempty_list.map
                   ~f:(fun x -> (`Meta x, peer))
                   metas )
          | `Present ->
              (* Present *)
              let%map.I.Result res =
                download_ancestors ~preferred_peers:(peer :: preferred_peers)
                  ~lookup_transition ~network metas
                  (module I)
              in
              Mina_stdlib.Nonempty_list.map res
                ~f:(Tuple2.map_snd ~f:(Option.value ~default:peer))
          | `Not_present ->
              failwith "Unexpected return of retrieve_hash_chain" )
      | `Not_present, Some ancestors_and_senders -> (
          let ancestors, senders =
            Mina_stdlib.Nonempty_list.unzip ancestors_and_senders
          in
          let metas =
            hash_chain_to_metas ~target_length ~target_hash ancestors
          in
          let%map.I.Result res =
            download_ancestors ~preferred_peers ~lookup_transition ~network
              metas
              (module I)
          in
          (* Invariant: |metas| = |senders| = |res| *)
          let f default = Tuple2.map_snd ~f:(Option.value ~default) in
          match Mina_stdlib.Nonempty_list.map2 ~f senders res with
          | List.Or_unequal_lengths.Ok a ->
              a
          | _ ->
              failwith "unexpected condition in retrieve_chain" )

    let genesis_state_hash =
      let genesis_protocol_state =
        Precomputed_values.genesis_state_with_hashes precomputed_values
      in
      State_hash.With_state_hashes.state_hash genesis_protocol_state

    let verify_blockchain_proofs (module I : Interruptible.F) =
      Fn.compose I.lift
      @@ Mina_block.Validation.validate_proofs ~verifier ~genesis_state_hash

    let verify_transaction_proofs (module I : Interruptible.F) =
      Fn.compose I.lift @@ Verifier.verify_transaction_snarks verifier

    let processed_dsu = Processed_skipping.Dsu.create ()

    let remote s = Network_peer.Envelope.Sender.Remote s

    let record_event = function
      | `Invalid_frontier_dependencies (e, state_hash, senders) ->
          Transition_handler.Processor.handle_frontier_validation_error
            ~trust_system ~logger
            ~senders:(List.map ~f:remote senders)
            ~state_hash e
      | `Verified_header_relevance (Ok (), header_with_hash, sender) ->
          let sender = Network_peer.Envelope.Sender.Remote sender in
          (* This action is deferred because it may potentially trigger change of
             ban status of a peer which requires writing to a synchonous pipe. *)
          don't_wait_for
          @@ Transition_handler.Validator.record_transition_is_relevant ~logger
               ~trust_system ~sender ~time_controller header_with_hash
      | `Verified_header_relevance (Error error, header_with_hash, sender) ->
          let sender = Network_peer.Envelope.Sender.Remote sender in
          (* This action is deferred because it may potentially trigger change of
             ban status of a peer which requires writing to a synchonous pipe. *)
          don't_wait_for
          @@ Transition_handler.Validator.record_transition_is_irrelevant
               ~frontier ~outdated_root_cache ~logger ~trust_system ~sender
               ~error header_with_hash
      | `Pre_validate_header_invalid (sender, header, e) ->
          let sender = Network_peer.Envelope.Sender.Remote sender in
          let action = pre_validate_header_invalid_action ~header e in
          (* This action is deferred because it may potentially trigger change of
             ban status of a peer which requires writing to a synchonous pipe. *)
          don't_wait_for
          @@ Trust_system.record_envelope_sender trust_system logger sender
               action
  end in
  (module Context : CONTEXT)

module Transition_states_callbacks (Context : sig
  val trust_system : Trust_system.t

  val logger : Logger.t
end) =
struct
  let on_invalid ?(reason = `Other) ~error ~aux _meta =
    let f { Transition_state.sender; gossip; _ } =
      let action =
        match reason with
        | `Other when gossip ->
            Trust_system.Actions.Gossiped_invalid_transition
        | `Other ->
            Sent_invalid_transition
        | `Proof ->
            Sent_invalid_proof
        | `Signature_or_proof ->
            Sent_invalid_signature_or_proof
      in
      Trust_system.record_envelope_sender Context.trust_system Context.logger
        (Network_peer.Envelope.Sender.Remote sender)
        (action, Some (Error.to_string_hum error, []))
    in
    don't_wait_for (Deferred.List.iter ~f aux.Transition_state.received)

  let on_add_new state_hash =
    [%log' info Context.logger]
      "Adding transition $state_hash to bit-catchup state"
      ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
    Mina_metrics.Gauge.inc_one
      Mina_metrics.Transition_frontier_controller.transitions_being_processed

  let on_remove state_hash =
    [%log' info Context.logger]
      "Removing transition $state_hash from bit-catchup state"
      ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
    Mina_metrics.Gauge.dec_one
      Mina_metrics.Transition_frontier_controller.transitions_being_processed
end

let create_in_mem_transition_states ~trust_system ~logger =
  Transition_states.create_inmem
    ( module Transition_states_callbacks (struct
      let trust_system = trust_system

      let logger = logger
    end) )

let run ~frontier ~context ~trust_system ~verifier ~network ~time_controller
    ~get_completed_work ~collected_transitions ~network_transition_reader
    ~producer_transition_reader ~clear_reader ~verified_transition_writer =
  let open Pipe_lib in
  (* Overflow of this buffer shouldn't happen because building a breadcrumb is expected to be a more time-heavy action than inserting the breadcrumb into frontier *)
  let breadcrumb_notification_reader, breadcrumb_notification_writer =
    Strict_pipe.create ~name:"frontier-notifier"
      (Buffered (`Capacity 1, `Overflow (Strict_pipe.Drop_head ignore)))
  in
  let state =
    match Transition_frontier.catchup_state frontier with
    | Bit t ->
        t
    | _ ->
        failwith
          "If super catchup is running, the frontier should have a full \
           catchup tree"
  in
  let (module Context_ : Transition_handler.Validator.CONTEXT) = context in
  (* TODO is "block-db" the right path ? *)
  let block_storage = Block_storage.open_ ~logger:Context_.logger "block-db" in

  let write_verified_transition (`Transition t, `Source s) : unit =
    (* TODO remove validation_callback from Transition_router and then remove the `Valid_cb argument *)
    Pipe_lib.Strict_pipe.Writer.write verified_transition_writer
      (`Transition t, `Source s, `Valid_cb None)
  in
  let write_breadcrumb source b =
    Queue.enqueue state.breadcrumb_queue (source, b) ;
    Pipe_lib.Strict_pipe.Writer.write breadcrumb_notification_writer ()
  in
  let write_actions = { write_verified_transition; write_breadcrumb } in

  let context =
    make_context ~context ~frontier ~time_controller ~verifier ~trust_system
      ~network ~block_storage ~get_completed_work
  in
  let (module Context : CONTEXT) = context in
  let logger = Context.logger in
  let transition_states = state.transition_states in
  let actions = actions ~context ~state ~write_actions in
  List.iter collected_transitions
    ~f:(Received.handle_collected_transition ~context ~actions ~state) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback producer_transition_reader
       ~f:(fun b ->
         let st_opt =
           Waiting_to_be_added_to_frontier.handle_produced_transition ~context
             ~transition_states b
         in
         Option.iter st_opt
           ~f:
             (Fn.compose
                (Misc.add_to_children_of_parent_in_frontier ~state)
                Transition_state.State_functions.transition_meta ) ;
         write_breadcrumb `Internal b ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback network_transition_reader
       ~f:(Received.handle_network_transition ~context ~actions ~state) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback clear_reader ~f:(fun _ ->
         let open Strict_pipe.Writer in
         Transition_states.shutdown_in_progress transition_states ;
         kill breadcrumb_notification_writer ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter breadcrumb_notification_reader ~f:(fun () ->
         let f (_, b) =
           let parent_hash = Frontier_base.Breadcrumb.parent_hash b in
           match Transition_frontier.find frontier parent_hash with
           | Some _ ->
               true
           | _ ->
               let state_hash = Frontier_base.Breadcrumb.state_hash b in
               [%log warn]
                 "When trying to add breadcrumb $state_hash, its parent had \
                  been removed from transition frontier: $parent_hash"
                 ~metadata:
                   [ ("parent_hash", State_hash.to_yojson parent_hash)
                   ; ("state_hash", State_hash.to_yojson state_hash)
                   ] ;
               false
         in
         let breadcrumbs =
           Queue.to_list state.breadcrumb_queue |> List.filter ~f
         in
         Queue.clear state.breadcrumb_queue ;
         List.iter breadcrumbs ~f:(fun (source, b) ->
             match source with
             | `Gossip ->
                 Mina_metrics.Counter.inc_one
                   Mina_metrics.Transition_frontier_controller
                   .breadcrumbs_built_by_processor
             | `Internal ->
                 let transition_time =
                   Transition_frontier.Breadcrumb.validated_transition b
                   |> Mina_block.Validated.header
                   |> Mina_block.Header.protocol_state
                   |> Mina_state.Protocol_state.blockchain_state
                   |> Mina_state.Blockchain_state.timestamp
                   |> Block_time.to_time_exn
                 in
                 Perf_histograms.add_span
                   ~name:"accepted_transition_local_latency"
                   (Core_kernel.Time.diff
                      Block_time.(now time_controller |> to_time_exn)
                      transition_time )
             | _ ->
                 () ) ;
         let%map.Deferred () =
           Transition_frontier.add_breadcrumbs_exn Context.frontier
             (List.map ~f:snd breadcrumbs)
         in
         let promote_do =
           promote_to_higher_state_impl ~context ~transition_states ~actions
             ~write_actions
         in
         let promote (source, b) =
           ( match source with
           | `Internal ->
               ()
           | _ ->
               Transition_handler.Processor.record_block_inclusion_time
                 (Frontier_base.Breadcrumb.validated_transition b)
                 ~time_controller
                 ~consensus_constants:Context.consensus_constants ) ;
           let state_hash = Frontier_base.Breadcrumb.state_hash b in
           Transition_states.update' transition_states state_hash ~f:promote_do
         in
         List.iter breadcrumbs ~f:promote )
(* TODO handle case when transition states were recovered from persistence and some transitions
   were marked `Processing Done` or `Processed` but were not promoted *)
