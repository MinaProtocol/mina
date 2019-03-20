open Core
open Async
open Protocols.Coda_transition_frontier
open Cache_lib
open Pipe_lib
open Coda_base

(** [Ledger_catchup] is a procedure that connects a foreign external transition
    into a transition frontier by requesting a path of external_transitions
    from its peer. It receives the external_transition to catchup from
    [Catchup_monitor]. With that external_transition, it will ask its peers for
    a path of external_transitions from their root to the transition it is
    asking for. It will then perform the following validations on each
    external_transition:

    1. The root should exist in the frontier. The frontier should not be
    missing too many external_transitions, so the querying node should have the
    root in its transition_frontier.

    2. Each transition is checked through [Transition_processor.Validator] and
    [Protocol_state_validator]

    If any of the external_transitions is invalid, the sender is punished.
    Otherwise, [Ledger_catchup] will build a corresponding breadcrumb path from
    the path of external_transitions. A breadcrumb from the path is built using
    its corresponding external_transition staged_ledger_diff and applying it to
    its preceding breadcrumb staged_ledger to obtain its corresponding
    staged_ledger. If there was an error in building the breadcrumbs, then
    catchup will punish the sender for sending a faulty staged_ledger_diff.
    After building the breadcrumb path, [Ledger_catchup] will then send it to
    the [Processor] via writing them to catchup_breadcrumbs_writer. *)

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
     of external transitions when trying to build breadcrumb_path. Therefore,
     this function needs to return a Deferred *)
  let construct_breadcrumb_path ~logger frontier initial_state_hash tree =
    (* If the breadcrumb we are targetting is removed from the transition
     * frontier while we're catching up, it means this path is not on the
     * critical path that has been chosen in the frontier. As such, we should
     * drop it on the floor. *)
    let breadcrumb_if_present () =
      match Transition_frontier.find frontier initial_state_hash with
      | None ->
          let msg =
            Printf.sprintf
              !"Transition frontier garbage already collected the parent on \
                %{sexp: Coda_base.State_hash.t}"
              initial_state_hash
          in
          Logger.error logger ~module_:__MODULE__ ~location:__LOC__ !"%s" msg ;
          Or_error.error_string msg
      | Some crumb -> Or_error.return crumb
    in
    let open Deferred.Or_error.Let_syntax in
    let%map tree =
      Rose_tree.Deferred.Or_error.fold_map tree
        ~init:(Cached.pure `Initial)
        ~f:
          (fun cached_parent_breadcrumb_or_initial cached_transition_with_hash ->
          let open Deferred.Let_syntax in
          let%map cached_result =
            Cached.transform cached_transition_with_hash
              ~f:(fun transition_with_hash ->
                let open Deferred.Or_error.Let_syntax in
                let parent_or_initial =
                  Cached.peek cached_parent_breadcrumb_or_initial
                in
                let%bind well_formed_parent =
                  match parent_or_initial with
                  | `Initial ->
                      let%map crumb =
                        breadcrumb_if_present () |> Deferred.return
                      in
                      crumb
                  | `Constructed parent -> Deferred.Or_error.return parent
                in
                let parent_state_hash =
                  Transition_frontier.Breadcrumb.transition_with_hash
                    well_formed_parent
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
                                %{sexp:State_hash.t} does not equal to \
                                current external_transition's parent hash \
                                %{sexp:State_hash.t}"
                              parent_state_hash current_state_hash ))
                in
                let open Deferred.Let_syntax in
                match%map
                  Transition_frontier.Breadcrumb.build ~logger
                    ~parent:well_formed_parent ~transition_with_hash
                with
                | Ok new_breadcrumb ->
                    let open Result.Let_syntax in
                    (* After we do a bunch of async work on what used to be our initial breacrumb
                        * make sure it's still there, otherwise drop it on the floor *)
                    let%map _ : Transition_frontier.Breadcrumb.t =
                      breadcrumb_if_present ()
                    in
                    `Constructed new_breadcrumb
                | Error (`Fatal_error exn) -> Or_error.of_exn exn
                | Error (`Validation_error error) -> Error error )
            |> Cached.sequence_deferred
          in
          Cached.sequence_result cached_result )
    in
    Rose_tree.map tree ~f:(fun c ->
        Cached.transform c ~f:(function
          | `Initial -> failwith "impossible"
          | `Constructed breadcrumb -> breadcrumb ) )

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
        Logger.faulty_peer logger ~module_:__MODULE__ ~location:__LOC__ "%s"
          message ;
        Deferred.return @@ Or_error.error_string message
    | Some _ ->
        construct_breadcrumb_path ~logger frontier initial_state_hash tree

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
        Logger.info logger ~module_:__MODULE__ ~location:__LOC__
          "transition queried during ledger catchup has already been seen" ;
        Ok None
    | Error (`Invalid reason) ->
        Logger.faulty_peer logger ~module_:__MODULE__ ~location:__LOC__
          "transition queried during ledger catchup was not valid because %s"
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
                Logger.faulty_peer logger ~module_:__MODULE__ ~location:__LOC__
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
                  Logger.faulty_peer logger ~module_:__MODULE__
                    ~location:__LOC__ "%s" error ;
                  Error (Error.of_string error) )
            in
            let full_subtree =
              List.fold_right verified_transitions ~init:target_subtree
                ~f:(fun transition acc -> Rose_tree.T (transition, [acc]) )
            in
            materialize_breadcrumbs ~frontier ~logger ~peer full_subtree )

  let run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer ~unprocessed_transition_cache =
    Strict_pipe.Reader.iter catchup_job_reader ~f:(fun subtree ->
        match%bind
          get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
            ~num_peers:8 ~unprocessed_transition_cache ~target_subtree:subtree
        with
        | Ok tree -> Strict_pipe.Writer.write catchup_breadcrumbs_writer [tree]
        | Error e ->
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              !"All peers either sent us bad data, didn't have the info, or \
                our transition frontier moved too fast: %s"
              (Error.to_string_hum e) ;
            Deferred.unit )
    |> don't_wait_for
end
