package main

import (
	"context"
	ipc "libp2p_ipc"
	"math"
	"testing"

	logging "github.com/ipfs/go-log/v2"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
	peer "github.com/libp2p/go-libp2p-core/peer"
	"github.com/stretchr/testify/require"
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
	ResourceUpdate        chan ipc.DaemonInterface_ResourceUpdate
	DropMask              uint32
}

func (trap *upcallTrap) Close() {
	close(trap.PeerConnected)
	close(trap.PeerDisconnected)
	close(trap.IncomingStream)
	close(trap.GossipReceived)
	close(trap.StreamLost)
	close(trap.StreamComplete)
	close(trap.StreamMessageReceived)
	close(trap.ResourceUpdate)
}

type upcallSubChan = uint32

const (
	PeerConnectedChan upcallSubChan = iota
	PeerDisconnectedChan
	IncomingStreamChan
	GossipReceivedChan
	StreamLostChan
	StreamCompleteChan
	StreamMessageReceivedChan
	ResourceUpdateChan
)

const upcallDropAllMask = math.MaxUint32

func newUpcallTrap(tag string, chanSize int, dropMask uint32) *upcallTrap {
	return &upcallTrap{
		Tag:                   tag,
		PeerConnected:         make(chan ipc.DaemonInterface_PeerConnected, chanSize),
		PeerDisconnected:      make(chan ipc.DaemonInterface_PeerDisconnected, chanSize),
		IncomingStream:        make(chan ipc.DaemonInterface_IncomingStream, chanSize),
		GossipReceived:        make(chan ipc.DaemonInterface_GossipReceived, chanSize),
		StreamLost:            make(chan ipc.DaemonInterface_StreamLost, chanSize),
		StreamComplete:        make(chan ipc.DaemonInterface_StreamComplete, chanSize),
		StreamMessageReceived: make(chan ipc.DaemonInterface_StreamMessageReceived, chanSize),
		ResourceUpdate:        make(chan ipc.DaemonInterface_ResourceUpdate, chanSize),
		DropMask:              dropMask,
	}
}

func launchFeedUpcallTrap(logger logging.StandardLogger, out chan *capnp.Message, trap *upcallTrap, errChan chan<- error, ctx context.Context) {
	go func() {
		err := feedUpcallTrap(func(format string, args ...interface{}) {
			logger.Debugf(format, args...)
		}, out, trap, ctx)
		if err != nil && ctx.Err() != nil {
			errChan <- err
		}
	}()
}

func feedUpcallTrap(logf func(format string, args ...interface{}), out chan *capnp.Message, trap *upcallTrap, ctx context.Context) error {
	defer trap.Close()
	for {
		select {
		case <-ctx.Done():
			return nil
		case rawMsg := <-out:
			imsg, err := ipc.ReadRootDaemonInterface_Message(rawMsg)
			if err != nil {
				return err
			}
			if !imsg.HasPushMessage() {
				return errors.New("Received message is not a push")
			}
			// TODO instrument in- and out- for each message and count bracket balance
			// TODO make the up-caller use not t.Logf, but app's logger
			pmsg, err := imsg.PushMessage()
			if err != nil {
				return err
			}
			which := pmsg.Which()
			logf("%s: handling %s", trap.Tag, which)
			switch which {
			case ipc.DaemonInterface_PushMessage_Which_peerConnected:
				m, err := pmsg.PeerConnected()
				if err != nil {
					return err
				}
				if trap.DropMask&(1<<PeerConnectedChan) == 0 {
					trap.PeerConnected <- m
				}
			case ipc.DaemonInterface_PushMessage_Which_peerDisconnected:
				m, err := pmsg.PeerDisconnected()
				if err != nil {
					return err
				}
				if trap.DropMask&(1<<PeerDisconnectedChan) == 0 {
					trap.PeerDisconnected <- m
				}
			case ipc.DaemonInterface_PushMessage_Which_gossipReceived:
				m, err := pmsg.GossipReceived()
				if err != nil {
					return err
				}
				if trap.DropMask&(1<<GossipReceivedChan) == 0 {
					trap.GossipReceived <- m
				}
			case ipc.DaemonInterface_PushMessage_Which_incomingStream:
				m, err := pmsg.IncomingStream()
				if err != nil {
					return err
				}
				if trap.DropMask&(1<<IncomingStreamChan) == 0 {
					trap.IncomingStream <- m
				}
			case ipc.DaemonInterface_PushMessage_Which_streamLost:
				m, err := pmsg.StreamLost()
				if err != nil {
					return err
				}
				if trap.DropMask&(1<<StreamLostChan) == 0 {
					trap.StreamLost <- m
				}
			case ipc.DaemonInterface_PushMessage_Which_streamComplete:
				m, err := pmsg.StreamComplete()
				if err != nil {
					return err
				}
				if trap.DropMask&(1<<StreamCompleteChan) == 0 {
					trap.StreamComplete <- m
				}
			case ipc.DaemonInterface_PushMessage_Which_streamMessageReceived:
				m, err := pmsg.StreamMessageReceived()
				if err != nil {
					return err
				}
				if trap.DropMask&(1<<StreamMessageReceivedChan) == 0 {
					trap.StreamMessageReceived <- m
				}
			case ipc.DaemonInterface_PushMessage_Which_resourceUpdated:
				m, err := pmsg.ResourceUpdated()
				if err != nil {
					return err
				}
				if trap.DropMask&(1<<ResourceUpdateChan) == 0 {
					trap.ResourceUpdate <- m
				}
			}
			logf("%s: handled %s", trap.Tag, which)
		}
	}
}

func mkAppForUpcallTest(t *testing.T, tag string) (*upcallTrap, *app, uint16, peer.AddrInfo) {
	trap := newUpcallTrap(tag, 64, 1<<ResourceUpdateChan)

	app, appPort := newTestApp(t, nil, false)
	app.NoMDNS = true
	app.NoDHT = true
	appInfos, err := addrInfos(app.P2p.Host)
	require.NoError(t, err)

	require.NoError(t, configurePubsub(app, 32, nil, nil))

	beginAdvertisingSendAndCheck(t, app)

	info := appInfos[0]
	t.Logf("%s: %s", tag, info.ID.String())

	return trap, app, appPort, info
}

func TestUpcalls(t *testing.T) {
	newProtocol := "/mina/97"
	// TODO refactor test so that:
	// 1. error on upcall chan is received immediately
	// 2. test is exited immediately after it's received

	aTrap, alice, alicePort, aliceInfo := mkAppForUpcallTest(t, "alice")
	bTrap, bob, bobPort, bobInfo := mkAppForUpcallTest(t, "bob")
	cTrap, carol, carolPort, carolInfo := mkAppForUpcallTest(t, "carol")

	// Initiate stream handlers
	testAddStreamHandlerDo(t, newProtocol, alice, 10990)
	testAddStreamHandlerDo(t, newProtocol, bob, 10991)
	testAddStreamHandlerDo(t, newProtocol, carol, 10992)

	errChan := make(chan error, 3)
	ctx, cancelF := context.WithCancel(context.Background())

	t.Cleanup(func() {
		cancelF()
		close(errChan)
		for err := range errChan {
			t.Errorf("feedUpcallTrap failed with %s", err)
		}
	})

	launchFeedUpcallTrap(alice.P2p.Logger, alice.OutChan, aTrap, errChan, ctx)
	launchFeedUpcallTrap(bob.P2p.Logger, bob.OutChan, bTrap, errChan, ctx)
	launchFeedUpcallTrap(carol.P2p.Logger, carol.OutChan, cTrap, errChan, ctx)

	// subscribe
	topic := "testtopic"
	var subId uint64 = 123
	testSubscribeDo(t, alice, topic, subId, 11960)

	// Bob connects to Alice
	testAddPeerImplDo(t, bob, aliceInfo, true)
	t.Logf("peer connected: waiting bob <-> alice")
	checkPeerConnected(t, <-aTrap.PeerConnected, bobInfo)
	checkPeerConnected(t, <-bTrap.PeerConnected, aliceInfo)
	t.Logf("peer connected: performed bob <-> alice")

	// Alice initiates and then closes connection to Bob
	testStreamOpenSendClose(t, alice, alicePort, bob, bobPort, 11900, newProtocol, aTrap, bTrap)
	t.Logf("alice -> bob: opened, used and closed stream")
	// Bob initiates and then closes connection to Alice
	testStreamOpenSendClose(t, bob, bobPort, alice, alicePort, 11910, newProtocol, bTrap, aTrap)
	t.Logf("bob -> alice: opened, used and closed stream")

	// Bob connects to Carol
	testAddPeerImplDo(t, bob, carolInfo, true)
	t.Logf("peer connected: waiting bob <-> carol")
	checkPeerConnected(t, <-cTrap.PeerConnected, bobInfo)
	checkPeerConnected(t, <-bTrap.PeerConnected, carolInfo)
	t.Logf("peer connected: performed bob <-> carol")

	_ = carolPort
	select {
	case pc := <-aTrap.PeerConnected:
		pid, err := pc.PeerId()
		require.NoError(t, err)
		id, err := pid.Id()
		require.NoError(t, err)

		t.Fatalf("Peer connected to peer %s (unexpectedly)", id)
	default:
	}
	// Bob initiates and then closes connection to Carol
	_, cStreamId1 := testStreamOpenSend(t, bob, bobPort, carol, carolPort, 11920, newProtocol, bTrap, cTrap)

	// Alice initiates and then resets connection to Bob
	testStreamOpenSendReset(t, alice, alicePort, bob, bobPort, 11930, newProtocol, aTrap, bTrap)
	// Bob initiates and then resets connection to Alice
	testStreamOpenSendReset(t, bob, bobPort, alice, alicePort, 11940, newProtocol, bTrap, aTrap)
	require.NoError(t, bob.P2p.Host.Close())
	for {
		t.Logf("awaiting disconnect from Alice ...")
		m := <-aTrap.PeerDisconnected
		pid := getPeerDisconnectedPeerId(t, m)
		if pid == peerId(carolInfo) {
			// Carol can connect to alice and even disconnect when Bob closes
			// Seems like a legit behaviour overall
		} else if pid == peerId(bobInfo) {
			break
		} else {
			t.Logf("Unexpected disconnect from peer id %s", pid)
		}
	}
	t.Logf("stream lost, carol: waiting")
	checkStreamLost(t, <-cTrap.StreamLost, cStreamId1, "read failure: stream reset")
	t.Logf("stream lost, carol: processed")

	testAddPeerImplDo(t, alice, carolInfo, true)
	testStreamOpenSendClose(t, carol, carolPort, alice, alicePort, 11950, newProtocol, cTrap, aTrap)

	msg := []byte("bla-bla")
	testPublishDo(t, carol, topic, msg, 11970)

	t.Logf("checkGossipReceived: waiting")
	checkGossipReceived(t, <-aTrap.GossipReceived, msg, subId, peerId(carolInfo))
}

func checkGossipReceived(t *testing.T, m ipc.DaemonInterface_GossipReceived, msg []byte, subId uint64, senderPeerId string) {
	pi, err := m.Sender()
	require.NoError(t, err)
	actualPI, err := readPeerInfo(pi)
	require.NoError(t, err)
	require.Equal(t, senderPeerId, actualPI.PeerID)
	data, err := m.Data()
	require.NoError(t, err)
	subscriptionId, err := m.SubscriptionId()
	require.NoError(t, err)
	require.Equal(t, subId, subscriptionId.Id())
	require.Equal(t, msg, data)
}

func testStreamOpenSend(t *testing.T, appA *app, appAPort uint16, appB *app, appBPort uint16, rpcSeqno uint64, protocol string, aTrap *upcallTrap, bTrap *upcallTrap) (uint64, uint64) {
	aPeerId := appA.P2p.Host.ID().String()

	// Open a stream from A to B
	aStreamId := testOpenStreamDo(t, appA, appB.P2p.Host, appBPort, rpcSeqno, protocol)
	bStreamId := checkIncomingStream(t, <-bTrap.IncomingStream, aPeerId, protocol)

	// // Send a message from B to A
	// msg := []byte("msg")
	// testSendStreamDo(t, appB, bStreamId, msg, rpcSeqno+1)
	// checkStreamMessageReceived(t, <-aTrap.StreamMessageReceived, aStreamId, msg)

	return aStreamId, bStreamId
}
func testStreamOpenSendReset(t *testing.T, appA *app, appAPort uint16, appB *app, appBPort uint16, rpcSeqno uint64, protocol string, aTrap *upcallTrap, bTrap *upcallTrap) {
	aStreamId, bStreamId := testStreamOpenSend(t, appA, appAPort, appB, appBPort, rpcSeqno+1, protocol, aTrap, bTrap)
	// A closes the stream
	testResetStreamDo(t, appA, aStreamId, rpcSeqno)
	checkStreamLost(t, <-aTrap.StreamLost, aStreamId, "read failure: stream reset")
	checkStreamLost(t, <-bTrap.StreamLost, bStreamId, "read failure: stream reset")
}

func testStreamOpenSendClose(t *testing.T, appA *app, appAPort uint16, appB *app, appBPort uint16, rpcSeqno uint64, protocol string, aTrap *upcallTrap, bTrap *upcallTrap) {
	aPeerId := appA.P2p.Host.ID().String()

	// Open a stream from A to B
	aStreamId := testOpenStreamDo(t, appA, appB.P2p.Host, appBPort, rpcSeqno, protocol)
	bStreamId := checkIncomingStream(t, <-bTrap.IncomingStream, aPeerId, protocol)

	// Send a message from A to B
	msg1 := []byte("somedata")
	testSendStreamDo(t, appA, aStreamId, msg1, rpcSeqno+1)
	checkStreamMessageReceived(t, <-bTrap.StreamMessageReceived, bStreamId, msg1)

	// Send a message from A to B
	msg2 := []byte("otherdata")
	testSendStreamDo(t, appA, aStreamId, msg2, rpcSeqno+2)
	checkStreamMessageReceived(t, <-bTrap.StreamMessageReceived, bStreamId, msg2)

	// Send a message from B to A
	msg3 := []byte("reply")
	testSendStreamDo(t, appB, bStreamId, msg3, rpcSeqno+3)
	checkStreamMessageReceived(t, <-aTrap.StreamMessageReceived, aStreamId, msg3)

	// A closes the stream
	testCloseStreamDo(t, appA, aStreamId, rpcSeqno+4)
	checkStreamLost(t, <-aTrap.StreamLost, aStreamId, "")
	checkStreamComplete(t, <-bTrap.StreamComplete, bStreamId)
}

func peerId(info peer.AddrInfo) string {
	return info.ID.String()
}

func checkPeerConnected(t *testing.T, m ipc.DaemonInterface_PeerConnected, peerInfo peer.AddrInfo) {
	pid, err := m.PeerId()
	require.NoError(t, err)
	pid_, err := pid.Id()
	require.NoError(t, err)
	require.Equal(t, peerId(peerInfo), pid_)
}

func getPeerDisconnectedPeerId(t *testing.T, m ipc.DaemonInterface_PeerDisconnected) string {
	pid, err := m.PeerId()
	require.NoError(t, err)
	pid_, err := pid.Id()
	require.NoError(t, err)
	return pid_
}

func checkIncomingStream(t *testing.T, m ipc.DaemonInterface_IncomingStream, expectedPeerId string, expectedProtocol string) uint64 {
	sid, err := m.StreamId()
	require.NoError(t, err)
	pi, err := m.Peer()
	require.NoError(t, err)
	actualPI, err := readPeerInfo(pi)
	require.NoError(t, err)
	protocol, err := m.Protocol()
	require.NoError(t, err)
	require.Equal(t, expectedPeerId, actualPI.PeerID)
	require.Equal(t, expectedProtocol, protocol)
	return sid.Id()
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
	if expectedReason != "" {
		require.Equal(t, expectedReason, reason)
	}
}

func checkStreamComplete(t *testing.T, m ipc.DaemonInterface_StreamComplete, expectedStreamId uint64) {
	sid, err := m.StreamId()
	require.NoError(t, err)
	require.Equal(t, expectedStreamId, sid.Id())
}
