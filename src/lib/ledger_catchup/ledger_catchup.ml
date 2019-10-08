open Core
open Async
open Cache_lib
open Pipe_lib
open Coda_base
open Coda_transition

(** [Ledger_catchup] is a procedure that connects a foreign external transition
    into a transition frontier by requesting a path of external_transitions
    from its peer. It receives the state_hash to catchup from
    [Catchup_scheduler]. With that state_hash, it will ask its peers for
    a merkle path/list from their oldest transition to the state_hash it is
    asking for. Upon receiving the merkle path/list, it will do the following:
    
    1. verify the merkle path/list is correct by calling
    [Transition_chain_verifier.verify]. This function would returns a list
    of state hashes if the verification is successful.
    
    2. using the list of state hashes to poke a transition frontier
    in order to find the hashes of missing transitions. If none of the hashes
    are found, then it means some more transitions are missing.

    Once the list of missing hashes are computed, it would do another request to
    download the corresponding transitions in a batch fashion. Next it will perform the
    following validations on each external_transition:

    1. Check the list of transitions corresponds to the list of hashes that we
    requested;

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
    catchup would invalidate the cached transitions.
    After building the breadcrumb path, [Ledger_catchup] will then send it to
    the [Processor] via writing them to catchup_breadcrumbs_writer. *)

module Make (Inputs : Inputs.S) :
  Coda_intf.Catchup_intf
  with type unprocessed_transition_cache :=
              Inputs.Unprocessed_transition_cache.t
   and type transition_frontier := Inputs.Transition_frontier.t
   and type transition_frontier_breadcrumb :=
              Inputs.Transition_frontier.Breadcrumb.t
   and type network := Inputs.Network.t = struct
  open Inputs

  let verify_transition ~logger ~trust_system ~verifier ~frontier
      ~unprocessed_transition_cache enveloped_transition =
    let sender = Envelope.Incoming.sender enveloped_transition in
    let cached_initially_validated_transition_result =
      let open Deferred.Result.Let_syntax in
      let transition = Envelope.Incoming.data enveloped_transition in
      let%bind initially_validated_transition =
        External_transition.Validation.wrap transition
        |> External_transition.skip_time_received_validation
             `This_transition_was_not_received_via_gossip
        |> External_transition.validate_proof ~verifier
        >>= Fn.compose Deferred.return
              External_transition.validate_delta_transition_chain
      in
      let enveloped_initially_validated_transition =
        Envelope.Incoming.map enveloped_transition
          ~f:(Fn.const initially_validated_transition)
      in
      Deferred.return
      @@ Transition_handler_validator.validate_transition ~logger ~frontier
           ~unprocessed_transition_cache
           enveloped_initially_validated_transition
    in
    let open Deferred.Let_syntax in
    match%bind cached_initially_validated_transition_result with
    | Ok x ->
        Deferred.return @@ Ok (`Building_path x)
    | Error (`In_frontier hash) ->
        Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
          "transition queried during ledger catchup has already been seen" ;
        Deferred.return @@ Ok (`In_frontier hash)
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
            Ok (`In_frontier hash) )
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
    | Error `Invalid_delta_transition_chain_proof ->
        let%map () =
          Trust_system.record_envelope_sender trust_system logger sender
            ( Trust_system.Actions.Gossiped_invalid_transition
            , Some ("invalid delta transition chain witness", []) )
        in
        Error (Error.of_string "invalid delta transition chain witness")
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
  let download_state_hashes ~logger ~trust_system ~network ~frontier ~num_peers
      ~target_hash =
    let peers = Network.random_peers network num_peers in
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      ~metadata:[("target_hash", State_hash.to_yojson target_hash)]
      "Doing a catchup job with target $target_hash" ;
    Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
        let open Deferred.Or_error.Let_syntax in
        let%bind transition_chain_proof =
          Network.get_transition_chain_proof network peer target_hash
        in
        (* a list of state_hashes from new to old *)
        let%bind hashes =
          match
            Transition_chain_verifier.verify ~target_hash
              ~transition_chain_proof
          with
          | Some hashes ->
              Deferred.Or_error.return hashes
          | None ->
              let error_msg =
                sprintf
                  !"Peer %{sexp:Network_peer.Peer.t} sent us bad proof"
                  peer
              in
              ignore
                Trust_system.(
                  record trust_system logger peer.host
                    Actions.
                      ( Sent_invalid_transition_chain_merkle_proof
                      , Some (error_msg, []) )) ;
              Deferred.Or_error.error_string error_msg
        in
        Deferred.return
        @@ List.fold_until
             (Non_empty_list.to_list hashes)
             ~init:[]
             ~f:(fun acc hash ->
               if Transition_frontier.find frontier hash |> Option.is_some then
                 Continue_or_stop.Stop (Ok (peer, acc))
               else Continue_or_stop.Continue (hash :: acc) )
             ~finish:(fun _ ->
               Or_error.errorf
                 !"Peer %{sexp:Network_peer.Peer.t} moves too fast"
                 peer ) )

  let verify_against_hashes transitions hashes =
    List.length transitions = List.length hashes
    && List.for_all2_exn transitions hashes ~f:(fun transition hash ->
           State_hash.equal (External_transition.state_hash transition) hash )

  let rec partition size = function
    | [] ->
        []
    | ls ->
        let sub, rest = List.split_n ls size in
        sub :: partition size rest

  (* returns a list of transitions with old ones comes first *)
  let download_transitions ~logger ~trust_system ~network ~num_peers
      ~preferred_peer ~maximum_download_size ~hashes_of_missing_transitions =
    let random_peers = Network.random_peers network num_peers in
    Deferred.Or_error.List.concat_map
      (partition maximum_download_size hashes_of_missing_transitions)
      ~how:`Parallel ~f:(fun hashes ->
        Deferred.Or_error.find_map_ok (preferred_peer :: random_peers)
          ~f:(fun peer ->
            let open Deferred.Or_error.Let_syntax in
            let%bind transitions =
              Network.get_transition_chain network peer hashes
            in
            Coda_metrics.(
              Gauge.set
                Transition_frontier_controller
                .transitions_downloaded_from_catchup
                (Float.of_int (List.length transitions))) ;
            if not @@ verify_against_hashes transitions hashes then (
              let error_msg =
                sprintf
                  !"Peer %{sexp:Network_peer.Peer.t} returned a list that is \
                    different from the one that is requested."
                  peer
              in
              Trust_system.(
                record trust_system logger peer.host
                  Actions.(Violated_protocol, Some (error_msg, [])))
              |> don't_wait_for ;
              Deferred.Or_error.error_string error_msg )
            else
              Deferred.Or_error.return
              @@ List.map2_exn hashes transitions ~f:(fun hash transition ->
                     let transition_with_hash =
                       With_hash.of_data transition ~hash_data:(Fn.const hash)
                     in
                     Envelope.Incoming.wrap ~data:transition_with_hash
                       ~sender:(Envelope.Sender.Remote peer.host) ) ) )

  let verify_transitions_and_build_breadcrumbs ~logger ~trust_system ~verifier
      ~frontier ~unprocessed_transition_cache ~transitions ~target_hash
      ~subtrees =
    let open Deferred.Or_error.Let_syntax in
    let%bind transitions_with_initial_validation, initial_hash =
      fold_until (List.rev transitions) ~init:[]
        ~f:(fun acc transition ->
          let open Deferred.Let_syntax in
          match%bind
            verify_transition ~logger ~trust_system ~verifier ~frontier
              ~unprocessed_transition_cache transition
          with
          | Error e ->
              List.map acc ~f:Cached.invalidate_with_failure |> ignore ;
              Deferred.Or_error.fail e
          | Ok (`In_frontier initial_hash) ->
              Deferred.Or_error.return
              @@ Continue_or_stop.Stop (acc, initial_hash)
          | Ok (`Building_path transition_with_initial_validation) ->
              Deferred.Or_error.return
              @@ Continue_or_stop.Continue
                   (transition_with_initial_validation :: acc) )
        ~finish:(fun acc ->
          if List.length transitions <= 0 then
            Deferred.Or_error.return ([], target_hash)
          else
            let oldest_missing_transition =
              List.hd_exn transitions |> Envelope.Incoming.data
              |> With_hash.data
            in
            let initial_state_hash =
              External_transition.parent_hash oldest_missing_transition
            in
            Deferred.Or_error.return (acc, initial_state_hash) )
    in
    let trees_of_transitions =
      Option.fold
        (Non_empty_list.of_list_opt transitions_with_initial_validation)
        ~init:subtrees ~f:(fun _ transitions ->
          [Rose_tree.of_non_empty_list ~subtrees transitions] )
    in
    let open Deferred.Let_syntax in
    match%bind
      Breadcrumb_builder.build_subtrees_of_breadcrumbs ~logger ~verifier
        ~trust_system ~frontier ~initial_hash trees_of_transitions
    with
    | Ok result ->
        Deferred.Or_error.return result
    | Error e ->
        List.map transitions_with_initial_validation
          ~f:Cached.invalidate_with_failure
        |> ignore ;
        Deferred.Or_error.fail e

  let garbage_collect_subtrees ~logger ~subtrees =
    List.iter subtrees ~f:(fun subtree ->
        Rose_tree.map subtree ~f:Cached.invalidate_with_failure |> ignore ) ;
    Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
      "garbage collected failed cached transitions"

  let run ~logger ~trust_system ~verifier ~network ~frontier
      ~catchup_job_reader
      ~(catchup_breadcrumbs_writer :
         ( (Inputs.Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
           Rose_tree.t
           list
           * [`Ledger_catchup of unit Ivar.t | `Catchup_scheduler]
         , Strict_pipe.crash Strict_pipe.buffered
         , unit )
         Strict_pipe.Writer.t) ~unprocessed_transition_cache : unit =
    let num_peers = 8 in
    let maximum_download_size = 100 in
    Strict_pipe.Reader.iter_without_pushback catchup_job_reader
      ~f:(fun (target_hash, subtrees) ->
        (let start_time = Core.Time.now () in
         let%bind () = Transition_frontier.incr_num_catchup_jobs frontier in
         match%bind
           let open Deferred.Or_error.Let_syntax in
           let%bind preferred_peer, hashes_of_missing_transitions =
             download_state_hashes ~logger ~trust_system ~network ~frontier
               ~num_peers ~target_hash
           in
           let num_of_missing_transitions =
             List.length hashes_of_missing_transitions
           in
           Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
             ~metadata:
               [ ( "hashes_of_missing_transitions"
                 , `List
                     (List.map hashes_of_missing_transitions
                        ~f:State_hash.to_yojson) ) ]
             !"Number of missing transitions is %d"
             num_of_missing_transitions ;
           let%bind transitions =
             if num_of_missing_transitions <= 0 then
               Deferred.Or_error.return []
             else
               download_transitions ~logger ~trust_system ~network ~num_peers
                 ~preferred_peer ~maximum_download_size
                 ~hashes_of_missing_transitions
           in
           verify_transitions_and_build_breadcrumbs ~logger ~trust_system
             ~verifier ~frontier ~unprocessed_transition_cache ~transitions
             ~target_hash ~subtrees
         with
         | Ok trees_of_breadcrumbs ->
             Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
               ~metadata:
                 [ ( "hashes of transitions"
                   , `List
                       (List.map trees_of_breadcrumbs ~f:(fun tree ->
                            Rose_tree.to_yojson
                              (fun breadcrumb ->
                                Cached.peek breadcrumb
                                |> Transition_frontier.Breadcrumb.state_hash
                                |> State_hash.to_yojson )
                              tree )) ) ]
               "about to write to the catchup breadcrumbs pipe" ;
             if Strict_pipe.Writer.is_closed catchup_breadcrumbs_writer then (
               Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
                 "catchup breadcrumbs pipe was closed; attempt to write to \
                  closed pipe" ;
               garbage_collect_subtrees ~logger ~subtrees:trees_of_breadcrumbs ;
               Coda_metrics.(
                 Gauge.set Transition_frontier_controller.catchup_time_ms
                   Core.Time.(Span.to_ms @@ diff (now ()) start_time)) ;
               Transition_frontier.decr_num_catchup_jobs frontier )
             else
               let ivar = Ivar.create () in
               Strict_pipe.Writer.write catchup_breadcrumbs_writer
                 (trees_of_breadcrumbs, `Ledger_catchup ivar) ;
               let%bind () = Ivar.read ivar in
               Coda_metrics.(
                 Gauge.set Transition_frontier_controller.catchup_time_ms
                   Core.Time.(Span.to_ms @@ diff (now ()) start_time)) ;
               Transition_frontier.decr_num_catchup_jobs frontier
         | Error e ->
             Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
               ~metadata:[("error", `String (Error.to_string_hum e))]
               "Catchup process failed -- unable to receive valid data from \
                peers or transition frontier progressed faster than catchup \
                data received. See error for details: $error" ;
             garbage_collect_subtrees ~logger ~subtrees ;
             Coda_metrics.(
               Gauge.set Transition_frontier_controller.catchup_time_ms
                 Core.Time.(Span.to_ms @@ diff (now ()) start_time)) ;
             Transition_frontier.decr_num_catchup_jobs frontier)
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
end)
