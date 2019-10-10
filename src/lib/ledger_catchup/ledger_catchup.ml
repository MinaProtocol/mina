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

module Catchup_jobs = struct
  open Broadcast_pipe

  let reader, writer = create 0

  let update f = Writer.write writer (f (Reader.peek reader))

  let incr () = update (( + ) 1)

  let decr () = update (( - ) 1)
end

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
    @@ Transition_handler.Validator.validate_transition ~logger ~frontier
         ~unprocessed_transition_cache enveloped_initially_validated_transition
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

(* returns a list of state-hashes with the older ones at the front *)
let download_state_hashes ~logger ~trust_system ~network ~frontier ~num_peers
    ~target_hash =
  let peers = Coda_networking.random_peers network num_peers in
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

(* returns a list of transitions with old ones comes first *)
let download_transitions ~logger ~trust_system ~network ~num_peers
    ~preferred_peer ~maximum_download_size ~hashes_of_missing_transitions =
  let random_peers = Coda_networking.random_peers network num_peers in
  Deferred.Or_error.List.concat_map
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
                     ~sender:(Envelope.Sender.Remote peer.host) ) ) )

let verify_transitions_and_build_breadcrumbs ~logger ~trust_system ~verifier
    ~frontier ~unprocessed_transition_cache ~transitions ~target_hash ~subtrees
    =
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
            List.hd_exn transitions |> Envelope.Incoming.data |> With_hash.data
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
    Transition_handler.Breadcrumb_builder.build_subtrees_of_breadcrumbs ~logger
      ~verifier ~trust_system ~frontier ~initial_hash trees_of_transitions
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

let run ~logger ~trust_system ~verifier ~network ~frontier ~catchup_job_reader
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
              let%bind transitions =
                if num_of_missing_transitions <= 0 then
                  Deferred.Or_error.return []
                else
                  download_transitions ~logger ~trust_system ~network
                    ~num_peers ~preferred_peer ~maximum_download_size
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

    let trust_system = Trust_system.null ()

    let time_controller = Block_time.Controller.basic ~logger

    let downcast_breadcrumb breadcrumb =
      let transition =
        Transition_frontier.Breadcrumb.validated_transition breadcrumb
        |> External_transition.Validation
           .reset_frontier_dependencies_validation
        |> External_transition.Validation.reset_staged_ledger_diff_validation
      in
      Envelope.Incoming.wrap ~data:transition ~sender:Envelope.Sender.Local

    let test_catchup ~my_net ~target_best_tip_path =
      let open Fake_network in
      let target_best_tip = List.last_exn target_best_tip_path in
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
      let target_transition =
        Transition_handler.Unprocessed_transition_cache.register_exn
          unprocessed_transition_cache
          (downcast_breadcrumb target_best_tip)
      in
      let parent_hash =
        Transition_frontier.Breadcrumb.parent_hash target_best_tip
      in
      Strict_pipe.Writer.write catchup_job_writer
        (parent_hash, [Rose_tree.T (target_transition, [])]) ;
      let pids = Child_processes.Termination.create_pid_table () in
      let%bind verifier = Verifier.create ~logger ~pids in
      run ~logger ~verifier ~trust_system ~network:my_net.network
        ~frontier:my_net.frontier ~catchup_breadcrumbs_writer
        ~catchup_job_reader ~unprocessed_transition_cache ;
      let result_ivar = Ivar.create () in
      (* TODO: expose Strict_pipe.read *)
      Strict_pipe.Reader.iter catchup_breadcrumbs_reader ~f:(fun rose_tree ->
          Deferred.return @@ Ivar.fill result_ivar rose_tree )
      |> don't_wait_for ;
      let%map cached_catchup_breadcrumbs =
        match%map
          Block_time.Timeout.await time_controller
            ~timeout_duration:(Block_time.Span.of_ms 15000L)
            (let%map breadcrumbs, catchup_signal = Ivar.read result_ivar in
             ( match catchup_signal with
             | `Catchup_scheduler ->
                 failwith "Did not expect a catchup scheduler action"
             | `Ledger_catchup ivar ->
                 Ivar.fill ivar () ) ;
             List.hd_exn breadcrumbs)
        with
        | `Ok x ->
            x
        | `Timeout ->
            failwith "timed out waiting for catchup breadcrumbs"
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

    let%test_unit "catchup to a peer" =
      Quickcheck.test ~trials:1
        Fake_network.(
          gen ~max_frontier_length
            [ make_peer_config ~initial_frontier_size:0
            ; make_peer_config ~initial_frontier_size:(max_frontier_length / 2)
            ])
        ~f:(fun network ->
          let open Fake_network in
          let [my_net; peer_net] = network.peer_networks in
          let target_best_tip_path =
            Transition_frontier.(
              path_map ~f:Fn.id peer_net.frontier (best_tip peer_net.frontier))
          in
          Thread_safe.block_on_async_exn (fun () ->
              test_catchup ~my_net ~target_best_tip_path ) )

    (*
    let%test "peers can provide transitions with length between max_length to \
              2 * max_length" =
      let pids = Child_processes.Termination.create_pid_set () in
      heartbeat_flag := true ;
      Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let num_breadcrumbs =
            Int.gen_incl max_length (2 * max_length) |> Quickcheck.random_value
          in
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts ~num_breadcrumbs
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.validated_transition best_breadcrumb
          in
          let best_transition_enveloped =
            let transition =
              best_transition
              |> External_transition.Validation
                 .reset_frontier_dependencies_validation
              |> External_transition.Validation
                 .reset_staged_ledger_diff_validation
            in
            Envelope.Incoming.wrap ~data:transition
              ~sender:Envelope.Sender.Local
          in
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            ~metadata:
              [ ( "state_hash"
                , State_hash.to_yojson
                    (External_transition.Validated.state_hash best_transition)
                ) ]
            "Best transition of peer: $state_hash" ;
          let history =
            Transition_frontier.root_history_path_map peer.frontier
              (External_transition.Validated.state_hash best_transition)
              ~f:Fn.id
            |> Option.value_exn
          in
          let%map res =
            test_catchup ~logger ~pids ~trust_system ~network me
              best_transition_enveloped
              (Rose_tree.of_list_exn @@ Non_empty_list.tail history)
          in
          heartbeat_flag := false ;
          res )

    let%test "catchup would be successful even if the parent transition is \
              already in the frontier" =
      let pids = Child_processes.Termination.create_pid_set () in
      heartbeat_flag := true ;
      Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts ~num_breadcrumbs:1
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.validated_transition best_breadcrumb
          in
          let%map res =
            test_catchup ~logger ~pids ~trust_system ~network me
              (let transition =
                 best_transition
                 |> External_transition.Validation
                    .reset_frontier_dependencies_validation
                 |> External_transition.Validation
                    .reset_staged_ledger_diff_validation
               in
               Envelope.Incoming.wrap ~data:transition
                 ~sender:Envelope.Sender.Local)
              (Rose_tree.of_list_exn [best_breadcrumb])
          in
          heartbeat_flag := false ;
          res )

    let%test "catchup would fail if one of the parent transition fails" =
      let pids = Child_processes.Termination.create_pid_set () in
      heartbeat_flag := true ;
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Crash))
      in
      let _catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Transition_handler.Unprocessed_transition_cache.create ~logger
      in
      Thread_safe.block_on_async_exn (fun () ->
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts
              ~num_breadcrumbs:max_length
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.validated_transition best_breadcrumb
          in
          let history =
            Transition_frontier.root_history_path_map peer.frontier
              (External_transition.Validated.state_hash best_transition)
              ~f:Fn.id
            |> Option.value_exn
          in
          let missing_breadcrumbs = Non_empty_list.tail history in
          let missing_transitions =
            List.map missing_breadcrumbs
              ~f:Transition_frontier.Breadcrumb.validated_transition
          in
          let cached_best_transition =
            Transition_handler.Unprocessed_transition_cache.register_exn
              unprocessed_transition_cache
              (let transition =
                 best_transition
                 |> External_transition.Validation
                    .reset_frontier_dependencies_validation
                 |> External_transition.Validation
                    .reset_staged_ledger_diff_validation
               in
               Envelope.Incoming.wrap ~data:transition
                 ~sender:Envelope.Sender.Local)
          in
          let parent_hash =
            External_transition.Validated.parent_hash best_transition
          in
          Strict_pipe.Writer.write catchup_job_writer
            (parent_hash, [Rose_tree.T (cached_best_transition, [])]) ;
          let failing_transition = List.nth_exn missing_transitions 1 in
          let cached_failing_transition =
            Transition_handler.Unprocessed_transition_cache.register_exn
              unprocessed_transition_cache
              (let transition =
                 failing_transition
                 |> External_transition.Validation
                    .reset_frontier_dependencies_validation
                 |> External_transition.Validation
                    .reset_staged_ledger_diff_validation
               in
               Envelope.Incoming.wrap ~data:transition
                 ~sender:Envelope.Sender.Local)
          in
          let%bind run = run_ledger_catchup ~logger ~pids in
          run ~logger ~trust_system ~network ~frontier:me
            ~catchup_breadcrumbs_writer ~catchup_job_reader
            ~unprocessed_transition_cache ;
          let%bind () = after (Core.Time.Span.of_sec 1.) in
          Cache_lib.Cached.invalidate_with_failure cached_failing_transition
          |> ignore ;
          let%map result =
            Ivar.read (Cache_lib.Cached.final_state cached_best_transition)
          in
          heartbeat_flag := false ;
          result = `Failed )

    let%test_unit "catchup won't be blocked by transitions that are still \
                   under processing" =
      let pids = Child_processes.Termination.create_pid_set () in
      heartbeat_flag := true ;
      let catchup_job_reader, catchup_job_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Crash))
      in
      let catchup_breadcrumbs_reader, catchup_breadcrumbs_writer =
        Strict_pipe.create (Buffered (`Capacity 10, `Overflow Crash))
      in
      let unprocessed_transition_cache =
        Transition_handler.Unprocessed_transition_cache.create ~logger
      in
      Thread_safe.block_on_async_exn (fun () ->
          let open Deferred.Let_syntax in
          print_heartbeat hb_logger |> don't_wait_for ;
          let%bind me, peer, network =
            Network_builder.setup_me_and_a_peer
              ~source_accounts:Genesis_ledger.accounts ~logger ~pids
              ~trust_system ~target_accounts:Genesis_ledger.accounts
              ~num_breadcrumbs:max_length
          in
          let best_breadcrumb = Transition_frontier.best_tip peer.frontier in
          let best_transition =
            Transition_frontier.Breadcrumb.validated_transition best_breadcrumb
          in
          let history =
            Transition_frontier.root_history_path_map peer.frontier
              (External_transition.Validated.state_hash best_transition)
              ~f:Fn.id
            |> Option.value_exn
          in
          let missing_breadcrumbs = Non_empty_list.tail history in
          Logger.trace logger !"Breadcrumbs to process"
            ~metadata:
              [ ( "Breadcrumbs"
                , `List
                    (List.map
                       ~f:
                         (Fn.compose State_hash.to_yojson
                            Transition_frontier.Breadcrumb.state_hash)
                       missing_breadcrumbs) ) ]
            ~location:__LOC__ ~module_:__MODULE__ ;
          let missing_transitions =
            List.map missing_breadcrumbs
              ~f:Transition_frontier.Breadcrumb.validated_transition
            |> List.rev
          in
          let last_breadcrumb = List.last_exn missing_breadcrumbs in
          let parent_hashes =
            List.map missing_transitions
              ~f:External_transition.Validated.parent_hash
          in
          let cached_transitions =
            List.map missing_transitions ~f:(fun transition ->
                let transition =
                  transition
                  |> External_transition.Validation
                     .reset_frontier_dependencies_validation
                  |> External_transition.Validation
                     .reset_staged_ledger_diff_validation
                in
                Envelope.Incoming.wrap ~data:transition
                  ~sender:Envelope.Sender.Local
                |> Transition_handler.Unprocessed_transition_cache.register_exn
                     unprocessed_transition_cache )
          in
          let forests =
            List.map2_exn parent_hashes cached_transitions
              ~f:(fun parent_hash cached_transition ->
                (parent_hash, [Rose_tree.T (cached_transition, [])]) )
          in
          List.iter forests ~f:(fun forest ->
              Deferred.upon
                (after (Core.Time.Span.of_ms 500.))
                (fun () -> Strict_pipe.Writer.write catchup_job_writer forest)
          ) ;
          let%bind run = run_ledger_catchup ~logger ~pids in
          run ~logger ~trust_system ~network ~frontier:me
            ~catchup_breadcrumbs_writer ~catchup_job_reader
            ~unprocessed_transition_cache ;
          let missing_breadcrumbs_queue =
            List.map missing_breadcrumbs ~f:(fun breadcrumb ->
                Rose_tree.T (breadcrumb, []) )
            |> Queue.of_list
          in
          let finished = Ivar.create () in
          Strict_pipe.Reader.iter catchup_breadcrumbs_reader
            ~f:(fun (rose_trees, catchup_signal) ->
              let catchup_breadcrumb_tree =
                Rose_tree.map (List.hd_exn rose_trees)
                  ~f:Cache_lib.Cached.invalidate_with_success
              in
              Logger.info logger
                !"Breadcrumbs that got processed"
                ~module_:__MODULE__ ~location:__LOC__
                ~metadata:
                  [ ( "rose_tree"
                    , Rose_tree.to_yojson State_hash.to_yojson
                        (Rose_tree.map catchup_breadcrumb_tree
                           ~f:Transition_frontier.Breadcrumb.state_hash) ) ] ;
              assert (
                List.length (Rose_tree.flatten catchup_breadcrumb_tree) = 1 ) ;
              let catchup_breadcrumb =
                List.hd_exn (Rose_tree.flatten catchup_breadcrumb_tree)
              in
              let expected_breadcrumb =
                List.hd_exn @@ Rose_tree.flatten
                @@ Queue.dequeue_exn missing_breadcrumbs_queue
              in
              assert (
                Transition_frontier.Breadcrumb.equal expected_breadcrumb
                  catchup_breadcrumb ) ;
              Transition_frontier.add_breadcrumb_exn me expected_breadcrumb
              |> ignore ;
              ( match catchup_signal with
              | `Catchup_scheduler ->
                  failwith "Did not expect a catchup scheduler action"
              | `Ledger_catchup ivar ->
                  Ivar.fill ivar () ) ;
              if
                Transition_frontier.Breadcrumb.equal expected_breadcrumb
                  last_breadcrumb
              then Ivar.fill finished () ;
              Deferred.unit )
          |> don't_wait_for ;
          let%bind () = Ivar.read finished in
          let%map () = Async.Scheduler.yield_until_no_jobs_remain () in
          heartbeat_flag := false ;
          assert_catchup_jobs_are_flushed me )
  *)
  end )
