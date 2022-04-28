open Ipc

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

module Configure : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.Configure.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.Configure.Response.t

  val create_request : libp2p_config:libp2p_config -> Request.t
end

module SetGatingConfig : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.SetGatingConfig.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.SetGatingConfig.Response.t

  val create_request : gating_config:gating_config -> Request.t
end

module Listen : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.Listen.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.Listen.Response.t

  val create_request : iface:multiaddr -> Request.t
end

module GetListeningAddrs : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.GetListeningAddrs.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.GetListeningAddrs.Response.t

  val create_request : unit -> Request.t
end

module BeginAdvertising : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.BeginAdvertising.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.BeginAdvertising.Response.t

  val create_request : unit -> Request.t
end

module AddPeer : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.AddPeer.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.AddPeer.Response.t

  val create_request : multiaddr:multiaddr -> is_seed:bool -> Request.t
end

module ListPeers : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.ListPeers.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.ListPeers.Response.t

  val create_request : unit -> Request.t
end

module BandwidthInfo : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.BandwidthInfo.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.BandwidthInfo.Response.t

  val create_request : unit -> Request.t
end

module GenerateKeypair : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.GenerateKeypair.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.GenerateKeypair.Response.t

  val create_request : unit -> Request.t
end

module Publish : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.Publish.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.Publish.Response.t

  val create_request : topic:string -> data:string -> Request.t
end

module Subscribe : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.Subscribe.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.Subscribe.Response.t

  val create_request :
    topic:string -> subscription_id:subscription_id -> Request.t
end

module Unsubscribe : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.Unsubscribe.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.Unsubscribe.Response.t

  val create_request : subscription_id:subscription_id -> Request.t
end

module AddStreamHandler : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.AddStreamHandler.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.AddStreamHandler.Response.t

  val create_request : protocol:string -> Request.t
end

module RemoveStreamHandler : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.RemoveStreamHandler.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.RemoveStreamHandler.Response.t

  val create_request : protocol:string -> Request.t
end

module OpenStream : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.OpenStream.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.OpenStream.Response.t

  val create_request : peer_id:Builder.PeerId.t -> protocol:string -> Request.t
end

module CloseStream : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.CloseStream.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.CloseStream.Response.t

  val create_request : stream_id:stream_id -> Request.t
end

module ResetStream : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.ResetStream.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.ResetStream.Response.t

  val create_request : stream_id:stream_id -> Request.t
end

module SendStream : sig
  include
    Rpc_intf
      with type Request.t = Builder.Libp2pHelperInterface.SendStream.Request.t
       and type Response.t = Reader.Libp2pHelperInterface.SendStream.Response.t

  val create_request : stream_id:stream_id -> data:string -> Request.t
end

module SetNodeStatus : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.SetNodeStatus.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.SetNodeStatus.Response.t

  val create_request : data:string -> Request.t
end

module GetPeerNodeStatus : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.GetPeerNodeStatus.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.GetPeerNodeStatus.Response.t

  val create_request : peer_multiaddr:multiaddr -> Request.t
end

module TestDecodeBitswapBlocks : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.TestDecodeBitswapBlocks.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.TestDecodeBitswapBlocks.Response.t

  val create_request :
    blocks:(Blake2.t * string) list -> root_block_hash:Blake2.t -> Request.t
end

module TestEncodeBitswapBlocks : sig
  include
    Rpc_intf
      with type Request.t =
            Builder.Libp2pHelperInterface.TestEncodeBitswapBlocks.Request.t
       and type Response.t =
            Reader.Libp2pHelperInterface.TestEncodeBitswapBlocks.Response.t

  val create_request : max_block_size:int -> data:string -> Request.t
end
