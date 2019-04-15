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
    match%bind cached_verified_transition with
    | Ok x -> Deferred.return @@ Ok (Either.Second x)
    | Error (`In_frontier hash) ->
        Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
          "transition queried during ledger catchup has already been seen" ;
        Deferred.return @@ Ok (Either.First hash)
    | Error (`Under_processing consumed_state) -> (
        Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
          "transition queried during ledger catchup is still under procession" ;
        match%map Ivar.read consumed_state with
        | `Failed ->
            Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
              "transition queried during ledger catchup failed" ;
            Error (Error.of_string "Previous transition failed")
        | `Success hash -> Ok (Either.First hash) )
    | Error (`Invalid reason) ->
        Logger.faulty_peer logger ~module_:__MODULE__ ~location:__LOC__
          "transition queried during ledger catchup was not valid because %s"
          reason ;
        Deferred.return @@ Error (Error.of_string reason)

  let take_while_map_result_rev ~f list =
    let open Deferred.Or_error.Let_syntax in
    let%map result, initial_state_hash =
      Deferred.Or_error.List.fold list ~init:([], None)
        ~f:(fun (acc, initial_state_hash) elem ->
          let open Deferred.Let_syntax in
          if Option.is_some initial_state_hash then
            Deferred.Or_error.return (acc, initial_state_hash)
          else
            match%bind f elem with
            | Error e -> Deferred.return (Error e)
            | Ok (Either.First hash) ->
                Deferred.Or_error.return (acc, Some hash)
            | Ok (Either.Second transition) ->
                Deferred.Or_error.return (transition :: acc, None) )
    in
    (result, Option.value_exn initial_state_hash)

  let get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
      ~num_peers ~unprocessed_transition_cache ~target_forest =
    let peers = Network.random_peers network num_peers in
    let target_hash, subtrees = target_forest in
    let open Deferred.Or_error.Let_syntax in
    Logger.trace logger "doing a catchup job with target $target_hash"
      ~module_:__MODULE__ ~location:__LOC__
      ~metadata:[("target_hash", State_hash.to_yojson target_hash)] ;
    Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
        O1trace.trace_recurring_task "ledger catchup" (fun () ->
            match%bind Network.catchup_transition network peer target_hash with
            | None ->
                Deferred.return
                @@ Or_error.errorf
                     !"Peer %{sexp:Network_peer.Peer.t} did not have transition"
                     peer
            | Some queried_transitions -> (
                let rev_queried_transitions =
                  Non_empty_list.rev queried_transitions
                in
                let last = Non_empty_list.head rev_queried_transitions in
                let%bind () =
                  if
                    State_hash.equal
                      (Consensus.Protocol_state.hash
                         (External_transition.protocol_state last))
                      target_hash
                  then return ()
                  else (
                    Logger.faulty_peer logger ~module_:__MODULE__
                      ~location:__LOC__
                      !"Peer %{sexp:Network_peer.Peer.t} returned an \
                        different target transition than we requested"
                      peer ;
                    Deferred.return (Error (Error.of_string "")) )
                in
                let%bind verified_transitions, initial_state_hash =
                  take_while_map_result_rev
                    Non_empty_list.(to_list rev_queried_transitions)
                    ~f:
                      (verify_transition ~logger ~frontier
                         ~unprocessed_transition_cache)
                in
                let subtrees_of_transitions =
                  if List.length verified_transitions > 0 then
                    let rest, target_transition_singleton =
                      List.split_n verified_transitions
                        (List.length verified_transitions - 1)
                    in
                    let target_transition =
                      List.hd_exn target_transition_singleton
                    in
                    [ List.fold_right rest
                        ~init:(Rose_tree.T (target_transition, subtrees))
                        ~f:(fun transition acc ->
                          Rose_tree.T (transition, [acc]) ) ]
                  else subtrees
                in
                let open Deferred.Let_syntax in
                match%bind
                  Breadcrumb_builder.build_subtrees_of_breadcrumbs ~logger
                    ~frontier ~initial_hash:initial_state_hash
                    subtrees_of_transitions
                with
                | Ok result -> Deferred.Or_error.return result
                | error ->
                    List.iter verified_transitions
                      ~f:(Fn.compose ignore Cached.invalidate) ;
                    Deferred.return error ) ) )

  let run ~logger ~network ~frontier ~catchup_job_reader
      ~catchup_breadcrumbs_writer ~unprocessed_transition_cache =
    Strict_pipe.Reader.iter catchup_job_reader ~f:(fun forest ->
        ( match%bind
            get_transitions_and_compute_breadcrumbs ~logger ~network ~frontier
              ~num_peers:8 ~unprocessed_transition_cache ~target_forest:forest
          with
        | Ok trees ->
            Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
              "about to write to the catchup breadcrumbs pipe" ;
            Strict_pipe.Writer.write catchup_breadcrumbs_writer trees
        | Error e ->
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              !"All peers either sent us bad data, didn't have the info, or \
                our transition frontier moved too fast: %s"
              (Error.to_string_hum e) ;
            List.iter (snd forest) ~f:(fun subtree ->
                Rose_tree.iter subtree ~f:(fun cached_transition ->
                    Cached.invalidate cached_transition |> ignore ) ) ;
            Deferred.unit )
        |> don't_wait_for ;
        Deferred.unit )
    |> don't_wait_for
end
