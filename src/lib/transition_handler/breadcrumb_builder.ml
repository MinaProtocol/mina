open Protocols.Coda_pow
open Coda_base
open Coda_state
open Core
open Async
open Cache_lib

module Make (Inputs : Inputs.S) :
  Breadcrumb_builder_intf
  with type state_hash := State_hash.t
  with type trust_system := Trust_system.t
  with type external_transition_verified :=
              Inputs.External_transition.Verified.t
  with type transition_frontier := Inputs.Transition_frontier.t
  with type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t = struct
  open Inputs

  let build_subtrees_of_breadcrumbs ~logger ~trust_system ~frontier
      ~initial_hash subtrees_of_enveloped_transitions =
    (* If the breadcrumb we are targetting is removed from the transition
     * frontier while we're catching up, it means this path is not on the
     * critical path that has been chosen in the frontier. As such, we should
     * drop it on the floor. *)
    let breadcrumb_if_present () =
      match Transition_frontier.find frontier initial_hash with
      | None ->
          let msg =
            Printf.sprintf
              !"Transition frontier garbage already collected the parent on \
                %{sexp: Coda_base.State_hash.t}"
              initial_hash
          in
          Logger.error logger ~module_:__MODULE__ ~location:__LOC__ !"%s" msg ;
          Or_error.error_string msg
      | Some breadcrumb ->
          Or_error.return breadcrumb
    in
    Deferred.Or_error.List.map subtrees_of_enveloped_transitions
      ~f:(fun subtree_of_enveloped_transitions ->
        let open Deferred.Or_error.Let_syntax in
        let%bind init_breadcrumb =
          breadcrumb_if_present () |> Deferred.return
        in
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
                  let transition =
                    Envelope.Incoming.data enveloped_transition
                  in
                  let sender = Envelope.Incoming.sender enveloped_transition in
                  let parent = Cached.peek cached_parent in
                  let expected_parent_hash =
                    Transition_frontier.Breadcrumb.transition_with_hash parent
                    |> With_hash.hash
                  in
                  let actual_parent_hash =
                    transition |> With_hash.data
                    |> External_transition.Verified.protocol_state
                    |> Protocol_state.previous_state_hash
                  in
                  let%bind () =
                    Deferred.return
                      (Result.ok_if_true
                         (State_hash.equal actual_parent_hash
                            expected_parent_hash)
                         ~error:
                           (Error.of_string
                              "Previous external transition hash does not \
                               equal to current external transition's parent \
                               hash"))
                  in
                  let epoch_ledger =
                    Transition_frontier.consensus_local_state frontier
                    |> Consensus.Data.Local_state.get_last_epoch_ledger
                  in
                  let open Deferred.Let_syntax in
                  match%bind
                    Transition_frontier.Breadcrumb.build ~logger ~trust_system
                      ~parent ~transition_with_hash:transition
                      ~sender:(Some sender) ~epoch_ledger
                  with
                  | Ok new_breadcrumb ->
                      let open Result.Let_syntax in
                      Deferred.return
                        (let%map (_ : Transition_frontier.Breadcrumb.t) =
                           breadcrumb_if_present ()
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
                            | Remote inet_addr ->
                                Set.add inet_addrs inet_addr )
                      in
                      let ip_addresses = Set.to_list ip_address_set in
                      let trust_system_record_invalid msg error =
                        let%map () =
                          Deferred.List.iter ip_addresses ~f:(fun ip_addr ->
                              Trust_system.record trust_system logger ip_addr
                                ( Trust_system.Actions
                                  .Gossiped_invalid_transition
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
end
