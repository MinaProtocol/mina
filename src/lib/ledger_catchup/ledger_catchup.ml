open Core
open Async
open Cache_lib
open Pipe_lib
open Coda_base
open Coda_transition
open Network_peer

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

module Catchup_jobs = struct
  open Broadcast_pipe

  let reader, writer = create 0

  let update f = Writer.write writer (f (Reader.peek reader))

  let incr () = update (( + ) 1)

  let decr () = update (( - ) 1)
end

let verify_transition ~logger ~consensus_constants ~trust_system ~verifier
    ~frontier ~unprocessed_transition_cache enveloped_transition =
  let sender = Envelope.Incoming.sender enveloped_transition in
  let genesis_state_hash = Transition_frontier.genesis_state_hash frontier in
  let transition_with_hash = Envelope.Incoming.data enveloped_transition in
  let cached_initially_validated_transition_result =
    let open Deferred.Result.Let_syntax in
    let%bind initially_validated_transition =
      External_transition.Validation.wrap transition_with_hash
      |> External_transition.skip_time_received_validation
           `This_transition_was_not_received_via_gossip
      |> Fn.compose Deferred.return
           (External_transition.validate_genesis_protocol_state
              ~genesis_state_hash)
      >>= External_transition.validate_proof ~verifier
      >>= Fn.compose Deferred.return
            External_transition.validate_protocol_versions
      >>= Fn.compose Deferred.return
            External_transition.validate_delta_transition_chain
    in
    let enveloped_initially_validated_transition =
      Envelope.Incoming.map enveloped_transition
        ~f:(Fn.const initially_validated_transition)
    in
    Deferred.return
    @@ Transition_handler.Validator.validate_transition ~logger ~frontier
         ~consensus_constants ~unprocessed_transition_cache
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
        "transition queried during ledger catchup is still in process in one \
         of the components in transition_frontier" ;
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
  | Error `Invalid_genesis_protocol_state ->
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_invalid_transition
          , Some ("invalid genesis protocol state", []) )
      in
      Error (Error.of_string "invalid genesis protocol state")
  | Error `Invalid_delta_transition_chain_proof ->
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Gossiped_invalid_transition
          , Some ("invalid delta transition chain witness", []) )
      in
      Error (Error.of_string "invalid delta transition chain witness")
  | Error `Invalid_protocol_version ->
      let transition = With_hash.data transition_with_hash in
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Sent_invalid_protocol_version
          , Some
              ( "Invalid current or proposed protocol version in catchup block"
              , [ ( "current_protocol_version"
                  , `String
                      ( External_transition.current_protocol_version transition
                      |> Protocol_version.to_string ) )
                ; ( "proposed_protocol_version"
                  , `String
                      ( External_transition.proposed_protocol_version_opt
                          transition
                      |> Option.value_map ~default:"<None>"
                           ~f:Protocol_version.to_string ) ) ] ) )
      in
      Error (Error.of_string "invalid protocol version")
  | Error `Mismatched_protocol_version ->
      let transition = With_hash.data transition_with_hash in
      let%map () =
        Trust_system.record_envelope_sender trust_system logger sender
          ( Trust_system.Actions.Sent_mismatched_protocol_version
          , Some
              ( "Current protocol version in catchup block does not match \
                 daemon protocol version"
              , [ ( "block_current_protocol_version"
                  , `String
                      ( External_transition.current_protocol_version transition
                      |> Protocol_version.to_string ) )
                ; ( "daemon_current_protocol_version"
                  , `String Protocol_version.(get_current () |> to_string) ) ]
              ) )
      in
      Error (Error.of_string "mismatched protocol version")
  | Error `Disconnected ->
      Deferred.Or_error.fail @@ Error.of_string "disconnected chain"

let rec fold_until ~(init : 'accum)
    ~(f :
       'accum -> 'a -> ('accum, 'final) Continue_or_stop.t Deferred.Or_error.t)
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

(** returns a list of state-hashes with the older ones at the front *)
let download_state_hashes ~logger ~trust_system ~network ~frontier ~num_peers
    ~target_hash =
  let%bind peers = Coda_networking.random_peers network num_peers in
  Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
    ~metadata:[("target_hash", State_hash.to_yojson target_hash)]
    "Doing a catchup job with target $target_hash" ;
  Deferred.Or_error.find_map_ok peers ~f:(fun peer ->
      let open Deferred.Or_error.Let_syntax in
      let%bind transition_chain_proof =
        Coda_networking.get_transition_chain_proof network peer target_hash
      in
      (* a list of state_hashes from new to old *)
      let%bind hashes =
        match
          Transition_chain_verifier.verify ~target_hash ~transition_chain_proof
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

(** returns a list of lists of transitions with old ones comes first *)
let download_transitions_in_chunks ~logger ~trust_system ~network ~num_peers
    ~preferred_peer ~maximum_download_size ~hashes_of_missing_transitions =
  let%bind random_peers = Coda_networking.random_peers network num_peers in
  Deferred.Or_error.List.map
    (* May change to normal List.map to have a list of Deferred.t *)
    (partition maximum_download_size hashes_of_missing_transitions)
    ~how:`Parallel ~f:(fun hashes ->
      Deferred.Or_error.find_map_ok (preferred_peer :: random_peers)
        ~f:(fun peer ->
          let open Deferred.Or_error.Let_syntax in
          let%bind transitions =
            Coda_networking.get_transition_chain network peer hashes
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
                     ~sender:(Envelope.Sender.Remote (peer.host, peer.peer_id))
               ) ) )

(** Build result will be a list of breadcrumbs if it is not the last chunk.
 * Otherwise, it will be a list of subtrees, as usual. *)
type ('a, 'b) build_result_t = T of 'a | L of 'b

let verify_transitions_and_build_breadcrumbs ~logger
    ~(precomputed_values : Precomputed_values.t) ~trust_system ~verifier
    ~frontier ~unprocessed_transition_cache ~transitions ~target_hash ~subtrees
    ~prev_hash ~prev_breadcrumb =
  let open Deferred.Or_error.Let_syntax in
  let%bind transitions_with_initial_validation, initial_hash =
    fold_until (List.rev transitions) ~init:[]
      ~f:(fun acc transition ->
        let open Deferred.Let_syntax in
        match%bind
          verify_transition ~logger
            ~consensus_constants:precomputed_values.consensus_constants
            ~trust_system ~verifier ~frontier ~unprocessed_transition_cache
            transition
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
            List.hd_exn transitions |> Envelope.Incoming.data |> With_hash.data
          in
          let initial_state_hash =
            External_transition.parent_hash oldest_missing_transition
          in
          Deferred.Or_error.return (acc, initial_state_hash) )
  in
  let passed_initial_hash =
    match prev_hash with Some hash_value -> hash_value | None -> initial_hash
  in
  match subtrees with
  | Some subtrees -> (
      let trees_of_transitions =
        Option.fold
          (Non_empty_list.of_list_opt transitions_with_initial_validation)
          ~init:subtrees ~f:(fun _ transitions ->
            [Rose_tree.of_non_empty_list ~subtrees transitions] )
      in
      let open Deferred.Let_syntax in
      match%bind
        Transition_handler.Breadcrumb_builder
        .build_subtrees_of_breadcrumbs_in_sequence ~logger ~precomputed_values
          ~verifier ~trust_system ~frontier ~initial_hash:passed_initial_hash
          ~initial_breadcrumb:prev_breadcrumb trees_of_transitions
      with
      | Ok result ->
          Deferred.Or_error.return (T (passed_initial_hash, result))
      | Error e ->
          List.map transitions_with_initial_validation
            ~f:Cached.invalidate_with_failure
          |> ignore ;
          Deferred.Or_error.fail e )
  | None -> (
      let open Deferred.Let_syntax in
      match%bind
        Transition_handler.Breadcrumb_builder
        .build_list_of_breadcrumbs_in_sequence ~logger ~precomputed_values
          ~verifier ~trust_system ~frontier ~initial_hash:passed_initial_hash
          ~initial_breadcrumb:prev_breadcrumb
          transitions_with_initial_validation
      with
      | Ok result ->
          Deferred.Or_error.return (L (passed_initial_hash, result))
      | Error e ->
          List.map transitions_with_initial_validation
            ~f:Cached.invalidate_with_failure
          |> ignore ;
          Deferred.Or_error.fail e )

let garbage_collect_subtrees ~logger ~subtrees =
  List.iter subtrees ~f:(fun subtree ->
      Rose_tree.map subtree ~f:Cached.invalidate_with_failure |> ignore ) ;
  Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
    "garbage collected failed cached transitions"

let garbage_collect_lists ~logger ~lists =
  List.iter lists ~f:(fun breadcrumb ->
      Cached.invalidate_with_failure breadcrumb |> ignore ) ;
  Logger.trace logger ~module_:__MODULE__ ~location:__LOC__
    "garbage collected failed cached transitions"

let verify_transitions_and_build_breadcrumbs_in_chunks ~logger
    ~precomputed_values ~trust_system ~verifier ~frontier
    ~unprocessed_transition_cache ~transitions_chunks ~target_hash ~subtrees =
  let previous_list_of_breadcrumbs = ref [] in
  let previous_initial_hash = ref None in
  let previous_breadcrumb = ref None in
  let last_one_as_trees = ref [] in
  let modified_transitions_chunks =
    if List.length transitions_chunks = 0 then [[]] else transitions_chunks
  in
  let open Deferred.Or_error.Let_syntax in
  let%bind _ =
    Deferred.Or_error.List.foldi modified_transitions_chunks ~init:[]
      ~f:(fun index acc transitions_chunk ->
        let current_subtrees =
          if index <> List.length modified_transitions_chunks - 1 then None
          else Some subtrees
        in
        let open Deferred.Let_syntax in
        match%bind
          verify_transitions_and_build_breadcrumbs ~logger ~precomputed_values
            ~trust_system ~verifier ~frontier ~unprocessed_transition_cache
            ~transitions:transitions_chunk ~target_hash
            ~prev_breadcrumb:!previous_breadcrumb
            ~prev_hash:!previous_initial_hash ~subtrees:current_subtrees
        with
        | Ok (T (initial_hash, trees_of_breadcrumbs)) ->
            previous_initial_hash := Some initial_hash ;
            last_one_as_trees := trees_of_breadcrumbs ;
            Deferred.Or_error.return (T trees_of_breadcrumbs :: acc)
        | Ok (L (initial_hash, list_of_breadcrumbs)) ->
            previous_initial_hash := Some initial_hash ;
            previous_list_of_breadcrumbs :=
              List.rev list_of_breadcrumbs :: !previous_list_of_breadcrumbs ;
            (previous_breadcrumb :=
               match List.nth list_of_breadcrumbs 0 with
               | Some breadcrumb_cache ->
                   Some (Cached.peek breadcrumb_cache)
               | None ->
                   None) ;
            Deferred.Or_error.return (L list_of_breadcrumbs :: acc)
        | Error e ->
            List.map !previous_list_of_breadcrumbs ~f:(fun lists ->
                garbage_collect_lists ~logger ~lists )
            |> ignore ;
            Deferred.Or_error.fail e )
  in
  Option.fold
    (Non_empty_list.of_list_opt
       (List.concat (List.rev !previous_list_of_breadcrumbs)))
    ~init:!last_one_as_trees
    ~f:(fun _ breadcrumbs ->
      [Rose_tree.of_non_empty_list ~subtrees:!last_one_as_trees breadcrumbs] )
  |> Deferred.Or_error.return

let run ~logger ~precomputed_values ~trust_system ~verifier ~network ~frontier
    ~catchup_job_reader
    ~(catchup_breadcrumbs_writer :
       ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t Rose_tree.t
         list
         * [`Ledger_catchup of unit Ivar.t | `Catchup_scheduler]
       , Strict_pipe.crash Strict_pipe.buffered
       , unit )
       Strict_pipe.Writer.t) ~unprocessed_transition_cache : unit =
  let num_peers = 8 in
  let maximum_download_size = 100 in
  don't_wait_for
    (Strict_pipe.Reader.iter_without_pushback catchup_job_reader
       ~f:(fun (target_hash, subtrees) ->
         don't_wait_for
           (let start_time = Core.Time.now () in
            let%bind () = Catchup_jobs.incr () in
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
              let%bind transitions_chunks =
                if num_of_missing_transitions <= 0 then
                  Deferred.Or_error.return []
                else
                  download_transitions_in_chunks ~logger ~trust_system ~network
                    ~num_peers ~preferred_peer ~maximum_download_size
                    ~hashes_of_missing_transitions
              in
              verify_transitions_and_build_breadcrumbs_in_chunks ~logger
                ~precomputed_values ~trust_system ~verifier ~frontier
                ~unprocessed_transition_cache ~transitions_chunks ~target_hash
                ~subtrees
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
                  garbage_collect_subtrees ~logger
                    ~subtrees:trees_of_breadcrumbs ;
                  Coda_metrics.(
                    Gauge.set Transition_frontier_controller.catchup_time_ms
                      Core.Time.(Span.to_ms @@ diff (now ()) start_time)) ;
                  Catchup_jobs.decr () )
                else
                  let ivar = Ivar.create () in
                  Strict_pipe.Writer.write catchup_breadcrumbs_writer
                    (trees_of_breadcrumbs, `Ledger_catchup ivar) ;
                  let%bind () = Ivar.read ivar in
                  Coda_metrics.(
                    Gauge.set Transition_frontier_controller.catchup_time_ms
                      Core.Time.(Span.to_ms @@ diff (now ()) start_time)) ;
                  Catchup_jobs.decr ()
            | Error e ->
                Logger.warn logger ~module_:__MODULE__ ~location:__LOC__
                  ~metadata:[("error", `String (Error.to_string_hum e))]
                  "Catchup process failed -- unable to receive valid data \
                   from peers or transition frontier progressed faster than \
                   catchup data received. See error for details: $error" ;
                garbage_collect_subtrees ~logger ~subtrees ;
                Coda_metrics.(
                  Gauge.set Transition_frontier_controller.catchup_time_ms
                    Core.Time.(Span.to_ms @@ diff (now ()) start_time)) ;
                Catchup_jobs.decr ()) ))

let%test_module "Ledger_catchup tests" =
  ( module struct
    let () =
      Core.Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    let max_frontier_length = 10

    let logger = Logger.null ()

    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    let proof_level = precomputed_values.proof_level

    let trust_system = Trust_system.null ()

    let time_controller = Block_time.Controller.basic ~logger

    let downcast_transition transition =
      let transition =
        transition
        |> External_transition.Validation
           .reset_frontier_dependencies_validation
        |> External_transition.Validation.reset_staged_ledger_diff_validation
      in
      Envelope.Incoming.wrap ~data:transition ~sender:Envelope.Sender.Local

    let downcast_breadcrumb breadcrumb =
      downcast_transition
        (Transition_frontier.Breadcrumb.validated_transition breadcrumb)

    type catchup_test =
      { cache: Transition_handler.Unprocessed_transition_cache.t
      ; job_writer:
          ( State_hash.t
            * ( External_transition.Initial_validated.t Envelope.Incoming.t
              , State_hash.t )
              Cached.t
              Rose_tree.t
              list
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
      ; breadcrumbs_reader:
          ( (Transition_frontier.Breadcrumb.t, State_hash.t) Cached.t
            Rose_tree.t
            list
          * [`Catchup_scheduler | `Ledger_catchup of unit Ivar.t] )
          Strict_pipe.Reader.t }

    let run_catchup ~network ~frontier =
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
          (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Transition_handler.Unprocessed_transition_cache.create ~logger
      in
      let pids = Child_processes.Termination.create_pid_table () in
      let%map verifier =
        Verifier.create ~logger ~proof_level ~conf_dir:None ~pids
      in
      run ~logger ~precomputed_values ~verifier ~trust_system ~network
        ~frontier ~catchup_breadcrumbs_writer ~catchup_job_reader
        ~unprocessed_transition_cache ;
      { cache= unprocessed_transition_cache
      ; job_writer= catchup_job_writer
      ; breadcrumbs_reader= catchup_breadcrumbs_reader }

    let run_catchup_with_target ~network ~frontier ~target_breadcrumb =
      let%map test = run_catchup ~network ~frontier in
      let parent_hash =
        Transition_frontier.Breadcrumb.parent_hash target_breadcrumb
      in
      let target_transition =
        Transition_handler.Unprocessed_transition_cache.register_exn test.cache
          (downcast_breadcrumb target_breadcrumb)
      in
      Strict_pipe.Writer.write test.job_writer
        (parent_hash, [Rose_tree.T (target_transition, [])]) ;
      (`Test test, `Cached_transition target_transition)

    let test_successful_catchup ~my_net ~target_best_tip_path =
      let open Fake_network in
      let target_breadcrumb = List.last_exn target_best_tip_path in
      let%bind `Test {breadcrumbs_reader; _}, _ =
        run_catchup_with_target ~network:my_net.network
          ~frontier:my_net.state.frontier ~target_breadcrumb
      in
      (* TODO: expose Strict_pipe.read *)
      let%map cached_catchup_breadcrumbs =
        Block_time.Timeout.await_exn time_controller
          ~timeout_duration:(Block_time.Span.of_ms 30000L)
          ( match%map Strict_pipe.Reader.read breadcrumbs_reader with
          | `Eof ->
              (* Core.printf "unexpected EOF\n%!" ; *)
              failwith "unexpected EOF"
          | `Ok (_, `Catchup_scheduler) ->
              (* Core.printf "did not expect a catchup scheduler action\n%!" ; *)
              failwith "did not expect a catchup scheduler action"
          | `Ok (breadcrumbs, `Ledger_catchup ivar) ->
              (* Core.printf "success on first timeout error\n%!" ; *)
              Ivar.fill ivar () ; List.hd_exn breadcrumbs )
      in
      let catchup_breadcrumbs =
        Rose_tree.map cached_catchup_breadcrumbs
          ~f:Cache_lib.Cached.invalidate_with_success
      in
      [%test_result: int]
        ~message:
          "Transition_frontier should not have any more catchup jobs at the \
           end of the test"
        ~equal:( = ) ~expect:0
        (Broadcast_pipe.Reader.peek Catchup_jobs.reader) ;
      let catchup_breadcrumbs_are_best_tip_path =
        Rose_tree.equal (Rose_tree.of_list_exn target_best_tip_path)
          catchup_breadcrumbs ~f:(fun breadcrumb_tree1 breadcrumb_tree2 ->
            External_transition.Validated.equal
              (Transition_frontier.Breadcrumb.validated_transition
                 breadcrumb_tree1)
              (Transition_frontier.Breadcrumb.validated_transition
                 breadcrumb_tree2) )
      in
      if not catchup_breadcrumbs_are_best_tip_path then
        failwith
          "catchup breadcrumbs were not equal to the best tip path we expected"

    let%test_unit "can catchup to a peer within [2/k,k]" =
      Quickcheck.test ~trials:5
        Fake_network.Generator.(
          let open Quickcheck.Generator.Let_syntax in
          let%bind peer_branch_size =
            Int.gen_incl (max_frontier_length / 2) (max_frontier_length - 1)
          in
          gen ~precomputed_values ~max_frontier_length
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:peer_branch_size ])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          (* TODO: I don't think I'm testing this right... *)
          let target_best_tip_path =
            Transition_frontier.(
              path_map ~f:Fn.id peer_net.state.frontier
                (best_tip peer_net.state.frontier))
          in
          Thread_safe.block_on_async_exn (fun () ->
              test_successful_catchup ~my_net ~target_best_tip_path ) )

    let%test_unit "catchup succeeds even if the parent transition is already \
                   in the frontier" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~max_frontier_length
            [fresh_peer; peer_with_branch ~frontier_branch_size:1])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          let target_best_tip_path =
            [Transition_frontier.best_tip peer_net.state.frontier]
          in
          Thread_safe.block_on_async_exn (fun () ->
              test_successful_catchup ~my_net ~target_best_tip_path ) )

    let%test_unit "catchup fails if one of the parent transitions fail" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~precomputed_values ~max_frontier_length
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:(max_frontier_length * 2)
            ])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          let target_breadcrumb =
            Transition_frontier.best_tip peer_net.state.frontier
          in
          let failing_transition =
            let open Transition_frontier.Extensions in
            let history =
              get_extension
                (Transition_frontier.extensions peer_net.state.frontier)
                Root_history
            in
            let failing_root_data =
              List.nth_exn (Root_history.to_list history) 1
            in
            downcast_transition
              (Frontier_base.Root_data.Historical.transition failing_root_data)
          in
          Thread_safe.block_on_async_exn (fun () ->
              let%bind `Test {cache; _}, `Cached_transition cached_transition =
                run_catchup_with_target ~network:my_net.network
                  ~frontier:my_net.state.frontier ~target_breadcrumb
              in
              let cached_failing_transition =
                Transition_handler.Unprocessed_transition_cache.register_exn
                  cache failing_transition
              in
              let%bind () = after (Core.Time.Span.of_sec 1.) in
              ignore
                (Cache_lib.Cached.invalidate_with_failure
                   cached_failing_transition) ;
              let%map result =
                Block_time.Timeout.await_exn time_controller
                  ~timeout_duration:(Block_time.Span.of_ms 10000L)
                  (Ivar.read (Cache_lib.Cached.final_state cached_transition))
              in
              if result <> `Failed then
                failwith "expected ledger catchup to fail, but it succeeded" )
          )

    (* TODO: fix and re-enable *)
    (*
    let%test_unit "catchup won't be blocked by transitions that are still being processed" =
      Quickcheck.test ~trials:1
        Fake_network.Generator.(
          gen ~max_frontier_length
            [ fresh_peer
            ; peer_with_branch ~frontier_branch_size:(max_frontier_length-1) ])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          Core.Printf.printf "$my_net.state.frontier.root = %s\n"
            (State_hash.to_base58_check @@ Transition_frontier.(Breadcrumb.state_hash @@ root my_net.state.frontier));
          Core.Printf.printf "$peer_net.state.frontier.root = %s\n"
            (State_hash.to_base58_check @@ Transition_frontier.(Breadcrumb.state_hash @@ root my_net.state.frontier));
          let missing_breadcrumbs =
            let best_tip_path = Transition_frontier.best_tip_path peer_net.state.frontier in
            Core.Printf.printf "$best_tip_path=\n  %s\n"
              (String.concat ~sep:"\n  " @@ List.map ~f:(Fn.compose State_hash.to_base58_check Transition_frontier.Breadcrumb.state_hash) best_tip_path);
            (* List.take best_tip_path (List.length best_tip_path - 1) *)
            best_tip_path
          in
          Async.Thread_safe.block_on_async_exn (fun () ->
            let%bind {cache; job_writer; breadcrumbs_reader} = run_catchup ~network:my_net.network ~frontier:my_net.state.frontier in
            let jobs =
              List.map (List.rev missing_breadcrumbs) ~f:(fun breadcrumb ->
                let parent_hash = Transition_frontier.Breadcrumb.parent_hash breadcrumb in
                let cached_transition =
                  Transition_handler.Unprocessed_transition_cache.register_exn cache
                    (downcast_breadcrumb breadcrumb)
                in
                Core.Printf.printf "$job = %s --> %s\n"
                  (State_hash.to_base58_check @@ External_transition.Initial_validated.state_hash @@ Envelope.Incoming.data @@ Cached.peek cached_transition)
                  (State_hash.to_base58_check parent_hash);
                (parent_hash, [Rose_tree.T (cached_transition, [])]))
            in
            let%bind () = after (Core.Time.Span.of_ms 500.) in
            List.iter jobs ~f:(Strict_pipe.Writer.write job_writer);
            match%map
              Block_time.Timeout.await_exn time_controller
                ~timeout_duration:(Block_time.Span.of_ms 15000L)
                (Strict_pipe.Reader.fold_until breadcrumbs_reader ~init:missing_breadcrumbs ~f:(fun remaining_breadcrumbs (rose_trees, catchup_signal) ->
                  let[@warning "-8"] [rose_tree] = rose_trees in
                  let catchup_breadcrumb_tree = Rose_tree.map rose_tree ~f:Cached.invalidate_with_success in
                  Core.Printf.printf "!!!%d\n" (List.length @@ Rose_tree.flatten catchup_breadcrumb_tree);
                  let[@warning "-8"] [received_breadcrumb] = Rose_tree.flatten catchup_breadcrumb_tree in
                  match remaining_breadcrumbs with
                  | [] -> failwith "received more breadcrumbs than expected"
                  | expected_breadcrumb :: remaining_breadcrumbs' ->
                      Core.Printf.printf "COMPARING %s vs. %s..."
                        (State_hash.to_base58_check @@ Transition_frontier.Breadcrumb.state_hash expected_breadcrumb)
                        (State_hash.to_base58_check @@ Transition_frontier.Breadcrumb.state_hash received_breadcrumb);
                      [%test_eq: State_hash.t]
                        (Transition_frontier.Breadcrumb.state_hash expected_breadcrumb)
                        (Transition_frontier.Breadcrumb.state_hash received_breadcrumb)
                        ~message:"received breadcrumb state hash did not match expected breadcrumb state hash";
                      [%test_eq: Transition_frontier.Breadcrumb.t]
                        expected_breadcrumb
                        received_breadcrumb
                        ~message:"received breadcrumb matched expected state hash, but was not equal to expected breadcrumb";
                      ( match catchup_signal with
                      | `Catchup_scheduler ->
                          failwith "Did not expect a catchup scheduler action"
                      | `Ledger_catchup ivar ->
                          Ivar.fill ivar () ) ;
                      print_endline " ok";
                      if remaining_breadcrumbs' = [] then
                        return (`Stop ())
                      else
                        return (`Continue remaining_breadcrumbs')))
            with
            | `Eof _ -> failwith "unexpected EOF"
            | `Terminated () -> ()))
    *)
  end )
