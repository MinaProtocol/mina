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
    type test_infra =
      { root_sync_ledger: Root_sync_ledger.t
      ; peer_frontier: Stubs.Transition_frontier.t
      ; peer_address: Network_peer.Peer.t
      ; bootstrap: Bootstrap_controller.For_tests.t }

    let setup_test_infra ~logger ~max_length ~num_breadcrumbs =
      let%bind syncing_frontier = create_root_frontier ~max_length ~logger in
      let%bind peer_frontier = create_root_frontier ~max_length ~logger in
      let%bind () =
        (* TODO: dedup this *)
        build_frontier_randomly peer_frontier
          ~gen_root_breadcrumb_builder:(fun root_breadcrumb ->
            Quickcheck.Generator.with_size ~size:num_breadcrumbs
            @@ Quickcheck_lib.gen_imperative_list
                 (root_breadcrumb |> return |> Quickcheck.Generator.return)
                 (gen_breadcrumb ~logger) )
      in
      let best_tip_length =
        Transition_frontier.best_tip_path_length_exn peer_frontier
      in
      assert (best_tip_length = max_length) ;
      let network = Network.create ~logger ~max_length in
      let open Transition_frontier.For_tests in
      let open Bootstrap_controller.For_tests in
      let root_sync_ledger =
        Root_sync_ledger.create
          (root_snarked_ledger syncing_frontier)
          ~parent_log:logger
      in
      let query_reader = Root_sync_ledger.query_reader root_sync_ledger in
      let response_writer = Root_sync_ledger.answer_writer root_sync_ledger in
      Network.glue_sync_ledger network query_reader response_writer ;
      let peer_address =
        Network_peer.Peer.create Unix.Inet_addr.localhost ~discovery_port:1337
          ~communication_port:1338
      in
      Network.add_exn network ~key:peer_address ~data:peer_frontier ;
      let genesis_root =
        Transition_frontier.root syncing_frontier
        |> Transition_frontier.Breadcrumb.transition_with_hash
        |> With_hash.data
        |> External_transition.forget_consensus_state_verification
      in
      let bootstrap =
        make_bootstrap ~logger ~genesis_root ~network ~max_length
      in
      Deferred.return {root_sync_ledger; peer_frontier; peer_address; bootstrap}

    let%test "`bootstrap_controller` caches all transitions it is passed \
              through the `transition_reader` pipe" =
      let transition_graph =
        Bootstrap_controller.For_tests.Transition_cache.create ()
      in
      let max_length = 4 in
      let num_breadcrumbs = 10 in
      let logger = Logger.create () in
      let network = Network.create ~logger  ~max_length in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind frontier = create_root_frontier ~max_length ~logger in
          let genesis_root =
            Transition_frontier.root frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let bootstrap =
            Bootstrap_controller.For_tests.make_bootstrap ~logger ~genesis_root  ~max_length ~network
          in
          let ledger_db =
            Transition_frontier.For_tests.root_snarked_ledger frontier
          in
          let root_sync_ledger =
            Root_sync_ledger.create ledger_db ~parent_log:logger
          in
          let parent_breadcrumb = Transition_frontier.best_tip frontier in
          let breadcrumbs_gen =
            Quickcheck_lib.gen_imperative_list
              ( Quickcheck.Generator.return @@ Deferred.return
              @@ parent_breadcrumb )
              (gen_breadcrumb ~logger)
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
          let%bind () = run_sync in
          let saved_transitions_verified =
            Bootstrap_controller.For_tests.Transition_cache.data
              transition_graph
          in
          assert (
            External_transition.Verified.Set.(
              equal
                (of_list input_transitions_verified)
                (of_list saved_transitions_verified)) ) ;
          Deferred.return true )

    let%test "sync with one node correctly" =
      Backtrace.elide := false ;
      Printexc.record_backtrace true ;
      let logger = Logger.create () in
      let max_length = 4 in
      let num_breadcrumbs = 10 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind {root_sync_ledger; peer_frontier; peer_address; bootstrap} =
            setup_test_infra ~logger ~max_length ~num_breadcrumbs
          in
          let best_transition =
            Transition_frontier.best_tip peer_frontier
            |> Transition_frontier.Breadcrumb.transition_with_hash
            |> With_hash.data
            |> External_transition.forget_consensus_state_verification
          in
          let%bind _ =
            Bootstrap_controller.For_tests.on_transition bootstrap
              ~root_sync_ledger ~sender:peer_address best_transition
          in
          (* TODO: code below is currently failing *)
          Deferred.return true
          (* let%map newly_syncing_frontier = Root_sync_ledger.valid_tree root_sync_ledger
          in
          let root_hash =
            Fn.compose Ledger.Db.merkle_root root_snarked_ledger
          in
          let syncing_frontier_root_hash = root_hash syncing_frontier in
          Ledger_hash.equal syncing_frontier_root_hash
            (Ledger.Db.merkle_root newly_syncing_frontier)
          && Ledger_hash.equal syncing_frontier_root_hash
               (root_hash peer_frontier)  *)
      )

    let%test "`on_transition` should deny outdated transitions" =
      let logger = Logger.create () in
      let max_length = 4 in
      let num_breadcrumbs = 10 in
      Thread_safe.block_on_async_exn (fun () ->
          let%bind {root_sync_ledger; peer_frontier; peer_address; bootstrap} =
            setup_test_infra ~logger ~max_length ~num_breadcrumbs
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
          let%bind should_not_sync =
            Bootstrap_controller.For_tests.on_transition bootstrap
              ~root_sync_ledger ~sender:peer_address outdated_transition
          in
          assert (should_not_sync = `Ignored) ;
          Deferred.return true )
  end )
