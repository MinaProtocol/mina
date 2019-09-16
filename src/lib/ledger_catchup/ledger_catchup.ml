open Core
open Async
open Cache_lib
open Pipe_lib
open Coda_base
open Coda_state

(** [Ledger_catchup] is a procedure that connects a foreign external transition
    into a transition frontier by requesting a path of external_transitions
    from its peer. It receives the state_hash to catchup from
    [Catchup_scheduler]. With that state_hash, it will ask its peers for
    a path of external_transitions from their root to the state_hash it is
    asking for. It will then perform the following validations on each
    external_transition:

    1. The root should exist in the frontier. The frontier should not be
    missing too many external_transitions, so the querying node should have the
    root in its transition_frontier.

    2. Each transition is checked through [Transition_processor.Validator] and
    [Protocol_state_validator]

    If any of the external_transitions is invalid,
    1) the sender is punished;
    2) those external_transitions that already passed validation would be
       invalidated.
    Otherwise, [Ledger_catchup] will build a corresponding breadcrumb path from
    the path of external_transitions. A breadcrumb from the path is built using
    its corresponding external_transition staged_ledger_diff and applying it to
    its preceding breadcrumb staged_ledger to obtain its corresponding
    staged_ledger. If there was an error in building the breadcrumbs, then
    1) catchup will punish the sender for sending a faulty staged_ledger_diff;
    2) catchup would invalidate the cached transitions.
    After building the breadcrumb path, [Ledger_catchup] will then send it to
    the [Processor] via writing them to catchup_breadcrumbs_writer. *)

module Make (Inputs : Inputs.S) :
  Coda_intf.Catchup_intf
  with type external_transition_with_initial_validation :=
              Inputs.External_transition.with_initial_validation
   and type unprocessed_transition_cache :=
              Inputs.Unprocessed_transition_cache.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t
   and type network := Inputs.Network.t
   and type verifier := Inputs.Verifier.t = struct
  open Inputs

  type verification_error =
    [ `In_frontier of State_hash.t
    | `In_process of State_hash.t Cache_lib.Intf.final_state
    | `Disconnected
    | `Verifier_error of Error.t
    | `Invalid_proof ]

  type 'a verification_result = ('a, verification_error) Result.t

  let verify_transition ~logger ~trust_system ~verifier ~frontier
      ~unprocessed_transition_cache enveloped_transition =
    let sender = Envelope.Incoming.sender enveloped_transition in
    let cached_initially_validated_transition_result =
      let open Deferred.Result.Let_syntax in
      let transition = Envelope.Incoming.data enveloped_transition in
      let%bind initially_validated_transition =
        ( External_transition.Validation.wrap transition
          |> External_transition.skip_time_received_validation
               `This_transition_was_not_received_via_gossip
          |> External_transition.validate_proof ~verifier
          :> External_transition.with_initial_validation verification_result
             Deferred.t )
      in
      let enveloped_initially_validated_transition =
        Envelope.Incoming.map enveloped_transition
          ~f:(Fn.const initially_validated_transition)
      in
      Deferred.return
        ( Transition_handler_validator.validate_transition ~logger ~frontier
            ~unprocessed_transition_cache
            enveloped_initially_validated_transition
          :> ( External_transition.with_initial_validation Envelope.Incoming.t
             , State_hash.t )
             Cached.t
             verification_result )
    in
    let open Deferred.Let_syntax in
    match%bind cached_initially_validated_transition_result with
    | Ok x ->
        Deferred.return @@ Ok (Either.Second x)
    | Error (`In_frontier hash) ->
        Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
          "transition queried during ledger catchup has already been seen" ;
        Deferred.return @@ Ok (Either.First hash)
    | Error (`In_process consumed_state) -> (
        Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
          "transition queried during ledger catchup is still in process in \
           one of the components in transition_frontier" ;
        match%map Ivar.read consumed_state with
        | `Failed ->
            Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
              "transition queried during ledger catchup failed" ;
            Error (Error.of_string "Previous transition failed")
        | `Success hash ->
            Ok (Either.First hash) )
    | Error (`Verifier_error error) ->
        Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("error", `String (Error.to_string_hum error))]
          "verifier threw an error while verifying transiton queried during \
           ledger catchup: $error" ;
        return
          (Error
             (Error.of_string
                (sprintf "verifier threw an error: %s"
                   (Error.to_string_hum error))))
    | Error `Invalid_proof ->
        let%map () =
          Trust_system.record_envelope_sender trust_system logger sender
            ( Trust_system.Actions.Gossiped_invalid_transition
            , Some ("invalid proof", []) )
        in
        Error (Error.of_string "invalid proof")
    | Error `Disconnected ->
        let%map () =
          Trust_system.record_envelope_sender trust_system logger sender
            (Trust_system.Actions.Disconnected_chain, None)
        in
        Error (Error.of_string "disconnected chain")

  let take_while_map_result_rev ~f list =
    let open Deferred.Or_error.Let_syntax in
    let%map result, initial_state_hash_opt =
      Deferred.Or_error.List.fold list ~init:([], None)
        ~f:(fun (acc, initial_state_hash) elem ->
          let open Deferred.Let_syntax in
          if Option.is_some initial_state_hash then
            Deferred.Or_error.return (acc, initial_state_hash)
          else
            match%bind f elem with
            | Error e ->
                List.iter acc
                  ~f:(Fn.compose ignore Cached.invalidate_with_failure) ;
                Deferred.return (Error e)
            | Ok (Either.First hash) ->
                Deferred.Or_error.return (acc, Some hash)
            | Ok (Either.Second transition) ->
                Deferred.Or_error.return (transition :: acc, None) )
    in
    (result, initial_state_hash_opt)

  let verified_transitions_to_yojson subtrees_of_transitions =
    let rose_tree_hash =
      List.map subtrees_of_transitions ~f:(fun sub_tree ->
          Rose_tree.to_yojson State_hash.to_yojson
            (Rose_tree.map sub_tree ~f:Cached.original) )
    in
    `List rose_tree_hash

  let get_transitions_and_compute_breadcrumbs ~logger ~trust_system ~verifier
      ~network ~frontier ~num_peers ~unprocessed_transition_cache
      ~target_forest =
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
                      (Protocol_state.hash
                         (External_transition.protocol_state last))
                      target_hash
                  then return ()
                  else (
                    ignore
                      Trust_system.(
                        record trust_system logger peer.host
                          Actions.
                            ( Violated_protocol
                            , Some
                                ( "Peer returned a different target \
                                   transition than requested"
                                , [] ) )) ;
                    Deferred.return (Error (Error.of_string "")) )
                in
                Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                  ~metadata:[("count", `Int (Non_empty_list.length rev_queried_transitions))]
                    !"Queried $count external transitions from the network";
                let%bind verified_transitions, initial_state_hash_opt =
                  take_while_map_result_rev
                    Non_empty_list.(to_list rev_queried_transitions)
                    ~f:(fun transition ->
                      let transition_with_hash =
                        With_hash.of_data
                          ~hash_data:
                            (Fn.compose Protocol_state.hash
                               External_transition.protocol_state)
                          transition
                      in
                      Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                        ~metadata:[("state_hash", State_hash.to_yojson transition_with_hash.hash)]
                        !"Verifying external transition received from network: $state_hash";
                      verify_transition ~logger ~trust_system ~verifier
                        ~frontier ~unprocessed_transition_cache
                        (Envelope.Incoming.wrap ~data:transition_with_hash
                           ~sender:(Envelope.Sender.Remote peer.host)) )
                in
                let%bind initial_state_hash =
                  Deferred.return (
                    Option.map initial_state_hash_opt ~f:Or_error.return
                    |> Option.value ~default:(Error (Error.of_string "transitions queried during catchup did not have a known ancestor")))
                in
                let split_last xs =
                  let init = List.take xs (List.length xs - 1) in
                  let last = List.last_exn xs in
                  (init, last)
                in
                let subtrees_of_transitions =
                  if List.length verified_transitions > 0 then
                    let rest, target_transition =
                      split_last verified_transitions
                    in
                    [ List.fold_right rest
                        ~init:(Rose_tree.T (target_transition, subtrees))
                        ~f:(fun transition acc ->
                          Rose_tree.T (transition, [acc]) ) ]
                  else subtrees
                in
                let open Deferred.Let_syntax in
                Logger.trace logger
                  !"Attempting to build subtree"
                  ~metadata:
                    [ ("initial_hash", State_hash.to_yojson initial_state_hash)
                    ; ( "subtree"
                      , verified_transitions_to_yojson subtrees_of_transitions
                      ) ]
                  ~location:__LOC__ ~module_:__MODULE__ ;
                match%bind
                  Breadcrumb_builder.build_subtrees_of_breadcrumbs
                    ~logger:
                      (Logger.extend logger
                         [ ( "ledger_catchup"
                           , `String "Called from ledger catchup" ) ])
                    ~verifier ~trust_system ~frontier
                    ~initial_hash:initial_state_hash subtrees_of_transitions
                with
                | Ok result ->
                    Deferred.Or_error.return result
                | error ->
                    List.iter verified_transitions
                      ~f:(Fn.compose ignore Cached.invalidate_with_failure) ;
                    Deferred.return error ) ) )

  let run ~logger ~trust_system ~verifier ~network ~frontier
      ~catchup_job_reader
      ~(catchup_breadcrumbs_writer :
         ( (Inputs.Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
           Rose_tree.t
           list
         , Strict_pipe.crash Strict_pipe.buffered
         , unit )
         Strict_pipe.Writer.t) ~unprocessed_transition_cache : unit =
    Strict_pipe.Reader.iter_without_pushback catchup_job_reader
      ~f:(fun (hash, subtrees) ->
        (* create a unique id for each catchup job logging *)
        let logger = Logger.extend logger [("catchup_job_id", `String (Uuid.to_string_hum (Uuid_unix.create ())))] in
        don't_wait_for (
          match%bind
            get_transitions_and_compute_breadcrumbs ~logger ~trust_system
              ~verifier ~network ~frontier ~num_peers:8
              ~unprocessed_transition_cache ~target_forest:(hash, subtrees)
          with
          | Ok trees ->
              Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                "about to write to the catchup breadcrumbs pipe" ;
              if Strict_pipe.Writer.is_closed catchup_breadcrumbs_writer then (
                Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                  "catchup breadcrumbs pipe was closed; attempt to write to \
                   closed pipe" ;
                Deferred.unit )
              else
                ( Logger.trace logger !"Writing subtree to pipe"
                    ~metadata:[("subtree", verified_transitions_to_yojson trees)]
                    ~location:__LOC__ ~module_:__MODULE__ ;
                  Strict_pipe.Writer.write catchup_breadcrumbs_writer trees )
                |> Deferred.return
          | Error e ->
              Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                !"All peers either sent us bad data, didn't have the info, or \
                  our transition frontier moved too fast: %s"
                (Error.to_string_hum e) ;
              List.iter subtrees ~f:(fun subtree ->
                  Rose_tree.iter subtree ~f:(fun cached_transition ->
                      Cached.invalidate_with_failure cached_transition |> ignore
                  ) ) ;
              Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                "garbage collected failed cached transitions" ;
              Deferred.unit ))
    |> don't_wait_for
end
