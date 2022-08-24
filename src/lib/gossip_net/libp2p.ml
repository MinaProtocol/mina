open Core
open Async
open Network_peer
open Pipe_lib
open Network_peer.Rpc_intf

type ('q, 'r) dispatch =
  Versioned_rpc.Connection_with_menu.t -> 'q -> 'r Deferred.Or_error.t

module Connection_with_state = struct
  type t = Banned | Allowed of Rpc.Connection.t Ivar.t

  let value_map ~when_allowed ~when_banned t =
    match t with Allowed c -> when_allowed c | _ -> when_banned
end

type pubsub_topic_mode_t = RO | RW | N

let v1_topic_block = "mina/block/1.0.0"

let v1_topic_tx = "mina/tx/1.0.0"

let v1_topic_snark_work = "mina/snark-work/1.0.0"

let v1_topics = [ v1_topic_block; v1_topic_snark_work; v1_topic_tx ]

let v0_topic = "coda/consensus-messages/0.0.1"

module Config = struct
  type t =
    { timeout : Time.Span.t
    ; initial_peers : Mina_net2.Multiaddr.t list
    ; addrs_and_ports : Node_addrs_and_ports.t
    ; metrics_port : int option
    ; conf_dir : string
    ; chain_id : string
    ; logger : Logger.t
    ; unsafe_no_trust_ip : bool
    ; isolate : bool
    ; trust_system : Trust_system.t
    ; flooding : bool
    ; direct_peers : Mina_net2.Multiaddr.t list
    ; peer_exchange : bool
    ; mina_peer_exchange : bool
    ; seed_peer_list_url : Uri.t option
    ; min_connections : int
    ; time_controller : Block_time.Controller.t
    ; max_connections : int
    ; pubsub_v1 : pubsub_topic_mode_t
    ; pubsub_v0 : pubsub_topic_mode_t
    ; validation_queue_size : int
    ; mutable keypair : Mina_net2.Keypair.t option
    ; all_peers_seen_metric : bool
    ; known_private_ip_nets : Core.Unix.Cidr.t list
    }
  [@@deriving make]
end

module type S = sig
  include Intf.Gossip_net_intf

  val create :
       Config.t
    -> pids:Child_processes.Termination.t
    -> Rpc_intf.rpc_handler list
    -> Message.sinks
    -> t Deferred.t
end

let rpc_transport_proto = "coda/rpcs/0.0.1"

let download_seed_peer_list uri =
  let%bind _resp, body = Cohttp_async.Client.get uri in
  let%map contents = Cohttp_async.Body.to_string body in
  Mina_net2.Multiaddr.of_file_contents contents

type publish_functions =
  { publish_v0 : Message.msg -> unit Deferred.t
  ; publish_v1_block : Message.state_msg -> unit Deferred.t
  ; publish_v1_tx : Message.transaction_pool_diff_msg -> unit Deferred.t
  ; publish_v1_snark_work : Message.snark_pool_diff_msg -> unit Deferred.t
  }

let empty_publish_functions =
  { publish_v0 = (fun _ -> failwith "Call of uninitialized publish_v0")
  ; publish_v1_block =
      (fun _ -> failwith "Call of uninitialized publish_v1_block")
  ; publish_v1_tx = (fun _ -> failwith "Call of uninitialized publish_v1_tx")
  ; publish_v1_snark_work =
      (fun _ -> failwith "Call of uninitialized publish_v1_snark_work")
  }

let validate_gossip_base ~fn my_peer_id envelope validation_callback =
  (* Messages from ourselves are valid. Don't try and reingest them. *)
  match Envelope.Incoming.sender envelope with
  | Local ->
      Mina_net2.Validation_callback.fire_if_not_already_fired
        validation_callback `Accept ;
      Deferred.unit
  | Remote sender ->
      if not (Peer.Id.equal sender.peer_id my_peer_id) then
        (* Match on different cases *)
        fn (envelope, validation_callback)
      else (
        Mina_net2.Validation_callback.fire_if_not_already_fired
          validation_callback `Accept ;
        Deferred.unit )

let on_gossip_decode_failure (config : Config.t) envelope (err : Error.t) =
  let peer = Envelope.Incoming.sender envelope |> Envelope.Sender.remote_exn in
  let metadata =
    [ ("sender_peer_id", `String peer.peer_id)
    ; ("error", Error_json.error_to_yojson err)
    ]
  in
  Trust_system.(
    record config.trust_system config.logger peer
      Actions.
        (Decoding_failed, Some ("failed to decode gossip message", metadata)))
  |> don't_wait_for ;
  ()

module Make (Rpc_intf : Network_peer.Rpc_intf.Rpc_interface_intf) :
  S with module Rpc_intf := Rpc_intf = struct
  open Rpc_intf

  module T = struct
    type t =
      { config : Config.t
      ; mutable added_seeds : Peer.Hash_set.t
      ; net2 : Mina_net2.t Deferred.t ref
      ; first_peer_ivar : unit Ivar.t
      ; high_connectivity_ivar : unit Ivar.t
      ; ban_reader : Intf.ban_notification Linear_pipe.Reader.t
      ; publish_functions : publish_functions ref
      ; restart_helper : unit -> unit
      }

    let create_rpc_implementations
        (Rpc_handler { rpc; f = handler; cost; budget }) =
      let (module Impl) = implementation_of_rpc rpc in
      let logger = Logger.create () in
      let log_rate_limiter_occasionally rl =
        let t = Time.Span.of_min 1. in
        every t (fun () ->
            [%log' debug logger]
              ~metadata:
                [ ("rate_limiter", Network_pool.Rate_limiter.summary rl) ]
              !"%s $rate_limiter" Impl.name )
      in
      let rl = Network_pool.Rate_limiter.create ~capacity:budget in
      log_rate_limiter_occasionally rl ;
      let handler (peer : Network_peer.Peer.t) ~version q =
        Mina_metrics.(Counter.inc_one Network.rpc_requests_received) ;
        Mina_metrics.(Counter.inc_one @@ fst Impl.received_counter) ;
        Mina_metrics.(Gauge.inc_one @@ snd Impl.received_counter) ;
        let score = cost q in
        match
          Network_pool.Rate_limiter.add rl (Remote peer) ~now:(Time.now ())
            ~score
        with
        | `Capacity_exceeded ->
            failwithf "peer exceeded capacity: %s"
              (Network_peer.Peer.to_multiaddr_string peer)
              ()
        | `Within_capacity ->
            O1trace.thread (Printf.sprintf "handle_rpc_%s" Impl.name) (fun () ->
                handler peer ~version q )
      in
      Impl.implement_multi handler

    let prepare_stream_transport stream =
      (* Closing the connection calls close_read on the read
          pipe, which mina_net2 does not expect. To avoid this, add
          an extra pipe and don't propagate the close. We still want
          to close the connection because it flushes all the internal
          state machines and fills the `closed` ivar.

          Pipe.transfer isn't appropriate because it will close the
          real_r when read_w is closed, precisely what we don't want.
      *)
      let read_r, read_w = Pipe.create () in
      let underlying_r, underlying_w = Mina_net2.Libp2p_stream.pipes stream in
      don't_wait_for
        (Pipe.iter underlying_r ~f:(fun msg ->
             Pipe.write_without_pushback_if_open read_w msg ;
             Deferred.unit ) ) ;
      let transport =
        Async_rpc_kernel.Pipe_transport.(create Kind.string read_r underlying_w)
      in
      transport

    (* peers_snapshot is updated every 30 seconds.
*)
    let peers_snapshot = ref []

    let peers_snapshot_max_staleness = Time.Span.of_sec 30.

    (* Creates just the helper, making sure to register everything
       BEFORE we start listening/advertise ourselves for discovery. *)
    let create_libp2p (config : Config.t) rpc_handlers first_peer_ivar
        high_connectivity_ivar ~added_seeds ~pids ~on_unexpected_termination
        ~sinks:
          (Message.Any_sinks (sinksM, (sink_block, sink_tx, sink_snark_work))) =
      let module Sinks = (val sinksM) in
      let ctr = ref 0 in
      let record_peer_connection () =
        [%log' trace config.logger] "Fired peer_connected callback" ;
        Ivar.fill_if_empty first_peer_ivar () ;
        if !ctr < 4 then incr ctr
        else Ivar.fill_if_empty high_connectivity_ivar ()
      in
      let handle_mina_net2_exception exn =
        match exn with
        | Mina_net2.Libp2p_helper_died_unexpectedly ->
            on_unexpected_termination ()
        | _ ->
            raise exn
      in
      let%bind seeds_from_url =
        match config.seed_peer_list_url with
        | None ->
            Deferred.return []
        | Some u ->
            download_seed_peer_list u
      in
      let fail err =
        Error.tag err ~tag:"Failed to connect to libp2p_helper process"
        |> Error.raise
      in
      let conf_dir = config.conf_dir ^/ "mina_net2" in
      let%bind () = Unix.mkdir ~p:() conf_dir in
      match%bind
        Monitor.try_with ~here:[%here] ~rest:(`Call handle_mina_net2_exception)
          (fun () ->
            O1trace.thread "mina_net2" (fun () ->
                Mina_net2.create
                  ~all_peers_seen_metric:config.all_peers_seen_metric
                  ~on_peer_connected:(fun _ -> record_peer_connection ())
                  ~on_peer_disconnected:ignore ~logger:config.logger ~conf_dir
                  ~pids ) )
      with
      | Ok (Ok net2) -> (
          let open Mina_net2 in
          (* Make an ephemeral keypair for this session TODO: persist in the config dir *)
          let%bind me =
            match config.keypair with
            | Some kp ->
                return kp
            | None ->
                Mina_net2.generate_random_keypair net2
          in
          let my_peer_id = Keypair.to_peer_id me |> Peer.Id.to_string in
          Logger.append_to_global_metadata
            [ ("peer_id", `String my_peer_id)
            ; ( "host"
              , `String
                  (Unix.Inet_addr.to_string config.addrs_and_ports.external_ip)
              )
            ; ("port", `Int config.addrs_and_ports.libp2p_port)
            ] ;
          ( match config.addrs_and_ports.peer with
          | Some _ ->
              ()
          | None ->
              config.addrs_and_ports.peer <-
                Some
                  (Peer.create config.addrs_and_ports.bind_ip
                     ~libp2p_port:config.addrs_and_ports.libp2p_port
                     ~peer_id:my_peer_id ) ) ;
          [%log' info config.logger] "libp2p peer ID this session is $peer_id"
            ~metadata:[ ("peer_id", `String my_peer_id) ] ;
          let initializing_libp2p_result : _ Deferred.Or_error.t =
            [%log' debug config.logger] "(Re)initializing libp2p result" ;
            let open Deferred.Or_error.Let_syntax in
            let seed_peers =
              List.dedup_and_sort ~compare:Mina_net2.Multiaddr.compare
                (List.concat
                   [ config.initial_peers
                   ; seeds_from_url
                   ; List.map
                       ~f:
                         (Fn.compose Mina_net2.Multiaddr.of_string
                            Peer.to_multiaddr_string )
                       (Hash_set.to_list added_seeds)
                   ] )
            in
            let%bind () =
              configure net2 ~me ~metrics_port:config.metrics_port
                ~maddrs:
                  [ Multiaddr.of_string
                      (sprintf "/ip4/0.0.0.0/tcp/%d"
                         (Option.value_exn config.addrs_and_ports.peer)
                           .libp2p_port )
                  ]
                ~external_maddr:
                  (Multiaddr.of_string
                     (sprintf "/ip4/%s/tcp/%d"
                        (Unix.Inet_addr.to_string
                           config.addrs_and_ports.external_ip )
                        (Option.value_exn config.addrs_and_ports.peer)
                          .libp2p_port ) )
                ~network_id:config.chain_id
                ~unsafe_no_trust_ip:config.unsafe_no_trust_ip ~seed_peers
                ~direct_peers:config.direct_peers
                ~peer_exchange:config.peer_exchange
                ~mina_peer_exchange:config.mina_peer_exchange
                ~flooding:config.flooding
                ~min_connections:config.min_connections
                ~max_connections:config.max_connections
                ~validation_queue_size:config.validation_queue_size
                ~known_private_ip_nets:config.known_private_ip_nets
                ~initial_gating_config:
                  Mina_net2.
                    { banned_peers =
                        Trust_system.peer_statuses config.trust_system
                        |> List.filter_map ~f:(fun (peer, status) ->
                               match status.banned with
                               | Banned_until _ ->
                                   Some peer
                               | _ ->
                                   None )
                    ; trusted_peers =
                        List.filter_map ~f:Mina_net2.Multiaddr.to_peer
                          config.initial_peers
                    ; isolate = config.isolate
                    }
                ~topic_config:[ [ v0_topic ]; v1_topics ]
            in
            let implementation_list =
              List.bind rpc_handlers ~f:create_rpc_implementations
            in
            let implementations =
              let handle_unknown_rpc conn_state ~rpc_tag ~version =
                Deferred.don't_wait_for
                  Trust_system.(
                    record config.trust_system config.logger conn_state
                      Actions.
                        ( Unknown_rpc
                        , Some
                            ( "Attempt to make unknown (fixed-version) RPC \
                               call \"$rpc\" with version $version"
                            , [ ("rpc", `String rpc_tag)
                              ; ("version", `Int version)
                              ] ) )) ;
                `Close_connection
              in
              Rpc.Implementations.create_exn
                ~implementations:(Versioned_rpc.Menu.add implementation_list)
                ~on_unknown_rpc:(`Call handle_unknown_rpc)
            in
            let%bind () =
              O1trace.thread "handle_protocol_streams" (fun () ->
                  Mina_net2.open_protocol net2 ~on_handler_error:`Raise
                    ~protocol:rpc_transport_proto (fun stream ->
                      let peer = Mina_net2.Libp2p_stream.remote_peer stream in
                      let transport = prepare_stream_transport stream in
                      let open Deferred.Let_syntax in
                      match%bind
                        Async_rpc_kernel.Rpc.Connection.create ~implementations
                          ~connection_state:(Fn.const peer)
                          ~description:
                            (Info.of_thunk (fun () ->
                                 sprintf "stream from %s" peer.peer_id ) )
                          transport
                      with
                      | Error handshake_error ->
                          let%bind () =
                            Async_rpc_kernel.Rpc.Transport.close transport
                          in
                          don't_wait_for
                            (Mina_net2.reset_stream net2 stream >>| ignore) ;
                          Trust_system.(
                            record config.trust_system config.logger peer
                              Actions.
                                ( Incoming_connection_error
                                , Some
                                    ( "Handshake error: $exn"
                                    , [ ( "exn"
                                        , `String
                                            (Exn.to_string handshake_error) )
                                      ] ) ))
                      | Ok rpc_connection -> (
                          let%bind () =
                            Async_rpc_kernel.Rpc.Connection.close_finished
                              rpc_connection
                          in
                          let%bind () =
                            Async_rpc_kernel.Rpc.Connection.close
                              ~reason:(Info.of_string "connection completed")
                              rpc_connection
                          in
                          match%map Mina_net2.reset_stream net2 stream with
                          | Error e ->
                              [%log' warn config.logger]
                                "failed to reset stream (this means it was \
                                 probably closed successfully): $error"
                                ~metadata:
                                  [ ("error", Error_json.error_to_yojson e) ]
                          | Ok () ->
                              () ) ) )
            in
            let subscribe ~fn topic bin_prot =
              Mina_net2.Pubsub.subscribe_encode net2
                topic
                (* Fix for #4097: validation is tied into a lot of complex control flow.
                   Instead of refactoring it to have validation up-front and decoupled,
                   we pass along a validation callback with the message. This ends up
                   ignoring the actual subscription message pipe, so drain it separately. *)
                ~handle_and_validate_incoming_message:
                  (validate_gossip_base ~fn my_peer_id)
                ~bin_prot
                ~on_decode_failure:(`Call (on_gossip_decode_failure config))
            in
            let tx_bin_prot =
              Network_pool.Transaction_pool.Diff_versioned.Stable.Latest.bin_t
            in
            let snark_bin_prot =
              Network_pool.Snark_pool.Diff_versioned.Stable.Latest.bin_t
            in
            let block_bin_prot = Mina_block.Stable.Latest.bin_t in
            let unit_f _ = Deferred.unit in
            let publish_v1_impl push_impl bin_prot topic =
              match config.pubsub_v1 with
              | RW ->
                  subscribe ~fn:push_impl topic bin_prot >>| Pubsub.publish net2
              | RO ->
                  subscribe ~fn:push_impl topic bin_prot >>| fun _ -> unit_f
              | _ ->
                  Deferred.Or_error.return unit_f
            in
            let%bind publish_v1_tx =
              publish_v1_impl
                (Sinks.Tx_sink.push sink_tx)
                tx_bin_prot v1_topic_tx
            in
            let%bind publish_v1_snark_work =
              publish_v1_impl
                (Sinks.Snark_sink.push sink_snark_work)
                snark_bin_prot v1_topic_snark_work
            in
            let%bind publish_v1_block =
              publish_v1_impl
                (fun (env, vc) ->
                  Sinks.Block_sink.push sink_block
                    ( `Transition env
                    , `Time_received (Block_time.now config.time_controller)
                    , `Valid_cb vc ) )
                block_bin_prot v1_topic_block
            in
            let map_v0_msg msg =
              match msg with
              | Message.New_state state ->
                  Message.Latest.T.New_state state
              | Message.Transaction_pool_diff diff ->
                  Message.Latest.T.Transaction_pool_diff diff
              | Message.Snark_pool_diff diff ->
                  Message.Latest.T.Snark_pool_diff diff
            in
            let subscribe_v0_impl =
              subscribe
                ~fn:(fun (env, vc) ->
                  match Envelope.Incoming.data env with
                  | Message.Latest.T.New_state state ->
                      let transactions =
                        Mina_block.transactions state
                          ~constraint_constants:
                            Genesis_constants.Constraint_constants.compiled
                      in
                      let _valid_txns, too_big_txns =
                        List.partition_tf transactions ~f:(fun txn ->
                            Mina_transaction.Transaction.valid_size txn.data )
                      in
                      if not @@ List.is_empty too_big_txns then (
                        [%log' warn config.logger]
                          "Not accepting incoming block with %d too-big \
                           transactions"
                          (List.length too_big_txns) ;
                        [%log' debug config.logger]
                          "Rejected block with too-big transactions"
                          ~metadata:[ ("block", Mina_block.to_yojson state) ] ;
                        Deferred.unit )
                      else
                        Sinks.Block_sink.push sink_block
                          ( `Transition
                              (Envelope.Incoming.map ~f:(const state) env)
                          , `Time_received
                              (Block_time.now config.time_controller)
                          , `Valid_cb vc )
                  | Message.Latest.T.Transaction_pool_diff diff ->
                      Sinks.Tx_sink.push sink_tx
                        ( Envelope.Incoming.map
                            ~f:(fun _ ->
                              let valid_size_cmds, too_big_cmds =
                                List.partition_tf diff
                                  ~f:Mina_base.User_command.valid_size
                              in
                              if not @@ List.is_empty too_big_cmds then (
                                [%log' warn config.logger]
                                  "Not adding %d too-big user commands to \
                                   transaction pool"
                                  (List.length too_big_cmds) ;
                                [%log' debug config.logger]
                                  "Too-big user commands not added to \
                                   transaction pool"
                                  ~metadata:
                                    [ ( "user_commands"
                                      , `List
                                          (List.map too_big_cmds
                                             ~f:Mina_base.User_command.to_yojson )
                                      )
                                    ] ) ;
                              valid_size_cmds )
                            env
                        , vc )
                  | Message.Latest.T.Snark_pool_diff diff ->
                      Sinks.Snark_sink.push sink_snark_work
                        (Envelope.Incoming.map ~f:(fun _ -> diff) env, vc) )
                v0_topic Message.Latest.T.bin_msg
            in
            let%bind publish_v0 =
              match config.pubsub_v0 with
              | RW ->
                  subscribe_v0_impl >>| Pubsub.publish net2
                  >>| Fn.flip Fn.compose map_v0_msg
              | RO ->
                  subscribe_v0_impl >>| fun _ -> unit_f
              | _ ->
                  Deferred.Or_error.return unit_f
            in
            let%map _ =
              (* XXX: this ALWAYS needs to be AFTER handle_protocol/subscribe
                 or it is possible to miss connections! *)
              listen_on net2
                (Multiaddr.of_string
                   (sprintf "/ip4/%s/tcp/%d"
                      ( config.addrs_and_ports.bind_ip
                      |> Unix.Inet_addr.to_string )
                      (Option.value_exn config.addrs_and_ports.peer).libp2p_port ) )
            in
            let add_many xs ~is_seed =
              Deferred.map
                (Deferred.List.iter ~how:`Parallel xs ~f:(fun x ->
                     let open Deferred.Let_syntax in
                     Mina_net2.add_peer ~is_seed net2 x >>| ignore ) )
                ~f:(fun () -> Ok ())
            in
            don't_wait_for
              (Deferred.map
                 (let%bind () = add_many seed_peers ~is_seed:true
                  and () =
                    let seeds =
                      String.Hash_set.of_list
                        (List.map ~f:Multiaddr.to_string seed_peers)
                    in
                    add_many ~is_seed:false
                      (List.filter !peers_snapshot ~f:(fun p ->
                           not (Hash_set.mem seeds (Multiaddr.to_string p)) ) )
                  in
                  let%bind () = Mina_net2.begin_advertising net2 in
                  return () )
                 ~f:(function
                   | Ok () ->
                       ()
                   | Error e ->
                       [%log' warn config.logger]
                         "starting libp2p up failed: $error"
                         ~metadata:[ ("error", Error_json.error_to_yojson e) ]
                   ) ) ;
            { publish_v0
            ; publish_v1_block
            ; publish_v1_tx
            ; publish_v1_snark_work
            }
          in
          match%map initializing_libp2p_result with
          | Ok pfs ->
              (net2, pfs, me)
          | Error e ->
              fail e )
      | Ok (Error e) ->
          fail e
      | Error e ->
          fail (Error.of_exn e)

    let peers t = !(t.net2) >>= Mina_net2.peers

    let bandwidth_info t = !(t.net2) >>= Mina_net2.bandwidth_info

    let create (config : Config.t) ~pids rpc_handlers (sinks : Message.sinks) =
      let first_peer_ivar = Ivar.create () in
      let high_connectivity_ivar = Ivar.create () in
      let net2_ref = ref (Deferred.never ()) in
      let pfs_ref = ref empty_publish_functions in
      let restarts_r, restarts_w =
        Strict_pipe.create ~name:"libp2p-restarts"
          (Strict_pipe.Buffered
             (`Capacity 0, `Overflow (Strict_pipe.Drop_head ignore)) )
      in
      let added_seeds = Peer.Hash_set.create () in
      let%bind () =
        let rec on_libp2p_create res =
          net2_ref :=
            Deferred.map res ~f:(fun (n, _, _) ->
                ( match
                    Sys.getenv "MINA_LIBP2P_HELPER_RESTART_INTERVAL_BASE"
                  with
                | Some base_time ->
                    let restart_after =
                      let plus_or_minus initial ~delta =
                        initial +. (Random.float (2. *. delta) -. delta)
                      in
                      let base_time = Float.of_string base_time in
                      let delta =
                        Option.value_map ~f:Float.of_string
                          (Sys.getenv
                             "MINA_LIBP2P_HELPER_RESTART_INTERVAL_DELTA" )
                          ~default:2.5
                        |> Float.min (base_time /. 2.)
                      in
                      Time.Span.(of_min (base_time |> plus_or_minus ~delta))
                    in
                    don't_wait_for
                      ( after restart_after
                      >>= fun () -> Mina_net2.shutdown n >>| restart_libp2p )
                | None ->
                    () ) ;
                n ) ;
          let pf_impl f msg =
            let%bind _, pf, _ = res in
            f pf msg
          in
          pfs_ref :=
            { publish_v0 = pf_impl (fun pf -> pf.publish_v0)
            ; publish_v1_block = pf_impl (fun pf -> pf.publish_v1_block)
            ; publish_v1_tx = pf_impl (fun pf -> pf.publish_v1_tx)
            ; publish_v1_snark_work =
                pf_impl (fun pf -> pf.publish_v1_snark_work)
            } ;
          upon res (fun (_, _, me) ->
              (* This is a hack so that we keep the same keypair across restarts. *)
              config.keypair <- Some me ;
              let logger = config.logger in
              [%log trace] ~metadata:[] "Successfully restarted libp2p" )
        and start_libp2p () =
          let libp2p =
            create_libp2p config rpc_handlers first_peer_ivar
              high_connectivity_ivar ~added_seeds ~pids
              ~on_unexpected_termination:restart_libp2p ~sinks
          in
          on_libp2p_create libp2p ; Deferred.ignore_m libp2p
        and restart_libp2p () = don't_wait_for (start_libp2p ()) in
        don't_wait_for
          (Strict_pipe.Reader.iter restarts_r ~f:(fun () ->
               let%bind n = !net2_ref in
               let%bind () = Mina_net2.shutdown n in
               restart_libp2p () ; !net2_ref >>| ignore ) ) ;
        start_libp2p ()
      in
      let ban_configuration =
        ref { Mina_net2.banned_peers = []; trusted_peers = []; isolate = false }
      in
      let do_ban (banned_peer, expiration) =
        O1trace.thread "execute_gossip_net_bans" (fun () ->
            don't_wait_for
              ( Clock.at expiration
              >>= fun () ->
              let%bind net2 = !net2_ref in
              ban_configuration :=
                { !ban_configuration with
                  banned_peers =
                    List.filter !ban_configuration.banned_peers ~f:(fun p ->
                        not (Peer.equal p banned_peer) )
                } ;
              Mina_net2.set_connection_gating_config net2 !ban_configuration
              |> Deferred.ignore_m ) ;
            (let%bind net2 = !net2_ref in
             ban_configuration :=
               { !ban_configuration with
                 banned_peers = banned_peer :: !ban_configuration.banned_peers
               } ;
             Mina_net2.set_connection_gating_config net2 !ban_configuration )
            |> Deferred.ignore_m )
      in
      let%map () =
        Deferred.List.iter (Trust_system.peer_statuses config.trust_system)
          ~f:(function
          | ( addr
            , { banned = Trust_system.Banned_status.Banned_until expiration; _ }
            ) ->
              do_ban (addr, expiration)
          | _ ->
              Deferred.unit )
      in
      let ban_reader, ban_writer = Linear_pipe.create () in
      don't_wait_for
        (let%map () =
           Strict_pipe.Reader.iter
             (Trust_system.ban_pipe config.trust_system)
             ~f:do_ban
         in
         Linear_pipe.close ban_writer ) ;
      let t =
        { config
        ; added_seeds
        ; net2 = net2_ref
        ; first_peer_ivar
        ; high_connectivity_ivar
        ; publish_functions = pfs_ref
        ; ban_reader
        ; restart_helper = (fun () -> Strict_pipe.Writer.write restarts_w ())
        }
      in
      Clock.every' peers_snapshot_max_staleness (fun () ->
          O1trace.thread "snapshot_peers" (fun () ->
              let%map peers = peers t in
              Mina_metrics.(
                Gauge.set Network.peers (List.length peers |> Int.to_float)) ;
              peers_snapshot :=
                List.map peers
                  ~f:
                    (Fn.compose Mina_net2.Multiaddr.of_string
                       Peer.to_multiaddr_string ) ) ) ;
      t

    let set_node_status t data =
      !(t.net2) >>= Fn.flip Mina_net2.set_node_status data

    let get_peer_node_status t peer =
      !(t.net2)
      >>= Fn.flip Mina_net2.get_peer_node_status
            (Peer.to_multiaddr_string peer |> Mina_net2.Multiaddr.of_string)

    let initial_peers t = t.config.initial_peers

    let add_peer t p ~is_seed =
      let open Mina_net2 in
      if is_seed then Hash_set.add t.added_seeds p ;
      !(t.net2)
      >>= Fn.flip (add_peer ~is_seed)
            (Multiaddr.of_string (Peer.to_multiaddr_string p))

    (* OPTIMIZATION: use fast n choose k implementation - see python or old flow code *)
    let random_sublist xs n = List.take (List.permute xs) n

    let random_peers t n =
      let%map peers = peers t in
      random_sublist peers n

    let random_peers_except t n ~except =
      let%map peers = peers t in
      random_sublist
        Hash_set.(diff (Peer.Hash_set.of_list peers) except |> to_list)
        n

    let try_call_rpc_with_dispatch :
        type r q.
           ?heartbeat_timeout:Time_ns.Span.t
        -> ?timeout:Time.Span.t
        -> rpc_counter:Mina_metrics.Counter.t * Mina_metrics.Gauge.t
        -> rpc_failed_counter:Mina_metrics.Counter.t
        -> rpc_name:string
        -> t
        -> Peer.t
        -> Async.Rpc.Transport.t
        -> (r, q) dispatch
        -> r
        -> q Deferred.Or_error.t =
     fun ?heartbeat_timeout ?timeout ~rpc_counter ~rpc_failed_counter ~rpc_name
         t peer transport dispatch query ->
      let call () =
        Monitor.try_with ~here:[%here] (fun () ->
            (* Async_rpc_kernel takes a transport instead of a Reader.t *)
            Async_rpc_kernel.Rpc.Connection.with_close
              ~heartbeat_config:
                (Async_rpc_kernel.Rpc.Connection.Heartbeat_config.create
                   ~send_every:(Time_ns.Span.of_sec 10.)
                   ~timeout:
                     (Option.value ~default:(Time_ns.Span.of_sec 120.)
                        heartbeat_timeout )
                   () )
              ~connection_state:(Fn.const ())
              ~dispatch_queries:(fun conn ->
                Versioned_rpc.Connection_with_menu.create conn
                >>=? fun conn' ->
                Mina_metrics.(Counter.inc_one Network.rpc_requests_sent) ;
                Mina_metrics.(Counter.inc_one @@ fst rpc_counter) ;
                Mina_metrics.(Gauge.inc_one @@ snd rpc_counter) ;
                let d = dispatch conn' query in
                match timeout with
                | None ->
                    d
                | Some timeout ->
                    Deferred.choose
                      [ Deferred.choice d Fn.id
                      ; choice (after timeout) (fun () ->
                            Or_error.error_string "rpc timed out" )
                      ] )
              transport
              ~on_handshake_error:
                (`Call
                  (fun exn ->
                    let%map () =
                      Trust_system.(
                        record t.config.trust_system t.config.logger peer
                          Actions.
                            ( Outgoing_connection_error
                            , Some
                                ( "Handshake error: $exn"
                                , [ ("exn", `String (Exn.to_string exn)) ] ) ))
                    in
                    Or_error.error_string "handshake error" ) ) )
        >>= function
        | Ok (Ok result) ->
            (* call succeeded, result is valid *)
            Deferred.return (Ok result)
        | Ok (Error err) -> (
            (* call succeeded, result is an error *)
            [%log' warn t.config.logger] "RPC call error for $rpc"
              ~metadata:
                [ ("rpc", `String rpc_name)
                ; ("error", Error_json.error_to_yojson err)
                ] ;
            Mina_metrics.(Counter.inc_one rpc_failed_counter) ;
            match (Error.to_exn err, Error.sexp_of_t err) with
            | ( _
              , Sexp.List
                  [ Sexp.List
                      [ Sexp.Atom "rpc_error"
                      ; Sexp.List [ Sexp.Atom "Connection_closed"; _ ]
                      ]
                  ; _connection_description
                  ; _rpc_tag
                  ; _rpc_version
                  ] ) ->
                Mina_metrics.(Counter.inc_one Network.rpc_connections_failed) ;
                let%map () =
                  Trust_system.(
                    record t.config.trust_system t.config.logger peer
                      Actions.
                        ( Outgoing_connection_error
                        , Some ("Closed connection", []) ))
                in
                Error err
            | _ ->
                let%map () =
                  Trust_system.(
                    record t.config.trust_system t.config.logger peer
                      Actions.
                        ( Outgoing_connection_error
                        , Some
                            ( "RPC call failed, reason: $exn"
                            , [ ("exn", Error_json.error_to_yojson err) ] ) ))
                in
                Error err )
        | Error monitor_exn ->
            (* call itself failed *)
            (* TODO: learn what other exceptions are raised here *)
            Mina_metrics.(Counter.inc_one rpc_failed_counter) ;
            let exn = Monitor.extract_exn monitor_exn in
            let () =
              match Error.sexp_of_t (Error.of_exn exn) with
              | Sexp.List (Sexp.Atom "connection attempt timeout" :: _) ->
                  [%log' debug t.config.logger]
                    "RPC call for $rpc raised an exception"
                    ~metadata:
                      [ ("rpc", `String rpc_name)
                      ; ("exn", `String (Exn.to_string exn))
                      ]
              | _ ->
                  [%log' warn t.config.logger]
                    "RPC call for $rpc raised an exception"
                    ~metadata:
                      [ ("rpc", `String rpc_name)
                      ; ("exn", `String (Exn.to_string exn))
                      ]
            in
            Deferred.return (Or_error.of_exn exn)
      in
      call ()

    let try_call_rpc :
        type q r.
           ?heartbeat_timeout:Time_ns.Span.t
        -> ?timeout:Time.Span.t
        -> t
        -> Peer.t
        -> _
        -> (q, r) rpc
        -> q
        -> r Deferred.Or_error.t =
     fun ?heartbeat_timeout ?timeout t peer transport rpc query ->
      let (module Impl) = implementation_of_rpc rpc in
      try_call_rpc_with_dispatch ?heartbeat_timeout ?timeout
        ~rpc_counter:Impl.sent_counter
        ~rpc_failed_counter:Impl.failed_request_counter ~rpc_name:Impl.name t
        peer transport Impl.dispatch_multi query

    let query_peer ?heartbeat_timeout ?timeout t (peer_id : Peer.Id.t) rpc
        rpc_input =
      let%bind net2 = !(t.net2) in
      match%bind
        Mina_net2.open_stream net2 ~protocol:rpc_transport_proto ~peer:peer_id
      with
      | Ok stream ->
          let peer = Mina_net2.Libp2p_stream.remote_peer stream in
          let transport = prepare_stream_transport stream in
          try_call_rpc ?heartbeat_timeout ?timeout t peer transport rpc
            rpc_input
          >>| fun data ->
          Connected (Envelope.Incoming.wrap_peer ~data ~sender:peer)
      | Error e ->
          Mina_metrics.(Counter.inc_one Network.rpc_connections_failed) ;
          return (Failed_to_connect e)

    let query_peer' (type q r) ?how ?heartbeat_timeout ?timeout t
        (peer_id : Peer.Id.t) (rpc : (q, r) rpc) (qs : q list) =
      let%bind net2 = !(t.net2) in
      match%bind
        Mina_net2.open_stream net2 ~protocol:rpc_transport_proto ~peer:peer_id
      with
      | Ok stream ->
          let peer = Mina_net2.Libp2p_stream.remote_peer stream in
          let transport = prepare_stream_transport stream in
          let (module Impl) = implementation_of_rpc rpc in
          try_call_rpc_with_dispatch ?heartbeat_timeout ?timeout
            ~rpc_counter:Impl.sent_counter
            ~rpc_failed_counter:Impl.failed_request_counter ~rpc_name:Impl.name
            t peer transport
            (fun conn qs ->
              Deferred.Or_error.List.map ?how qs ~f:(fun q ->
                  Impl.dispatch_multi conn q ) )
            qs
          >>| fun data ->
          Connected (Envelope.Incoming.wrap_peer ~data ~sender:peer)
      | Error e ->
          Mina_metrics.(Counter.inc_one Network.rpc_connections_failed) ;
          return (Failed_to_connect e)

    let query_random_peers t n rpc query =
      let%map peers = random_peers t n in
      [%log' trace t.config.logger]
        !"Querying random peers: %s"
        (Peer.pretty_list peers) ;
      List.map peers ~f:(fun peer -> query_peer t peer.peer_id rpc query)

    (* Do not broadcast to the topic from which message was originally received *)
    let guard_topic ?origin_topic topic f msg =
      if Option.equal String.equal origin_topic (Some topic) then Deferred.unit
      else f msg

    (* broadcast to new topics  *)
    let broadcast_state ?origin_topic t state =
      let pfs = !(t.publish_functions) in
      let%bind () =
        guard_topic ?origin_topic v1_topic_block pfs.publish_v1_block state
      in
      guard_topic ?origin_topic v0_topic pfs.publish_v0 (Message.New_state state)

    let broadcast_transaction_pool_diff ?origin_topic t diff =
      let pfs = !(t.publish_functions) in
      let%bind () =
        guard_topic ?origin_topic v1_topic_tx pfs.publish_v1_tx diff
      in
      guard_topic ?origin_topic v0_topic pfs.publish_v0
        (Message.Transaction_pool_diff diff)

    let broadcast_snark_pool_diff ?origin_topic t diff =
      let pfs = !(t.publish_functions) in
      let%bind () =
        guard_topic ?origin_topic v1_topic_snark_work pfs.publish_v1_snark_work
          diff
      in
      guard_topic ?origin_topic v0_topic pfs.publish_v0
        (Message.Snark_pool_diff diff)

    let on_first_connect t ~f = Deferred.map (Ivar.read t.first_peer_ivar) ~f

    let on_first_high_connectivity t ~f =
      Deferred.map (Ivar.read t.high_connectivity_ivar) ~f

    let ban_notification_reader t = t.ban_reader

    let connection_gating t =
      let%map net2 = !(t.net2) in
      Mina_net2.connection_gating_config net2

    let set_connection_gating t config =
      let%bind net2 = !(t.net2) in
      Mina_net2.set_connection_gating_config net2 config

    let restart_helper t = t.restart_helper ()
  end

  include T
end
