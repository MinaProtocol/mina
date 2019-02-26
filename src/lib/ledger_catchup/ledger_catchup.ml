open Core
open Async
open Protocols.Coda_transition_frontier
open Pipe_lib
open Coda_base

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

  let get_previous_state_hash transition =
    transition |> With_hash.data |> External_transition.Verified.protocol_state
    |> External_transition.Protocol_state.previous_state_hash

  (* We would like the async scheduler to context switch between each iteration 
  of external transitions when trying to build breadcrumb_path. Therefore, this 
  function needs to return a Deferred *)
  let construct_breadcrumb_path ~logger initial_breadcrumb external_transitions
      =
    let open Deferred.Or_error.Let_syntax in
    let%map _, breadcrumbs =
      fold_result_seq external_transitions ~init:(initial_breadcrumb, [])
        ~f:(fun (parent, acc) transition_with_hash ->
          let parent_state_hash =
            With_hash.hash
            @@ Transition_frontier.Breadcrumb.transition_with_hash parent
          in
          let current_state_hash = With_hash.hash transition_with_hash in
          let%bind () =
            Deferred.return
              (Result.ok_if_true
                 ( State_hash.equal parent_state_hash
                 @@ get_previous_state_hash transition_with_hash )
                 ~error:
                   ( Error.of_string
                   @@ sprintf
                        !"Previous external transition hash \
                          %{sexp:State_hash.t} does not equal to current \
                          external_transition's parent hash \
                          %{sexp:State_hash.t}"
                        parent_state_hash current_state_hash ))
          in
          let open Deferred.Let_syntax in
          match%map
            Transition_frontier.Breadcrumb.build ~logger ~parent
              ~transition_with_hash
          with
          | Ok new_breadcrumb -> Ok (new_breadcrumb, new_breadcrumb :: acc)
          | Error (`Fatal_error exn) -> Or_error.of_exn exn
          | Error (`Validation_error error) -> Error error )
    in
    List.rev breadcrumbs

  let materialize_breadcrumbs ~frontier ~logger ~peer
      peer_child_root_transition external_transitions =
    let initial_state_hash =
      With_hash.data peer_child_root_transition
      |> External_transition.Verified.protocol_state
      |> External_transition.Protocol_state.previous_state_hash
    in
    match Transition_frontier.find frontier initial_state_hash with
    | None ->
        let message =
          sprintf
            !"Could not find root hash, %{sexp:State_hash.t}.Peer \
              %{sexp:Network_peer.Peer.t} is seen as malicious"
            initial_state_hash peer
        in
        Logger.faulty_peer logger !"%s" message ;
        Deferred.return @@ Or_error.error_string message
    | Some initial_breadcrumb ->
        construct_breadcrumb_path ~logger initial_breadcrumb
          (peer_child_root_transition :: external_transitions)

  let verify_transition ~logger ~frontier transition =
    let verified_transition =
      let open Deferred.Result.Let_syntax in
      let%bind _ : External_transition.Proof_verified.t =
        Protocol_state_validator.validate_proof transition
        |> Deferred.Result.map_error ~f:(fun error ->
               `Invalid (Error.to_string_hum error) )
      in
      (* We need to coerce the transition from a proof_verified 
        transition to a fully verified in 
        order to add the transition to be added to the 
        transition frontier and to be fed through the 
        transition_handler_validator. *)
      let (`I_swear_this_is_safe_see_my_comment verified_transition) =
        External_transition.to_verified transition
      in
      let verified_transition_with_hash =
        With_hash.of_data verified_transition
          ~hash_data:
            (Fn.compose Consensus.Protocol_state.hash
               External_transition.Verified.protocol_state)
      in
      let%map () =
        Deferred.return
        @@ Transition_handler_validator.validate_transition ~logger ~frontier
             verified_transition_with_hash
      in
      verified_transition_with_hash
    in
    let open Deferred.Let_syntax in
    match%map verified_transition with
    | Ok verified_transition -> Ok (Some verified_transition)
    | Error `Duplicate ->
        Logger.info logger
          !"transition queried during ledger catchup has already been seen" ;
        Ok None
    | Error (`Invalid reason) ->
        Logger.faulty_peer logger
          !"transition queried during ledger catchup was not valid because %s"
          reason ;
        Error (Error.of_string reason)

  let get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
      ~num_peers hash =
    let peers = Network.random_peers network num_peers in
    let open Deferred.Or_error.Let_syntax in
    Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
        match%bind Network.catchup_transition network peer hash with
        | None ->
            Deferred.return
            @@ Or_error.errorf
                 !"Peer %{sexp:Network_peer.Peer.t} did not have transition"
                 peer
        | Some queried_transitions ->
            let%bind queried_transitions_verified =
              Deferred.Or_error.List.filter_map
                (Non_empty_list.to_list queried_transitions)
                ~f:(verify_transition ~logger ~frontier)
            in
            let%bind head_transition, tail_transitions =
              ( match
                  Non_empty_list.of_list_opt queried_transitions_verified
                with
              | Some result -> Ok (Non_empty_list.uncons result)
              | None ->
                  let error =
                    "Peer should have given us some new transitions that are \
                     not in our transition frontier"
                  in
                  Logger.faulty_peer logger "%s" error ;
                  Error (Error.of_string error) )
              |> Deferred.return
            in
            materialize_breadcrumbs ~frontier ~logger ~peer head_transition
              tail_transitions )

  let run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer =
    Strict_pipe.Reader.iter catchup_job_reader ~f:(fun hash ->
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
