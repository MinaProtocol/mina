open Core
open Async
open Coda_base

module Stubs = Stubs.Make (struct
  let max_length = 4
end)

open Stubs
open Signature_lib

module Root_sync_ledger =
  Syncable_ledger.Make (Ledger.Db.Addr) (Account)
    (struct
      include Ledger_hash

      let hash_account = Fn.compose Ledger_hash.of_digest Account.digest

      let empty_account = hash_account Account.empty
    end)
    (struct
      include Ledger_hash

      let to_hash (h : t) =
        Ledger_hash.of_digest (h :> Snark_params.Tick.Pedersen.Digest.t)
    end)
    (struct
      include Ledger.Db
    end)
    (struct
      let subtree_height = 3
    end)

module Bootstrap_controller = Bootstrap_controller.Make (struct
  include Transition_frontier_inputs
  module Transition_frontier = Transition_frontier
  module Merkle_address = Ledger.Db.Addr
  module Root_sync_ledger = Root_sync_ledger
  module Network = Network
  module Time = Time
  module Protocol_state_validator = Protocol_state_validator
  module Sync_handler = Sync_handler
  module Root_prover = Root_prover
end)

let%test_module "Bootstrap Controller" =
  ( module struct
    type peer_config =
      { num_breadcrumbs: int
      ; accounts: (Private_key.t option * Account.Stable.Latest.t) list }

    type peer = {address: Network_peer.Peer.t; frontier: Transition_frontier.t}

    type initial_network =
      { syncing_frontier: Transition_frontier.t
      ; peers: peer List.t
      ; network: Network.t }

    let setup_nodes ~source_accounts ~logger configs =
      let%bind syncing_frontier =
        create_root_frontier ~logger source_accounts
      in
      let init_address = 1337 in
      let network = Network.create ~logger in
      let%map _, peers =
        Deferred.List.fold ~init:(init_address, []) configs
          ~f:(fun (discovery_port, acc_peers) {num_breadcrumbs; accounts} ->
            let%bind frontier = create_root_frontier ~logger accounts in
            let%map () =
              build_frontier_randomly frontier
                ~gen_root_breadcrumb_builder:
                  (gen_linear_breadcrumbs ~logger ~size:num_breadcrumbs
                     ~accounts_with_secret_keys:accounts)
            in
            let best_tip_length =
              Transition_frontier.best_tip_path_length_exn frontier
            in
            assert (best_tip_length = Transition_frontier.max_length) ;
            let address =
              Network_peer.Peer.create Unix.Inet_addr.localhost ~discovery_port
                ~communication_port:(discovery_port + 1)
            in
            Network.add_exn network ~key:address ~data:frontier ;
            let peer = {address; frontier} in
            (discovery_port + 2, peer :: acc_peers) )
      in
      {syncing_frontier; network; peers= List.rev peers}

    let setup_single_node ~source_accounts ~target_accounts ~logger
        ~num_breadcrumbs =
      let%map {syncing_frontier; network; peers} =
        setup_nodes ~source_accounts ~logger
          [{num_breadcrumbs; accounts= target_accounts}]
      in
      (syncing_frontier, network, List.hd_exn peers)

    let send_transition ~logger ~transition_writer ~peer:{address; frontier}
        state_hash =
      let dummy_time = Int64.of_int 1 in
      let transition =
        Transition_frontier.(
          find_exn frontier state_hash
          |> Breadcrumb.transition_with_hash |> With_hash.data)
      in
      Logger.info logger
        !"Peer %{sexp:Network_peer.Peer.t} sending %{sexp:State_hash.t}"
        address state_hash ;
      let enveloped_transition =
        Envelope.Incoming.wrap ~data:transition ~sender:address
      in
      Pipe_lib.Strict_pipe.Writer.write transition_writer
        (`Transition enveloped_transition, `Time_received dummy_time)

    let%test "`bootstrap_controller` caches all transitions it is passed \
              through the `transition_reader` pipe" =
      let transition_graph =
        Bootstrap_controller.For_tests.Transition_cache.create ()
      in
      let num_breadcrumbs = (Transition_frontier.max_length * 2) + 2 in
      let logger = Logger.create () in
      let network = Network.create ~logger in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier =
            create_root_frontier ~logger Genesis_ledger.accounts
          in
          let genesis_root =
            Transition_frontier.root frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let bootstrap =
            Bootstrap_controller.For_tests.make_bootstrap ~logger ~genesis_root
              ~network
          in
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger frontier
          in
          let root_sync_ledger =
            Root_sync_ledger.create ledger_db ~parent_log:logger
          in
          let parent_breadcrumb = Transition_frontier.best_tip frontier in
          let breadcrumbs_gen =
            gen_linear_breadcrumbs ~logger ~size:num_breadcrumbs
              ~accounts_with_secret_keys:Genesis_ledger.accounts
              parent_breadcrumb
            |> Quickcheck.Generator.with_size ~size:num_breadcrumbs
          in
          let%bind breadcrumbs =
            Deferred.all @@ Quickcheck.random_value breadcrumbs_gen
          in
          let input_transitions_verified =
            List.map
              ~f:
                (Fn.compose With_hash.data
                   Transition_frontier.Breadcrumb.transition_with_hash)
              breadcrumbs
          in
          let envelopes =
            List.map ~f:Envelope.Incoming.local input_transitions_verified
          in
          let transition_reader, transition_writer =
            Pipe_lib.Strict_pipe.create Synchronous
          in
          let () =
            List.iter
              ~f:(fun x ->
                Pipe_lib.Strict_pipe.Writer.write transition_writer x
                |> don't_wait_for )
              (List.zip_exn
                 (List.map ~f:(fun e -> `Transition e) envelopes)
                 (List.map
                    ~f:(fun t -> `Time_received t)
                    (List.init num_breadcrumbs ~f:Fn.id)))
          in
          let run_sync =
            Bootstrap_controller.For_tests.sync_ledger bootstrap
              ~root_sync_ledger ~transition_graph ~transition_reader
          in
          let () = Pipe_lib.Strict_pipe.Writer.close transition_writer in
          let%map () = run_sync in
          let saved_transitions_verified =
            Bootstrap_controller.For_tests.Transition_cache.data
              transition_graph
          in
          External_transition.Verified.Set.(
            equal
              (of_list input_transitions_verified)
              (of_list saved_transitions_verified)) )

    let make_transition_pipe () =
      Pipe_lib.Strict_pipe.create
        (Buffered (`Capacity 10, `Overflow Drop_head))

    let get_best_tip_hash peer =
      Transition_frontier.best_tip peer.frontier
      |> Transition_frontier.Breadcrumb.transition_with_hash |> With_hash.hash

    let root_hash =
      Fn.compose Ledger.Db.merkle_root
        Transition_frontier.For_tests.root_snarked_ledger

    let%test "sync with one node correctly" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.create () in
      let num_breadcrumbs = 10 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind syncing_frontier, network, peer =
            setup_single_node ~logger ~num_breadcrumbs
              ~source_accounts:[List.hd_exn Genesis_ledger.accounts]
              ~target_accounts:Genesis_ledger.accounts
          in
          let transition_reader, transition_writer = make_transition_pipe () in
          let best_hash = get_best_tip_hash peer in
          send_transition ~logger ~transition_writer ~peer best_hash ;
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger syncing_frontier
          in
          let%map new_frontier, (_ : External_transition.Verified.t list) =
            Bootstrap_controller.run ~parent_log:logger ~network
              ~frontier:syncing_frontier ~ledger_db ~transition_reader
          in
          Ledger_hash.equal (root_hash new_frontier) (root_hash peer.frontier)
      )

    let%test "if we see a new transition that is better than the transition \
              that we are syncing from, than we should retarget our root" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.create () in
      let small_peer_num_breadcrumbs = 6 in
      let large_peer_num_breadcrumbs = small_peer_num_breadcrumbs * 2 in
      let source_accounts = [List.hd_exn Genesis_ledger.accounts] in
      let small_peer_accounts =
        List.take Genesis_ledger.accounts
          (List.length Genesis_ledger.accounts / 2)
      in
      Thread_safe.block_on_async_exn (fun () ->
          let large_peer_accounts = Genesis_ledger.accounts in
          let%bind {syncing_frontier; peers; network} =
            setup_nodes ~source_accounts ~logger
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
            Transition_frontier.For_tests.root_snarked_ledger syncing_frontier
          in
          send_transition ~logger ~transition_writer ~peer:small_peer
            (get_best_tip_hash small_peer) ;
          (* Have a bit of delay when sending the more recent transition *)
          let%bind () =
            after (Core.Time.Span.of_sec 1.0)
            >>| fun () ->
            send_transition ~logger ~transition_writer ~peer:large_peer
              (get_best_tip_hash large_peer)
          in
          let%map new_frontier, (_ : External_transition.Verified.t list) =
            Bootstrap_controller.run ~parent_log:logger ~network
              ~frontier:syncing_frontier ~ledger_db ~transition_reader
          in
          Ledger_hash.equal (root_hash new_frontier)
            (root_hash large_peer.frontier) )

    let%test "`on_transition` should deny outdated transitions" =
      let logger = Logger.create () in
      let num_breadcrumbs = 10 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind syncing_frontier, network, peer =
            setup_single_node ~logger ~num_breadcrumbs
              ~source_accounts:Genesis_ledger.accounts
              ~target_accounts:Genesis_ledger.accounts
          in
          let root_sync_ledger =
            Root_sync_ledger.create
              (Transition_frontier.For_tests.root_snarked_ledger
                 syncing_frontier)
              ~parent_log:logger
          in
          let query_reader = Root_sync_ledger.query_reader root_sync_ledger in
          let response_writer =
            Root_sync_ledger.answer_writer root_sync_ledger
          in
          Network.glue_sync_ledger network query_reader response_writer ;
          let genesis_root =
            Transition_frontier.root syncing_frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let open Bootstrap_controller.For_tests in
          let bootstrap = make_bootstrap ~logger ~genesis_root ~network in
          let best_transition =
            Transition_frontier.best_tip peer.frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let%bind should_sync =
            Bootstrap_controller.For_tests.on_transition bootstrap
              ~root_sync_ledger ~sender:peer.address best_transition
          in
          assert (should_sync = `Syncing) ;
          let outdated_transition =
            Transition_frontier.root peer.frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let%map should_not_sync =
            Bootstrap_controller.For_tests.on_transition bootstrap
              ~root_sync_ledger ~sender:peer.address outdated_transition
          in
          should_not_sync = `Ignored )
  end )
