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
        Deferred.Or_error.fail @@ Error.of_string "disconnected chain"

  let rec fold_until ~(init : 'accum)
      ~(f :
            'accum
         -> 'a
         -> ('accum, 'final) Continue_or_stop.t Deferred.Or_error.t)
      ~(finish : 'accum -> 'final Deferred.Or_error.t) :
      'a list -> 'final Deferred.Or_error.t = function
    | [] ->
        finish init
    | x :: xs -> (
        let open Deferred.Or_error.Let_syntax in
        match%bind f init x with
        | Continue_or_stop.Stop res ->
            Deferred.Or_error.return res
        | Continue_or_stop.Continue init ->
            fold_until ~init ~f ~finish xs )

  (* returns a list of state-hashes with the older ones at the front *)
  let get_state_hashes ~logger ~trust_system ~network ~frontier ~num_peers
      ~unprocessed_transition_cache ~state_hash =
    let peers = Network.random_peers network num_peers in
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:[("target_hash", State_hash.to_yojson state_hash)]
      "Doing a catchup job with target $target_hash" ;
    Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
        match%map
          Network.get_transition_chain_witness network peer state_hash
        with
        | None ->
            Or_error.errorf
              !"Peer %{sexp:Network_peer.Peer.t} did not have the transition"
              peer
        | Some transition_chain_witness ->
            let open Or_error.Let_syntax in
            (* a list of state_hashes from new to old *)
            let%bind state_hashes =
              match
                Transition_chain_witness.verify ~state_hash
                  ~transition_chain_witness
              with
              | Some state_hashes ->
                  return state_hashes
              | None ->
                  let error_msg =
                    sprintf
                      !"Peer %{sexp:Network_peer.Peer.t} sent us bad proof"
                      peer
                  in
                  ignore
                    Trust_system.(
                      record trust_system logger peer.host
                        Actions.(Violated_protocol, Some (error_msg, []))) ;
                  Or_error.error_string error_msg
            in
            List.fold_until state_hashes ~init:[]
              ~f:(fun acc state_hash ->
                if
                  Unprocessed_transition_cache.mem_target
                    unprocessed_transition_cache state_hash
                  || Transition_frontier.find frontier state_hash
                     |> Option.is_some
                then (
                  let num_of_missing_transitions = List.length acc in
                  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
                    ~metadata:
                      [ ( "states_hashes"
                        , `List (List.map acc ~f:State_hash.to_yojson) ) ]
                    !"The total number of missing transitions are %d"
                    num_of_missing_transitions ;
                  Continue_or_stop.Stop (Ok (peer, acc)) )
                else Continue_or_stop.Continue (state_hash :: acc) )
              ~finish:(fun _ ->
                Or_error.errorf
                  !"Peer %{sexp:Network_peer.Peer.t} moves too fast"
                  peer ) )

  let verify_against_hashes transitions hashes =
    List.length transitions = List.length hashes
    && List.for_all2_exn transitions hashes ~f:(fun transition hash ->
           State_hash.equal
             ( External_transition.protocol_state transition
             |> Protocol_state.hash )
             hash )

  let get_transitions_and_compute_breadcrumbs ~logger ~trust_system ~verifier
      ~network ~frontier ~num_peers ~unprocessed_transition_cache
      ~preferred_peer ~hashes ~subtrees =
    let random_peers = Network.random_peers network num_peers in
    Deferred.Or_error.find_map_ok (preferred_peer :: random_peers)
      ~f:(fun peer ->
        match%bind Network.get_transition_chain network peer hashes with
        | None ->
            Deferred.Or_error.errorf
              !"Peer %{sexp:Network_peer.Peer.t} did not have the transitions \
                we requested"
              peer
        | Some transitions -> (
            let open Deferred.Or_error.Let_syntax in
            let%bind () =
              if not @@ verify_against_hashes transitions hashes then (
                let error_msg =
                  sprintf
                    !"Peer %{sexp:Network_peer.Peer.t} returned a list that \
                      is different from the one that is requested."
                    peer
                in
                Trust_system.(
                  record trust_system logger peer.host
                    Actions.(Violated_protocol, Some (error_msg, [])))
                |> don't_wait_for ;
                Deferred.Or_error.error_string error_msg )
              else Deferred.Or_error.return ()
            in
            (* a list of verified_transitions with new-er one at the front *)
            let%bind verified_transitions, initial_state_hash =
              fold_until transitions ~init:[]
                ~f:(fun acc transition ->
                  let hashed_transition =
                    With_hash.of_data transition
                      ~hash_data:
                        (Fn.compose Protocol_state.hash
                           External_transition.protocol_state)
                  in
                  let enveloped_transition =
                    Envelope.Incoming.wrap ~data:hashed_transition
                      ~sender:(Envelope.Sender.Remote peer.host)
                  in
                  let open Deferred.Let_syntax in
                  match%bind
                    verify_transition ~logger ~trust_system ~verifier ~frontier
                      ~unprocessed_transition_cache enveloped_transition
                  with
                  | Error e ->
                      List.map acc ~f:Cached.invalidate_with_failure |> ignore ;
                      Deferred.Or_error.fail e
                  | Ok (Either.First initial_state_hash) ->
                      Deferred.Or_error.return
                      @@ Continue_or_stop.Stop (acc, initial_state_hash)
                  | Ok (Either.Second verified_transition) ->
                      Deferred.Or_error.return
                      @@ Continue_or_stop.Continue (verified_transition :: acc)
                  )
                ~finish:(fun acc ->
                  let oldest_missing_transition = List.hd_exn transitions in
                  let initial_state_hash =
                    External_transition.protocol_state
                      oldest_missing_transition
                    |> Protocol_state.previous_state_hash
                  in
                  Deferred.Or_error.return (acc, initial_state_hash) )
            in
            let subtrees_of_transitions =
              if List.length verified_transitions <= 0 then subtrees
              else
                [ List.(
                    fold
                      (tl_exn verified_transitions)
                      ~init:
                        (Rose_tree.T (hd_exn verified_transitions, subtrees))
                      ~f:(fun acc verified_transition ->
                        Rose_tree.T (verified_transition, [acc]) )) ]
            in
            let open Deferred.Let_syntax in
            match%bind
              Breadcrumb_builder.build_subtrees_of_breadcrumbs ~logger
                ~verifier ~trust_system ~frontier
                ~initial_hash:initial_state_hash subtrees_of_transitions
            with
            | Ok result ->
                Deferred.Or_error.return result
            | Error e ->
                List.map verified_transitions ~f:Cached.invalidate_with_failure
                |> ignore ;
                Deferred.Or_error.fail e ) )

  let garbage_collect_disconnected_subtrees ~logger ~disconnected_subtrees =
    List.iter disconnected_subtrees ~f:(fun subtree ->
        Rose_tree.map subtree ~f:Cached.invalidate_with_failure |> ignore ) ;
    Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
      "garbage collected failed cached transitions"

  let run ~logger ~trust_system ~verifier ~network ~frontier
      ~catchup_job_reader
      ~(catchup_breadcrumbs_writer :
         ( (Inputs.Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
           Rose_tree.t
           list
         , Strict_pipe.crash Strict_pipe.buffered
         , unit )
         Strict_pipe.Writer.t) ~unprocessed_transition_cache : unit =
    let num_peers = 8 in
    Strict_pipe.Reader.iter_without_pushback catchup_job_reader
      ~f:(fun (hash, received_subtrees) ->
        ( match%bind
            get_state_hashes ~logger ~trust_system ~network ~frontier
              ~num_peers ~unprocessed_transition_cache ~state_hash:hash
          with
        | Error e ->
            Logger.info logger ~module_:__MODULE__ ~location:__LOC__
              !"All peers either sent us bad transition_chain_witness, didn't \
                have the info, or our transition frontier moved too fast: %s"
              (Error.to_string_hum e) ;
            garbage_collect_disconnected_subtrees ~logger
              ~disconnected_subtrees:received_subtrees ;
            Deferred.unit
        | Ok (preferred_peer, hashes) -> (
            match%bind
              get_transitions_and_compute_breadcrumbs ~logger ~trust_system
                ~verifier ~network ~frontier ~num_peers
                ~unprocessed_transition_cache ~preferred_peer ~hashes
                ~subtrees:received_subtrees
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
                  Strict_pipe.Writer.write catchup_breadcrumbs_writer trees
                  |> Deferred.return
            | Error e ->
                Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                  !"All peers either sent us bad transitions, didn't have the \
                    info, or our transition frontier moved too fast: %s"
                  (Error.to_string_hum e) ;
                garbage_collect_disconnected_subtrees ~logger
                  ~disconnected_subtrees:received_subtrees ;
                Deferred.unit ) )
        |> don't_wait_for )
    |> don't_wait_for
end

include Make (struct
  include Transition_frontier.Inputs
  module Transition_frontier = Transition_frontier
  module Unprocessed_transition_cache =
    Transition_handler.Unprocessed_transition_cache
  module Transition_handler_validator = Transition_handler.Validator
  module Breadcrumb_builder = Transition_handler.Breadcrumb_builder
  module Network = Coda_networking
  module Transition_chain_witness = Transition_chain_witness
end)
