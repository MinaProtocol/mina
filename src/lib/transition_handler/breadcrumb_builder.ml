open Coda_base
open Core
open Async
open Cache_lib
open Coda_transition
open Network_peer

let build_list_of_breadcrumbs_in_sequence ~logger ~precomputed_values ~verifier
    ~trust_system ~frontier ~initial_hash ~initial_breadcrumb
    list_of_enveloped_transitions =
  (* Similar to build_subtrees_of_breadcrumbs_in_sequence, this function takes
   * in a list of transitions instead list of rose_trees of transitions. It also
   * returns a list of breadcrumbs it has built. Note that the returned list is
   * in reversed order, from latest breadcrumb to oldest. It is convenient for
   * ledger_catchup to get the latest breadcrumb as the start of next chunk. *)
  let breadcrumb_if_present logger =
    (* function to get previous breadcrumb based on initial_hash *)
    match Transition_frontier.find frontier initial_hash with
    | None ->
        let msg =
          Printf.sprintf
            "Transition frontier already garbage-collected the parent of %s"
            (Coda_base.State_hash.to_base58_check initial_hash)
        in
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("state_hash", Coda_base.State_hash.to_yojson initial_hash)
            ; ( "transition_hashes"
              , `List
                  (List.map list_of_enveloped_transitions
                     ~f:(fun enveloped_transitions ->
                       Cached.peek enveloped_transitions
                       |> Envelope.Incoming.data
                       |> External_transition.Initial_validated.state_hash
                       |> Coda_base.State_hash.to_yojson )) ) ]
          "Transition frontier already garbage-collected the parent of \
           $state_hash" ;
        Or_error.error_string msg
    | Some breadcrumb ->
        Or_error.return breadcrumb
  in
  let open Deferred.Or_error.Let_syntax in
  let%bind init_breadcrumb =
    match initial_breadcrumb with
    | Some breadcrumb ->
        Deferred.return breadcrumb
    | None ->
        breadcrumb_if_present
          (Logger.extend logger
             [("Check", `String "Before creating breadcrumb")])
        |> Deferred.return
  in
  Deferred.Or_error.List.foldi list_of_enveloped_transitions ~init:[]
    ~f:(fun index previous_finished_breadcrumbs cached_enveloped_transition ->
      (* May need to transfer cache *)
      let cached_parent =
        match List.nth previous_finished_breadcrumbs 0 with
        | Some cached_breadcrumb ->
            cached_breadcrumb
        | None ->
            Cached.pure init_breadcrumb
      in
      let open Deferred.Or_error.Let_syntax in
      let%map current_breadcrumb =
        let open Deferred.Let_syntax in
        let%bind current_breadcrumb_or_error_cache =
          Cached.transform cached_enveloped_transition
            ~f:(fun enveloped_transition ->
              let open Deferred.Or_error.Let_syntax in
              let transition_with_initial_validation =
                Envelope.Incoming.data enveloped_transition
              in
              let transition_with_hash, _ =
                transition_with_initial_validation
              in
              let mostly_validated_transition =
                External_transition.skip_frontier_dependencies_validation
                  `This_transition_belongs_to_a_detached_subtree
                  transition_with_initial_validation
              in
              let sender = Envelope.Incoming.sender enveloped_transition in
              let parent = Cached.peek cached_parent in
              let expected_parent_hash =
                Transition_frontier.Breadcrumb.state_hash parent
              in
              let actual_parent_hash =
                transition_with_hash |> With_hash.data
                |> External_transition.parent_hash
              in
              let%bind () =
                Deferred.return
                  (Result.ok_if_true
                     (State_hash.equal actual_parent_hash expected_parent_hash)
                     ~error:
                       (Error.of_string
                          "Previous external transition hash does not equal \
                           to current external transition's parent hash"))
              in
              let open Deferred.Let_syntax in
              match%bind
                O1trace.trace_recurring "Breadcrumb.build" (fun () ->
                    (* actually build the current breadcrumb *)
                    Transition_frontier.Breadcrumb.build ~logger
                      ~precomputed_values ~verifier ~trust_system ~parent
                      ~transition:mostly_validated_transition
                      ~sender:(Some sender) )
              with
              | Ok new_breadcrumb ->
                  let open Result.Let_syntax in
                  Coda_metrics.(
                    Counter.inc_one
                      Transition_frontier_controller
                      .breadcrumbs_built_by_builder) ;
                  Deferred.return
                    (let%map (_ : Transition_frontier.Breadcrumb.t) =
                       breadcrumb_if_present
                         (* check if initial_hash is still in frontier *)
                         (Logger.extend logger
                            [("Check", `String "After creating breadcrumb")])
                     in
                     new_breadcrumb)
              | Error err -> (
                  (* propagate bans through list*)
                  let list_nodes =
                    List.slice list_of_enveloped_transitions index
                      (List.length list_of_enveloped_transitions)
                  in
                  let ip_address_set =
                    let sender_from_node node =
                      Envelope.Incoming.sender (Cached.peek node)
                    in
                    List.fold list_nodes
                      ~init:(Set.empty (module Unix.Inet_addr))
                      ~f:(fun inet_addrs node ->
                        match sender_from_node node with
                        | Local ->
                            failwith
                              "build_list_of_breadcrumbs: sender of external \
                               transition should not be Local"
                        | Remote (inet_addr, _peer_id) ->
                            Set.add inet_addrs inet_addr )
                  in
                  let ip_addresses = Set.to_list ip_address_set in
                  let trust_system_record_invalid msg error =
                    let%map () =
                      Deferred.List.iter ip_addresses ~f:(fun ip_addr ->
                          Trust_system.record trust_system logger ip_addr
                            ( Trust_system.Actions.Gossiped_invalid_transition
                            , Some (msg, []) ) )
                    in
                    Error error
                  in
                  match err with
                  | `Invalid_staged_ledger_hash error ->
                      trust_system_record_invalid "invalid staged ledger hash"
                        error
                  | `Invalid_staged_ledger_diff error ->
                      trust_system_record_invalid "invalid staged ledger diff"
                        error
                  | `Fatal_error exn ->
                      Deferred.return (Or_error.of_exn exn) ) )
          |> Cached.sequence_deferred
        in
        Cached.sequence_result current_breadcrumb_or_error_cache
        |> Deferred.return
      in
      current_breadcrumb :: previous_finished_breadcrumbs )

let build_subtrees_of_breadcrumbs_in_sequence ~logger ~precomputed_values
    ~verifier ~trust_system ~frontier ~initial_hash ~initial_breadcrumb
    subtrees_of_enveloped_transitions =
  (* Similar to build_subtrees_of_breadcrumbs, this function takes one more
   * argument to specify the previous breadcrumb. Thus, we can build breadcrumb
   * based on a not-yet-in-frontier breadcrumb with the provided breadcrumb.
   * We need to make sure initial_hash is still the hash of the parent of the
   * very first breadcrumb in our sequence. This will help to determine if the
   * breadcrumb we are targetting is removed from the transition frontier while
   * we're catching up. *)
  let breadcrumb_if_present logger =
    (* function to get previous breadcrumb based on initial_hash *)
    match Transition_frontier.find frontier initial_hash with
    | None ->
        let msg =
          Printf.sprintf
            "Transition frontier already garbage-collected the parent of %s"
            (Coda_base.State_hash.to_base58_check initial_hash)
        in
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("state_hash", Coda_base.State_hash.to_yojson initial_hash)
            ; ( "transition_hashes"
              , `List
                  (List.map subtrees_of_enveloped_transitions
                     ~f:(fun subtree ->
                       Rose_tree.to_yojson
                         (fun enveloped_transitions ->
                           Cached.peek enveloped_transitions
                           |> Envelope.Incoming.data
                           |> External_transition.Initial_validated.state_hash
                           |> Coda_base.State_hash.to_yojson )
                         subtree )) ) ]
          "Transition frontier already garbage-collected the parent of \
           $state_hash" ;
        Or_error.error_string msg
    | Some breadcrumb ->
        Or_error.return breadcrumb
  in
  Deferred.Or_error.List.map subtrees_of_enveloped_transitions
    ~f:(fun subtree_of_enveloped_transitions ->
      let open Deferred.Or_error.Let_syntax in
      let%bind init_breadcrumb =
        (* previous breadcrumb*)
        match initial_breadcrumb with
        | Some breadcrumb ->
            Deferred.Or_error.return breadcrumb
        | None ->
            breadcrumb_if_present
              (Logger.extend logger
                 [("Check", `String "Before creating breadcrumb")])
            |> Deferred.return
      in
      (* start to build based on the initial breadcrumb *)
      Rose_tree.Deferred.Or_error.fold_map_over_subtrees
        subtree_of_enveloped_transitions ~init:(Cached.pure init_breadcrumb)
        ~f:(fun cached_parent
           (Rose_tree.T (cached_enveloped_transition, _) as subtree)
           ->
          let open Deferred.Let_syntax in
          let%map cached_result =
            Cached.transform cached_enveloped_transition
              ~f:(fun enveloped_transition ->
                let open Deferred.Or_error.Let_syntax in
                let transition_with_initial_validation =
                  Envelope.Incoming.data enveloped_transition
                in
                let transition_with_hash, _ =
                  transition_with_initial_validation
                in
                let mostly_validated_transition =
                  (* TODO: handle this edge case more gracefully *)
                  (* since we are building a disconnected subtree of breadcrumbs,
                   * we skip this step in validation *)
                  External_transition.skip_frontier_dependencies_validation
                    `This_transition_belongs_to_a_detached_subtree
                    transition_with_initial_validation
                in
                let sender = Envelope.Incoming.sender enveloped_transition in
                let parent = Cached.peek cached_parent in
                let expected_parent_hash =
                  Transition_frontier.Breadcrumb.state_hash parent
                in
                let actual_parent_hash =
                  transition_with_hash |> With_hash.data
                  |> External_transition.parent_hash
                in
                let%bind () =
                  Deferred.return
                    (Result.ok_if_true
                       (State_hash.equal actual_parent_hash
                          expected_parent_hash)
                       ~error:
                         (Error.of_string
                            "Previous external transition hash does not equal \
                             to current external transition's parent hash"))
                in
                let open Deferred.Let_syntax in
                match%bind
                  O1trace.trace_recurring "Breadcrumb.build" (fun () ->
                      Transition_frontier.Breadcrumb.build ~logger
                        ~precomputed_values ~verifier ~trust_system ~parent
                        ~transition:mostly_validated_transition
                        ~sender:(Some sender) )
                with
                | Ok new_breadcrumb ->
                    let open Result.Let_syntax in
                    Coda_metrics.(
                      Counter.inc_one
                        Transition_frontier_controller
                        .breadcrumbs_built_by_builder) ;
                    Deferred.return
                      (let%map (_ : Transition_frontier.Breadcrumb.t) =
                         breadcrumb_if_present
                           (Logger.extend logger
                              [("Check", `String "After creating breadcrumb")])
                       in
                       new_breadcrumb)
                | Error err -> (
                    (* propagate bans through subtree *)
                    let subtree_nodes = Rose_tree.flatten subtree in
                    let ip_address_set =
                      let sender_from_tree_node node =
                        Envelope.Incoming.sender (Cached.peek node)
                      in
                      List.fold subtree_nodes
                        ~init:(Set.empty (module Unix.Inet_addr))
                        ~f:(fun inet_addrs node ->
                          match sender_from_tree_node node with
                          | Local ->
                              failwith
                                "build_subtrees_of_breadcrumbs: sender of \
                                 external transition should not be Local"
                          | Remote (inet_addr, _peer_id) ->
                              Set.add inet_addrs inet_addr )
                    in
                    let ip_addresses = Set.to_list ip_address_set in
                    let trust_system_record_invalid msg error =
                      let%map () =
                        Deferred.List.iter ip_addresses ~f:(fun ip_addr ->
                            Trust_system.record trust_system logger ip_addr
                              ( Trust_system.Actions.Gossiped_invalid_transition
                              , Some (msg, []) ) )
                      in
                      Error error
                    in
                    match err with
                    | `Invalid_staged_ledger_hash error ->
                        trust_system_record_invalid
                          "invalid staged ledger hash" error
                    | `Invalid_staged_ledger_diff error ->
                        trust_system_record_invalid
                          "invalid staged ledger diff" error
                    | `Fatal_error exn ->
                        Deferred.return (Or_error.of_exn exn) ) )
            |> Cached.sequence_deferred
          in
          Cached.sequence_result cached_result ) )

let build_subtrees_of_breadcrumbs ~logger ~precomputed_values ~verifier
    ~trust_system ~frontier ~initial_hash subtrees_of_enveloped_transitions =
  (* If the breadcrumb we are targetting is removed from the transition
   * frontier while we're catching up, it means this path is not on the
   * critical path that has been chosen in the frontier. As such, we should
   * drop it on the floor. *)
  let breadcrumb_if_present logger =
    (* function to get previous breadcrumb based on initial_hash *)
    match Transition_frontier.find frontier initial_hash with
    | None ->
        let msg =
          Printf.sprintf
            "Transition frontier already garbage-collected the parent of %s"
            (Coda_base.State_hash.to_base58_check initial_hash)
        in
        Logger.error logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:
            [ ("state_hash", Coda_base.State_hash.to_yojson initial_hash)
            ; ( "transition_hashes"
              , `List
                  (List.map subtrees_of_enveloped_transitions
                     ~f:(fun subtree ->
                       Rose_tree.to_yojson
                         (fun enveloped_transitions ->
                           Cached.peek enveloped_transitions
                           |> Envelope.Incoming.data
                           |> External_transition.Initial_validated.state_hash
                           |> Coda_base.State_hash.to_yojson )
                         subtree )) ) ]
          "Transition frontier already garbage-collected the parent of \
           $state_hash" ;
        Or_error.error_string msg
    | Some breadcrumb ->
        Or_error.return breadcrumb
  in
  Deferred.Or_error.List.map subtrees_of_enveloped_transitions
    ~f:(fun subtree_of_enveloped_transitions ->
      (* one rose tree *)
      let open Deferred.Or_error.Let_syntax in
      let%bind init_breadcrumb =
        (* previous breadcrumb*)
        breadcrumb_if_present
          (Logger.extend logger
             [("Check", `String "Before creating breadcrumb")])
        |> Deferred.return
      in
      (* start to build based on the initial breadcrumb *)
      Rose_tree.Deferred.Or_error.fold_map_over_subtrees
        subtree_of_enveloped_transitions ~init:(Cached.pure init_breadcrumb)
        ~f:(fun cached_parent (* parent value *)
           (Rose_tree.T (cached_enveloped_transition, _) as subtree)
           (* self, ignore children*)
           ->
          let open Deferred.Let_syntax in
          let%map cached_result =
            Cached.transform cached_enveloped_transition
              ~f:(fun enveloped_transition ->
                (* transfer current transition value *)
                let open Deferred.Or_error.Let_syntax in
                let transition_with_initial_validation =
                  Envelope.Incoming.data enveloped_transition
                  (* get the value from envelope *)
                in
                let transition_with_hash, _ =
                  (* get the transition hash *)
                  transition_with_initial_validation
                in
                let mostly_validated_transition =
                  (* TODO: handle this edge case more gracefully *)
                  (* since we are building a disconnected subtree of breadcrumbs,
                   * we skip this step in validation *)
                  External_transition.skip_frontier_dependencies_validation
                    `This_transition_belongs_to_a_detached_subtree
                    transition_with_initial_validation
                in
                let sender = Envelope.Incoming.sender enveloped_transition in
                let parent = Cached.peek cached_parent in
                (* parent breadcrumb *)
                let expected_parent_hash =
                  (* parent hash *)
                  Transition_frontier.Breadcrumb.state_hash parent
                in
                let actual_parent_hash =
                  (* get parent hash from current transition *)
                  transition_with_hash |> With_hash.data
                  |> External_transition.parent_hash
                in
                let%bind () =
                  Deferred.return
                    (Result.ok_if_true
                       (State_hash.equal actual_parent_hash
                          (* check if have same parent hash *)
                          expected_parent_hash)
                       ~error:
                         (Error.of_string
                            "Previous external transition hash does not equal \
                             to current external transition's parent hash"))
                in
                let open Deferred.Let_syntax in
                match%bind
                  O1trace.trace_recurring "Breadcrumb.build" (fun () ->
                      (* actually build the current breadcrumb *)
                      Transition_frontier.Breadcrumb.build ~logger
                        ~precomputed_values ~verifier ~trust_system ~parent
                        ~transition:mostly_validated_transition
                        ~sender:(Some sender) )
                with
                | Ok new_breadcrumb ->
                    let open Result.Let_syntax in
                    Coda_metrics.(
                      Counter.inc_one
                        Transition_frontier_controller
                        .breadcrumbs_built_by_builder) ;
                    Deferred.return
                      (let%map (_ : Transition_frontier.Breadcrumb.t) =
                         breadcrumb_if_present
                           (* check if initial_hash is still in frontier *)
                           (Logger.extend logger
                              [("Check", `String "After creating breadcrumb")])
                       in
                       new_breadcrumb)
                | Error err -> (
                    (* propagate bans through subtree *)
                    let subtree_nodes = Rose_tree.flatten subtree in
                    let ip_address_set =
                      let sender_from_tree_node node =
                        Envelope.Incoming.sender (Cached.peek node)
                      in
                      List.fold subtree_nodes
                        ~init:(Set.empty (module Unix.Inet_addr))
                        ~f:(fun inet_addrs node ->
                          match sender_from_tree_node node with
                          | Local ->
                              failwith
                                "build_subtrees_of_breadcrumbs: sender of \
                                 external transition should not be Local"
                          | Remote (inet_addr, _peer_id) ->
                              Set.add inet_addrs inet_addr )
                    in
                    let ip_addresses = Set.to_list ip_address_set in
                    let trust_system_record_invalid msg error =
                      let%map () =
                        Deferred.List.iter ip_addresses ~f:(fun ip_addr ->
                            Trust_system.record trust_system logger ip_addr
                              ( Trust_system.Actions.Gossiped_invalid_transition
                              , Some (msg, []) ) )
                      in
                      Error error
                    in
                    match err with
                    | `Invalid_staged_ledger_hash error ->
                        trust_system_record_invalid
                          "invalid staged ledger hash" error
                    | `Invalid_staged_ledger_diff error ->
                        trust_system_record_invalid
                          "invalid staged ledger diff" error
                    | `Fatal_error exn ->
                        Deferred.return (Or_error.of_exn exn) ) )
            |> Cached.sequence_deferred
          in
          Cached.sequence_result cached_result ) )
