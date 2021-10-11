open Core
open Async
open Async_unix
open Network_peer
module Keypair = Keypair
module Libp2p_stream = Libp2p_stream
module Multiaddr = Multiaddr
module Validation_callback = Validation_callback
module Sink = Sink

exception
  Libp2p_helper_died_unexpectedly = Libp2p_helper
                                    .Libp2p_helper_died_unexpectedly

(** Set of peers, represented as a host/port pair. We ignore the peer ID so
    that the same node restarting and attaining a new peer ID will not be
    double (or triple, etc.) counted.
*)
module Peer_without_id = struct
  module T = struct
    type t = { libp2p_port : int; host : string }
    [@@deriving sexp, compare, yojson]
  end

  include T
  module Set = Set.Make (T)

  let of_peer ({ libp2p_port; host; _ } : Peer.t) =
    { libp2p_port; host = Unix.Inet_addr.to_string host }
end

(* TODO: connection gating info is currently stored in to places, that needs to be fixed... *)
type connection_gating =
  { banned_peers : Peer.t list; trusted_peers : Peer.t list; isolate : bool }

let gating_config_to_helper_format (config : connection_gating) =
  let trusted_ips =
    List.map ~f:(fun p -> Unix.Inet_addr.to_string p.host) config.trusted_peers
  in
  let banned_ips =
    let trusted = String.Set.of_list trusted_ips in
    List.filter_map
      ~f:(fun p ->
        let p = Unix.Inet_addr.to_string p.host in
        (* Trusted peers cannot be banned. *)
        if Set.mem trusted p then None else Some p)
      config.banned_peers
  in
  let banned_peers =
    List.map
      ~f:(fun p -> Libp2p_ipc.create_peer_id p.peer_id)
      config.banned_peers
  in
  let trusted_peers =
    List.map
      ~f:(fun p -> Libp2p_ipc.create_peer_id p.peer_id)
      config.trusted_peers
  in
  Libp2p_ipc.create_gating_config ~banned_ips ~banned_peers ~trusted_ips
    ~trusted_peers ~isolate:config.isolate

type protocol_handler =
  { protocol_name : string
  ; mutable closed : bool
  ; on_handler_error :
      [ `Raise | `Ignore | `Call of Libp2p_stream.t -> exn -> unit ]
  ; handler : Libp2p_stream.t -> unit Deferred.t
  }

type t =
  { conf_dir : string
  ; helper : Libp2p_helper.t
  ; logger : Logger.t
  ; my_keypair : Keypair.t Ivar.t
  ; subscriptions : Subscription.e Subscription.Id.Table.t
        (* we use string as the key here because there is no hashable instance for Uint64.t *)
  ; streams : Libp2p_stream.t String.Table.t
  ; protocol_handlers : protocol_handler String.Table.t
  ; mutable connection_gating : connection_gating
  ; mutable all_peers_seen : Peer_without_id.Set.t option
  ; mutable banned_ips : Unix.Inet_addr.t list
  ; peer_connected_callback : string -> unit
  ; peer_disconnected_callback : string -> unit
  }

let banned_ips t = t.banned_ips

let connection_gating_config t = t.connection_gating

let me t = Ivar.read t.my_keypair

(** TODO: graceful shutdown. Reset all our streams, sync the databases, then
    shutdown. Replace kill invocation with an RPC. *)
let shutdown t = Libp2p_helper.shutdown t.helper

let generate_random_keypair t = Keypair.generate_random t.helper

module Pubsub = struct
  type 'a subscription = 'a Subscription.t

  let subscribe_raw t topic ~handle_and_validate_incoming_message ~encode
      ~decode ~on_decode_failure =
    let open Deferred.Or_error.Let_syntax in
    (* Linear scan over all subscriptions. Should generally be small, probably not a problem. *)
    let topic_subscription_already_exists =
      Hashtbl.data t.subscriptions
      |> List.exists ~f:(fun (Subscription.E sub') ->
             String.equal (Subscription.topic sub') topic)
    in
    if topic_subscription_already_exists then
      Deferred.Or_error.errorf "already subscribed to topic %s" topic
    else
      let%map sub =
        Subscription.subscribe ~helper:t.helper ~topic ~encode ~decode
          ~on_decode_failure ~validator:handle_and_validate_incoming_message
      in
      Hashtbl.add_exn t.subscriptions ~key:(Subscription.id sub)
        ~data:(Subscription.E sub) ;
      sub

  let subscribe_encode t topic ~handle_and_validate_incoming_message ~bin_prot
      ~on_decode_failure =
    subscribe_raw
      ~decode:(fun msg_str ->
        let b = Bigstring.of_string msg_str in
        Bigstring.read_bin_prot b bin_prot.Bin_prot.Type_class.reader
        |> Or_error.map ~f:fst)
      ~encode:(fun msg ->
        Bin_prot.Utils.bin_dump ~header:true bin_prot.Bin_prot.Type_class.writer
          msg
        |> Bigstring.to_string)
      ~handle_and_validate_incoming_message ~on_decode_failure t topic

  let subscribe =
    subscribe_raw ~encode:Fn.id ~decode:Or_error.return
      ~on_decode_failure:`Ignore

  let unsubscribe t = Subscription.unsubscribe ~helper:t.helper

  let publish t = Subscription.publish ~logger:t.logger ~helper:t.helper

  let publish_raw t = Subscription.publish_raw ~logger:t.logger ~helper:t.helper
end

let set_node_status t data =
  Libp2p_helper.do_rpc t.helper
    (module Libp2p_ipc.Rpcs.SetNodeStatus)
    (Libp2p_ipc.Rpcs.SetNodeStatus.create_request ~data)
  |> Deferred.Or_error.ignore_m

let get_peer_node_status t peer =
  let open Deferred.Or_error.Let_syntax in
  let peer_multiaddr = Multiaddr.to_libp2p_ipc peer in
  let%map response =
    Libp2p_helper.do_rpc t.helper
      (module Libp2p_ipc.Rpcs.GetPeerNodeStatus)
      (Libp2p_ipc.Rpcs.GetPeerNodeStatus.create_request ~peer_multiaddr)
  in
  let open Libp2p_ipc.Reader.Libp2pHelperInterface.GetPeerNodeStatus.Response in
  result_get response

let list_peers t =
  match%map
    Libp2p_helper.do_rpc t.helper
      (module Libp2p_ipc.Rpcs.ListPeers)
      (Libp2p_ipc.Rpcs.ListPeers.create_request ())
  with
  | Ok response ->
      let open Libp2p_ipc.Reader.Libp2pHelperInterface.ListPeers.Response in
      let peers = result_get_list response in
      (* FIXME #4039: filter_map shouldn't be necessary *)
      peers
      |> List.map ~f:Libp2p_ipc.unsafe_parse_peer
      |> List.filter ~f:(fun peer -> not (Int.equal peer.libp2p_port 0))
  | Error error ->
      [%log' error t.logger]
        "Encountered $error while asking libp2p_helper for peers"
        ~metadata:[ ("error", Error_json.error_to_yojson error) ] ;
      []

let bandwidth_info t =
  Deferred.Or_error.map ~f:(fun response ->
      let open Libp2p_ipc.Reader.Libp2pHelperInterface.BandwidthInfo.Response in
      let input_bandwidth = input_bandwidth_get response
      and output_bandwidth = output_bandwidth_get response
      and cpu_usage = cpu_usage_get response in
      (`Input input_bandwidth, `Output output_bandwidth, `Cpu_usage cpu_usage))
  @@ Libp2p_helper.do_rpc t.helper
       (module Libp2p_ipc.Rpcs.BandwidthInfo)
       (Libp2p_ipc.Rpcs.BandwidthInfo.create_request ())

(* `on_new_peer` fires whenever a peer connects OR disconnects *)
let configure t ~me ~external_maddr ~maddrs ~network_id ~metrics_port
    ~unsafe_no_trust_ip ~flooding ~direct_peers ~peer_exchange
    ~mina_peer_exchange ~seed_peers ~initial_gating_config ~min_connections
    ~max_connections ~validation_queue_size =
  let open Deferred.Or_error.Let_syntax in
  let libp2p_config =
    Libp2p_ipc.create_libp2p_config ~private_key:(Keypair.secret me)
      ~statedir:t.conf_dir
      ~listen_on:(List.map ~f:Multiaddr.to_libp2p_ipc maddrs)
      ?metrics_port
      ~external_multiaddr:(Multiaddr.to_libp2p_ipc external_maddr)
      ~network_id ~unsafe_no_trust_ip ~flood:flooding
      ~direct_peers:(List.map ~f:Multiaddr.to_libp2p_ipc direct_peers)
      ~seed_peers:(List.map ~f:Multiaddr.to_libp2p_ipc seed_peers)
      ~peer_exchange ~mina_peer_exchange ~min_connections ~max_connections
      ~validation_queue_size
      ~gating_config:(gating_config_to_helper_format initial_gating_config)
  in
  let%map _ =
    Libp2p_helper.do_rpc t.helper
      (module Libp2p_ipc.Rpcs.Configure)
      (Libp2p_ipc.Rpcs.Configure.create_request ~libp2p_config)
  in
  t.connection_gating <- initial_gating_config ;
  Ivar.fill_if_empty t.my_keypair me

(** List of all peers we are currently connected to. *)
let peers t = list_peers t

let listen_on t iface =
  let open Deferred.Or_error.Let_syntax in
  let%map response =
    Libp2p_helper.do_rpc t.helper
      (module Libp2p_ipc.Rpcs.Listen)
      (Libp2p_ipc.Rpcs.Listen.create_request
         ~iface:(Multiaddr.to_libp2p_ipc iface))
  in
  let open Libp2p_ipc.Reader.Libp2pHelperInterface.Listen.Response in
  result_get_list response |> List.map ~f:Multiaddr.of_libp2p_ipc

let listening_addrs t =
  let open Deferred.Or_error.Let_syntax in
  let%map response =
    Libp2p_helper.do_rpc t.helper
      (module Libp2p_ipc.Rpcs.GetListeningAddrs)
      (Libp2p_ipc.Rpcs.GetListeningAddrs.create_request ())
  in
  let open Libp2p_ipc.Reader.Libp2pHelperInterface.GetListeningAddrs.Response in
  result_get_list response |> List.map ~f:Multiaddr.of_libp2p_ipc

let open_protocol t ~on_handler_error ~protocol f =
  let open Deferred.Or_error.Let_syntax in
  let protocol_handler =
    { closed = false; on_handler_error; handler = f; protocol_name = protocol }
  in
  if Hashtbl.mem t.protocol_handlers protocol then
    Deferred.Or_error.errorf "already handling protocol %s" protocol
  else
    let%map _ =
      Libp2p_helper.do_rpc t.helper
        (module Libp2p_ipc.Rpcs.AddStreamHandler)
        (Libp2p_ipc.Rpcs.AddStreamHandler.create_request ~protocol)
    in
    Hashtbl.add_exn t.protocol_handlers ~key:protocol ~data:protocol_handler

let close_protocol ?(reset_existing_streams = false) t ~protocol =
  let%map result =
    Libp2p_helper.do_rpc t.helper
      (module Libp2p_ipc.Rpcs.RemoveStreamHandler)
      (Libp2p_ipc.Rpcs.RemoveStreamHandler.create_request ~protocol)
  in
  if reset_existing_streams then
    Hashtbl.filter_inplace t.streams ~f:(fun stream ->
        if not (String.equal (Libp2p_stream.protocol stream) protocol) then true
        else (
          don't_wait_for
            (* TODO: this probably needs to be more thorough than a reset. Also force the write pipe closed? *)
            ( match%map Libp2p_stream.reset ~helper:t.helper stream with
            | Ok () ->
                ()
            | Error e ->
                [%log' error t.logger]
                  "failed to reset stream while closing protocol: $error"
                  ~metadata:[ ("error", `String (Error.to_string_hum e)) ] ) ;
          false )) ;
  match result with
  | Ok _ ->
      Hashtbl.remove t.protocol_handlers protocol
  | Error e ->
      [%log' info t.logger]
        "error while closing handler for $protocol, closing connections \
         anyway: $err"
        ~metadata:
          [ ("protocol", `String protocol)
          ; ("err", Error_json.error_to_yojson e)
          ]

let release_stream t id =
  Hashtbl.remove t.streams (Libp2p_ipc.stream_id_to_string id)

let open_stream t ~protocol ~peer =
  let open Deferred.Or_error.Let_syntax in
  let peer_id = Libp2p_ipc.create_peer_id (Peer.Id.to_string peer) in
  let%map stream =
    Libp2p_stream.open_ ~logger:t.logger ~helper:t.helper ~protocol ~peer_id
      ~release_stream:(release_stream t)
  in
  Hashtbl.add_exn t.streams
    ~key:(Libp2p_ipc.stream_id_to_string (Libp2p_stream.id stream))
    ~data:stream ;
  stream

let reset_stream t = Libp2p_stream.reset ~helper:t.helper

let add_peer t maddr ~is_seed =
  Libp2p_ipc.Rpcs.AddPeer.create_request
    ~multiaddr:(Multiaddr.to_libp2p_ipc maddr)
    ~is_seed
  |> Libp2p_helper.do_rpc t.helper (module Libp2p_ipc.Rpcs.AddPeer)
  |> Deferred.Or_error.ignore_m

let begin_advertising t =
  Libp2p_ipc.Rpcs.BeginAdvertising.create_request ()
  |> Libp2p_helper.do_rpc t.helper (module Libp2p_ipc.Rpcs.BeginAdvertising)
  |> Deferred.Or_error.ignore_m

let set_connection_gating_config t config =
  match%map
    Libp2p_helper.do_rpc t.helper
      (module Libp2p_ipc.Rpcs.SetGatingConfig)
      (Libp2p_ipc.Rpcs.SetGatingConfig.create_request
         ~gating_config:(gating_config_to_helper_format config))
  with
  | Ok _ ->
      t.connection_gating <- config ;
      config
  | Error e ->
      Error.tag e ~tag:"Unexpected error doing setGatingConfig" |> Error.raise

let handle_push_message t push_message =
  let open Libp2p_ipc.Reader in
  let open DaemonInterface in
  let open PushMessage in
  match push_message with
  | PeerConnected m ->
      let peer_id =
        Libp2p_ipc.unsafe_parse_peer_id (PeerConnected.peer_id_get m)
      in
      t.peer_connected_callback peer_id
  | PeerDisconnected m ->
      let peer_id =
        Libp2p_ipc.unsafe_parse_peer_id (PeerDisconnected.peer_id_get m)
      in
      t.peer_disconnected_callback peer_id
  | GossipReceived m -> (
      let open GossipReceived in
      let data = data_get m in
      let subscription_id = subscription_id_get m in
      let sender = Libp2p_ipc.unsafe_parse_peer (sender_get m) in
      let validation_id = validation_id_get m in
      let validation_expiration =
        Libp2p_ipc.unix_nano_to_time_span (expiration_get m)
      in
      match Hashtbl.find t.subscriptions subscription_id with
      | Some (Subscription.E sub) ->
          upon
            (Subscription.handle_and_validate sub ~validation_expiration ~sender
               ~data) (function
            | `Validation_timeout ->
                [%log' warn t.logger]
                  "validation callback timed out before we could respond"
            | `Decoding_error e ->
                [%log' error t.logger]
                  "failed to decode message published on subscription $topic \
                   ($subscription_id): $error"
                  ~metadata:
                    [ ("topic", `String (Subscription.topic sub))
                    ; ( "subscription_id"
                      , `String (Subscription.Id.to_string subscription_id) )
                    ; ("error", Error_json.error_to_yojson e)
                    ] ;
                Libp2p_helper.send_validation t.helper ~validation_id
                  ~validation_result:ValidationResult.Reject
            | `Validation_result validation_result ->
                Libp2p_helper.send_validation t.helper ~validation_id
                  ~validation_result)
      | None ->
          [%log' error t.logger]
            "asked to validate message for unregistered subscription id \
             $subscription_id"
            ~metadata:
              [ ( "subscription_id"
                , `String (Subscription.Id.to_string subscription_id) )
              ] )
  (* A new inbound stream was opened *)
  | IncomingStream m -> (
      let open IncomingStream in
      let stream_id = stream_id_get m in
      let protocol = protocol_get m in
      let peer = Libp2p_ipc.unsafe_parse_peer (peer_get m) in
      Option.iter t.all_peers_seen ~f:(fun all_peers_seen ->
          let all_peers_seen =
            Set.add all_peers_seen (Peer_without_id.of_peer peer)
          in
          t.all_peers_seen <- Some all_peers_seen ;
          Mina_metrics.(
            Gauge.set Network.all_peers
              (Set.length all_peers_seen |> Int.to_float))) ;
      let stream =
        Libp2p_stream.create_from_existing ~logger:t.logger ~helper:t.helper
          ~stream_id ~protocol ~peer ~release_stream:(release_stream t)
      in
      match Hashtbl.find t.protocol_handlers protocol with
      | Some ph ->
          if not ph.closed then (
            Hashtbl.add_exn t.streams
              ~key:(Libp2p_ipc.stream_id_to_string stream_id)
              ~data:stream ;
            don't_wait_for
              (let open Deferred.Let_syntax in
              (* Call the protocol handler. If it throws an exception,
                  handle it according to [on_handler_error]. Mimics
                  [Tcp.Server.create]. See [handle_protocol] doc comment.
              *)
              match%map
                Monitor.try_with ~here:[%here] ~extract_exn:true (fun () ->
                    ph.handler stream)
              with
              | Ok () ->
                  ()
              | Error e -> (
                  try
                    match ph.on_handler_error with
                    | `Raise ->
                        raise e
                    | `Ignore ->
                        ()
                    | `Call f ->
                        f stream e
                  with handler_exn ->
                    ph.closed <- true ;
                    don't_wait_for
                      (let%map result =
                         Libp2p_helper.do_rpc t.helper
                           (module Libp2p_ipc.Rpcs.RemoveStreamHandler)
                           (Libp2p_ipc.Rpcs.RemoveStreamHandler.create_request
                              ~protocol)
                       in
                       if Or_error.is_ok result then
                         Hashtbl.remove t.protocol_handlers protocol) ;
                    raise handler_exn )) )
          else
            (* silently ignore new streams for closed protocol handlers.
                these are buffered stream open RPCs that were enqueued before
                our close went into effect. *)
            (* TODO: we leak the new pipes here*)
            [%log' warn t.logger]
              "incoming stream for protocol that is being closed after error"
      | None ->
          (* TODO: punish *)
          [%log' error t.logger]
            "incoming stream for protocol we don't know about?" )
  (* Received a message on some stream *)
  | StreamMessageReceived m -> (
      let open StreamMessageReceived in
      let open StreamMessage in
      let msg = msg_get m in
      let stream_id = stream_id_get msg in
      let data = data_get msg in
      match
        Hashtbl.find t.streams (Libp2p_ipc.stream_id_to_string stream_id)
      with
      | Some stream ->
          Libp2p_stream.data_received stream data
      | None ->
          [%log' error t.logger]
            "incoming stream message for stream we don't know about?" )
  (* Stream was reset, either by the remote peer or an error on our end. *)
  | StreamLost m ->
      let open StreamLost in
      let stream_id = stream_id_get m in
      let reason = reason_get m in
      let stream_id_str = Libp2p_ipc.stream_id_to_string stream_id in
      ( match Hashtbl.find t.streams stream_id_str with
      | Some stream ->
          let (`Stream_should_be_released should_release) =
            Libp2p_stream.stream_closed ~logger:t.logger ~who_closed:Them stream
          in
          if should_release then Hashtbl.remove t.streams stream_id_str
      | None ->
          () ) ;
      [%log' trace t.logger]
        "Encountered error while reading stream $id: $error"
        ~metadata:
          [ ("error", `String reason)
          ; ("id", `String (Libp2p_ipc.stream_id_to_string stream_id))
          ]
  (* The remote peer closed its write end of one of our streams *)
  | StreamComplete m -> (
      let open StreamComplete in
      let stream_id = stream_id_get m in
      let stream_id_str = Libp2p_ipc.stream_id_to_string stream_id in
      match Hashtbl.find t.streams stream_id_str with
      | Some stream ->
          let (`Stream_should_be_released should_release) =
            Libp2p_stream.stream_closed ~logger:t.logger ~who_closed:Them stream
          in
          if should_release then Hashtbl.remove t.streams stream_id_str
      | None ->
          [%log' error t.logger]
            "streamReadComplete for stream we don't know about $stream_id"
            ~metadata:[ ("stream_id", `String stream_id_str) ] )
  | ResourceUpdated _ ->
      [%log' error t.logger] "resourceUpdated upcall not supported yet"
  | Undefined n ->
      Libp2p_ipc.undefined_union ~context:"DaemonInterface.PushMessage" n

let create ~all_peers_seen_metric ~logger ~pids ~conf_dir ~on_peer_connected
    ~on_peer_disconnected =
  let open Deferred.Or_error.Let_syntax in
  let push_message_handler =
    ref (fun _msg ->
        [%log error]
          "received push message from libp2p_helper before handler was attached")
  in
  let%bind helper =
    Libp2p_helper.spawn ~logger ~pids ~conf_dir
      ~handle_push_message:(fun _helper msg ->
        Deferred.return (!push_message_handler msg))
  in
  let t =
    { helper
    ; conf_dir
    ; logger
    ; banned_ips = []
    ; connection_gating =
        { banned_peers = []; trusted_peers = []; isolate = false }
    ; my_keypair = Ivar.create ()
    ; subscriptions = Subscription.Id.Table.create ()
    ; streams = String.Table.create ()
    ; all_peers_seen =
        (if all_peers_seen_metric then Some Peer_without_id.Set.empty else None)
    ; peer_connected_callback =
        (fun peer_id -> on_peer_connected (Peer.Id.unsafe_of_string peer_id))
    ; peer_disconnected_callback =
        (fun peer_id -> on_peer_disconnected (Peer.Id.unsafe_of_string peer_id))
    ; protocol_handlers = Hashtbl.create (module String)
    }
  in
  (push_message_handler := fun msg -> handle_push_message t msg) ;
  ( if all_peers_seen_metric then
    let log_all_peers_interval = Time.Span.of_hr 2.0 in
    let log_message_batch_size = 50 in
    every log_all_peers_interval (fun () ->
        Option.iter t.all_peers_seen ~f:(fun all_peers_seen ->
            let num_batches, num_in_batch, batches, batch =
              Set.fold_right all_peers_seen ~init:(0, 0, [], [])
                ~f:(fun peer (num_batches, num_in_batch, batches, batch) ->
                  if num_in_batch >= log_message_batch_size then
                    (num_batches + 1, 1, batch :: batches, [ peer ])
                  else (num_batches, num_in_batch + 1, batches, peer :: batch))
            in
            let num_batches, batches =
              if num_in_batch > 0 then (num_batches + 1, batch :: batches)
              else (num_batches, batches)
            in
            List.iteri batches ~f:(fun batch_num batch ->
                [%log info]
                  "All peers seen by this node, batch $batch_num/$num_batches"
                  ~metadata:
                    [ ("batch_num", `Int batch_num)
                    ; ("num_batches", `Int num_batches)
                    ; ( "peers"
                      , `List (List.map ~f:Peer_without_id.to_yojson batch) )
                    ]))) ) ;
  Deferred.Or_error.return t
