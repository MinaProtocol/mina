open Core
open Async
open Network_peer

let%test_module "Gossip_net.Libp2p RPC tests" =
  ( module struct
    module Echo = struct
      type ctx = unit

      type query = string

      type response = string

      let name = "echo"

      let rpc =
        Rpc.Rpc.create ~name ~version:1 ~bin_query:String.bin_t
          ~bin_response:String.bin_t

      let versions () = Int.Set.singleton 1

      let sent_counter = Mina_metrics.Network.get_some_initial_peers_rpcs_sent

      let received_counter =
        Mina_metrics.Network.get_some_initial_peers_rpcs_received

      let failed_request_counter =
        Mina_metrics.Network.get_some_initial_peers_rpc_requests_failed

      let failed_response_counter =
        Mina_metrics.Network.get_some_initial_peers_rpc_responses_failed

      let implement_multi ?log_not_previously_seen_version:_ handler =
        [ Rpc.Rpc.implement rpc (fun peer query ->
              handler peer ~version:1 query )
        ]

      let dispatch_multi conn query =
        Rpc.Rpc.dispatch rpc
          (Versioned_rpc.Connection_with_menu.connection conn)
          query

      let log_request_received ~logger:_ ~sender:_ _ = ()

      let receipt_trust_action_message _ = ("echo", [])

      let handle_request () ~version:_ request =
        return (Envelope.Incoming.data request)

      let response_is_successful _ = true

      let rate_limit_cost _ = 1

      let rate_limit_budget = (100_000, `Per Time.Span.minute)
    end

    module Rpc_interface = struct
      type ctx = unit

      type ('query, 'response) rpc = Echo : (string, string) rpc

      type any_rpc = Rpc : ('query, 'response) rpc -> any_rpc

      let all_rpcs = [ Rpc Echo ]

      let implementation :
          type q r. (q, r) rpc -> (ctx, q, r) Gossip_net.rpc_implementation =
        function
        | Echo ->
            (module Echo)
    end

    module Net = Gossip_net.Make (Rpc_interface)

    module Sinks = struct
      module Block_sink = struct
        type t = unit

        let push () _ = Deferred.unit
      end

      module Tx_sink = Block_sink
      module Snark_sink = Block_sink

      type t = Block_sink.t * Tx_sink.t * Snark_sink.t
    end

    let sinks = Net.Message.Any_sinks ((module Sinks), ((), (), ()))

    (* Records the messages logged to loggers created with [id] *)
    let capture_logs ~id =
      let captured = Queue.create () in
      let module Capture = struct
        type t = Logger.Message.t Queue.t

        let process captured msg = Queue.enqueue captured msg ; None

        let accepts _ _ = true
      end in
      Logger.Consumer_registry.register ~id
        ~processor:(Logger.Processor.create (module Capture) captured)
        ~transport:(Logger.Transport.raw ignore)
        () ;
      captured

    let pids = Child_processes.Termination.create_pid_table ()

    let free_port () =
      let socket =
        Core.Unix.socket ~domain:PF_INET ~kind:SOCK_STREAM ~protocol:0 ()
      in
      Core.Unix.bind socket ~addr:(ADDR_INET (Core.Unix.Inet_addr.localhost, 0)) ;
      let port =
        match Core.Unix.getsockname socket with
        | ADDR_INET (_, port) ->
            port
        | ADDR_UNIX _ ->
            failwith "Expected an internet address"
      in
      Core.Unix.close socket ; port

    let create_node ~name ~logger ~initial_peers =
      let%bind conf_dir = Unix.mkdtemp ("gossip_net_test_" ^ name) in
      let libp2p_port = free_port () in
      let config : Gossip_net.Libp2p.Config.t =
        { timeout = Time.Span.of_sec 3.
        ; initial_peers
        ; addrs_and_ports =
            { external_ip = Core.Unix.Inet_addr.localhost
            ; bind_ip = Core.Unix.Inet_addr.localhost
            ; peer = None
            ; libp2p_port
            ; client_port = 0
            }
        ; metrics_port = None
        ; mina_net_location = conf_dir ^/ "mina_net2"
        ; chain_id = "gossip_net_test"
        ; logger
        ; unsafe_no_trust_ip = true
        ; isolate = false
        ; trust_system = Trust_system.null ()
        ; flooding = false
        ; direct_peers = []
        ; peer_exchange = false
        ; peer_protection_ratio = 0.2
        ; seed_peer_list_url = None
        ; min_connections = 1
        ; time_controller = Block_time.Controller.basic ~logger
        ; max_connections = 50
        ; pubsub_v1 = N
        ; pubsub_v0 = N
        ; validation_queue_size = 150
        ; keypair = None
        ; all_peers_seen_metric = false
        ; known_private_ip_nets = []
        }
      in
      let%map t =
        Net.Libp2p.create ~allow_multiple_instances:true config ~pids () sinks
      in
      let peer_id =
        Mina_net2.Keypair.to_peer_id (Option.value_exn config.keypair)
      in
      let maddr =
        Mina_net2.Multiaddr.of_string
          (sprintf "/ip4/127.0.0.1/tcp/%d/p2p/%s" libp2p_port peer_id)
      in
      (t, peer_id, maddr)

    let%test_unit "many sequential RPCs to one peer are answered cleanly" =
      let () = Core.Backtrace.elide := false in
      let test_def () =
        let open Deferred.Let_syntax in
        let server_logs = capture_logs ~id:"gossip_net_test_server" in
        let server_logger = Logger.create ~id:"gossip_net_test_server" () in
        let%bind _server, server_peer_id, server_maddr =
          create_node ~name:"server" ~logger:server_logger ~initial_peers:[]
        in
        let%bind client, _, _ =
          create_node ~name:"client" ~logger:(Logger.null ())
            ~initial_peers:[ server_maddr ]
        in
        let%bind () = Net.Libp2p.on_first_connect client ~f:Fn.id in
        (* Far more RPCs than a peer accepts streams at once for a single
           protocol from a single peer *)
        let num_rpcs = 300 in
        let%bind () =
          Deferred.List.iter (List.range 0 num_rpcs) ~f:(fun i ->
              let query = sprintf "ping %d" i in
              match%map
                Net.Libp2p.query_peer client server_peer_id Rpc_interface.Echo
                  query
              with
              | Connected envelope -> (
                  match Envelope.Incoming.data envelope with
                  | Ok response ->
                      [%test_eq: string] response query
                  | Error e ->
                      failwithf "RPC %d failed: %s" i (Error.to_string_hum e) ()
                  )
              | Failed_to_connect e ->
                  failwithf "RPC %d failed to connect: %s" i
                    (Error.to_string_hum e) () )
        in
        (* Leave time for the server's RPC heartbeats to fire *)
        let%map () = after (Time.Span.of_sec 15.) in
        let problems =
          Queue.filter server_logs ~f:(fun msg ->
              match msg.level with Warn | Error | Fatal -> true | _ -> false )
          |> Queue.to_list
        in
        let summary =
          List.map problems ~f:(fun msg ->
              ( Logger.Level.show msg.level
              , msg.message
              , Yojson.Safe.to_string (`Assoc (String.Map.to_alist msg.metadata))
              ) )
          |> List.sort ~compare:(fun (l1, m1, _) (l2, m2, _) ->
                 [%compare: string * string] (l1, m1) (l2, m2) )
          |> List.group ~break:(fun (l1, m1, _) (l2, m2, _) ->
                 not ([%equal: string * string] (l1, m1) (l2, m2)) )
          |> List.map ~f:(fun group ->
                 let level, message, metadata = List.hd_exn group in
                 sprintf "%d x [%s] %s (e.g. %s)" (List.length group) level
                   message metadata )
        in
        if not (List.is_empty summary) then
          failwithf "The server logged %d problems:\n%s" (List.length problems)
            (String.concat ~sep:"\n" summary)
            ()
      in
      Async.Thread_safe.block_on_async_exn test_def
  end )
