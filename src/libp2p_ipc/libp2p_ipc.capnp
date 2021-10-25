using Go = import "/go.capnp";
@0xfb174cb3ecf64f4f;
$Go.package("libp2p_ipc");
$Go.import("libp2p_ipc");

struct Multiaddr {
  representation @0 :Text;
}

struct PeerId {
  id @0 :Text;
}

struct AddrInfo {
  peerId @0 :PeerId;
  addrs @1 :List(Multiaddr);
}

struct PeerInfo {
  libp2pPort @0 :UInt16;
  host @1 :Text;
  peerId @2 :PeerId;
}

struct StreamId {
  id @0 :UInt64;
}

struct SubscriptionId {
  id @0 :UInt64;
}

struct Libp2pKeypair {
  privateKey @0 :Text;
  publicKey @1 :Text;
  peerId @2 :PeerId;
}

struct GatingConfig {
  bannedIps @0 :List(Text);
  bannedPeerIds @1 :List(Text);
  trustedIps @2 :List(Text);
  trustedPeerIds @3 :List(Text);
  isolate @4 :Bool;
}

struct Libp2pConfig {
  statedir @0 :Text;
  privateKey @1 :Text;
  networkId @2 :Text;
  listenOn @3 :List(Text);
  metricsPort @4 :Int16;
  externalMultiaddr @5 :Text;
  unsafeNoTrustIp @6 :Bool;
  flood @7 :Bool;
  peerExchange @8 :Bool;
  directPeers @9 :List(Text);
  seedPeers @10 :List(Text);
  gatingConfig @11 :GatingConfig;
  maxConnections @12 :UInt32;
  validationQueueSize @13 :UInt32;
  minaPeerExchange @14 :Bool;
}

enum ValidationResult {
  accept @0;
  reject @1;
  ignore @2;
}

struct StreamMessage {
  id @0 :StreamId;
  data @1 :Data;
}

struct PushMessageHeader {
  timeSent @0 :UInt64;
}

struct RpcMessageHeader {
  timeSent @0 :UInt64;
  seqNumber @1 :UInt64;
}

# all messages in the libp2p_helper interface are Rpc calls, except for validations
struct Libp2pHelperInterface {
  struct Configure {
    struct Request {
      config @0 :Libp2pConfig;
    }

    struct Response {}
  }

  struct SetGatingConfig  {
    struct Request {
      gatingConfig @0 :GatingConfig;
    }

    struct Response {}
  }

  struct Listen {
    struct Request {
      iface @0 :Text;
    }

    struct Response {
      result @0 :List(Multiaddr);
    }
  }

  struct GetListeningAddrs {
    struct Request {}

    struct Response {
      result @0 :List(Multiaddr);
    }
  }

  struct BeginAdvertising {
    struct Request {}

    struct Response {}
  }

  struct AddPeer {
    struct Request {
      multiaddr @0 :Multiaddr;
      isSeed @1 :Bool;
    }

    struct Response {
      result @0 :AddrInfo;
    }
  }

  struct ListPeers {
    struct Request {}

    struct Response {
      result @0 :List(PeerInfo);
    }
  }

  struct GenerateKeypair {
    struct Request {}

    struct Response {
      result @0 :Libp2pKeypair;
    }
  }

  struct Publish {
    struct Request {
      topic @0 :Text;
      data @1 :Data;
    }

    struct Response {}
  }

  struct Subscribe {
    struct Request {
      topic @0 :Text;
      subscriptionId @1 :UInt64;
    }

    struct Response {}
  }

  # do we use this anymore?
  struct Unsubscribe {
   struct Request {
      subscriptionId @0 :SubscriptionId;
    }

    struct Response {}
  }

  struct AddStreamHandler {
   struct Request {
      protocol @0 :Text;
    }

    struct Response {}
  }

  # do we use this anymore?
  struct RemoveStreamHandler {
   struct Request {
      protocol @0 :Text;
    }

    struct Response {}
  }

  struct OpenStream {
   struct Request {
      peer @0 :Text;
      protocolId @1 :Text;
    }

    struct Response {
      id @0 :StreamId;
      peer @1 :PeerInfo;
    }
  }

  struct CloseStream {
   struct Request {
      streamId @0 :StreamId;
    }

    struct Response {}
  }

  struct ResetStream {
   struct Request {
      streamId @0 :StreamId;
    }

    struct Response {}
  }

  struct SendStream {
   struct Request {
      msg @0 :StreamMessage;
    }

    struct Response {}
  }

  struct SetNodeStatus {
   struct Request {
      status @0 :Data;
    }

    struct Response {}
  }

  struct GetPeerNodeStatus {
   struct Request {
      peer @0 :Multiaddr;
    }

    struct Response {
      result @0 :Data;
    }
  }

  # validation is a special push message where the sequence number
  # corresponds to the the push message sent to the daemon in the
  # GossipReceived message
  struct Validation {
    validationSeqNumber @0 :UInt64;
    result @1 :ValidationResult;
  }

  struct RpcRequest {
    header @0 :RpcMessageHeader;

    union {
      configure @1 :Libp2pHelperInterface.Configure.Request;
      setGatingConfig @2 :Libp2pHelperInterface.SetGatingConfig.Request;
      listen @3 :Libp2pHelperInterface.Listen.Request;
      getListeningAddrs @4 :Libp2pHelperInterface.GetListeningAddrs.Request;
      beginAdvertising @5 :Libp2pHelperInterface.BeginAdvertising.Request;
      addPeer @6 :Libp2pHelperInterface.AddPeer.Request;
      listPeers @7 :Libp2pHelperInterface.ListPeers.Request;
      generateKeypair @8 :Libp2pHelperInterface.GenerateKeypair.Request;
      publish @9 :Libp2pHelperInterface.Publish.Request;
      subscribe @10 :Libp2pHelperInterface.Subscribe.Request;
      unsubscribe @11 :Libp2pHelperInterface.Unsubscribe.Request;
      addStreamHandler @12 :Libp2pHelperInterface.AddStreamHandler.Request;
      removeStreamHandler @13 :Libp2pHelperInterface.RemoveStreamHandler.Request;
      openStream @14 :Libp2pHelperInterface.OpenStream.Request;
      closeStream @15 :Libp2pHelperInterface.CloseStream.Request;
      resetStream @16 :Libp2pHelperInterface.ResetStream.Request;
      sendStream @17 :Libp2pHelperInterface.SendStream.Request;
      setNodeStatus @18 :Libp2pHelperInterface.SetNodeStatus.Request;
      getPeerNodeStatus @19 :Libp2pHelperInterface.GetPeerNodeStatus.Request;
    }
  }

  struct RpcResponseSuccess {
    union {
      configure @0 :Libp2pHelperInterface.Configure.Response;
      setGatingConfig @1 :Libp2pHelperInterface.SetGatingConfig.Response;
      listen @2 :Libp2pHelperInterface.Listen.Response;
      getListeningAddrs @3 :Libp2pHelperInterface.GetListeningAddrs.Response;
      beginAdvertising @4 :Libp2pHelperInterface.BeginAdvertising.Response;
      addPeer @5 :Libp2pHelperInterface.AddPeer.Response;
      listPeers @6 :Libp2pHelperInterface.ListPeers.Response;
      generateKeypair @7 :Libp2pHelperInterface.GenerateKeypair.Response;
      publish @8 :Libp2pHelperInterface.Publish.Response;
      subscribe @9 :Libp2pHelperInterface.Subscribe.Response;
      unsubscribe @10 :Libp2pHelperInterface.Unsubscribe.Response;
      addStreamHandler @11 :Libp2pHelperInterface.AddStreamHandler.Response;
      removeStreamHandler @12 :Libp2pHelperInterface.RemoveStreamHandler.Response;
      openStream @13 :Libp2pHelperInterface.OpenStream.Response;
      closeStream @14 :Libp2pHelperInterface.CloseStream.Response;
      resetStream @15 :Libp2pHelperInterface.ResetStream.Response;
      sendStream @16 :Libp2pHelperInterface.SendStream.Response;
      setNodeStatus @17 :Libp2pHelperInterface.SetNodeStatus.Response;
      getPeerNodeStatus @18 :Libp2pHelperInterface.GetPeerNodeStatus.Response;
    }
  }

  struct RpcResponse {
    header @0 :RpcMessageHeader;
    union {
      error @1 :Text;
      success @2 :RpcResponseSuccess;
    }
  }

  struct PushMessage {
    header @0 :PushMessageHeader;

    # union {
    validation @1 :Libp2pHelperInterface.Validation;
    # }
  }

  struct Message {
    union {
      rpcRequest @0 :Libp2pHelperInterface.RpcRequest;
      pushMessage @1 :Libp2pHelperInterface.PushMessage;
    }
  }
}

# all messages in the daemon interface are push messages 
struct DaemonInterface {
  struct PeerConnected {
    peerId @0 :PeerId;
  }

  struct GossipReceived {
    sender @0 :PeerInfo;
    seenAt @1 :UInt64;
    expiration @2 :UInt64;
    subscriptionId @3 :UInt64;
    validationSeqNumber @4 :UInt64;
    data @5 :Data;
  }

  struct IncomingStream {
    id @0 :UInt64;
    peer @1 :PeerInfo;
    protocol @2 :Text;
  }

  struct StreamLost {
    id @0 :UInt64;
    reason @1 :Text;
  }

  struct StreamComplete {
    streamId @0 :StreamId;
  }

  struct StreamMessageReceived {
    msg @0 :StreamMessage;
  }

  struct PushMessage {
    header @0 :PushMessageHeader;

    union {
      peerConnected @1 :DaemonInterface.PeerConnected;
      gossipReceived @2 :DaemonInterface.GossipReceived;
      incomingStream @3 :DaemonInterface.IncomingStream;
      streamLost @4 :DaemonInterface.StreamLost;
      streamComplete @5 :DaemonInterface.StreamComplete;
      streamMessageReceived @6 :DaemonInterface.StreamMessageReceived;
    }
  }

  struct Message {
    union {
      libp2pHelperResponse @0 :Libp2pHelperInterface.RpcResponse;
      pushMessage @1 :DaemonInterface.PushMessage;
    }
  }
}