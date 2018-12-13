open Core
open Async
open Protocols.Coda_transition_frontier
open Pipe_lib
open Coda_base

module Make (Inputs : Inputs.S) :
  Catchup_intf
  with type external_transition := Inputs.External_transition.t
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
  of external transitions when trying to build breadcrumb_path. Therefore, this
  function needs to return a Deferred *)
  let construct_breadcrumb_path ~logger initial_staged_ledger
      external_transitions =
    let open Deferred.Or_error.Let_syntax in
    let%map _, breadcrumbs =
      fold_result_seq external_transitions ~init:(initial_staged_ledger, [])
        ~f:(fun (staged_ledger, acc) external_transition ->
          let diff =
            External_transition.Verified.staged_ledger_diff external_transition
          in
          let%map _, _, `Staged_ledger staged_ledger =
            Deferred.create (fun ivar ->
                Ivar.fill ivar
                @@ Staged_ledger.apply ~logger staged_ledger diff )
          in
          let transition_with_hash =
            With_hash.of_data external_transition
              ~hash_data:
                (Fn.compose Consensus.Mechanism.Protocol_state.hash
                   External_transition.Verified.protocol_state)
          in
          let new_breadcrumb =
            Transition_frontier.Breadcrumb.create transition_with_hash
              staged_ledger
          in
          (staged_ledger, new_breadcrumb :: acc) )
    in
    List.rev breadcrumbs

  let materialize_breadcrumbs ~frontier ~logger ~peer external_transitions =
    let root_transition = List.hd_exn external_transitions in
    let initial_state_hash =
      root_transition |> External_transition.Verified.protocol_state
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
              let staged_ledger =
                Transition_frontier.best_tip frontier
                |> Transition_frontier.Breadcrumb.staged_ledger
              in
              Deferred.Or_error.List.map queried_transitions
                ~f:(fun transition ->
                  Transition_handler_validator.verify_transition ~staged_ledger
                    ~transition
                  |> Deferred.return )
            in
            materialize_breadcrumbs ~frontier ~logger ~peer
              queried_transitions_verified )

  let run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer =
    Strict_pipe.Reader.iter catchup_job_reader ~f:(fun transition_with_hash ->
        let hash = With_hash.hash transition_with_hash in
        match%map
          get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
            ~num_peers:8 hash
        with
        | Ok breadcrumbs ->
            Strict_pipe.Writer.write catchup_breadcrumbs_writer breadcrumbs
        | Error e ->
            Logger.info logger
              !"None of the peers have a transition with state hash:\n%s"
              (Error.to_string_hum e) )
    |> don't_wait_for
end
