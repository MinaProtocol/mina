package main

import (
	capnp "capnproto.org/go/capnp/v3"
	peer "github.com/libp2p/go-libp2p-core/peer"
	"github.com/stretchr/testify/require"
	ipc "libp2p_ipc"
	"testing"
)

type upcallTrap struct {
	Tag                   string
	PeerConnected         chan ipc.DaemonInterface_PeerConnected
	PeerDisconnected      chan ipc.DaemonInterface_PeerDisconnected
	IncomingStream        chan ipc.DaemonInterface_IncomingStream
	GossipReceived        chan ipc.DaemonInterface_GossipReceived
	StreamLost            chan ipc.DaemonInterface_StreamLost
	StreamComplete        chan ipc.DaemonInterface_StreamComplete
	StreamMessageReceived chan ipc.DaemonInterface_StreamMessageReceived
}

func newUpcallTrap(tag string, chanSize int) *upcallTrap {
	return &upcallTrap{
		Tag:                   tag,
		PeerConnected:         make(chan ipc.DaemonInterface_PeerConnected, chanSize),
		PeerDisconnected:      make(chan ipc.DaemonInterface_PeerDisconnected, chanSize),
		IncomingStream:        make(chan ipc.DaemonInterface_IncomingStream, chanSize),
		GossipReceived:        make(chan ipc.DaemonInterface_GossipReceived, chanSize),
		StreamLost:            make(chan ipc.DaemonInterface_StreamLost, chanSize),
		StreamComplete:        make(chan ipc.DaemonInterface_StreamComplete, chanSize),
		StreamMessageReceived: make(chan ipc.DaemonInterface_StreamMessageReceived, chanSize),
	}
}

func feedUpcallTrap(t *testing.T, out chan *capnp.Message, trap *upcallTrap, done chan interface{}) {
	for {
		select {
		case <-done:
			return
		case rawMsg := <-out:
			imsg, err := ipc.ReadRootDaemonInterface_Message(rawMsg)
			require.NoError(t, err)
			if !imsg.HasPushMessage() {
				t.Fatal("Received message is not a push")
			}
			pmsg, err := imsg.PushMessage()
			require.NoError(t, err)
			if pmsg.HasPeerConnected() {
				m, err := pmsg.PeerConnected()
				require.NoError(t, err)
				trap.PeerConnected <- m
			} else if pmsg.HasPeerDisconnected() {
				m, err := pmsg.PeerDisconnected()
				require.NoError(t, err)
				trap.PeerDisconnected <- m
			} else if pmsg.HasGossipReceived() {
				m, err := pmsg.GossipReceived()
				require.NoError(t, err)
				trap.GossipReceived <- m
			} else if pmsg.HasIncomingStream() {
				m, err := pmsg.IncomingStream()
				require.NoError(t, err)
				trap.IncomingStream <- m
			} else if pmsg.HasStreamLost() {
				t.Logf("%s: Stream lost", trap.Tag)
				m, err := pmsg.StreamLost()
				require.NoError(t, err)
				trap.StreamLost <- m
			} else if pmsg.HasStreamComplete() {
				t.Logf("%s: Stream complete", trap.Tag)
				m, err := pmsg.StreamComplete()
				require.NoError(t, err)
				trap.StreamComplete <- m
			} else if pmsg.HasStreamMessageReceived() {
				m, err := pmsg.StreamMessageReceived()
				require.NoError(t, err)
				trap.StreamMessageReceived <- m
			}
		}
	}
}

func TestUpcalls(t *testing.T) {
	newProtocol := "/mina/97"
	aTrap := newUpcallTrap("a", 64)
	bTrap := newUpcallTrap("b", 64)

	// Alice
	appA, appAPort := newTestApp(t, nil, false)
	appA.NoMDNS = true
	appA.NoDHT = true
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	// Bob
	appB, appBPort := newTestApp(t, nil, false)
	appB.NoMDNS = true
	appB.NoDHT = true
	appBInfos, err := addrInfos(appB.P2p.Host)
	require.NoError(t, err)

	beginAdvertisingSendAndCheck(t, appA)
	beginAdvertisingSendAndCheck(t, appB)

	withTimeoutAsync(t, func(done chan interface{}) {
		defer close(done)
		go feedUpcallTrap(t, appA.OutChan, aTrap, done)
		go feedUpcallTrap(t, appB.OutChan, bTrap, done)

		// Bob connects to Alice
		testAddPeerImplDo(t, appB, appAInfos[0], true)
		checkPeerConnected(t, <-aTrap.PeerConnected, appBInfos[0])
		checkPeerConnected(t, <-bTrap.PeerConnected, appAInfos[0])

		// Initiate stream handlers
		testAddStreamHandlerDo(t, newProtocol, appA, 10990)
		testAddStreamHandlerDo(t, newProtocol, appB, 10991)

		// Stream 1
		testStreamOpenSendClose(t, appA, appAPort, appB, appBPort, 11900, newProtocol, aTrap, bTrap)
		testStreamOpenSendClose(t, appB, appBPort, appA, appAPort, 11910, newProtocol, bTrap, aTrap)

	}, "test upcalls: some of upcalls didn't happen")
}

func testStreamOpenSendClose(t *testing.T, appA *app, appAPort uint16, appB *app, appBPort uint16, rpcSeqno uint64, protocol string, aTrap *upcallTrap, bTrap *upcallTrap) {
	aPI := mkPeerInfo(t, appA.P2p.Host, appAPort)

	// Alice opens stream to Bob
	streamId := testOpenStreamDo(t, appA, appB.P2p.Host, appBPort, rpcSeqno, protocol)
	checkIncomingStream(t, <-bTrap.IncomingStream, streamId, aPI, protocol)

	// Alice sends a message to Bob
	msg1 := []byte("somedata")
	testSendStreamDo(t, appA, streamId, msg1, rpcSeqno+1)
	checkStreamMessageReceived(t, <-bTrap.StreamMessageReceived, streamId, msg1)

	// Alice sends a message to Bob
	msg2 := []byte("otherdata")
	testSendStreamDo(t, appA, streamId, msg2, rpcSeqno+2)
	checkStreamMessageReceived(t, <-bTrap.StreamMessageReceived, streamId, msg2)

	// Bob sends a message to Alice
	msg3 := []byte("reply")
	testSendStreamDo(t, appB, streamId, msg3, rpcSeqno+3)
	checkStreamMessageReceived(t, <-aTrap.StreamMessageReceived, streamId, msg3)

	// Alice closes the stream
	testCloseStreamDo(t, appA, streamId, rpcSeqno+4)
	checkStreamComplete(t, <-aTrap.StreamComplete, streamId)
	checkStreamComplete(t, <-bTrap.StreamComplete, streamId)
}

func checkPeerConnected(t *testing.T, m ipc.DaemonInterface_PeerConnected, peerInfo peer.AddrInfo) {
	pid, err := m.PeerId()
	require.NoError(t, err)
	pid_, err := pid.Id()
	require.NoError(t, err)
	require.Equal(t, peerInfo.ID.String(), pid_)
}

func checkIncomingStream(t *testing.T, m ipc.DaemonInterface_IncomingStream, expectedStreamId uint64, expectedPI codaPeerInfo, expectedProtocol string) {
	sid, err := m.StreamId()
	require.NoError(t, err)
	pi, err := m.Peer()
	require.NoError(t, err)
	actualPI, err := readPeerInfo(pi)
	require.NoError(t, err)
	protocol, err := m.Protocol()
	require.NoError(t, err)
	require.Equal(t, expectedStreamId, sid.Id())
	require.Equal(t, expectedPI, *actualPI)
	require.Equal(t, expectedProtocol, protocol)
}

func checkStreamMessageReceived(t *testing.T, m ipc.DaemonInterface_StreamMessageReceived, expectedStreamId uint64, expectedData []byte) {
	sm, err := m.Msg()
	require.NoError(t, err)
	sid, err := sm.StreamId()
	require.NoError(t, err)
	data, err := sm.Data()
	require.NoError(t, err)
	require.Equal(t, expectedStreamId, sid.Id())
	require.Equal(t, expectedData, data)
}

func checkStreamLost(t *testing.T, m ipc.DaemonInterface_StreamLost, expectedStreamId uint64, expectedReason string) {
	sid, err := m.StreamId()
	require.NoError(t, err)
	require.Equal(t, expectedStreamId, sid.Id())
	reason, err := m.Reason()
	require.NoError(t, err)
	require.Equal(t, expectedReason, reason)
}

func checkStreamComplete(t *testing.T, m ipc.DaemonInterface_StreamComplete, expectedStreamId uint64) {
	sid, err := m.StreamId()
	require.NoError(t, err)
	require.Equal(t, expectedStreamId, sid.Id())
}
