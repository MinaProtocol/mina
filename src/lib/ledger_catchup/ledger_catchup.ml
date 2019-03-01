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

  let get_previous_state_hash transition =
    transition |> With_hash.data |> External_transition.Verified.protocol_state
    |> External_transition.Protocol_state.previous_state_hash

  (* We would like the async scheduler to context switch between each iteration
     of external transitions when trying to build breadcrumb_path. Therefore, this 
     function needs to return a Deferred *)
  let construct_breadcrumb_path ~logger initial_breadcrumb tree =
    Rose_tree.Deferred.Or_error.fold_map tree
      ~init:(Cached.pure initial_breadcrumb)
      ~f:(fun cached_parent_breadcrumb cached_transition_with_hash ->
        let open Deferred.Let_syntax in
        let%map cached_result =
          Cached.transform cached_transition_with_hash
            ~f:(fun transition_with_hash ->
              let open Deferred.Or_error.Let_syntax in
              let parent_breadcrumb = Cached.peek cached_parent_breadcrumb in
              let parent_state_hash =
                Transition_frontier.Breadcrumb.transition_with_hash
                  parent_breadcrumb
                |> With_hash.hash
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
                Transition_frontier.Breadcrumb.build ~logger
                  ~parent:parent_breadcrumb ~transition_with_hash
              with
              | Ok new_breadcrumb -> Ok new_breadcrumb
              | Error (`Fatal_error exn) -> Or_error.of_exn exn
              | Error (`Validation_error error) -> Error error )
          |> Cached.sequence_deferred
        in
        Cached.sequence_result cached_result )

  let materialize_breadcrumbs ~frontier ~logger ~peer
      (Rose_tree.T (foreign_transition_head, _) as tree) =
    let initial_state_hash =
      With_hash.data (Cached.peek foreign_transition_head)
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
        construct_breadcrumb_path ~logger initial_breadcrumb tree

  let verify_transition ~logger ~frontier ~unprocessed_transition_cache
      transition =
    let cached_verified_transition =
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
      Deferred.return
      @@ Transition_handler_validator.validate_transition ~logger ~frontier
           ~unprocessed_transition_cache verified_transition_with_hash
    in
    let open Deferred.Let_syntax in
    match%map cached_verified_transition with
    | Ok x -> Ok (Some x)
    | Error `Duplicate ->
        Logger.info logger
          !"transition queried during ledger catchup has already been seen" ;
        Ok None
    | Error (`Invalid reason) ->
        Logger.faulty_peer logger
          !"transition queried during ledger catchup was not valid because %s"
          reason ;
        Error (Error.of_string reason)

  let take_while_map_result_rev ~f list =
    let open Deferred.Or_error.Let_syntax in
    let%map result, _ =
      Deferred.Or_error.List.fold list ~init:([], true)
        ~f:(fun (acc, should_continue) elem ->
          let open Deferred.Let_syntax in
          if not should_continue then Deferred.Or_error.return (acc, false)
          else
            match%bind f elem with
            | Error e -> Deferred.return (Error e)
            | Ok None -> Deferred.Or_error.return (acc, false)
            | Ok (Some y) -> Deferred.Or_error.return (y :: acc, true) )
    in
    result

  let get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
      ~num_peers ~unprocessed_transition_cache ~target_subtree =
    let peers = Network.random_peers network num_peers in
    let (Rose_tree.T (target_transition, _)) = target_subtree in
    let target_hash = With_hash.hash (Cached.peek target_transition) in
    let open Deferred.Or_error.Let_syntax in
    Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
        match%bind
          O1trace.trace_recurring_task "ledger catchup" (fun () ->
              Network.catchup_transition network peer target_hash )
        with
        | None ->
            Deferred.return
            @@ Or_error.errorf
                 !"Peer %{sexp:Network_peer.Peer.t} did not have transition"
                 peer
        | Some queried_transitions ->
            let last, rest =
              Non_empty_list.(uncons @@ rev queried_transitions)
            in
            let%bind () =
              if
                State_hash.equal
                  (Consensus.Protocol_state.hash
                     (External_transition.protocol_state last))
                  target_hash
              then return ()
              else (
                Logger.faulty_peer logger
                  !"Peer %{sexp:Network_peer.Peer.t} returned an different \
                    target transition than we requested"
                  peer ;
                Deferred.return (Error (Error.of_string "")) )
            in
            let%bind verified_transitions =
              take_while_map_result_rev rest
                ~f:
                  (verify_transition ~logger ~frontier
                     ~unprocessed_transition_cache)
            in
            let%bind () =
              Deferred.return
                ( if List.length verified_transitions > 0 then Ok ()
                else
                  let error =
                    "Peer should have given us some new transitions that are \
                     not in our transition frontier"
                  in
                  Logger.faulty_peer logger "%s" error ;
                  Error (Error.of_string error) )
            in
            let full_subtree =
              List.fold_right verified_transitions ~init:target_subtree
                ~f:(fun transition acc -> Rose_tree.T (transition, [acc]) )
            in
            materialize_breadcrumbs ~frontier ~logger ~peer full_subtree )

  let run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer ~unprocessed_transition_cache =
    let logger = Logger.child logger __MODULE__ in
    Strict_pipe.Reader.iter catchup_job_reader ~f:(fun subtree ->
        match%bind
          get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
            ~num_peers:8 ~unprocessed_transition_cache ~target_subtree:subtree
        with
        | Ok tree -> Strict_pipe.Writer.write catchup_breadcrumbs_writer [tree]
        | Error e ->
            Logger.info logger
              !"None of the peers have a transition with state hash:\n%s"
              (Error.to_string_hum e) ;
            Deferred.unit )
    |> don't_wait_for
end
