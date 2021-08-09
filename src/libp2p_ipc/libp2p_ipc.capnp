using Go = import "/go.capnp";
@0xfb174cb3ecf64f4f;
$Go.package("libp2p_ipc");
$Go.import("libp2p_ipc");

struct Multiaddr {
  representation @0 :Text;
}

struct PeerInfo {
  libp2pPort @0 :UInt16;
  host @1 :Text;
  peerId @2 :Text;
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
  peerId @2 :Text;
}

struct GatingConfig {
  bannedIPs @0 :List(Text);
  bannedPeerIDs @1 :List(Text);
  trustedIPs @2 :List(Text);
  trustedPeerIDs @3 :List(Text);
  isolate @4 :Bool;
}

struct Libp2pConfig {
  statedir @0 :Text;
  privateKey @1 :Text;
  networkId @2 :Text;
  listenOn @3 :List(Text);
  metricsPort @4 :Int16;
  externalMultiaddr @5 :Text;
  unsafeNoTrustIP @6 :Bool;
  flood @7 :Bool;
  peerExchange @8 :Bool;
  directPeers @9 :List(Text);
  seedPeers @10 :List(Text);
  gatingConfig @11 :GatingConfig;
  maxConnections @12 :UInt32;
  validationQueueSize @13 :UInt32;
  minaPeerExchange @14 :Bool;
}

struct Publish {
  topic @0 :Text;
  data @1 :Data;
}

struct Subscribe {
  topic @0 :Text;
  subscriptionId @1 :UInt64;
}

struct OutgoingStream {
  peer @0 :Text;
  protocolId @1 :Text;
}

struct Stream {
  id @0 :UInt64;
  peer @1 :PeerInfo;
}

struct NewPeer {
  multiaddr @0 :Multiaddr;
  isSeed @1 :Bool;
}

struct GossipMessage {
  sender @0 :PeerInfo;
  seenAt @1 :UInt64;
  expiration @2 :UInt64;
  subscriptionId @3 :UInt64;
  validationSeqNumber @4 :UInt64;
  data @5 :Data;
}

enum ValidationResult {
  accept @0;
  reject @1;
  ignore @2;
}

struct ValidationMessage {
  validationSeqNumber @0 :UInt64;
  result @1 :ValidationResult;
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

struct StreamMessage {
  id @0 :UInt64;
  data @1 :Data;
}

struct PushMessage(T) {
  timeSent @0 :UInt64;
  content @1 :T;
}

struct RPCMessage {
  struct Header {
    timeSent @0 :UInt64;
    seqNumber @1 :UInt64;
  }

  struct VoidRequest {
    header @0 :RPCMessage.Header;
  }

  struct Request(T) {
    header @0 :RPCMessage.Header;
    content @1 :T;
  }

  struct VoidResult {
    header @0 :RPCMessage.Header;
    union {
      error @1 :Text;
      success @2 :Void;
    }
  }

  struct Result(T) {
    header @0 :RPCMessage.Header;
    union {
      error @1 :Text;
      success @2 :T;
    }
  }
}

# all messages in the libp2p_helper interface are RPC calls, except for validations
struct Libp2pHelperInterface {
  struct Configure {
    struct Request {
      config @0 :RPCMessage.Request(Libp2pConfig);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct SetGatingConfig  {
    struct Request {
      gatingConfig @0 :RPCMessage.Request(GatingConfig);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct Listen {
    struct Request {
      iface @0 :RPCMessage.Request(Text);
    }

    struct Response {
      result @0 :RPCMessage.Result(List(Multiaddr));
    }
  }

  struct GetListeningAddrs {
    struct Request {
      void @0 :RPCMessage.VoidResult;
    }

    struct Response {
      result @0 :RPCMessage.Result(List(Multiaddr));
    }
  }

  struct BeginAdvertising {
    struct Request {}

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct AddPeer {
    struct Request {
      peer @0 :RPCMessage.Request(NewPeer);
    }

    struct Response {
      result @0 :RPCMessage.Result(NewPeer);
    }
  }

  struct ListPeers {
    struct Request {
      void @0 :RPCMessage.VoidResult;
    }

    struct Response {
      result @0 :RPCMessage.Result(List(PeerInfo));
    }
  }

  struct GenerateKeypair {
    struct Request {
      void @0 :RPCMessage.VoidResult;
    }

    struct Response {
      result @0 :RPCMessage.Result(Libp2pKeypair);
    }
  }

  struct Publish {
    struct Request {
      publish @0 :RPCMessage.Request(Publish);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct Subscribe {
    struct Request {
      subscribe @0 :RPCMessage.Request(Subscribe);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  # do we use this anymore?
  struct Unsubscribe {
   struct Request {
      subscriptionId @0 :RPCMessage.Request(SubscriptionId);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct AddStreamHandler {
   struct Request {
      protocol @0 :RPCMessage.Request(Text);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  # do we use this anymore?
  struct RemoveStreamHandler {
   struct Request {
      protocol @0 :RPCMessage.Request(Text);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct OpenStream {
   struct Request {
      stream @0 :RPCMessage.Request(OutgoingStream);
    }

    struct Response {
      result @0 :RPCMessage.Result(Stream);
    }
  }

  struct CloseStream {
   struct Request {
      streamId @0 :RPCMessage.Request(StreamId);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct ResetStream {
   struct Request {
      streamId @0 :RPCMessage.Request(StreamId);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct SendStream {
   struct Request {
      msg @0 :RPCMessage.Request(StreamMessage);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct SetNodeStatus {
   struct Request {
      status @0 :RPCMessage.Request(Data);
    }

    struct Response {
      result @0 :RPCMessage.VoidResult;
    }
  }

  struct GetPeerNodeStatus {
   struct Request {
      peer @0 :RPCMessage.Request(Multiaddr);
    }

    struct Response {
      result @0 :RPCMessage.Result(Data);
    }
  }

  # validation is a special push message where the sequence number
  # corresponds to the the push message sent to the daemon in the
  # GossipReceived message
  struct Validation {
    validation @0 :PushMessage(ValidationMessage);
  }
}

# all messages in the daemon interface are push messages 
struct DaemonInterface {
  struct PeerConnected {
    peerId @0 :PushMessage(Text);
  }

  struct GossipReceived {
    msg @0 :PushMessage(GossipMessage);
  }

  struct IncomingStream {
    stream @0 :PushMessage(IncomingStream);
  }

  struct StreamLost {
    streamLost @0 :PushMessage(StreamLost);
  }

  struct StreamComplete {
    streamId @0 :PushMessage(StreamId);
  }

  struct StreamMessageReceived {
    msg @0 :PushMessage(StreamMessage);
  }
}
