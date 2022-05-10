(* TODO: it would be a good idea to code generate this file from the capnp definitions, if feasible *)

open Build
open Ipc
open Core_kernel

module type Rpc_intf = sig
  val name : string

  module Request : sig
    type t

    val to_rpc_request_body : t -> rpc_request_body
  end

  module Response : sig
    type t

    val of_rpc_response_body : rpc_response_body -> t option
  end
end

type ('a, 'b) rpc =
  (module Rpc_intf with type Request.t = 'a and type Response.t = 'b)

module Configure = struct
  let name = "Configure"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.Configure.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.Configure req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.Configure.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.Configure resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~libp2p_config =
    let open Builder.Libp2pHelperInterface.Configure in
    build' (module Request) (reader_op Request.config_set_reader libp2p_config)
end

module SetGatingConfig = struct
  let name = "SetGatingConfig"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.SetGatingConfig.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.SetGatingConfig req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.SetGatingConfig.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.SetGatingConfig resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~gating_config =
    let open Builder.Libp2pHelperInterface.SetGatingConfig in
    build'
      (module Request)
      (reader_op Request.gating_config_set_reader gating_config)
end

module Listen = struct
  let name = "Listen"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.Listen.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.Listen req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.Listen.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.Listen resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~iface =
    let open Builder.Libp2pHelperInterface.Listen in
    build' (module Request) (builder_op Request.iface_set_builder iface)
end

module GetListeningAddrs = struct
  let name = "GetListeningAddrs"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.GetListeningAddrs.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.GetListeningAddrs req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.GetListeningAddrs.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.GetListeningAddrs resp
        ->
          Some resp
      | _ ->
          None
  end

  let create_request () =
    build' (module Builder.Libp2pHelperInterface.GetListeningAddrs.Request) noop
end

module BeginAdvertising = struct
  let name = "BeginAdvertising"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.BeginAdvertising.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.BeginAdvertising req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.BeginAdvertising.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.BeginAdvertising resp ->
          Some resp
      | _ ->
          None
  end

  let create_request () =
    build' (module Builder.Libp2pHelperInterface.BeginAdvertising.Request) noop
end

module AddPeer = struct
  let name = "AddPeer"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.AddPeer.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.AddPeer req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.AddPeer.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.AddPeer resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~multiaddr ~is_seed =
    let open Builder.Libp2pHelperInterface.AddPeer in
    build'
      (module Request)
      Request.(
        builder_op multiaddr_set_builder multiaddr *> op is_seed_set is_seed)
end

module ListPeers = struct
  let name = "ListPeers"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.ListPeers.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.ListPeers req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.ListPeers.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.ListPeers resp ->
          Some resp
      | _ ->
          None
  end

  let create_request () =
    build' (module Builder.Libp2pHelperInterface.ListPeers.Request) noop
end

module BandwidthInfo = struct
  let name = "BandwidthInfo"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.BandwidthInfo.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.BandwidthInfo req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.BandwidthInfo.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.BandwidthInfo resp ->
          Some resp
      | _ ->
          None
  end

  let create_request () =
    build' (module Builder.Libp2pHelperInterface.BandwidthInfo.Request) noop
end

module GenerateKeypair = struct
  let name = "GenerateKeypair"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.GenerateKeypair.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.GenerateKeypair req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.GenerateKeypair.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.GenerateKeypair resp ->
          Some resp
      | _ ->
          None
  end

  let create_request () =
    build' (module Builder.Libp2pHelperInterface.GenerateKeypair.Request) noop
end

module Publish = struct
  let name = "Publish"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.Publish.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.Publish req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.Publish.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.Publish resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~topic ~data =
    let open Builder.Libp2pHelperInterface.Publish in
    build' (module Request) Request.(op topic_set topic *> op data_set data)
end

module Subscribe = struct
  let name = "Subscribe"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.Subscribe.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.Subscribe req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.Subscribe.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.Subscribe resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~topic ~subscription_id =
    let open Builder.Libp2pHelperInterface.Subscribe in
    build'
      (module Request)
      Request.(
        op topic_set topic
        *> reader_op subscription_id_set_reader subscription_id)
end

module Unsubscribe = struct
  let name = "Unsubscribe"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.Unsubscribe.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.Unsubscribe req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.Unsubscribe.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.Unsubscribe resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~subscription_id =
    let open Builder.Libp2pHelperInterface.Unsubscribe in
    build'
      (module Request)
      Request.(reader_op subscription_id_set_reader subscription_id)
end

module AddStreamHandler = struct
  let name = "AddStreamHandler"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.AddStreamHandler.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.AddStreamHandler req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.AddStreamHandler.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.AddStreamHandler resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~protocol =
    let open Builder.Libp2pHelperInterface.AddStreamHandler in
    build' (module Request) Request.(op protocol_set protocol)
end

module RemoveStreamHandler = struct
  let name = "RemoveStreamHandler"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.RemoveStreamHandler.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.RemoveStreamHandler req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.RemoveStreamHandler.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.RemoveStreamHandler resp
        ->
          Some resp
      | _ ->
          None
  end

  let create_request ~protocol =
    let open Builder.Libp2pHelperInterface.RemoveStreamHandler in
    build' (module Request) (op Request.protocol_set protocol)
end

module OpenStream = struct
  let name = "OpenStream"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.OpenStream.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.OpenStream req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.OpenStream.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.OpenStream resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~peer_id ~protocol =
    let open Builder.Libp2pHelperInterface.OpenStream in
    build'
      (module Request)
      Request.(
        builder_op peer_set_builder peer_id *> op protocol_id_set protocol)
end

module CloseStream = struct
  let name = "CloseStream"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.CloseStream.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.CloseStream req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.CloseStream.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.CloseStream resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~stream_id =
    let open Builder.Libp2pHelperInterface.CloseStream in
    build' (module Request) Request.(reader_op stream_id_set_reader stream_id)
end

module ResetStream = struct
  let name = "ResetStream"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.ResetStream.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.ResetStream req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.ResetStream.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.ResetStream resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~stream_id =
    let open Builder.Libp2pHelperInterface.ResetStream in
    build' (module Request) Request.(reader_op stream_id_set_reader stream_id)
end

module SendStream = struct
  let name = "SendStream"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.SendStream.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.SendStream req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.SendStream.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.SendStream resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~stream_id ~data =
    let open Builder in
    let open Libp2pHelperInterface.SendStream in
    build'
      (module Request)
      Request.(
        reader_op Request.msg_set_reader
          (build
             (module StreamMessage)
             ( reader_op StreamMessage.stream_id_set_reader stream_id
             *> op StreamMessage.data_set data )))
end

module SetNodeStatus = struct
  let name = "SetNodeStatus"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.SetNodeStatus.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.SetNodeStatus req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.SetNodeStatus.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.SetNodeStatus resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~data =
    let open Builder.Libp2pHelperInterface.SetNodeStatus in
    build' (module Request) Request.(op Request.status_set data)
end

module GetPeerNodeStatus = struct
  let name = "GetPeerNodeStatus"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.GetPeerNodeStatus.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.GetPeerNodeStatus req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.GetPeerNodeStatus.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.GetPeerNodeStatus resp
        ->
          Some resp
      | _ ->
          None
  end

  let create_request ~peer_multiaddr =
    let open Builder.Libp2pHelperInterface.GetPeerNodeStatus in
    build'
      (module Request)
      Request.(builder_op Request.peer_set_builder peer_multiaddr)
end

module TestDecodeBitswapBlocks = struct
  let name = "TestDecodeBitswapBlocks"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.TestDecodeBitswapBlocks.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.TestDecodeBitswapBlocks req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.TestDecodeBitswapBlocks.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.TestDecodeBitswapBlocks
          resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~blocks ~root_block_hash =
    let open Builder.Libp2pHelperInterface.TestDecodeBitswapBlocks in
    build'
      (module Request)
      ( list_op Request.blocks_set_list
          (List.map blocks ~f:(fun (hash, block) ->
               build'
                 (module Builder.BlockWithId)
                 ( op Builder.BlockWithId.blake2b_hash_set
                     (Blake2.to_raw_string hash)
                 *> op Builder.BlockWithId.block_set block )))
      *> builder_op Request.root_block_id_set_builder
           (build'
              (module Builder.RootBlockId)
              (op Builder.RootBlockId.blake2b_hash_set
                 (Blake2.to_raw_string root_block_hash))) )
end

module TestEncodeBitswapBlocks = struct
  let name = "TestEncodeBitswapBlocks"

  module Request = struct
    type t = Builder.Libp2pHelperInterface.TestEncodeBitswapBlocks.Request.t

    let to_rpc_request_body req =
      Builder.Libp2pHelperInterface.RpcRequest.TestEncodeBitswapBlocks req
  end

  module Response = struct
    type t = Reader.Libp2pHelperInterface.TestEncodeBitswapBlocks.Response.t

    let of_rpc_response_body = function
      | Reader.Libp2pHelperInterface.RpcResponseSuccess.TestEncodeBitswapBlocks
          resp ->
          Some resp
      | _ ->
          None
  end

  let create_request ~max_block_size ~data =
    let open Builder.Libp2pHelperInterface.TestEncodeBitswapBlocks in
    build'
      (module Request)
      ( op Request.data_set data
      *> op Request.max_block_size_set_int max_block_size )
end
