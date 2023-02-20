open Mina_base
open Core_kernel
open Async_kernel
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

let check_hash_chain ~lookup_transition ~target_length ~root_length ~target_hash
    transition_chain_proof =
  let%bind.Result hashes =
    Transition_chain_verifier.verify ~target_hash ~transition_chain_proof
    |> Option.value_map ~f:Result.return
         ~default:(Error `Invalid_transition_chain_proof)
  in
  let hashes_without_target_hash = Mina_stdlib.Nonempty_list.tail hashes in
  try_to_connect_hash_chain ~lookup_transition ~target_length ~root_length
    hashes_without_target_hash

let parent_hash header =
  With_hash.data header |> Mina_block.Header.protocol_state
  |> Mina_state.Protocol_state.previous_state_hash

let parent_length h =
  With_hash.data h |> Mina_block.Header.blockchain_length
  |> Mina_numbers.Length.pred

let handle_transition_chain_proof ~lookup_transition ~root_length ~target_length
    ~target_hash (bottom_hash, body_hashes, headers) =
  let headers_rev = List.rev headers in
  let check_header (found_ancestor, state_hash, acc) header =
    let parent_hash = parent_hash header in
    if State_hash.(With_state_hashes.state_hash header = state_hash) then
      match lookup_transition parent_hash with
      | `Invalid ->
          Continue_or_stop.Stop (Result.Ok (true, parent_hash, header :: acc))
      | `Present ->
          Continue (true, parent_hash, header :: acc)
      | _ ->
          Continue (found_ancestor, parent_hash, header :: acc)
    else Stop (Error `Invalid_transition_chain_proof)
  in
  let%bind.Result found_ancestor, parent_hash_of_first_header, headers =
    List.fold_until headers_rev ~init:(false, target_hash, []) ~f:check_header
      ~finish:Result.return
  in
  if found_ancestor then
    Ok (Mina_stdlib.Nonempty_list.singleton parent_hash_of_first_header, headers)
  else
    let target_length' =
      Option.value_map (List.hd headers) ~default:target_length ~f:parent_length
    in
    check_hash_chain ~lookup_transition ~target_length:target_length'
      ~root_length ~target_hash:parent_hash_of_first_header
      (bottom_hash, body_hashes)
    |> Result.map ~f:(fun hashes -> (hashes, headers))

let retrieve_hash_chain_from_peer ~network ~trust_system ~logger ~root_length
    ~target_hash ~target_length ~lookup_transition ~canopy peer
    (module I : Interruptible.F) =
  let%bind.I.Result resp =
    I.map
      ~f:
        (Result.map_error
           ~f:(const `Failed_to_download_transition_chain_proof) )
    @@ I.lift
    @@ Mina_networking.get_transition_chain_proof
         ~timeout:(Time.Span.of_sec 10.) network peer (target_hash, canopy)
  in
  match
    handle_transition_chain_proof ~lookup_transition ~root_length ~target_length
      ~target_hash resp
  with
  | Ok res ->
      I.Result.return res
  | Error e ->
      let error_msg =
        sprintf !"Peer %{sexp:Network_peer.Peer.t} sent us bad proof" peer
      in
      let%map.I.Deferred_let_syntax () =
        Trust_system.(
          record trust_system logger peer
            Actions.
              (Sent_invalid_transition_chain_merkle_proof, Some (error_msg, [])))
      in
      Error e

let remove_duplicate_peers peers =
  let open Network_peer.Peer in
  List.stable_sort peers ~compare
  |> List.remove_consecutive_duplicates ~which_to_keep:`First ~equal

let get_peers ~preferred_peers network =
  Deferred.map ~f:(fun x -> remove_duplicate_peers @@ preferred_peers @ x)
  @@ Mina_networking.peers network

let retrieve_hash_chain ~network ~trust_system ~logger ~root_length
    ~preferred_peers ~target_hash ~target_length ~lookup_transition ~canopy
    ~config (module I : Interruptible.F) =
  let%bind.I.Deferred_let_syntax peers = get_peers ~preferred_peers network in
  let f peer =
    I.map ~f:(result_pair_both peer)
    @@ retrieve_hash_chain_from_peer ~network ~trust_system ~logger ~root_length
         ~target_hash ~target_length ~lookup_transition ~canopy peer
         (module I)
  in
  let%map.I res =
    I.Result.find_map
      ~how:(`Max_concurrent_jobs config.Mina_intf.max_retrieve_hash_chain_jobs)
      peers ~f
  in
  Result.map_error ~f:of_hash_chain_error res

let download_ancestors ~config ~preferred_peers ~lookup_transition ~network
    metas (module I : Interruptible.F) =
  let%bind.I.Deferred_let_syntax peers = get_peers ~preferred_peers network in
  let target, rev_metas = Mina_stdlib.Nonempty_list.(uncons @@ rev metas) in
  let target_hash = target.Substate.state_hash in
  let max_ = Transition_frontier.max_catchup_chunk_length in
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
    let timeout =
      Float.of_int n *. config.Mina_intf.max_download_time_per_block_sec
    in
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

(** [compute_next_state] takes state with [Processed] status and
    returns the next state with [Processing] status or [None] if the transition
    exits the catchup state.
    
    If needed, this function launches deferred action related to the new state.

    Note that some other states may be restarted (transitioned from [Failed] to [In_progress])
    on the course.

    Actions are wrapped into [Deferred.t] to prevent using them in the current async context.
    *)
let compute_next_state ~write_actions ~(actions : Misc.actions Deferred.t)
    ~context ~(transition_states : Transition_states.t) state =
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

let get_status_name =
  Substate.view
    ~f:{ viewer = (fun { status; _ } -> Substate.name_of_status status) }
    ~state_functions

(** [promote_to_next_state] takes [old_state] of a transition with [Processed] status
    and updates it to [next_state_opt].
    
    Some other states may also be promoted if promotion of the transition
    triggers they are successors of the transition and are in [Processed] status.
*)
let promote_to_next_state ~context:(module Context : CONTEXT) ~write_actions
    ~state ~actions old_state =
  let transition_states = state.transition_states in
  let new_state_opt =
    compute_next_state
      ~context:(module Context)
      ~transition_states ~write_actions ~actions old_state
  in
  let meta = Transition_state.State_functions.transition_meta old_state in
  let state_hash = meta.state_hash in
  let parent_hash = meta.parent_state_hash in
  [%log' info Context.logger]
    "Promoting transition $state_hash from state %s to state %s, status %s"
    (Transition_state.State_functions.name old_state)
    (Option.value_map ~default:"(none)" ~f:Transition_state.State_functions.name
       new_state_opt )
    Option.(value ~default:"(none)" @@ bind ~f:get_status_name new_state_opt)
    ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
  ( match new_state_opt with
  | None ->
      State_hash.Table.change state.children state_hash
        ~f:(Option.map ~f:(Tuple2.map_fst ~f:(const `Parent_in_frontier))) ;
      Transition_states.remove ~reason:`In_frontier transition_states state_hash
  | Some st ->
      Transition_states.update transition_states st ) ;
  Processed_skipping.Dsu.remove ~key:state_hash Context.processed_dsu ;
  ( match new_state_opt with
  | Some (Waiting_to_be_added_to_frontier { source; breadcrumb; _ } as st) ->
      Misc.add_to_children_of_parent_in_frontier ~state
        (Transition_state.State_functions.transition_meta st) ;
      (* This needs to be done after update of the state *)
      write_actions.write_breadcrumb source breadcrumb
  | _ ->
      () ) ;
  Substate.update_children_on_promotion ~state_functions ~transition_states
    ~parent_hash ~state_hash new_state_opt ;
  new_state_opt

let union_if_levels_equal ~dsu a_st b_st =
  let a = (Transition_state.State_functions.transition_meta a_st).state_hash in
  let b = (Transition_state.State_functions.transition_meta b_st).state_hash in
  if Transition_state.State_functions.equal_state_levels a_st b_st then
    Processed_skipping.Dsu.union ~a ~b dsu

let union_if_levels_equal' ~transition_states ~dsu a_st b =
  Option.value_map ~default:()
    ~f:(union_if_levels_equal ~dsu a_st)
    (Transition_states.find transition_states b)

let add_to_dsu ?parent_opt ~transition_states ~dsu st =
  let meta = Transition_state.State_functions.transition_meta st in
  Processed_skipping.Dsu.add_exn ~key:meta.Substate.state_hash ~data:meta dsu ;
  let is_processed st =
    let viewer = function
      | { Substate.status = Processed _; _ } ->
          true
      | _ ->
          false
    in
    Substate.view st ~state_functions ~f:{ viewer }
    |> Option.value ~default:false
  in
  let union_parent parent =
    if is_processed parent then union_if_levels_equal ~dsu st parent
  in
  let parent_opt =
    match parent_opt with
    | None ->
        Transition_states.find transition_states meta.parent_state_hash
    | Some p ->
        p
  in
  Option.iter parent_opt ~f:union_parent ;
  State_hash.Set.iter (Transition_state.children st).processed
    ~f:(union_if_levels_equal' ~transition_states ~dsu st)

let rec promote_to_higher_state ~context ~write_actions ~state ~actions
    old_state =
  let meta = Transition_state.State_functions.transition_meta old_state in
  let (module Context : CONTEXT) = context in
  let transition_states = state.transition_states in
  let update_dsu_and_decide_on_promotion st =
    let parent_opt =
      Transition_states.find transition_states meta.parent_state_hash
    in
    add_to_dsu ~transition_states ~dsu:Context.processed_dsu ~parent_opt st ;
    Substate.is_parent_higher ~state_functions st parent_opt
    |> Fn.flip Option.some_if st
  in
  let mark_single () =
    [%log' debug Context.logger]
      "Marking transition $state_hash processed (after just being promoted)"
      ~metadata:[ ("state_hash", State_hash.to_yojson meta.state_hash) ] ;
    let%bind.Option _old_state, _old_children =
      Substate.mark_processed_single ~logger:Context.logger ~state_functions
        ~transition_states meta.state_hash
    in
    Transition_states.find transition_states meta.state_hash
  in
  let continue_if_is_processing_done state =
    Option.some_if (Substate.is_processing_done ~state_functions state) ()
  in
  let open Option in
  promote_to_next_state ~context ~write_actions ~state ~actions old_state
  >>= continue_if_is_processing_done >>= mark_single
  >>= update_dsu_and_decide_on_promotion
  >>| promote_to_higher_state ~context ~write_actions ~state ~actions
  |> value ~default:()

let report_time_used_for type_ span =
  let gauge =
    let open Mina_metrics.Catchup in
    match type_ with
    | `Download ->
        download_time
    | `Initial_catchup ->
        initial_catchup_time
    | `Block_proof ->
        initial_validation_time
    | `Complete_work_proof ->
        verification_time
    | `Breadcrumb_build ->
        build_breadcrumb_time
  in
  Mina_metrics.Gauge.set gauge (Time.Span.to_ms span)

(** 
Returns [Misc.actions] object with [mark_invalid] and [mark_processed_and_promote] fields.

[mark_processed_and_promote] takes a list of state hashes and marks corresponding
transitions processed. Then it promotes all of the transitions that can be promoted
as the result of [mark_processed].

  Pre-conditions:
   1. Order of [state_hashes] respects parent-child relationship and parent always comes first
   2. Respective substates for states from [processed] are in [Processing (Done _)] status

  Post-condition: list returned respects parent-child relationship and parent always comes first 

This is a recursive function that is called recursively when a transition
is promoted multiple times or upon completion of deferred action.
*)
let actions ~write_actions ~context ~state =
  let (module Context : CONTEXT) = context in
  let transition_states = state.transition_states in
  let transition_json h =
    let h_json = State_hash.to_yojson h in
    Option.value ~default:h_json
    @@ let%map.Option s = Transition_states.find transition_states h in
       `Tuple
         [ h_json
         ; `String (Transition_state.State_functions.name s)
         ; `String (Option.value ~default:"" @@ get_status_name s)
         ]
  in
  let mpp_impl ~actions ?(reason = "(reason not specified)") state_hashes =
    [%log' debug Context.logger] "Marking $transitions processed: %s" reason
      ~metadata:
        [ ("transitions", `List (List.map ~f:transition_json state_hashes)) ] ;
    let higher_state_promotees =
      Substate.mark_processed ~logger:Context.logger ~state_functions
        ~transition_states state_hashes
    in
    List.iter state_hashes ~f:(fun state_hash ->
        Option.iter
          (Transition_states.find transition_states state_hash)
          ~f:(add_to_dsu ~transition_states ~dsu:Context.processed_dsu) ) ;
    List.iter higher_state_promotees ~f:(fun state_hash ->
        Transition_states.find transition_states state_hash
        |> Option.value_exn
        |> promote_to_higher_state ~write_actions ~context ~state ~actions )
  in
  let rec mark_processed_and_promote ?reason hashes =
    if List.is_empty hashes then ()
    else mpp_impl ~actions:(Deferred.return actions) ?reason hashes
  and actions =
    { mark_invalid = Bit_catchup_state.mark_invalid ~state
    ; mark_processed_and_promote
    }
  in
  actions

type throttles = { verifier : Simple_throttle.t; download : Simple_throttle.t }

let make_context ~frontier ~time_controller ~verifier ~trust_system ~network
    ~block_storage ~get_completed_work ~throttles
    ~context:(module Context_ : Context.MINI_CONTEXT) =
  let outdated_root_cache =
    Transition_handler.Core_extended_cache.Lru.create ~destruct:None 1000
  in
  let module Context = struct
    include Context_

    let frontier = frontier

    let time_controller = time_controller

    let verifier = verifier

    let trust_system = trust_system

    let check_body_in_storage body_ref =
      let res = Lmdb_storage.Block.read_body block_storage body_ref in
      Result.iter_error res ~f:(function
        | `Non_full ->
            ()
        | `Tx_failed ->
            [%log error]
              "LMDB transaction failed unexpectedly while reading block \
               $body_reference"
              ~metadata:
                [ ("body_reference", Consensus.Body_reference.to_yojson body_ref)
                ]
        | `Invalid_structure e ->
            [%log error]
              "Couldn't read body for $body_reference with Full status: $error"
              ~metadata:
                [ ("body_reference", Consensus.Body_reference.to_yojson body_ref)
                ; ("error", `String (Error.to_string_hum e))
                ] ) ;
      Result.ok res

    let download_body ~header ~preferred_peers (module I : Interruptible.F) =
      let start_time = Time.now () in
      let body_ref = Mina_block.Header.body_reference (With_hash.data header) in
      let meta = Substate.transition_meta_of_header_with_hash header in
      let%bind.I.Deferred_let_syntax () =
        if catchup_config.bitswap_enabled then
          let%bind () =
            Mina_networking.download_bitswap_resource network ~tag:Body
              ~ids:[ body_ref ]
          in
          Async.after catchup_config.bitwap_download_timeout
        else Deferred.unit
      in
      if catchup_config.bitswap_enabled then
        [%log info]
          "Bitswap download of body $body_reference for $state_hash failed"
          ~metadata:
            [ ("state_hash", State_hash.to_yojson meta.state_hash)
            ; ("body_reference", Consensus.Body_reference.to_yojson body_ref)
            ] ;
      let%bind.I.Result res =
        download_ancestors ~preferred_peers
          ~lookup_transition:(const `Not_present)
          ~network ~config:catchup_config
          (Mina_stdlib.Nonempty_list.singleton meta)
          (module I)
      in
      report_time_used_for `Download Time.(diff (now ()) start_time) ;
      match Mina_stdlib.Nonempty_list.head res with
      | `Block bh, _ ->
          let body = Mina_block.body (With_hash.data bh) in
          let%map.I.Deferred_let_syntax () =
            if Misc.is_block_not_full ~logger block_storage body_ref then
              Mina_networking.add_bitswap_resource network ~id:body_ref
                ~tag:Body
                ~data:(Staged_ledger_diff.Body.to_raw_string body)
            else Deferred.unit
          in
          Ok body
      | _ ->
          I.return
            ( Result.fail
            @@ Error.of_string "unexpected return of download_ancestors" )

    let build_breadcrumb ~received_at ~parent ~transition
        (module I : Interruptible.F) =
      let start_time = Time.now () in
      let%map.I.Result res =
        I.lift
          ( Frontier_base.Breadcrumb.build_no_reporting
              ~skip_staged_ledger_verification:`Proofs ~logger
              ~precomputed_values ~verifier ~get_completed_work ~parent
              ~transition ~transition_receipt_time:(Some received_at) ()
          |> Deferred.Result.map_error
               ~f:Frontier_base.Breadcrumb.simplify_breadcrumb_building_error )
      in
      report_time_used_for `Breadcrumb_build Time.(diff (now ()) start_time) ;
      res

    let retrieve_chain ~some_ancestors ~canopy ~target_hash ~target_length
        ~preferred_peers ~lookup_transition (module I : Interruptible.F) =
      match
        ( lookup_transition target_hash
        , Mina_stdlib.Nonempty_list.of_list_opt some_ancestors )
      with
      | `Invalid, _ | `Present, _ ->
          I.return (Or_error.error_string "target transition is present")
      | `Not_present, Some ancestors_and_senders
        when not catchup_config.bitswap_enabled -> (
          let ancestors, senders =
            Mina_stdlib.Nonempty_list.unzip ancestors_and_senders
          in
          let metas =
            hash_chain_to_metas ~target_length ~target_hash ancestors
          in
          let preferred_peers =
            preferred_peers @ Mina_stdlib.Nonempty_list.to_list senders
          in
          let start_time = Time.now () in
          let%map.I.Result res =
            download_ancestors ~preferred_peers ~lookup_transition ~network
              ~config:catchup_config metas
              (module I)
          in
          report_time_used_for `Download Time.(diff (now ()) start_time) ;
          (* Invariant: |metas| = |senders| = |res| *)
          let f default = Tuple2.map_snd ~f:(Option.value ~default) in
          match Mina_stdlib.Nonempty_list.map2 ~f senders res with
          | List.Or_unequal_lengths.Ok a ->
              a
          | _ ->
              failwith "unexpected condition in retrieve_chain" )
      | `Not_present, _ -> (
          let senders = List.(rev @@ map ~f:snd some_ancestors) in
          let preferred_peers = preferred_peers @ senders in
          let root_length =
            Transition_frontier.root frontier
            |> Frontier_base.Breadcrumb.consensus_state
            |> Consensus.Data.Consensus_state.blockchain_length
          in
          let%bind.I.Result peer, (hashes, headers) =
            retrieve_hash_chain ~network ~trust_system ~logger ~root_length
              ~preferred_peers ~target_hash ~target_length ~lookup_transition
              ~canopy ~config:catchup_config
              (module I)
          in
          let hash_metas =
            Option.value_map (List.hd headers)
              ~default:(hash_chain_to_metas ~target_length ~target_hash)
              ~f:(fun h ->
                hash_chain_to_metas ~target_length:(parent_length h)
                  ~target_hash:(parent_hash h) )
              hashes
          in
          let metas =
            let head, rest = Mina_stdlib.Nonempty_list.uncons hash_metas in
            Mina_stdlib.Nonempty_list.init (`Meta head, peer)
            @@ List.map ~f:(fun m -> (`Meta m, peer)) rest
            @ List.map headers ~f:(fun h -> (`Header h, peer))
          in
          match lookup_transition (Mina_stdlib.Nonempty_list.head hashes) with
          | `Present when List.is_empty headers ->
              let start_time = Time.now () in
              let%map.I.Result res =
                download_ancestors ~preferred_peers:(peer :: preferred_peers)
                  ~lookup_transition ~network ~config:catchup_config hash_metas
                  (module I)
              in
              report_time_used_for `Download Time.(diff (now ()) start_time) ;
              Mina_stdlib.Nonempty_list.map res
                ~f:(Tuple2.map_snd ~f:(Option.value ~default:peer))
          | _ ->
              I.Result.return metas )

    let genesis_state_hash =
      let genesis_protocol_state =
        Precomputed_values.genesis_state_with_hashes precomputed_values
      in
      State_hash.With_state_hashes.state_hash genesis_protocol_state

    let verify_blockchain_proofs (module I : Interruptible.F) headers =
      let start_time = Time.now () in
      let%map.I.Result res =
        I.lift
        @@ Mina_block.Validation.validate_proofs ~verifier ~genesis_state_hash
             headers
      in
      report_time_used_for `Block_proof Time.(diff (now ()) start_time) ;
      res

    let verify_transaction_proofs (module I : Interruptible.F) works =
      let start_time = Time.now () in
      let%map.I.Result res =
        I.lift @@ Verifier.verify_transaction_snarks verifier works
      in
      report_time_used_for `Complete_work_proof Time.(diff (now ()) start_time) ;
      res

    let processed_dsu = Processed_skipping.Dsu.create ()

    let record_event = function
      | `Verified_header_relevance (Ok (), header_with_hash, senders) ->
          (* This action is deferred because it may potentially trigger change of
             ban status of a peer which requires writing to a synchonous pipe. *)
          don't_wait_for
          @@ Transition_handler.Validator.record_transition_is_relevant ~logger
               ~trust_system ~senders ~time_controller header_with_hash
      | `Verified_header_relevance (Error error, header_with_hash, senders) ->
          (* This action is deferred because it may potentially trigger change of
             ban status of a peer which requires writing to a synchonous pipe. *)
          don't_wait_for
          @@ Transition_handler.Validator.record_transition_is_irrelevant
               ~frontier ~outdated_root_cache ~logger ~trust_system ~senders
               ~error header_with_hash
      | `Pre_validate_header_invalid (sender, header, e) ->
          let sender = Network_peer.Envelope.Sender.Remote sender in
          let action = pre_validate_header_invalid_action ~header e in
          (* This action is deferred because it may potentially trigger change of
             ban status of a peer which requires writing to a synchonous pipe. *)
          don't_wait_for
          @@ Trust_system.record_envelope_sender trust_system logger sender
               action
      | `Preserved_body_for_retrieved_ancestor (body_ref, body) ->
          if Misc.is_block_not_full ~logger block_storage body_ref then
            (* TODO check it's not yet there *)
            don't_wait_for
              (Mina_networking.add_bitswap_resource ~id:body_ref ~tag:Body
                 ~data:(Staged_ledger_diff.Body.to_raw_string body)
                 network )

    let allocate_bandwidth ?priority = function
      | `Verifier ->
          Simple_throttle.allocate ?priority throttles.verifier
      | `Download ->
          Simple_throttle.allocate ?priority throttles.download

    let deallocate_bandwidth = function
      | `Verifier ->
          Simple_throttle.deallocate throttles.verifier
      | `Download ->
          Simple_throttle.deallocate throttles.download

    let broadcast b =
      don't_wait_for (Mina_networking.broadcast_transition network b)

    let rebroadcast ~origin_topics b =
      don't_wait_for
        (Mina_networking.rebroadcast_transition network ~origin_topics b)
  end in
  (module Context : CONTEXT)

let run ~frontier ~on_block_body_update_ref ~context ~trust_system ~verifier
    ~network ~time_controller ~get_completed_work ~collected_transitions
    ~network_transition_reader ~producer_transition_reader ~clear_reader
    ~verified_transition_writer =
  let open Pipe_lib in
  (* Overflow of this buffer shouldn't happen because building a breadcrumb is expected to be a more time-heavy action than inserting the breadcrumb into frontier *)
  let breadcrumb_notification_reader, breadcrumb_notification_writer =
    Strict_pipe.create ~name:"frontier-notifier"
      (Buffered (`Capacity 1, `Overflow (Strict_pipe.Drop_head ignore)))
  in
  let state, for_catchup =
    match Transition_frontier.catchup_state frontier with
    | Bit t ->
        t
    | _ ->
        failwith
          "If super catchup is running, the frontier should have a full \
           catchup tree"
  in
  let (module Context_ : Context.MINI_CONTEXT) = context in
  let write_verified_transition (`Transition t, `Source _) : unit =
    Pipe_lib.Strict_pipe.Writer.write verified_transition_writer t
  in
  let write_breadcrumb source b =
    Queue.enqueue state.breadcrumb_queue (source, b) ;
    Pipe_lib.Strict_pipe.Writer.write breadcrumb_notification_writer ()
  in
  let write_actions = { write_verified_transition; write_breadcrumb } in
  let throttles =
    { verifier =
        Simple_throttle.create Context_.catchup_config.max_verifier_jobs
    ; download =
        Simple_throttle.create Context_.catchup_config.max_download_jobs
    }
  in
  let context =
    make_context ~context ~frontier ~time_controller ~verifier ~trust_system
      ~network ~block_storage:state.block_storage ~throttles ~get_completed_work
  in
  let logger = Context_.logger in
  let transition_states = state.transition_states in
  let actions = actions ~context ~state ~write_actions in
  let prev_bitswap_update_f = !on_block_body_update_ref in
  (on_block_body_update_ref :=
     function
     | `Broken ->
         List.iter
           ~f:
             (Known_body_refs.handle_broken ~logger state.known_body_refs
                ~mark_invalid:
                  (actions.Misc.mark_invalid
                     ~error:(Error.of_string "broken body") ) )
     | `Added ->
         List.iter
           ~f:
             (Received.handle_downloaded_body ~context ~actions
                ~known_body_refs:state.known_body_refs ~transition_states ) ) ;
  let initial_catchup_trigger = ref (Some (Block_time.now time_controller)) in
  List.iter for_catchup ~f:(fun hh ->
      let body = Context.check_body_of_header_in_storage ~context hh in
      Result.iter_error
        (Received.pre_validate_and_add_retrieved ~context ~actions ~state ?body
           hh ) ~f:(fun err ->
          [%log warn]
            "Invalid $header with $state_hash pre-loaded from header storage: \
             $error"
            ~metadata:
              [ ("header", Mina_block.Header.to_yojson (With_hash.data hh))
              ; ( "state_hash"
                , State_hash.With_state_hashes.state_hash hh
                  |> State_hash.to_yojson )
              ; ("error", Error_json.error_to_yojson err)
              ] ) ) ;
  List.iter collected_transitions ~f:(fun transition_tuple ->
      Received.handle_collected_transition ~context ~actions ~state
        transition_tuple
      |> function
      | `No_body_preserved ->
          ()
      | `Preserved_body (body_ref, body) ->
          if Misc.is_block_not_full ~logger state.block_storage body_ref then
            don't_wait_for
              (Mina_networking.add_bitswap_resource network ~id:body_ref
                 ~tag:Body
                 ~data:(Staged_ledger_diff.Body.to_raw_string body) ) ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter producer_transition_reader ~f:(fun b ->
         let body = Frontier_base.Breadcrumb.block b |> Mina_block.body in
         let body_ref =
           Frontier_base.Breadcrumb.block b
           |> Mina_block.header |> Mina_block.Header.body_reference
         in
         let%map () =
           Mina_networking.add_bitswap_resource network ~id:body_ref ~tag:Body
             ~data:(Staged_ledger_diff.Body.to_raw_string body)
         in
         let st_opt =
           Waiting_to_be_added_to_frontier.handle_produced_transition ~context
             ~state b
         in
         Option.iter st_opt
           ~f:
             (Fn.compose
                (Misc.add_to_children_of_parent_in_frontier ~state)
                Transition_state.State_functions.transition_meta ) ;
         write_breadcrumb `Internal b ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter network_transition_reader ~f:(fun gossip ->
         Received.handle_network_transition ~context ~actions ~state gossip
         |> function
         | `Preserved_body (body_ref, body)
           when Misc.is_block_not_full ~logger state.block_storage body_ref ->
             Mina_networking.add_bitswap_resource network ~id:body_ref ~tag:Body
               ~data:(Staged_ledger_diff.Body.to_raw_string body)
         | _ ->
             Deferred.unit ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter_without_pushback clear_reader ~f:(fun _ ->
         let open Strict_pipe.Writer in
         on_block_body_update_ref := prev_bitswap_update_f ;
         Transition_states.shutdown_in_progress transition_states ;
         kill breadcrumb_notification_writer ) ;
  don't_wait_for
  @@ Strict_pipe.Reader.iter breadcrumb_notification_reader ~f:(fun () ->
         let f (_, b) =
           let parent_hash = Frontier_base.Breadcrumb.parent_hash b in
           let state_hash = Frontier_base.Breadcrumb.state_hash b in
           match
             ( Transition_frontier.find frontier parent_hash
             , Transition_states.find transition_states state_hash )
           with
           | Some _, Some _ ->
               true
           | None, _ ->
               [%log warn]
                 "When trying to add breadcrumb $state_hash, its parent has \
                  been removed from transition frontier: $parent_hash"
                 ~metadata:
                   [ ("parent_hash", State_hash.to_yojson parent_hash)
                   ; ("state_hash", State_hash.to_yojson state_hash)
                   ] ;
               false
           | _, None ->
               [%log warn]
                 "When trying to add breadcrumb $state_hash, it has been \
                  removed from transition states"
                 ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] ;
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
           Transition_frontier.add_breadcrumbs_exn frontier
             (List.map ~f:snd breadcrumbs)
         in
         let promote (source, b) =
           ( match source with
           | `Internal ->
               ()
           | _ ->
               let transition_time =
                 Transition_handler.Processor.record_block_inclusion_time
                   (Frontier_base.Breadcrumb.validated_transition b)
                   ~time_controller
                   ~consensus_constants:Context_.consensus_constants
               in
               Option.iter !initial_catchup_trigger ~f:(fun start_time ->
                   if Block_time.(start_time < transition_time) then (
                     initial_catchup_trigger := None ;
                     let now_ = Block_time.now time_controller in
                     report_time_used_for `Initial_catchup
                       Block_time.(Span.to_time_span @@ diff now_ start_time) ) )
           ) ;
           let state_hash = Frontier_base.Breadcrumb.state_hash b in
           Transition_states.find transition_states state_hash
           |> Option.value_exn
           |> promote_to_next_state ~context ~write_actions ~state
                ~actions:(Deferred.return actions)
           |> (ignore : Transition_state.t option -> unit)
         in
         List.iter breadcrumbs ~f:promote )
(* TODO handle case when transition states were recovered from persistence and some transitions
   were marked `Processing Done` or `Processed` but were not promoted
   (not needed now because transition states are not persisted and are reset between calls to run() )*)
