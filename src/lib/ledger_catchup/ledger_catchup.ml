open Core
open Async
open Protocols.Coda_transition_frontier
open Cache_lib
open Pipe_lib
open Coda_base

module Make (Inputs : Inputs.S) :
  Catchup_intf
  with type external_transition_verified :=
              Inputs.External_transition.Verified.t
   and type unprocessed_transition_cache :=
              Inputs.Unprocessed_transition_cache.t
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
      cached_external_transitions =
    let open Deferred.Or_error.Let_syntax in
    let%map _, cached_breadcrumbs =
      fold_result_seq cached_external_transitions
        ~init:(initial_staged_ledger, [])
        ~f:(fun (staged_ledger, prev_breadcrumbs) cached_external_transition ->
          let open Deferred.Let_syntax in
          let%map cached_result =
            Cached.transform cached_external_transition
              ~f:(fun external_transition ->
                let open Deferred.Or_error.Let_syntax in
                let diff =
                  External_transition.Verified.staged_ledger_diff
                    (With_hash.data external_transition)
                in
                let%map _, `Ledger_proof _res_opt, `Staged_ledger staged_ledger
                    =
                  let open Deferred.Let_syntax in
                  match%map Staged_ledger.apply ~logger staged_ledger diff with
                  | Ok x -> Ok x
                  | Error e ->
                      Error (Staged_ledger.Staged_ledger_error.to_error e)
                in
                let new_breadcrumb =
                  Transition_frontier.Breadcrumb.create external_transition
                    staged_ledger
                in
                (staged_ledger, new_breadcrumb) )
            |> Cached.lift_deferred
          in
          let open Or_error.Let_syntax in
          let%map cached = Cached.lift_result cached_result in
          let staged_ledger, _ = Cached.peek cached in
          let cached_breadcrumb =
            Cached.transform cached ~f:(fun (_, breadcrumb) -> breadcrumb)
          in
          (staged_ledger, cached_breadcrumb :: prev_breadcrumbs) )
    in
    List.rev cached_breadcrumbs

  let materialize_breadcrumbs ~frontier ~logger ~peer external_transitions =
    let root_transition = List.hd_exn external_transitions in
    let initial_state_hash =
      With_hash.data (Cached.peek root_transition)
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
        let initial_staged_ledger =
          Transition_frontier.Breadcrumb.staged_ledger initial_breadcrumb
        in
        construct_breadcrumb_path ~logger initial_staged_ledger
          external_transitions

  let get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
      ~num_peers ~unprocessed_transition_cache hash =
    let peers = Network.random_peers network num_peers in
    let open Deferred.Or_error.Let_syntax in
    Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
        match%bind Network.catchup_transition network peer hash with
        | None ->
            Deferred.return
            @@ Or_error.errorf
                 !"Peer %{sexp:Network_peer.Peer.t} did not have transition"
                 peer
        | Some [] ->
            let message =
              sprintf
                !"Peer %{sexp:Network_peer.Peer.t} gave an empty list of \
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
                      transition to a fully verified in 
                      order to add the transition to be added to the 
                      transition frontier and to be fed through the 
                      transition_handler_validator. *)
                    let (`I_swear_this_is_safe_see_my_comment
                          verified_transition) =
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
                      @@ Transition_handler_validator.validate_transition
                           ~logger ~frontier ~unprocessed_transition_cache
                           verified_transition_with_hash
                    in
                    verified_transition_with_hash
                  in
                  let open Deferred.Let_syntax in
                  match%map verified_transition with
                  | Ok verified_transition ->
                      let open Or_error.Let_syntax in
                      let%map cached =
                        Unprocessed_transition_cache.register
                          unprocessed_transition_cache verified_transition
                      in
                      Some cached
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
      ~catchup_breadcrumbs_writer ~unprocessed_transition_cache =
    Strict_pipe.Reader.iter catchup_job_reader ~f:(fun transition_with_hash ->
        let hash = With_hash.hash (Cached.peek transition_with_hash) in
        match%bind
          get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
            ~num_peers:8 ~unprocessed_transition_cache hash
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
