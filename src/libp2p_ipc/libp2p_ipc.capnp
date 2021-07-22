using Go = import "/go.capnp";
@0xfb174cb3ecf64f4f;
$Go.package("libp2p_ipc");
$Go.import("libp2p_ipc");

struct VoidMsg {
  timeSent @0 :UInt64;
}

struct Msg(T) {
  timeSent @0 :UInt64;
  content @1 :T;
}

struct VoidResult {
  union {
    error @0 :Msg(Text);
    success @1 :VoidMsg;
  }
}

struct Result(T) {
  union {
    error @0 :Msg(Text);
    success @1 :Msg(T);
  }
}

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

interface Libp2pHelper {
  configure @0 (config :Msg(Libp2pConfig)) -> (result :VoidResult);
  setGatingConfig @1 (gatingConfig :Msg(GatingConfig)) -> (result :VoidResult);

  listen @2 (iface :Msg(Text)) -> (result :Result(List(Multiaddr)));
  getListeningAddrs @3 (void :VoidMsg) -> (result :Result(List(Multiaddr)));
  beginAdvertising @4 () -> (result :VoidResult);

  addPeer @5 (peer :Msg(NewPeer)) -> (result :Result(NewPeer));
  listPeers @6 (void :VoidMsg) -> (result :Result(List(PeerInfo)));

  generateKeypair @7 (void :VoidMsg) -> (result :Result(Libp2pKeypair));

  publish @8 (publish :Msg(Publish)) -> (result :VoidResult);
  subscribe @9 (subscribe :Msg(Subscribe)) -> (result :VoidResult);
  # do we use this anymore?
  unsubscribe @10 (subscriptionId :Msg(SubscriptionId)) -> (result :VoidResult);
  addStreamHandler @11 (protocol :Msg(Text)) -> (result :VoidResult);

  # do we use this anymore?
  removeStreamHandler @12 (protocol :Msg(Text)) -> (result :VoidResult);
  openStream @13 (stream :Msg(OutgoingStream)) -> (result :Result(Stream));
  closeStream @14 (streamId :Msg(StreamId)) -> (result :VoidResult);
  resetStream @15 (streamId :Msg(StreamId)) -> (result :VoidResult);
  sendStream @16 (msg :Msg(StreamMessage)) -> (result :VoidResult);

  setNodeStatus @17 (status :Msg(Data)) -> (result :VoidResult);
  getPeerNodeStatus @18 (peer :Msg(Multiaddr)) -> (result :Result(Data));
}


interface Validation {
  validate @0 (validation :Msg(Validation)) -> (result :VoidResult);
}

struct GossipMessage {
  sender @0 :PeerInfo;
  seenAt @1 :UInt64;
  expiration @2 :UInt64;
  subscriptionId @3 :UInt64;
  data @4 :Data;
  validation @5 :Validation;
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

interface Daemon {
  peerConnected @0 (peerId :Msg(Text));
  gossipReceived @1 (validation :Msg(GossipMessage));
  incomingStream @2 (stream :Msg(IncomingStream));
  streamLost @3 (streamLost :Msg(StreamLost));
  streamComplete @4 (streamId :Msg(StreamId));
  streamMessageReceived @5 (msg :Msg(StreamMessage));
}