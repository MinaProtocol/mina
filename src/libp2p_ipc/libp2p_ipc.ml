open Async
open Core
open Stdint
open Pipe_lib
open Network_peer

(* TODO: convert most of these return values from builders to readers *)

include Ipc
module Rpcs = Rpcs
module Build = Build
open Build

exception Received_undefined_union of string * int

module Make_capnp_unique_id (Capnp_id : sig
  type t

  val of_uint64 : Uint64.t -> t

  val to_uint64 : t -> Uint64.t
end)
() =
struct
  module Uid = Unique_id.Int63 ()

  let of_int63 n = n |> Int63.to_int64 |> Uint64.of_int64 |> Capnp_id.of_uint64

  let to_int63 capnp_id =
    capnp_id |> Capnp_id.to_uint64 |> Uint64.to_int64 |> Int63.of_int64_exn

  let of_uid (uid : Uid.t) = of_int63 (uid :> Int63.t)

  module T = struct
    type t = Capnp_id.t

    let sexp_of_t = Fn.compose Int63.sexp_of_t to_int63

    let t_of_sexp = Fn.compose of_int63 Int63.t_of_sexp

    let hash = Fn.compose Int63.hash to_int63

    let hash_fold_t state id = id |> to_int63 |> Int63.hash_fold_t state

    let compare a b = Int63.compare (to_int63 a) (to_int63 b)
  end

  include T
  include Comparable.Make (T)
  include Hashable.Make (T)

  let to_string = Fn.compose Uint64.to_string Capnp_id.to_uint64

  let create () = of_uid (Uid.create ())
end

module Sequence_number =
  Make_capnp_unique_id
    (struct
      type t = sequence_number

      let of_uint64 n =
        build
          (module Builder.SequenceNumber)
          (op Builder.SequenceNumber.seqno_set n)

      let to_uint64 = Reader.SequenceNumber.seqno_get
    end)
    ()

module Subscription_id =
  Make_capnp_unique_id
    (struct
      type t = subscription_id

      let of_uint64 n =
        build
          (module Builder.SubscriptionId)
          (op Builder.SubscriptionId.id_set n)

      let to_uint64 = Reader.SubscriptionId.id_get
    end)
    ()

let undefined_union ~context n = raise (Received_undefined_union (context, n))

let () =
  Stdlib.Printexc.register_printer (function
    | Received_undefined_union (ctx, n) ->
        Some
          (Printf.sprintf
             "Received an undefined union for %s over the libp2p IPC: %n " ctx
             n)
    | _ ->
        None)

let compression = `None

let now () =
  let now_int64 =
    (* can we make this int time? worried about float truncation *)
    Time_ns.now () |> Time_ns.to_span_since_epoch |> Time_ns.Span.to_ns
    |> Int64.of_float
  in
  build (module Builder.UnixNano) Builder.UnixNano.(op nano_sec_set now_int64)

let unsafe_parse_peer_id peer_id =
  peer_id |> Reader.PeerId.id_get |> Peer.Id.unsafe_of_string

let unsafe_parse_peer peer_info =
  let open Reader.PeerInfo in
  let libp2p_port = libp2p_port_get peer_info in
  let host = Unix.Inet_addr.of_string (host_get peer_info) in
  let peer_id = unsafe_parse_peer_id (peer_id_get peer_info) in
  Peer.create host ~libp2p_port ~peer_id

let stream_id_to_string = Fn.compose Uint64.to_string Reader.StreamId.id_get

let multiaddr_to_string = Reader.Multiaddr.representation_get

let unix_nano_to_time_span unix_nano =
  unix_nano |> Reader.UnixNano.nano_sec_get |> Float.of_int64
  |> Time_ns.Span.of_ns |> Time_ns.of_span_since_epoch

let create_multiaddr representation =
  build'
    (module Builder.Multiaddr)
    (op Builder.Multiaddr.representation_set representation)

let create_peer_id peer_id =
  build' (module Builder.PeerId) (op Builder.PeerId.id_set peer_id)

let create_libp2p_config ~private_key ~statedir ~listen_on ?metrics_port
    ~external_multiaddr ~network_id ~unsafe_no_trust_ip ~flood ~direct_peers
    ~seed_peers ~peer_exchange ~mina_peer_exchange ~max_connections
    ~validation_queue_size ~gating_config =
  build
    (module Builder.Libp2pConfig)
    Builder.Libp2pConfig.(
      op private_key_set private_key
      *> op statedir_set statedir
      *> list_op listen_on_set_list listen_on
      *> optional op metrics_port_set_exn metrics_port
      *> builder_op external_multiaddr_set_builder external_multiaddr
      *> op network_id_set network_id
      *> op unsafe_no_trust_ip_set unsafe_no_trust_ip
      *> op flood_set flood
      *> list_op direct_peers_set_list direct_peers
      *> list_op seed_peers_set_list seed_peers
      *> op peer_exchange_set peer_exchange
      *> op mina_peer_exchange_set mina_peer_exchange
      *> op max_connections_set_int_exn max_connections
      *> op validation_queue_size_set_int_exn validation_queue_size
      *> reader_op gating_config_set_reader gating_config)

let create_gating_config ~banned_ips ~banned_peers ~trusted_ips ~trusted_peers
    ~isolate =
  build
    (module Builder.GatingConfig)
    Builder.GatingConfig.(
      list_op banned_ips_set_list banned_ips
      *> list_op banned_peer_ids_set_list banned_peers
      *> list_op trusted_ips_set_list trusted_ips
      *> list_op trusted_peer_ids_set_list trusted_peers
      *> op isolate_set isolate)

let create_rpc_header ~sequence_number =
  build'
    (module Builder.RpcMessageHeader)
    Builder.RpcMessageHeader.(
      reader_op time_sent_set_reader (now ())
      *> reader_op sequence_number_set_reader sequence_number)

let rpc_request_body_set req body =
  let open Builder.Libp2pHelperInterface.RpcRequest in
  match body with
  | Configure b ->
      ignore @@ configure_set_builder req b
  | SetGatingConfig b ->
      ignore @@ set_gating_config_set_builder req b
  | Listen b ->
      ignore @@ listen_set_builder req b
  | GetListeningAddrs b ->
      ignore @@ get_listening_addrs_set_builder req b
  | BeginAdvertising b ->
      ignore @@ begin_advertising_set_builder req b
  | AddPeer b ->
      ignore @@ add_peer_set_builder req b
  | ListPeers b ->
      ignore @@ list_peers_set_builder req b
  | BandwidthInfo b ->
      ignore @@ bandwidth_info_set_builder req b
  | GenerateKeypair b ->
      ignore @@ generate_keypair_set_builder req b
  | Publish b ->
      ignore @@ publish_set_builder req b
  | Subscribe b ->
      ignore @@ subscribe_set_builder req b
  | Unsubscribe b ->
      ignore @@ unsubscribe_set_builder req b
  | AddStreamHandler b ->
      ignore @@ add_stream_handler_set_builder req b
  | RemoveStreamHandler b ->
      ignore @@ remove_stream_handler_set_builder req b
  | OpenStream b ->
      ignore @@ open_stream_set_builder req b
  | CloseStream b ->
      ignore @@ close_stream_set_builder req b
  | ResetStream b ->
      ignore @@ reset_stream_set_builder req b
  | SendStream b ->
      ignore @@ send_stream_set_builder req b
  | SetNodeStatus b ->
      ignore @@ set_node_status_set_builder req b
  | GetPeerNodeStatus b ->
      ignore @@ get_peer_node_status_set_builder req b
  | Undefined _ ->
      failwith "cannot set undefined rpc request body"

let create_rpc_request ~sequence_number body =
  let header = create_rpc_header ~sequence_number in
  build'
    (module Builder.Libp2pHelperInterface.RpcRequest)
    Builder.Libp2pHelperInterface.RpcRequest.(
      builder_op header_set_builder header *> op rpc_request_body_set body)

let rpc_response_to_or_error resp =
  let open Reader.Libp2pHelperInterface.RpcResponse in
  match get resp with
  | Error err ->
      Or_error.error_string err
  | Success body ->
      Or_error.return (Reader.Libp2pHelperInterface.RpcResponseSuccess.get body)
  | Undefined n ->
      undefined_union ~context:"Libp2pHelperInterface.RpcResponse" n

let rpc_request_to_outgoing_message request =
  build'
    (module Builder.Libp2pHelperInterface.Message)
    Builder.Libp2pHelperInterface.Message.(
      builder_op rpc_request_set_builder request)

let create_push_message_header () =
  build'
    (module Builder.PushMessageHeader)
    Builder.PushMessageHeader.(reader_op time_sent_set_reader (now ()))

let push_message_to_outgoing_message request =
  build'
    (module Builder.Libp2pHelperInterface.Message)
    Builder.Libp2pHelperInterface.Message.(
      builder_op push_message_set_builder request)

let create_push_message ~validation_id ~validation_result =
  build'
    (module Builder.Libp2pHelperInterface.PushMessage)
    Builder.Libp2pHelperInterface.PushMessage.(
      builder_op header_set_builder (create_push_message_header ())
      *> reader_op validation_set_reader
           (build
              (module Builder.Libp2pHelperInterface.Validation)
              Builder.Libp2pHelperInterface.Validation.(
                reader_op validation_id_set_reader validation_id
                *> op result_set validation_result)))

(* TODO: carefully think about the scheduling implications of this. *)
(* TODO: maybe IPC delay metrics should go here instead? *)
let stream_messages pipe =
  let open Capnp.Codecs in
  let stream = FramedStream.empty compression in
  let complete = ref false in
  let r, w = Strict_pipe.(create Synchronous) in
  let rec read_frames () =
    match FramedStream.get_next_frame stream with
    | Ok msg ->
        let%bind () = Strict_pipe.Writer.write w (Ok msg) in
        read_frames ()
    | Error FramingError.Unsupported ->
        complete := true ;
        Strict_pipe.Writer.write w
          (Or_error.error_string "unsupported capnp frame header")
    | Error FramingError.Incomplete ->
        Deferred.unit
  in

  let rec scheduler_loop () =
    let%bind () = Scheduler.yield () in
    if !complete then Deferred.unit
    else
      let%bind () = read_frames () in
      scheduler_loop ()
  in
  don't_wait_for
    (let%map () =
       Strict_pipe.Reader.iter pipe
         ~f:(Fn.compose Deferred.return (FramedStream.add_fragment stream))
     in
     complete := true) ;
  don't_wait_for (scheduler_loop ()) ;
  r

let read_incoming_messages reader =
  Strict_pipe.Reader.map (stream_messages reader)
    ~f:(Or_error.map ~f:Reader.DaemonInterface.Message.of_message)

let write_outgoing_message writer msg =
  msg |> Builder.Libp2pHelperInterface.Message.to_message
  |> Capnp.Codecs.serialize_iter ~compression ~f:(Writer.write writer)
