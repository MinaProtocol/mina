open Inline_test_quiet_logs

let%test_module "Epoch ledger sync tests" =
  ( module struct
    open Core_kernel
    open Async
    open Mina_base
    open Pipe_lib
    open Network_peer

    module type CONTEXT = sig
      include Mina_lib.CONTEXT

      val trust_system : Trust_system.t
    end

    type network_info =
      { networking : Mina_networking.t
      ; network_peer : Peer.t
      ; consensus_local_state : Consensus.Data.Local_state.t
      ; no_answer_ivar : unit Ivar.t
      }

    exception No_sync_answer

    exception Sync_timeout

    let () =
      Protocol_version.(set_current @@ create_exn ~major:2 ~minor:0 ~patch:0)

    let logger = Logger.create ()

    let default_timeout_min = 5.0

    let make_empty_ledger (module Context : CONTEXT) =
      Mina_ledger.Ledger.create
        ~depth:Context.precomputed_values.constraint_constants.ledger_depth ()

    let make_empty_db_ledger (module Context : CONTEXT) =
      Mina_ledger.Ledger.Db.create
        ~depth:Context.precomputed_values.constraint_constants.ledger_depth ()

    let dir_prefix = "sync_test_data"

    let make_dirname s =
      let open Core in
      let uuid = Uuid_unix.create () |> Uuid.to_string in
      dir_prefix ^/ sprintf "%s_%s" s uuid

    let peek_frontier frontier_broadcast_pipe =
      Broadcast_pipe.Reader.peek frontier_broadcast_pipe
      |> Result.of_option
           ~error:(Error.of_string "Cannot retrieve transition frontier")

    (* [instance] and [test_number] are used to make ports distinct
       among tests
    *)
    let make_mina_network ~context:(module Context : CONTEXT) ~name ~instance
        ~test_number ~libp2p_keypair_str ~initial_peers ~genesis_ledger_hashes =
      let open Context in
      let frontier_broadcast_pipe_r, frontier_broadcast_pipe_w =
        Broadcast_pipe.create None
      in
      let producer_transition_reader, _producer_transition_writer =
        Strict_pipe.create Synchronous
      in
      let precomputed_values = Context.precomputed_values in
      let time_controller =
        Block_time.Controller.create @@ Block_time.Controller.basic ~logger
      in
      let on_remote_push () = Deferred.unit in
      let block_reader, block_sink =
        let on_push () = Deferred.unit in
        Transition_handler.Block_sink.create
          { logger
          ; slot_duration_ms =
              precomputed_values.consensus_constants.slot_duration_ms
          ; on_push
          ; log_gossip_heard = false
          ; time_controller
          ; consensus_constants
          ; genesis_constants = precomputed_values.genesis_constants
          ; constraint_constants
          }
      in
      let pids = Child_processes.Termination.create_pid_table () in
      let verifier_tm0 = Unix.gettimeofday () in
      let%bind verifier =
        Verifier.create ~logger ~proof_level:precomputed_values.proof_level
          ~constraint_constants:precomputed_values.constraint_constants ~pids
          ~conf_dir:(Some (make_dirname "verifier"))
          ()
      in
      let verifier_tm1 = Unix.gettimeofday () in
      [%log debug] "(%s) Time to create verifier: %0.02f" name
        (verifier_tm1 -. verifier_tm0) ;
      let _transaction_pool, tx_remote_sink, _tx_local_sink =
        let config =
          Network_pool.Transaction_pool.Resource_pool.make_config ~verifier
            ~trust_system
            ~pool_max_size:precomputed_values.genesis_constants.txpool_max_size
            ~genesis_constants:precomputed_values.genesis_constants
        in
        Network_pool.Transaction_pool.create ~config ~constraint_constants
          ~consensus_constants ~time_controller ~logger
          ~frontier_broadcast_pipe:frontier_broadcast_pipe_r ~on_remote_push
          ~log_gossip_heard:false
      in
      let snark_remote_sink =
        let config =
          Network_pool.Snark_pool.Resource_pool.make_config ~verifier
            ~trust_system
            ~disk_location:(make_dirname "snark_pool_config")
        in
        let _snark_pool, snark_remote_sink, _snark_local_sink =
          Network_pool.Snark_pool.create ~config ~constraint_constants
            ~consensus_constants ~time_controller ~logger
            ~frontier_broadcast_pipe:frontier_broadcast_pipe_r ~on_remote_push
            ~log_gossip_heard:false
        in
        snark_remote_sink
      in
      let sinks = (block_sink, tx_remote_sink, snark_remote_sink) in
      let genesis_ledger =
        lazy
          (Mina_ledger.Ledger.create
             ~directory_name:(make_dirname "genesis_ledger")
             ~depth:precomputed_values.constraint_constants.ledger_depth () )
      in
      let genesis_epoch_data : Consensus.Genesis_epoch_data.t = None in
      let genesis_state_hash = Quickcheck.random_value Ledger_hash.gen in
      let consensus_local_state =
        Consensus.Data.Local_state.create
          ~context:(module Context)
          ~genesis_ledger ~genesis_epoch_data
          ~epoch_ledger_location:(make_dirname "epoch_ledger")
          ~genesis_state_hash
          (Signature_lib.Public_key.Compressed.Set.of_list [])
      in
      let genesis_ledger_hash =
        Mina_ledger.Ledger.merkle_root (Lazy.force genesis_ledger)
      in
      let is_seed = instance = 0 in
      let libp2p_keypair =
        Mina_net2.Keypair.of_string libp2p_keypair_str |> Or_error.ok_exn
      in
      let libp2p_port =
        Cli_lib.Flag.Port.default_libp2p + instance + (test_number * 2)
      in
      let creatable_gossip_net =
        let chain_id = "dummy_chain_id" in
        let conf_dir = make_dirname "libp2p" in
        let seed_peer_list_url = None in
        let addrs_and_ports =
          let external_ip = Core.Unix.Inet_addr.localhost in
          let bind_ip = Core.Unix.Inet_addr.of_string "0.0.0.0" in
          let client_port =
            Cli_lib.Flag.Port.default_client - instance - (test_number * 2)
          in
          ( { external_ip; bind_ip; peer = None; client_port; libp2p_port }
            : Node_addrs_and_ports.t )
        in
        let pubsub_v1 =
          (* TODO after introducing Bitswap-based block retrieval,
             use definition in Mina_cli_entrypoint
          *)
          Gossip_net.Libp2p.N
        in
        let pubsub_v0 = Cli_lib.Default.pubsub_v0 in
        let gossip_net_params : Gossip_net.Libp2p.Config.t =
          { timeout = Time.Span.of_sec 3.
          ; logger
          ; conf_dir
          ; chain_id
          ; unsafe_no_trust_ip = false
          ; seed_peer_list_url
          ; initial_peers
          ; addrs_and_ports
          ; metrics_port = None
          ; trust_system
          ; flooding = false
          ; direct_peers = []
          ; peer_protection_ratio = 0.2
          ; peer_exchange = false
          ; min_connections = Cli_lib.Default.min_connections
          ; max_connections = Cli_lib.Default.max_connections
          ; validation_queue_size = Cli_lib.Default.validation_queue_size
          ; isolate = false
          ; keypair = libp2p_keypair
          ; all_peers_seen_metric = false
          ; known_private_ip_nets = []
          ; time_controller
          ; pubsub_v1
          ; pubsub_v0
          }
        in
        Mina_networking.Gossip_net.(
          Any.Creatable
            ( (module Libp2p)
            , Libp2p.create ~allow_multiple_instances:true ~pids
                gossip_net_params ))
      in
      let log_gossip_heard : Mina_networking.Config.log_gossip_heard =
        { snark_pool_diff = false
        ; transaction_pool_diff = false
        ; new_state = false
        }
      in
      let config : Mina_networking.Config.t =
        { logger
        ; trust_system
        ; time_controller
        ; consensus_constants
        ; consensus_local_state
        ; genesis_ledger_hash
        ; constraint_constants
        ; precomputed_values
        ; creatable_gossip_net
        ; is_seed
        ; log_gossip_heard
        }
      in
      let no_answer_ivar = Ivar.create () in
      let get_best_tip _ = return None in
      let answer_sync_ledger_query query_env =
        let ledger_hash, _ = Envelope.Incoming.data query_env in
        let%bind.Deferred.Or_error frontier =
          Deferred.return @@ peek_frontier frontier_broadcast_pipe_r
        in
        Sync_handler.answer_query ~frontier ledger_hash
          (Envelope.Incoming.map ~f:Tuple2.get2 query_env)
          ~logger ~trust_system
        |> Deferred.map ~f:(function
             | Some answer ->
                 Ok answer
             | None ->
                 if
                   List.mem genesis_ledger_hashes ledger_hash
                     ~equal:Frozen_ledger_hash.equal
                 then
                   (* should happen only when trying to sync to genesis ledger *)
                   Ivar.fill_if_empty no_answer_ivar () ;
                 Error (Error.of_string "No answer to sync query") )
      in
      let unimplemented name _ = failwithf "RPC %s unimplemented" name () in
      let rpc_error name _ =
        return
        @@ Or_error.error_string (sprintf "Error for unimplemented RPC %s" name)
      in
      let%bind (mina_networking : Mina_networking.t) =
        Mina_networking.create config ~sinks ~answer_sync_ledger_query
          ~get_best_tip
          ~get_some_initial_peers:(unimplemented "get_some_initial_peers")
          ~get_staged_ledger_aux_and_pending_coinbases_at_hash:
            (unimplemented "get_staged_ledger_aux_and_pending_coinbases_at_hash")
          ~get_ancestry:(unimplemented "get_ancestry")
          ~get_node_status:(rpc_error "get_node_status")
          ~get_transition_chain_proof:
            (unimplemented "get_transition_chain_proof")
          ~get_transition_chain:(unimplemented "get_transition_chain")
          ~get_transition_knowledge:(unimplemented "get_transition_knowledge")
      in
      (* create transition frontier *)
      let tr_tm0 = Unix.gettimeofday () in
      let _valid_transitions, initialization_finish_signal =
        let notify_online () = Deferred.unit in
        let most_recent_valid_block =
          Broadcast_pipe.create
            ( Mina_block.genesis ~precomputed_values
            |> Mina_block.Validation.reset_frontier_dependencies_validation
            |> Mina_block.Validation.reset_staged_ledger_diff_validation )
        in
        (* we're going to set and sync the epoch ledgers in the test
           so router should not do a sync
        *)
        Transition_router.run ~sync_local_state:false
          ~context:(module Context)
          ~trust_system:config.trust_system ~verifier ~network:mina_networking
          ~is_seed:config.is_seed ~is_demo_mode:false
          ~time_controller:config.time_controller
          ~consensus_local_state:config.consensus_local_state
          ~persistent_root_location:(make_dirname "persistent_root_location")
          ~persistent_frontier_location:
            (make_dirname "persistent_frontier_location")
          ~frontier_broadcast_pipe:
            (frontier_broadcast_pipe_r, frontier_broadcast_pipe_w)
          ~catchup_mode:`Normal ~network_transition_reader:block_reader
          ~producer_transition_reader ~most_recent_valid_block ~notify_online ()
      in
      let%bind () = Ivar.read initialization_finish_signal in
      let tr_tm1 = Unix.gettimeofday () in
      [%log debug] "(%s) Time to start transition router: %0.02f" name
        (tr_tm1 -. tr_tm0) ;
      let network_peer =
        let peer_id = Mina_net2.Keypair.to_peer_id libp2p_keypair in
        Peer.create Core.Unix.Inet_addr.localhost ~libp2p_port ~peer_id
      in
      return
        { networking = mina_networking
        ; network_peer
        ; consensus_local_state
        ; no_answer_ivar
        }

    let make_context () : (module CONTEXT) Deferred.t =
      let%bind precomputed_values =
        let runtime_config : Runtime_config.t =
          { daemon = None
          ; genesis = None
          ; proof = None
          ; ledger = None
          ; epoch_data = None
          }
        in
        match%map
          Genesis_ledger_helper.init_from_config_file
            ~genesis_dir:(make_dirname "genesis_dir")
            ~logger ~proof_level:None runtime_config
        with
        | Ok (precomputed_values, _) ->
            precomputed_values
        | Error err ->
            failwithf "Could not create precomputed values: %s"
              (Error.to_string_hum err) ()
      in
      let constraint_constants = precomputed_values.constraint_constants in
      let consensus_constants =
        let genesis_constants = Genesis_constants.for_unit_tests in
        Consensus.Constants.create ~constraint_constants
          ~protocol_constants:genesis_constants.protocol
      in
      let trust_system = Trust_system.create (make_dirname "trust_system") in
      let module Context = struct
        let logger = logger

        let constraint_constants = constraint_constants

        let consensus_constants = consensus_constants

        let precomputed_values = precomputed_values

        let trust_system = trust_system
      end in
      return (module Context : CONTEXT)

    let run_test ?(timeout_min = default_timeout_min) (module Context : CONTEXT)
        ~name ~staking_epoch_ledger ~next_epoch_ledger ~starting_accounts
        ~test_number =
      let module Context2 = struct
        include Context

        let trust_system = Trust_system.create (make_dirname "trust_system")
      end in
      let test_finished = ref false in
      let cleanup () = test_finished := true in
      (* set timeout so CI doesn't run forever *)
      don't_wait_for
        (let%map () = after (Time.Span.of_min timeout_min) in
         if not !test_finished then (cleanup () ; raise Sync_timeout) ) ;
      let staking_ledger_root =
        Consensus.Data.Local_state.Snapshot.Ledger_snapshot.merkle_root
          staking_epoch_ledger
      in
      let next_epoch_ledger_root =
        Consensus.Data.Local_state.Snapshot.Ledger_snapshot.merkle_root
          next_epoch_ledger
      in
      let genesis_ledger_hashes =
        match (staking_epoch_ledger, next_epoch_ledger) with
        | Genesis_epoch_ledger _, Genesis_epoch_ledger _ ->
            [ staking_ledger_root; next_epoch_ledger_root ]
        | Genesis_epoch_ledger _, Ledger_db _ ->
            [ staking_ledger_root ]
        | Ledger_db _, Genesis_epoch_ledger _ ->
            [ next_epoch_ledger_root ]
        | Ledger_db _, Ledger_db _ ->
            []
      in
      let net_info1_tm0 = Unix.gettimeofday () in
      let%bind network_info1 =
        make_mina_network ~name
          ~context:(module Context)
          ~instance:0 ~test_number
          ~libp2p_keypair_str:
            "CAESQFzI5/57gycQ1qumCq00OFo60LArXgbrgV0b5P8tNiSujUZT5Psc+74luHmSSf7kVIZ7w0YObC//UVXPCOgeh4o=,CAESII1GU+T7HPu+Jbh5kkn+5FSGe8NGDmwv/1FVzwjoHoeK,12D3KooWKKqrPfHi4PNkWms5Z9oANjRftE5vueTmkt4rpz9sXM69"
          ~initial_peers:[] ~genesis_ledger_hashes
      in
      let net_info1_tm1 = Unix.gettimeofday () in
      [%log debug] "(%s) Time to create network 1: %0.02f" name
        (net_info1_tm1 -. net_info1_tm0) ;
      let staking_epoch_snapshot =
        Consensus.Data.Local_state.For_tests.snapshot_of_ledger
          staking_epoch_ledger
      in
      let next_epoch_snapshot =
        Consensus.Data.Local_state.For_tests.snapshot_of_ledger
          next_epoch_ledger
      in
      (* store snapshots in local state *)
      Consensus.Data.Local_state.For_tests.set_snapshot
        network_info1.consensus_local_state Staking_epoch_snapshot
        staking_epoch_snapshot ;
      Consensus.Data.Local_state.For_tests.set_snapshot
        network_info1.consensus_local_state Next_epoch_snapshot
        next_epoch_snapshot ;
      let net_info2_tm0 = Unix.gettimeofday () in
      let%bind network_info2 =
        make_mina_network ~name ~instance:1 ~test_number
          ~context:(module Context2)
          ~libp2p_keypair_str:
            "CAESQMHCQMQDqPKTFLAjZWwA3vvbkzMJZiVrjvte+bDfUvEeRhjvhsa9IfuFDEmJ721drMJ5cEWAmVmrQYfretz9MUQ=,CAESIEYY74bGvSH7hQxJie9tXazCeXBFgJlZq0GH63rc/TFE,12D3KooWEXzm5pMj1DQqNz6bpMRdJa55bytbawkuHVNhGR3XuTpw"
          ~initial_peers:
            [ Mina_net2.Multiaddr.of_peer network_info1.network_peer ]
          ~genesis_ledger_hashes
      in
      let net_info2_tm1 = Unix.gettimeofday () in
      [%log debug] "(%s) Time to create network 2: %0.02f" name
        (net_info2_tm1 -. net_info2_tm0) ;
      let make_sync_ledger () =
        let db_ledger = make_empty_db_ledger (module Context) in
        List.iter starting_accounts ~f:(fun (acct : Account.t) ->
            let acct_id = Account_id.create acct.public_key Token_id.default in
            match
              Mina_ledger.Ledger.Db.get_or_create_account db_ledger acct_id acct
            with
            | Ok _ ->
                ()
            | Error _ ->
                failwith "Could not add starting account" ) ;
        let sync_ledger =
          Mina_ledger.Sync_ledger.Db.create ~logger
            ~trust_system:Context.trust_system db_ledger
        in
        let query_reader =
          Mina_ledger.Sync_ledger.Db.query_reader sync_ledger
        in
        let response_writer =
          Mina_ledger.Sync_ledger.Db.answer_writer sync_ledger
        in
        Mina_networking.glue_sync_ledger network_info2.networking
          ~preferred:[ network_info1.network_peer ]
          query_reader response_writer ;
        sync_ledger
      in
      (* should only happen when syncing to a genesis ledger *)
      don't_wait_for
        (let%bind () = Ivar.read network_info1.no_answer_ivar in
         cleanup () ; raise No_sync_answer ) ;
      (* sync current staking ledger *)
      let sync_ledger1_tm0 = Unix.gettimeofday () in
      let sync_ledger1 = make_sync_ledger () in
      let%bind () =
        match%map
          Mina_ledger.Sync_ledger.Db.fetch sync_ledger1 staking_ledger_root
            ~data:() ~equal:(fun () () -> true)
        with
        | `Ok ledger ->
            let sync_ledger1_tm1 = Unix.gettimeofday () in
            [%log debug] "(%s) Time to sync ledger 1: %0.02f" name
              (sync_ledger1_tm1 -. sync_ledger1_tm0) ;
            let ledger_root = Mina_ledger.Ledger.Db.merkle_root ledger in
            assert (Ledger_hash.equal ledger_root staking_ledger_root) ;
            [%log debug] "Synced current epoch ledger successfully"
        | `Target_changed _ ->
            failwith "Target changed when getting staking ledger"
      in
      (* sync next staking ledger *)
      let sync_ledger2_tm0 = Unix.gettimeofday () in
      let sync_ledger2 = make_sync_ledger () in
      match%bind
        Mina_ledger.Sync_ledger.Db.fetch sync_ledger2 next_epoch_ledger_root
          ~data:() ~equal:(fun () () -> true)
      with
      | `Ok ledger ->
          let sync_ledger2_tm1 = Unix.gettimeofday () in
          [%log debug] "(%s) Time to sync ledger 2: %0.02f" name
            (sync_ledger2_tm1 -. sync_ledger2_tm0) ;
          cleanup () ;
          let ledger_root = Mina_ledger.Ledger.Db.merkle_root ledger in
          assert (Ledger_hash.equal ledger_root next_epoch_ledger_root) ;
          [%log debug] "Synced next epoch ledger, sync test succeeded" ;
          Deferred.unit
      | `Target_changed _ ->
          cleanup () ;
          failwith "Target changed when getting next epoch ledger"

    let make_genesis_ledger (module Context : CONTEXT)
        (accounts : Account.t list) =
      let ledger = make_empty_ledger (module Context) in
      List.iter accounts ~f:(fun acct ->
          let acct_id = Account_id.create acct.public_key Token_id.default in
          match
            Mina_ledger.Ledger.get_or_create_account ledger acct_id acct
          with
          | Ok _ ->
              ()
          | Error _ ->
              failwith "Could not add account" ) ;
      Consensus.Data.Local_state.Snapshot.Ledger_snapshot.Genesis_epoch_ledger
        ledger

    let make_db_ledger (module Context : CONTEXT) (accounts : Account.t list) =
      let db_ledger = make_empty_db_ledger (module Context) in
      List.iter accounts ~f:(fun acct ->
          let acct_id = Account_id.create acct.public_key Token_id.default in
          match
            Mina_ledger.Ledger.Db.get_or_create_account db_ledger acct_id acct
          with
          | Ok _ ->
              ()
          | Error _ ->
              failwith "Could not add account" ) ;
      Consensus.Data.Local_state.Snapshot.Ledger_snapshot.Ledger_db db_ledger

    let test_accounts =
      Quickcheck.(random_value @@ Generator.list_with_length 20 Account.gen)

    let%test_unit "Sync current, next staking ledgers to empty ledgers" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind (module Context) = make_context () in
          let staking_epoch_ledger =
            make_db_ledger (module Context) (List.take test_accounts 10)
          in
          let next_epoch_ledger =
            make_db_ledger (module Context) (List.take test_accounts 20)
          in
          run_test ~name:"sync to empty ledgers" ~timeout_min:6.0 ~test_number:1
            (module Context)
            ~staking_epoch_ledger ~next_epoch_ledger ~starting_accounts:[] )

    let%test_unit "Sync current, next staking ledgers to nonempty ledgers" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind (module Context) = make_context () in
          let staking_epoch_ledger =
            make_db_ledger (module Context) (List.take test_accounts 10)
          in
          let next_epoch_ledger =
            make_db_ledger (module Context) (List.take test_accounts 20)
          in
          (* we make sure the starting ledger is contained
             in the target ledgers
             possible bug: if the starting ledger is disjoint from
             the ledger to sync to, see issue #12170
          *)
          let starting_accounts = List.take test_accounts 8 in
          run_test ~name:"sync to nonempty ledgers" ~test_number:2
            (module Context)
            ~staking_epoch_ledger ~next_epoch_ledger ~starting_accounts )

    (* A `fetch` to sync a genesis ledger will just loop, because `get_ledger_by_hash`
       returns None for genesis ledgers

       In the consensus code, we don't call `fetch` if the requested hash is the
       genesis ledger hash, so such looping should not occur

       In the tests here, we check whether `answer_sync_query` returns None, reflecting
       the None returned by `get_ledger_by_hash`, and fill an ivar; if we detect
       that has been filled, we raise an exception, No_sync_answer

       That exception should be raised only in the following test
    *)
    let%test_unit "Sync genesis ledgers to empty ledgers, should fail" =
      let f () =
        Monitor.try_with ~here:[%here] (fun () ->
            let%bind (module Context) = make_context () in
            let staking_epoch_ledger =
              make_genesis_ledger (module Context) (List.take test_accounts 10)
            in
            let next_epoch_ledger = staking_epoch_ledger in
            run_test ~name:"fail to sync genesis ledgers" ~test_number:3
              (module Context)
              ~staking_epoch_ledger ~next_epoch_ledger ~starting_accounts:[] )
      in
      match Async.Thread_safe.block_on_async_exn f with
      | Ok () ->
          failwith "Ledgers synced to a genesis ledger, unexpectedly"
      | Error exn -> (
          match Monitor.extract_exn exn with
          | No_sync_answer ->
              [%log debug] "Did not sync to genesis ledger, sync test succeeded" ;
              ()
          | exn' ->
              failwithf "Unexpected exception: %s" (Exn.to_string exn') () )
  end )
