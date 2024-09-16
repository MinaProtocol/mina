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

      val genesis_ledger : Mina_ledger.Ledger.t Lazy.t
    end

    type network_info =
      { networking : Mina_networking.t; network_peer : Peer.t }

    type test_state =
      { name : string
      ; network_info1 : network_info
      ; network_info2 : network_info
      ; staking_epoch_ledger :
          Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
      ; next_epoch_ledger :
          Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
      ; cleanup : unit -> unit
      }

    exception Sync_timeout

    let logger = Logger.create ()

    let default_timeout_min = 5.0

    let dir_prefix = "sync_test_data"

    let genesis_constants = Genesis_constants.For_unit_tests.t

    let constraint_constants =
      Genesis_constants.For_unit_tests.Constraint_constants.t

    let make_dirname s =
      let open Core in
      let uuid = Uuid_unix.create () |> Uuid.to_string in
      dir_prefix ^/ sprintf "%s_%s" s uuid

    let make_context () : (module CONTEXT) Deferred.t =
      let%bind precomputed_values =
        let runtime_config : Runtime_config.t =
          { daemon = None
          ; genesis = None
          ; proof = None
          ; ledger =
              Some
                { base = Named "test"
                ; num_accounts = None
                ; balances = []
                ; hash = None
                ; s3_data_hash = None
                ; name = None
                ; add_genesis_winner = None
                }
          ; epoch_data = None
          }
        in
        match%map
          Genesis_ledger_helper.init_from_config_file
            ~genesis_dir:(make_dirname "genesis_dir")
            ~constraint_constants ~genesis_constants ~logger ~proof_level:None
            runtime_config ~cli_proof_level:None
        with
        | Ok (precomputed_values, _) ->
            precomputed_values
        | Error err ->
            failwithf "Could not create precomputed values: %s"
              (Error.to_string_hum err) ()
      in
      let constraint_constants = precomputed_values.constraint_constants in
      let consensus_constants =
        let genesis_constants = Genesis_constants.For_unit_tests.t in
        Consensus.Constants.create ~constraint_constants
          ~protocol_constants:genesis_constants.protocol
      in
      let%bind trust_system =
        Trust_system.create (make_dirname "trust_system")
      in
      let time_controller = Block_time.Controller.basic ~logger in
      let module Context = struct
        let logger = logger

        let constraint_constants = constraint_constants

        let consensus_constants = consensus_constants

        let precomputed_values = precomputed_values

        let trust_system = trust_system

        let time_controller = time_controller

        let commit_id = "not specified for unit test"
      end in
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
      let module Context = struct
        include Context

        let genesis_ledger = genesis_ledger

        let consensus_local_state = consensus_local_state
      end in
      return (module Context : CONTEXT)

    let pids = Child_processes.Termination.create_pid_table ()

    let make_verifier (module Context : CONTEXT) =
      let open Context in
      Verifier.create ~logger ~proof_level:precomputed_values.proof_level
        ~constraint_constants:precomputed_values.constraint_constants ~pids
        ~conf_dir:(Some (make_dirname "verifier"))
        ~commit_id:"not specified for unit tests" ()

    let make_empty_ledger (module Context : CONTEXT) =
      Mina_ledger.Ledger.create
        ~depth:Context.precomputed_values.constraint_constants.ledger_depth ()

    let make_empty_db_ledger (module Context : CONTEXT) =
      Mina_ledger.Ledger.Db.create
        ~depth:Context.precomputed_values.constraint_constants.ledger_depth ()

    (* [instance] and [test_number] are used to make ports distinct
       among tests
    *)
    let make_mina_network ~context:(module Context : CONTEXT) ~name ~instance
        ~test_number ~libp2p_keypair_str ~initial_peers =
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
      let%bind verifier = make_verifier (module Context) in
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
      let _transaction_pool, tx_remote_sink, _tx_local_sink =
        let config =
          Network_pool.Transaction_pool.Resource_pool.make_config ~verifier
            ~trust_system
            ~pool_max_size:precomputed_values.genesis_constants.txpool_max_size
            ~genesis_constants:precomputed_values.genesis_constants
            ~slot_tx_end:None
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
          ; keypair = Some libp2p_keypair
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
        { genesis_ledger_hash; creatable_gossip_net; is_seed; log_gossip_heard }
      in
      let rpc_error name _ =
        return
        @@ Or_error.error_string (sprintf "Error for unimplemented RPC %s" name)
      in
      let%bind (mina_networking : Mina_networking.t) =
        Mina_networking.create
          (module Context)
          config ~sinks
          ~get_transition_frontier:(fun () ->
            Broadcast_pipe.Reader.peek frontier_broadcast_pipe_r )
          ~get_node_status:(rpc_error "get_node_status")
      in
      (* create transition frontier *)
      let tr_tm0 = Unix.gettimeofday () in
      let _valid_transitions, initialization_finish_signal =
        let notify_online () = Deferred.unit in
        let most_recent_valid_block_reader, most_recent_valid_block_writer =
          Broadcast_pipe.create
            ( Mina_block.genesis ~precomputed_values
            |> Mina_block.Validation.reset_frontier_dependencies_validation
            |> Mina_block.Validation.reset_staged_ledger_diff_validation )
        in
        let get_current_frontier () =
          Broadcast_pipe.Reader.peek frontier_broadcast_pipe_r
        in
        let get_most_recent_valid_block () =
          Broadcast_pipe.Reader.peek most_recent_valid_block_reader
        in
        (* we're going to set and sync the epoch ledgers in the test
           so router should not do a sync
        *)
        Transition_router.run ~sync_local_state:false ~cache_exceptions:true
          ~context:(module Context)
          ~trust_system ~verifier ~network:mina_networking
          ~is_seed:config.is_seed ~is_demo_mode:false ~time_controller
          ~consensus_local_state
          ~persistent_root_location:(make_dirname "persistent_root_location")
          ~persistent_frontier_location:
            (make_dirname "persistent_frontier_location")
          ~get_current_frontier
          ~frontier_broadcast_writer:frontier_broadcast_pipe_w
          ~get_completed_work:(Fn.const None) ~catchup_mode:`Normal
          ~network_transition_reader:block_reader ~producer_transition_reader
          ~get_most_recent_valid_block ~most_recent_valid_block_writer
          ~notify_online ()
      in
      let%bind () = Ivar.read initialization_finish_signal in
      let tr_tm1 = Unix.gettimeofday () in
      [%log debug] "(%s) Time to start transition router: %0.02f" name
        (tr_tm1 -. tr_tm0) ;
      let network_peer =
        let peer_id = Mina_net2.Keypair.to_peer_id libp2p_keypair in
        Peer.create Core.Unix.Inet_addr.localhost ~libp2p_port ~peer_id
      in
      return { networking = mina_networking; network_peer }

    let setup_test ?(timeout_min = default_timeout_min)
        (module Context : CONTEXT) ~name ~staking_epoch_ledger
        ~next_epoch_ledger ~test_number =
      let%bind fresh_trust_system =
        Trust_system.create (make_dirname "trust_system")
      in
      let open Context in
      let module Context2 = struct
        include Context

        let trust_system = fresh_trust_system
      end in
      let test_finished = ref false in
      let cleanup () = test_finished := true in
      (* set timeout so CI doesn't run forever *)
      don't_wait_for
        (let%map () = after (Time.Span.of_min timeout_min) in
         if not !test_finished then (cleanup () ; raise Sync_timeout) ) ;
      let net_info1_tm0 = Unix.gettimeofday () in
      let%bind network_info1 =
        make_mina_network ~name
          ~context:(module Context)
          ~instance:0 ~test_number
          ~libp2p_keypair_str:
            "CAESQFzI5/57gycQ1qumCq00OFo60LArXgbrgV0b5P8tNiSujUZT5Psc+74luHmSSf7kVIZ7w0YObC//UVXPCOgeh4o=,CAESII1GU+T7HPu+Jbh5kkn+5FSGe8NGDmwv/1FVzwjoHoeK,12D3KooWKKqrPfHi4PNkWms5Z9oANjRftE5vueTmkt4rpz9sXM69"
          ~initial_peers:[]
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
      Consensus.Data.Local_state.For_tests.set_snapshot consensus_local_state
        Staking_epoch_snapshot staking_epoch_snapshot ;
      Consensus.Data.Local_state.For_tests.set_snapshot consensus_local_state
        Next_epoch_snapshot next_epoch_snapshot ;
      let net_info2_tm0 = Unix.gettimeofday () in
      let%map network_info2 =
        make_mina_network ~name ~instance:1 ~test_number
          ~context:(module Context2)
          ~libp2p_keypair_str:
            "CAESQMHCQMQDqPKTFLAjZWwA3vvbkzMJZiVrjvte+bDfUvEeRhjvhsa9IfuFDEmJ721drMJ5cEWAmVmrQYfretz9MUQ=,CAESIEYY74bGvSH7hQxJie9tXazCeXBFgJlZq0GH63rc/TFE,12D3KooWEXzm5pMj1DQqNz6bpMRdJa55bytbawkuHVNhGR3XuTpw"
          ~initial_peers:
            [ Mina_net2.Multiaddr.of_peer network_info1.network_peer ]
      in
      let net_info2_tm1 = Unix.gettimeofday () in
      [%log debug] "(%s) Time to create network 2: %0.02f" name
        (net_info2_tm1 -. net_info2_tm0) ;
      { name
      ; network_info1
      ; network_info2
      ; staking_epoch_ledger
      ; next_epoch_ledger
      ; cleanup
      }

    let both_ledgers_sync_successfully ~starting_accounts
        (module Context : CONTEXT) (test : test_state) =
      let open Context in
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
        let answer_writer =
          Mina_ledger.Sync_ledger.Db.answer_writer sync_ledger
        in
        (*
        (* setup a proxy response pipe so we can inspect the messages from our test *)
        let proxy_answer_reader, proxy_answer_writer =
          Linear_pipe.create ()
        in
        don't_wait_for (
          Linear_pipe.Reader.iter proxy_answer_reader ~f:(fun answer ->
            if Option.is_none response && is_genesis_state_hash
            ( match response with
              | None when genesis_state_hash ->
            )
            Linear_pipe.write proxy_response_writer response)
        *)
        Mina_networking.glue_sync_ledger test.network_info2.networking
          ~preferred:[ test.network_info1.network_peer ]
          query_reader answer_writer ;
        sync_ledger
      in
      let staking_ledger_root =
        Consensus.Data.Local_state.Snapshot.Ledger_snapshot.merkle_root
          test.staking_epoch_ledger
      in
      let next_epoch_ledger_root =
        Consensus.Data.Local_state.Snapshot.Ledger_snapshot.merkle_root
          test.next_epoch_ledger
      in
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
            [%log debug] "(%s) Time to sync ledger 1: %0.02f" test.name
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
          [%log debug] "(%s) Time to sync ledger 2: %0.02f" test.name
            (sync_ledger2_tm1 -. sync_ledger2_tm0) ;
          test.cleanup () ;
          let ledger_root = Mina_ledger.Ledger.Db.merkle_root ledger in
          assert (Ledger_hash.equal ledger_root next_epoch_ledger_root) ;
          [%log debug] "Synced next epoch ledger, sync test succeeded" ;
          Deferred.unit
      | `Target_changed _ ->
          test.cleanup () ;
          failwith "Target changed when getting next epoch ledger"

    let cannot_sync_staking_ledger (test : test_state) =
      let staking_ledger_root =
        Consensus.Data.Local_state.Snapshot.Ledger_snapshot.merkle_root
          test.staking_epoch_ledger
      in
      let%map response =
        Mina_networking.query_peer test.network_info2.networking
          test.network_info1.network_peer.peer_id
          Mina_networking.Rpcs.Answer_sync_ledger_query
          (staking_ledger_root, Num_accounts)
      in
      match response with
      | Connected { data = Ok (Error err); _ } ->
          if
            not
              (String.is_substring (Error.to_string_hum err)
                 ~substring:"Refusing to answer sync ledger query" )
          then
            failwithf "unexpected error returned from sync ledger RPC: %s"
              (Error.to_string_hum err) ()
      | Connected { data = Ok (Ok _); _ } ->
          failwith "unexpected successful RPC response"
      | Connected { data = Error err; _ } ->
          failwithf "unexpected RPC failure: %s" (Error.to_string_hum err) ()
      | Failed_to_connect err ->
          failwithf "unexpected connection failure: %s"
            (Error.to_string_hum err) ()

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
          setup_test ~name:"sync to empty ledgers" ~test_number:1
            (module Context)
            ~staking_epoch_ledger ~next_epoch_ledger
          >>= both_ledgers_sync_successfully
                (module Context)
                ~starting_accounts:[] )

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
          setup_test ~name:"sync to nonempty ledgers" ~test_number:2
            (module Context)
            ~staking_epoch_ledger ~next_epoch_ledger
          >>= both_ledgers_sync_successfully (module Context) ~starting_accounts )

    (* A `fetch` to sync a genesis ledger will just loop, because `get_ledger_by_hash`
       returns None for genesis ledgers

       In the consensus code, we don't call `fetch` if the requested hash is the
       genesis ledger hash, so such looping should not occur

       In the tests here, we send a single `Answer_sync_ledger_query` RPC to determine
       that the other peer will not serve us a genesis ledger.
    *)
    let%test_unit "Sync genesis ledgers to empty ledgers, should fail" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          let%bind (module Context) = make_context () in
          let staking_epoch_ledger =
            make_genesis_ledger (module Context) (List.take test_accounts 10)
          in
          let next_epoch_ledger = staking_epoch_ledger in
          setup_test ~name:"fail to sync genesis ledgers" ~test_number:3
            (module Context)
            ~staking_epoch_ledger ~next_epoch_ledger
          >>= cannot_sync_staking_ledger )
  end )
