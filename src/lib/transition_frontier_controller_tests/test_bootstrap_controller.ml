open Core
open Async
open Coda_base
open Stubs

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
    type initial_network =
      { syncing_frontier: Stubs.Transition_frontier.t
      ; peer: Network_peer.Peer.t * Stubs.Transition_frontier.t
      ; network: Network.t }

    let setup_nodes ~source_accounts ~target_accounts ~logger ~max_length
        ~num_breadcrumbs =
      let%bind syncing_frontier =
        create_root_frontier ~max_length ~logger ~accounts:source_accounts
      in
      let%bind peer_frontier =
        create_root_frontier ~max_length ~logger ~accounts:target_accounts
      in
      let%map () =
        build_frontier_randomly peer_frontier
          ~gen_root_breadcrumb_builder:
            (gen_linear_breadcrumbs ~logger ~size:num_breadcrumbs)
      in
      let best_tip_length =
        Transition_frontier.best_tip_path_length_exn peer_frontier
      in
      assert (best_tip_length = max_length) ;
      let peer_address =
        Network_peer.Peer.create Unix.Inet_addr.localhost ~discovery_port:1337
          ~communication_port:1338
      in
      let network = Network.create ~logger ~max_length in
      Network.add_exn network ~key:peer_address ~data:peer_frontier ;
      {syncing_frontier; network; peer= (peer_address, peer_frontier)}

    let dummy_time = Int64.of_int 1

    let send_transition ~transition_writer ~peer:(sender, frontier) state_hash
        =
      let transition =
        Transition_frontier.(
          find_exn frontier state_hash
          |> Breadcrumb.transition_with_hash |> With_hash.data)
      in
      let enveloped_transition =
        Envelope.Incoming.wrap ~data:transition ~sender
      in
      Pipe_lib.Strict_pipe.Writer.write transition_writer
        (`Transition enveloped_transition, `Time_received dummy_time)

    let%test "`bootstrap_controller` caches all transitions it is passed \
              through the `transition_reader` pipe" =
      let transition_graph =
        Bootstrap_controller.For_tests.Transition_cache.create ()
      in
      let max_length = 4 in
      let num_breadcrumbs = 10 in
      let logger = Logger.create () in
      let network = Network.create ~logger ~max_length in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier =
            create_root_frontier ~logger ~max_length ~accounts:genesis_accounts
          in
          let genesis_root =
            Transition_frontier.root frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let bootstrap =
            Bootstrap_controller.For_tests.make_bootstrap ~logger ~genesis_root
              ~max_length ~network
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

    let%test "sync with one node correctly" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.create () in
      let max_length = 4 in
      let num_breadcrumbs = 10 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind {syncing_frontier; peer= (_, peer_frontier) as peer; network}
              =
            setup_nodes ~logger ~max_length ~num_breadcrumbs
              ~source_accounts:[List.hd_exn genesis_accounts]
              ~target_accounts:genesis_accounts
          in
          let transition_reader, transition_writer =
            Pipe_lib.Strict_pipe.create
              (Buffered (`Capacity 10, `Overflow Drop_head))
          in
          let best_hash =
            Transition_frontier.best_tip peer_frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.hash
          in
          send_transition ~transition_writer ~peer best_hash ;
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger syncing_frontier
          in
          let%map new_frontier =
            Bootstrap_controller.run ~parent_log:logger ~network
              ~frontier:syncing_frontier ~ledger_db ~transition_reader
          in
          let root_hash =
            Fn.compose Ledger.Db.merkle_root
              Transition_frontier.For_tests.root_snarked_ledger
          in
          Ledger_hash.equal (root_hash new_frontier) (root_hash peer_frontier)
      )

    let%test "`on_transition` should deny outdated transitions" =
      let logger = Logger.create () in
      let max_length = 4 in
      let num_breadcrumbs = 10 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind { syncing_frontier
                   ; peer= peer_address, peer_frontier
                   ; network } =
            setup_nodes ~logger ~max_length ~num_breadcrumbs
              ~source_accounts:genesis_accounts
              ~target_accounts:genesis_accounts
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
          let bootstrap =
            make_bootstrap ~logger ~genesis_root ~network ~max_length
          in
          let best_transition =
            Transition_frontier.best_tip peer_frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let%bind should_sync =
            Bootstrap_controller.For_tests.on_transition bootstrap
              ~root_sync_ledger ~sender:peer_address best_transition
          in
          assert (should_sync = `Syncing) ;
          let outdated_transition =
            Transition_frontier.root peer_frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let%map should_not_sync =
            Bootstrap_controller.For_tests.on_transition bootstrap
              ~root_sync_ledger ~sender:peer_address outdated_transition
          in
          should_not_sync = `Ignored )
  end )
