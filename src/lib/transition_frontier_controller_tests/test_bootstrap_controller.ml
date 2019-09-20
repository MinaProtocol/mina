open Core
open Async
open Coda_base
open Coda_transition

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs

module Hash = struct
  include Ledger_hash

  let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

  let empty_account = hash_account Account.empty
end

module Root_sync_ledger = Sync_ledger.Db

module Bootstrap_controller = Bootstrap_controller.Make (struct
  include Transition_frontier_inputs
  module Transition_frontier = Transition_frontier
  module Merkle_address = Ledger.Db.Addr
  module Root_sync_ledger = Sync_ledger.Db
  module Network = Network
  module Time = Time
  module Sync_handler = Sync_handler
end)

let%test_module "Bootstrap Controller" =
  ( module struct
    let f_with_verifier ~f ~logger ~pids ~trust_system =
      let%map verifier = Verifier.create ~logger ~pids in
      f ~logger ~trust_system ~verifier

    let%test "`bootstrap_controller` caches all transitions it is passed \
              through the `transition_reader` pipe" =
      let transition_graph =
        Bootstrap_controller.For_tests.Transition_cache.create ()
      in
      let num_breadcrumbs = (Transition_frontier.max_length * 2) + 2 in
      let logger = Logger.null () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let network =
        Network.create_stub ~logger
          ~ip_table:(Hashtbl.create (module Unix.Inet_addr))
          ~peers:(Hash_set.create (module Network_peer.Peer) ())
      in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier =
            create_root_frontier ~logger ~pids Genesis_ledger.accounts
          in
          let genesis_root =
            Transition_frontier.root frontier
            |> Transition_frontier.Breadcrumb.validated_transition
          in
          let%bind make_bootstrap =
            f_with_verifier ~f:Bootstrap_controller.For_tests.make_bootstrap
              ~logger ~pids ~trust_system
          in
          let bootstrap = make_bootstrap ~genesis_root ~network in
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger frontier
          in
          let root_sync_ledger =
            Root_sync_ledger.create ledger_db ~logger ~trust_system
          in
          let parent_breadcrumb = Transition_frontier.best_tip frontier in
          let breadcrumbs_gen =
            gen_linear_breadcrumbs ~logger ~pids ~trust_system
              ~size:num_breadcrumbs
              ~accounts_with_secret_keys:Genesis_ledger.accounts
              parent_breadcrumb
            |> Quickcheck.Generator.with_size ~size:num_breadcrumbs
          in
          let%bind breadcrumbs =
            Deferred.all @@ Quickcheck.random_value breadcrumbs_gen
          in
          let input_transitions =
            List.map
              ~f:(fun breadcrumb ->
                Transition_frontier.Breadcrumb.validated_transition breadcrumb
                |> External_transition.Validation
                   .reset_frontier_dependencies_validation
                |> External_transition.Validation
                   .reset_staged_ledger_diff_validation )
              breadcrumbs
          in
          let envelopes =
            List.map
            (* in order to properly exercise this test code we need to make
             * these envelopes remote *)
              ~f:(fun x ->
                Envelope.Incoming.wrap ~data:x
                  ~sender:(Envelope.Sender.Remote Network_peer.Peer.local.host)
                )
              input_transitions
          in
          let sync_ledger_reader, sync_ledger_writer =
            Pipe_lib.Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
              Synchronous
          in
          let () =
            List.iter
              ~f:(fun x ->
                Pipe_lib.Strict_pipe.Writer.write sync_ledger_writer x
                |> don't_wait_for )
              (List.zip_exn
                 (List.map ~f:(fun e -> `Transition e) envelopes)
                 (List.map
                    ~f:(fun t -> `Time_received t)
                    (List.init num_breadcrumbs ~f:Fn.id)))
          in
          let run_sync =
            Bootstrap_controller.For_tests.sync_ledger bootstrap
              ~root_sync_ledger ~transition_graph ~sync_ledger_reader
          in
          let () = Pipe_lib.Strict_pipe.Writer.close sync_ledger_writer in
          let%map () = run_sync in
          let saved_transitions =
            Bootstrap_controller.For_tests.Transition_cache.data
              transition_graph
            |> List.map ~f:(fun enveloped_transition ->
                   Envelope.Incoming.data enveloped_transition
                   |> fst |> With_hash.data )
          in
          External_transition.Set.(
            equal
              (of_list
                 (List.map ~f:(Fn.compose With_hash.data fst) input_transitions))
              (of_list saved_transitions)) )

    let is_syncing = function
      | `Ignored ->
          false
      | `Syncing_new_snarked_ledger ->
          true
      | `Updating_root_transition ->
          false

    let make_transition_pipe () =
      Pipe_lib.Strict_pipe.create ~name:(__MODULE__ ^ __LOC__)
        (Buffered (`Capacity 10, `Overflow Drop_head))

    let get_best_tip_hash (peer : Network_builder.peer_with_frontier) =
      Transition_frontier.best_tip peer.frontier
      |> Transition_frontier.Breadcrumb.state_hash

    let root_hash =
      Fn.compose Ledger.Db.merkle_root
        Transition_frontier.For_tests.root_snarked_ledger

    let%test_unit "reconstruct staged_ledgers using \
                   of_scan_state_and_snarked_ledger" =
      let logger = Logger.null () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let num_breadcrumbs = 10 in
      let accounts = Genesis_ledger.accounts in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~logger ~pids accounts in
          let%bind () =
            build_frontier_randomly frontier
              ~gen_root_breadcrumb_builder:
                (gen_linear_breadcrumbs ~logger ~pids ~trust_system
                   ~size:num_breadcrumbs ~accounts_with_secret_keys:accounts)
          in
          Deferred.List.iter (Transition_frontier.all_breadcrumbs frontier)
            ~f:(fun breadcrumb ->
              let staged_ledger =
                Transition_frontier.Breadcrumb.staged_ledger breadcrumb
              in
              let expected_merkle_root =
                Staged_ledger.ledger staged_ledger |> Ledger.merkle_root
              in
              let snarked_ledger =
                Transition_frontier.shallow_copy_root_snarked_ledger frontier
              in
              let scan_state = Staged_ledger.scan_state staged_ledger in
              let pending_coinbases =
                Staged_ledger.pending_coinbase_collection staged_ledger
              in
              let%bind verifier = Verifier.create ~logger ~pids in
              let%map actual_staged_ledger =
                Staged_ledger
                .of_scan_state_pending_coinbases_and_snarked_ledger ~scan_state
                  ~logger ~verifier ~snarked_ledger ~expected_merkle_root
                  ~pending_coinbases
                |> Deferred.Or_error.ok_exn
              in
              assert (
                Staged_ledger_hash.equal
                  (Staged_ledger.hash staged_ledger)
                  (Staged_ledger.hash actual_staged_ledger) ) ) )

    let assert_transitions_increasingly_sorted ~root
        (incoming_transitions :
          External_transition.Initial_validated.t Envelope.Incoming.t list) =
      let root =
        With_hash.data @@ fst
        @@ Transition_frontier.Breadcrumb.validated_transition root
      in
      let blockchain_length =
        Fn.compose Consensus.Data.Consensus_state.blockchain_length
          External_transition.consensus_state
      in
      List.fold_result ~init:root incoming_transitions
        ~f:(fun max_acc incoming_transition ->
          let With_hash.{data= transition; _}, _ =
            Envelope.Incoming.data incoming_transition
          in
          let open Result.Let_syntax in
          let%map () =
            Result.ok_if_true
              Coda_numbers.Length.(
                blockchain_length max_acc <= blockchain_length transition)
              ~error:
                (Error.of_string
                   "The blocks are not sorted in increasing order")
          in
          transition )
      |> Or_error.ok_exn |> ignore

    let%test "sync with one node after receiving a transition" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.null () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let num_breadcrumbs = 10 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind syncing_frontier, peer, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~num_breadcrumbs
              ~source_accounts:[List.hd_exn Genesis_ledger.accounts]
              ~target_accounts:Genesis_ledger.accounts
          in
          let transition_reader, transition_writer = make_transition_pipe () in
          let best_hash = get_best_tip_hash peer in
          Network_builder.send_transition ~logger ~transition_writer ~peer
            best_hash ;
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger syncing_frontier
          in
          let%bind run =
            f_with_verifier ~f:Bootstrap_controller.For_tests.run ~logger ~pids
              ~trust_system
          in
          let%map ( new_frontier
                  , (sorted_external_transitions :
                      External_transition.Initial_validated.t
                      Envelope.Incoming.t
                      list) ) =
            run ~network ~frontier:syncing_frontier ~ledger_db
              ~transition_reader ~should_ask_best_tip:false
          in
          assert_transitions_increasingly_sorted
            ~root:(Transition_frontier.root new_frontier)
            sorted_external_transitions ;
          Ledger_hash.equal (root_hash new_frontier) (root_hash peer.frontier)
      )

    let%test "sync with one node eagerly" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.create () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let num_breadcrumbs = (2 * max_length) + Consensus.Constants.delta + 2 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind syncing_frontier, peer, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~num_breadcrumbs
              ~source_accounts:[List.hd_exn Genesis_ledger.accounts]
              ~target_accounts:Genesis_ledger.accounts
          in
          let transition_reader, _ = make_transition_pipe () in
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger syncing_frontier
          in
          let%bind run =
            f_with_verifier ~f:Bootstrap_controller.For_tests.run ~logger ~pids
              ~trust_system
          in
          let%map ( new_frontier
                  , (sorted_transitions :
                      External_transition.Initial_validated.t
                      Envelope.Incoming.t
                      list) ) =
            run ~network ~frontier:syncing_frontier ~ledger_db
              ~transition_reader ~should_ask_best_tip:true
          in
          let root = Transition_frontier.(root new_frontier) in
          assert_transitions_increasingly_sorted ~root sorted_transitions ;
          Ledger_hash.equal (root_hash new_frontier) (root_hash peer.frontier)
      )

    let%test "when eagerly syncing to multiple nodes, you should sync to the \
              node with the highest transition_frontier" =
      let logger = Logger.create () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let unsynced_peer_num_breadcrumbs = 6 in
      let unsynced_peers_accounts =
        List.take Genesis_ledger.accounts
          (List.length Genesis_ledger.accounts / 2)
      in
      let synced_peer_num_breadcrumbs = unsynced_peer_num_breadcrumbs * 2 in
      let source_accounts = [List.hd_exn Genesis_ledger.accounts] in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind {me; peers; network} =
            Network_builder.setup ~source_accounts ~logger ~pids ~trust_system
              [ { num_breadcrumbs= unsynced_peer_num_breadcrumbs
                ; accounts= unsynced_peers_accounts }
              ; { num_breadcrumbs= synced_peer_num_breadcrumbs
                ; accounts= Genesis_ledger.accounts } ]
          in
          let transition_reader, _ = make_transition_pipe () in
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger me
          in
          let synced_peer = List.nth_exn peers 1 in
          let%bind run =
            f_with_verifier ~f:Bootstrap_controller.For_tests.run ~logger ~pids
              ~trust_system
          in
          let%map ( new_frontier
                  , (sorted_external_transitions :
                      External_transition.Initial_validated.t
                      Envelope.Incoming.t
                      list) ) =
            run ~network ~frontier:me ~ledger_db ~transition_reader
              ~should_ask_best_tip:true
          in
          assert_transitions_increasingly_sorted
            ~root:(Transition_frontier.root new_frontier)
            sorted_external_transitions ;
          Ledger_hash.equal (root_hash new_frontier)
            (root_hash synced_peer.frontier) )

    let%test "if we see a new transition that is better than the transition \
              that we are syncing from, than we should retarget our root" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.null () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let small_peer_num_breadcrumbs = 6 in
      let large_peer_num_breadcrumbs = small_peer_num_breadcrumbs * 2 in
      let source_accounts = [List.hd_exn Genesis_ledger.accounts] in
      let small_peer_accounts =
        List.take Genesis_ledger.accounts
          (List.length Genesis_ledger.accounts / 2)
      in
      Thread_safe.block_on_async_exn (fun () ->
          let large_peer_accounts = Genesis_ledger.accounts in
          let%bind {me; peers; network} =
            Network_builder.setup ~source_accounts ~logger ~pids ~trust_system
              [ { num_breadcrumbs= small_peer_num_breadcrumbs
                ; accounts= small_peer_accounts }
              ; { num_breadcrumbs= large_peer_num_breadcrumbs
                ; accounts= large_peer_accounts } ]
          in
          let transition_reader, transition_writer = make_transition_pipe () in
          let small_peer, large_peer =
            (List.nth_exn peers 0, List.nth_exn peers 1)
          in
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger me
          in
          Network_builder.send_transition ~logger ~transition_writer
            ~peer:small_peer
            (get_best_tip_hash small_peer) ;
          (* Have a bit of delay when sending the more recent transition *)
          let%bind () =
            after (Core.Time.Span.of_sec 1.0)
            >>| fun () ->
            Network_builder.send_transition ~logger ~transition_writer
              ~peer:large_peer
              (get_best_tip_hash large_peer)
          in
          let%bind run =
            f_with_verifier ~f:Bootstrap_controller.For_tests.run ~logger ~pids
              ~trust_system
          in
          let%map ( new_frontier
                  , (sorted_external_transitions :
                      External_transition.Initial_validated.t
                      Envelope.Incoming.t
                      list) ) =
            run ~network ~frontier:me ~ledger_db ~transition_reader
              ~should_ask_best_tip:false
          in
          assert_transitions_increasingly_sorted
            ~root:(Transition_frontier.root new_frontier)
            sorted_external_transitions ;
          Ledger_hash.equal (root_hash new_frontier)
            (root_hash large_peer.frontier) )

    let%test "`on_transition` should deny outdated transitions" =
      let logger = Logger.null () in
      let pids = Child_processes.Termination.create_pid_set () in
      let trust_system = Trust_system.null () in
      let num_breadcrumbs = 10 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind syncing_frontier, peer_with_frontier, network =
            Network_builder.setup_me_and_a_peer ~logger ~pids ~trust_system
              ~num_breadcrumbs ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts
          in
          let root_sync_ledger =
            Root_sync_ledger.create
              (Transition_frontier.For_tests.root_snarked_ledger
                 syncing_frontier)
              ~logger ~trust_system
          in
          let query_reader = Root_sync_ledger.query_reader root_sync_ledger in
          let response_writer =
            Root_sync_ledger.answer_writer root_sync_ledger
          in
          Network.glue_sync_ledger network query_reader response_writer ;
          let genesis_root =
            Transition_frontier.root syncing_frontier
            |> Transition_frontier.Breadcrumb.validated_transition
          in
          let open Bootstrap_controller.For_tests in
          let%bind make =
            f_with_verifier ~f:make_bootstrap ~logger ~pids ~trust_system
          in
          let bootstrap = make ~genesis_root ~network in
          let best_transition =
            Transition_frontier.best_tip peer_with_frontier.frontier
            |> Transition_frontier.Breadcrumb.validated_transition
            |> External_transition.Validation.forget_validation
          in
          let%bind should_sync =
            Bootstrap_controller.For_tests.on_transition bootstrap
              ~root_sync_ledger ~sender:peer_with_frontier.peer.host
              best_transition
          in
          assert (is_syncing should_sync) ;
          let outdated_transition =
            Transition_frontier.root peer_with_frontier.frontier
            |> Transition_frontier.Breadcrumb.validated_transition
            |> External_transition.Validation.forget_validation
          in
          let%map should_not_sync =
            Bootstrap_controller.For_tests.on_transition bootstrap
              ~root_sync_ledger ~sender:peer_with_frontier.peer.host
              outdated_transition
          in
          should_not_sync = `Ignored )
  end )
