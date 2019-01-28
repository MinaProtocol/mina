open Core
open Async
open Protocols.Coda_transition_frontier
open Pipe_lib
open Coda_base

(** [Ledger_catchup] is a process that connects a foreign external transition
    into a transition frontier by asking it's peer a path of
    external_transitions. It receives the external_transition to catchup from
    [Catchup_monitor]. With that external_transition, it will ask it's peers
    for a path of external_transitions from their root to the transition it is
    asking for. It will then perform the following validations on each
    external_transition:

    1. The root should exist in the frontier. The frontier should not be
    missing too many external_transitions, so the querying node should have the
    root in it's transition_frontier.

    2. Each transitions are checked through [Transition_processor.Validator]
    and [Protocol_state_validator]

    If any of the external_transitions are invalid, the sender is punished.
    Otherwise, [Ledger_catchup] will build a corresponding breadcrumb path from
    the path of external_transitions. A breadcrumb from the path is built using
    it's corresponding external_transition staged_ledger_diff and applying it
    onto it's preceding breadcrumb staged_ledger to obtain it's corresponding
    staged_ledger. If there was an error in building the breadcrumbs, then
    catchup will punish the sender for sending a faulty staged_ledger_diff.
    After building the breadcrumb path, [Ledger_catchup] will then send them to
    the [Processor] via writing them to catchup_breadcrumbs_writer. *)

module Make (Inputs : Inputs.S) :
  Catchup_intf
  with type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t
   and type state_hash := State_hash.t
   and type network := Inputs.Network.t = struct
  open Inputs

  let fold_result_seq list ~init ~f =
    Deferred.List.fold list ~init:(Ok init) ~f:(fun acc elem ->
        match acc with
        | Error e -> Deferred.return (Error e)
        | Ok acc -> f acc elem )

  (* We would like the async scheduler to context switch between each iteration
     of external transitions when trying to build breadcrumb_path. Therefore,
     this function needs to return a Deferred *)
  let construct_breadcrumb_path ~logger initial_staged_ledger
      external_transitions =
    let open Deferred.Or_error.Let_syntax in
    let%map _, breadcrumbs =
      fold_result_seq external_transitions ~init:(initial_staged_ledger, [])
        ~f:(fun (staged_ledger, acc) external_transition ->
          let diff =
            External_transition.Verified.staged_ledger_diff
              (With_hash.data external_transition)
          in
          let%map _, _, `Staged_ledger staged_ledger =
            let open Deferred.Let_syntax in
            match%map Staged_ledger.apply ~logger staged_ledger diff with
            | Ok x -> Ok x
            | Error e -> Error (Staged_ledger.Staged_ledger_error.to_error e)
          in
          let new_breadcrumb =
            Transition_frontier.Breadcrumb.create external_transition
              staged_ledger
          in
          (staged_ledger, new_breadcrumb :: acc) )
    in
    List.rev breadcrumbs

  let materialize_breadcrumbs ~frontier ~logger ~peer external_transitions =
    let root_transition = List.hd_exn external_transitions in
    let initial_state_hash =
      With_hash.data root_transition
      |> External_transition.Verified.protocol_state
      |> External_transition.Protocol_state.previous_state_hash
    in
    match Transition_frontier.find frontier initial_state_hash with
    | None ->
        let message =
          sprintf
            !"Could not find root hash, %{sexp:State_hash.t}.Peer \
              %{sexp:Kademlia.Peer.t} is seen as malicious"
            initial_state_hash peer
        in
        Logger.faulty_peer logger !"%s" message ;
        Deferred.return @@ Or_error.error_string message
    | Some initial_breadcrumb ->
        let initial_staged_ledger =
          Transition_frontier.Breadcrumb.staged_ledger initial_breadcrumb
        in
        construct_breadcrumb_path ~logger initial_staged_ledger
          external_transitions

  let get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
      ~num_peers hash =
    let peers = Network.random_peers network num_peers in
    let open Deferred.Or_error.Let_syntax in
    Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
        match%bind Network.catchup_transition network peer hash with
        | None ->
            Deferred.return
            @@ Or_error.errorf
                 !"Peer %{sexp:Kademlia.Peer.t} did not have transition"
                 peer
        | Some [] ->
            let message =
              sprintf
                !"Peer %{sexp:Kademlia.Peer.t} gave an empty list of \
                  transitions. They should respond with none"
                peer
            in
            Logger.faulty_peer logger !"%s" message ;
            Deferred.return @@ Or_error.error_string message
        | Some queried_transitions ->
            let%bind queried_transitions_verified =
              Deferred.Or_error.List.filter_map queried_transitions
                ~f:(fun transition ->
                  let verified_transition =
                    let open Deferred.Result.Let_syntax in
                    let%bind _ : External_transition.Proof_verified.t =
                      Protocol_state_validator.validate_proof transition
                      |> Deferred.Result.map_error ~f:(fun error ->
                             `Invalid (Error.to_string_hum error) )
                    in
                    (* We need to coerce the transition from a proof_verified
                       transition to a fully verified in order to add the
                       transition to be added to the transition frontier and to
                       be fed through the transition_handler_validator. *)
                    let (`I_swear_this_is_safe_see_my_comment
                          verified_transition) =
                      External_transition.to_verified transition
                    in
                    let verified_transition_with_hash =
                      With_hash.of_data verified_transition
                        ~hash_data:
                          (Fn.compose Consensus.Mechanism.Protocol_state.hash
                             External_transition.Verified.protocol_state)
                    in
                    let%map () =
                      Deferred.return
                      @@ Transition_handler_validator.validate_transition
                           ~logger ~frontier verified_transition_with_hash
                    in
                    verified_transition_with_hash
                  in
                  let open Deferred.Let_syntax in
                  match%map verified_transition with
                  | Ok verified_transition -> Ok (Some verified_transition)
                  | Error `Duplicate ->
                      Logger.info logger
                        !"transition queried during ledger catchup has \
                          already been seen" ;
                      Ok None
                  | Error (`Invalid reason) ->
                      Logger.faulty_peer logger
                        !"transition queried during ledger catchup was not \
                          valid because %s"
                        reason ;
                      Error (Error.of_string reason) )
            in
            materialize_breadcrumbs ~frontier ~logger ~peer
              queried_transitions_verified )

  let run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer =
    Strict_pipe.Reader.iter catchup_job_reader ~f:(fun transition_with_hash ->
        let hash = With_hash.hash transition_with_hash in
        match%bind
          get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
            ~num_peers:8 hash
        with
        | Ok breadcrumbs ->
            Strict_pipe.Writer.write catchup_breadcrumbs_writer
              [Rose_tree.of_list_exn breadcrumbs]
        | Error e ->
            Logger.info logger
              !"None of the peers have a transition with state hash:\n%s"
              (Error.to_string_hum e) ;
            Deferred.unit )
    |> don't_wait_for
end
