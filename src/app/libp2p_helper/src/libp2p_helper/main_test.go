package main

import (
	"bufio"
	"context"
	crand "crypto/rand"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"strings"
	"sync"
	"testing"
	"time"

	"codanet"

	peerstore "github.com/libp2p/go-libp2p-core/peerstore"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"net/http"
	"strconv"

	logging "github.com/ipfs/go-log"

	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/host"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	protocol "github.com/libp2p/go-libp2p-core/protocol"

	"github.com/libp2p/go-libp2p-pubsub"
	ma "github.com/multiformats/go-multiaddr"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/stretchr/testify/require"
	ipc "libp2p_ipc"
)

var (
	testTimeout  = 10 * time.Second
	testProtocol = protocol.ID("/mina/")
)

var testPort uint16 = 7000

func TestMain(m *testing.M) {
	_ = logging.SetLogLevel("codanet.Helper", "warning")
	_ = logging.SetLogLevel("codanet.CodaGatingState", "warning")
	codanet.WithPrivate = true

	os.Exit(m.Run())
}

const (
	maxStatsMsg = 1 << 6
	minStatsMsg = 1 << 3
)

func newTestKey(t *testing.T) crypto.PrivKey {
	r := crand.Reader
	key, _, err := crypto.GenerateEd25519Key(r)
	require.NoError(t, err)

	return key
}

func testStreamHandler(_ net.Stream) {}

func newTestAppWithMaxConns(t *testing.T, seeds []peer.AddrInfo, noUpcalls bool, maxConns int, port uint16) *app {
	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	addr, err := ma.NewMultiaddr(fmt.Sprintf("/ip4/0.0.0.0/tcp/%d", port))
	require.NoError(t, err)

	helper, err := codanet.MakeHelper(context.Background(),
		[]ma.Multiaddr{addr},
		nil,
		dir,
		newTestKey(t),
		string(testProtocol),
		seeds,
		codanet.NewCodaGatingState(nil, nil, nil, nil),
		maxConns,
		true,
	)
	require.NoError(t, err)

	helper.GatingState.TrustedAddrFilters = ma.NewFilters()
	helper.Host.SetStreamHandler(testProtocol, testStreamHandler)

	t.Cleanup(func() {
		err := helper.Host.Close()
		if err != nil {
			panic(err)
		}
	})

	return &app{
		P2p:                      helper,
		Ctx:                      context.Background(),
		Subs:                     make(map[uint64]subscription),
		Topics:                   make(map[string]*pubsub.Topic),
		ValidatorMutex:           &sync.Mutex{},
		Validators:               make(map[uint64]*validationStatus),
		Streams:                  make(map[uint64]net.Stream),
		AddedPeers:               make([]peer.AddrInfo, 0, 512),
		OutChan:                  make(chan *capnp.Message, 64),
		MetricsRefreshTime:       time.Second * 2,
		NoUpcalls:                noUpcalls,
		metricsServer:            nil,
		metricsCollectionStarted: false,
	}
}

func newTestApp(t *testing.T, seeds []peer.AddrInfo, noUpcalls bool) (*app, uint16) {
	port := testPort
	testPort++
	return newTestAppWithMaxConns(t, seeds, noUpcalls, 50, port), port
}

func addrInfos(h host.Host) (addrInfos []peer.AddrInfo, err error) {
	for _, multiaddr := range multiaddrs(h) {
		addrInfo, err := peer.AddrInfoFromP2pAddr(multiaddr)
		if err != nil {
			return nil, err
		}
		addrInfos = append(addrInfos, *addrInfo)
	}
	return addrInfos, nil
}

func multiaddrs(h host.Host) (multiaddrs []ma.Multiaddr) {
	addrs := h.Addrs()
	for _, addr := range addrs {
		multiaddr, err := ma.NewMultiaddr(fmt.Sprintf("%s/p2p/%s", addr, h.ID()))
		if err != nil {
			continue
		}
		multiaddrs = append(multiaddrs, multiaddr)
	}
	return multiaddrs
}

func checkRpcResponseError(t *testing.T, resMsg *capnp.Message) (uint64, string) {
	msg, err := ipc.ReadRootDaemonInterface_Message(resMsg)
	require.NoError(t, err)
	require.True(t, msg.HasRpcResponse())
	resp, err := msg.RpcResponse()
	require.NoError(t, err)
	require.True(t, resp.HasError())
	header, err := resp.Header()
	require.NoError(t, err)
	seqno := header.SeqNumber()
	respError, err := resp.Error()
	require.NoError(t, err)
	return seqno, respError
}

func checkRpcResponseSuccess(t *testing.T, resMsg *capnp.Message) (uint64, ipc.Libp2pHelperInterface_RpcResponseSuccess) {
	msg, err := ipc.ReadRootDaemonInterface_Message(resMsg)
	require.NoError(t, err)
	require.True(t, msg.HasRpcResponse())
	resp, err := msg.RpcResponse()
	require.NoError(t, err)
	require.True(t, resp.HasSuccess())
	header, err := resp.Header()
	require.NoError(t, err)
	seqno := header.SeqNumber()
	respSuccess, err := resp.Success()
	require.NoError(t, err)
	return seqno, respSuccess
}

func beginAdvertisingSendAndCheck(t *testing.T, app *app) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_BeginAdvertising_Request(seg)
	require.NoError(t, err)
	var rpcSeqno uint64 = 123
	resMsg := app.handleBeginAdvertising(rpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasBeginAdvertising())
	_, err = respSuccess.BeginAdvertising()
	require.NoError(t, err)
}

func TestDHTDiscovery_TwoNodes(t *testing.T) {
	appA, _ := newTestApp(t, nil, true)
	appA.NoMDNS = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, _ := newTestApp(t, appAInfos, true)
	appB.AddedPeers = appAInfos
	appB.NoMDNS = true

	// begin appB and appA's DHT advertising
	beginAdvertisingSendAndCheck(t, appB)
	beginAdvertisingSendAndCheck(t, appA)

	time.Sleep(time.Second)
}

func TestDHTDiscovery_ThreeNodes(t *testing.T) {
	appA, _ := newTestApp(t, nil, true)
	appA.NoMDNS = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, _ := newTestApp(t, appAInfos, true)
	appB.NoMDNS = true

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC, _ := newTestApp(t, appAInfos, true)
	appC.NoMDNS = true

	err = appC.P2p.Host.Connect(appC.Ctx, appAInfos[0])
	require.NoError(t, err)

	time.Sleep(time.Second)

	// begin appB and appC's DHT advertising
	beginAdvertisingSendAndCheck(t, appB)
	beginAdvertisingSendAndCheck(t, appC)

	done := make(chan struct{})

	go func() {
		for {
			// check if peerB knows about peerC
			addrs := appB.P2p.Host.Peerstore().Addrs(appC.P2p.Host.ID())
			if len(addrs) != 0 {
				// send a stream message
				// then exit
				close(done)
				return
			}
			time.Sleep(time.Millisecond * 100)
		}
	}()

	select {
	case <-time.After(testTimeout):
		t.Fatal("B did not discover C via DHT")
	case <-done:
	}

	time.Sleep(time.Second)
}

func TestMDNSDiscovery(t *testing.T) {
	appA, appAPort := newTestApp(t, nil, true)
	appA.NoDHT = true

	appB, appBPort := newTestApp(t, nil, true)
	appB.NoDHT = true

	t.Logf("Using libp2p ports: %d and %d", appAPort, appBPort)

	// begin appA and appB's mDNS advertising
	beginAdvertisingSendAndCheck(t, appB)
	beginAdvertisingSendAndCheck(t, appA)

	done := make(chan struct{})

	go func() {
		for {
			// check if peerB knows about peerA
			addrs := appB.P2p.Host.Peerstore().Addrs(appA.P2p.Host.ID())
			if len(addrs) != 0 {
				close(done)
				return
			}
			time.Sleep(time.Millisecond * 100)
		}
	}()

	select {
	case <-time.After(testTimeout):
		t.Fatal("B did not discover A via mDNS")
	case <-done:
	}

	time.Sleep(time.Second * 3)
}

func createMessage(size uint64) []byte {
	return make([]byte, size)
}

func TestMplex_SendLargeMessage(t *testing.T) {
	// assert we are able to send and receive a message with size up to 1 << 30 bytes
	appA, _ := newTestApp(t, nil, true)
	appA.NoDHT = true

	appB, _ := newTestApp(t, nil, true)
	appB.NoDHT = true

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	// create handler that reads 1<<30 bytes
	done := make(chan struct{})
	handler := func(stream net.Stream) {
		r := bufio.NewReader(stream)
		i := 0

		for {
			_, err := r.ReadByte()
			if err == io.EOF {
				break
			}

			i++
			if i == 1<<30 {
				close(done)
				return
			}
		}
	}

	appB.P2p.Host.SetStreamHandler(testProtocol, handler)

	// send large message from A to B
	msg := createMessage(1 << 30)

	stream, err := appA.P2p.Host.NewStream(context.Background(), appB.P2p.Host.ID(), testProtocol)
	require.NoError(t, err)

	_, err = stream.Write(msg)
	require.NoError(t, err)

	select {
	case <-time.After(testTimeout):
		t.Fatal("B did not receive a large message from A")
	case <-done:
	}
}

func TestSetNodeStatus(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SetNodeStatus_Request(seg)
	require.NoError(t, err)
	testStatus := []byte("test_node_status")
	require.NoError(t, m.SetStatus(testStatus))

	resMsg := testApp.handleSetNodeStatus(11239, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(11239))
	require.True(t, respSuccess.HasSetNodeStatus())
	_, err = respSuccess.SetNodeStatus()
	require.NoError(t, err)

	require.Equal(t, testStatus, testApp.P2p.NodeStatus)
}

func TestConfigure(t *testing.T) {
	testApp := newApp()

	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	key, _, err := crypto.GenerateEd25519Key(crand.Reader)
	require.NoError(t, err)
	keyBytes, err := key.Bytes()
	require.NoError(t, err)

	external := "/ip4/0.0.0.0/tcp/7000"
	self := "/ip4/127.0.0.1/tcp/7000"

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Configure_Request(seg)
	require.NoError(t, err)
	c, err := m.NewConfig()
	require.NoError(t, err)

	require.NoError(t, c.SetStatedir(dir))
	require.NoError(t, c.SetPrivateKey(keyBytes))
	require.NoError(t, c.SetNetworkId(string(testProtocol)))
	lon, err := c.NewListenOn(1)
	require.NoError(t, err)
	require.NoError(t, lon.At(0).SetRepresentation(self))
	err = multiaddrListForeach(lon, func(v string) error {
		if v != self {
			return errors.New("Failed to iterate over freshly created listenOn list")
		}
		return nil
	})
	require.NoError(t, err)
	require.True(t, lon.Len() == 1)
	c.SetMetricsPort(0)
	ema, err := c.NewExternalMultiaddr()
	require.NoError(t, err)
	require.NoError(t, ema.SetRepresentation(external))
	c.SetUnsafeNoTrustIp(false)
	c.SetFlood(false)
	c.SetPeerExchange(false)
	_, err = c.NewDirectPeers(0)
	require.NoError(t, err)
	_, err = c.NewSeedPeers(0)
	require.NoError(t, err)
	c.SetMaxConnections(0)
	c.SetValidationQueueSize(16)
	c.SetMinaPeerExchange(false)

	gc, err := c.NewGatingConfig()
	require.NoError(t, err)
	_, err = gc.NewBannedIps(0)
	require.NoError(t, err)
	_, err = gc.NewBannedPeerIds(0)
	require.NoError(t, err)
	_, err = gc.NewTrustedIps(0)
	require.NoError(t, err)
	_, err = gc.NewTrustedPeerIds(0)
	require.NoError(t, err)
	gc.SetIsolate(false)

	resMsg := testApp.handleConfigure(239, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(239))
	require.True(t, respSuccess.HasConfigure())
	_, err = respSuccess.Configure()
	require.NoError(t, err)
}

func TestListen(t *testing.T) {
	addrStr := "/ip4/127.0.0.2/tcp/8000"

	testApp, _ := newTestApp(t, nil, true)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Listen_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetIface(addrStr))

	resMsg := testApp.handleListen(1239, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(1239))
	require.True(t, respSuccess.HasListen())
	lresp, err := respSuccess.Listen()
	require.NoError(t, err)
	l, err := lresp.Result()
	require.NoError(t, err)
	found := false
	err = multiaddrListForeach(l, func(v string) error {
		if v == addrStr {
			found = true
		}
		return nil
	})
	require.NoError(t, err)
	require.True(t, found)
}

func TestPublish(t *testing.T) {
	var err error
	testApp, _ := newTestApp(t, nil, true)
	testApp.P2p.Pubsub, err = pubsub.NewGossipSub(testApp.Ctx, testApp.P2p.Host)
	require.NoError(t, err)

	topic := "testtopic"
	data := []byte("testdata")

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Publish_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetTopic(topic))
	require.NoError(t, m.SetData(data))

	resMsg := testApp.handlePublish(39, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(39))
	require.True(t, respSuccess.HasPublish())
	_, err = respSuccess.Publish()
	require.NoError(t, err)

	_, has := testApp.Topics[topic]
	require.True(t, has)
}

func testSubscribeImpl(t *testing.T) (*app, string, uint64) {
	var err error
	testApp, _ := newTestApp(t, nil, true)
	testApp.P2p.Pubsub, err = pubsub.NewGossipSub(testApp.Ctx, testApp.P2p.Host)
	require.NoError(t, err)

	topic := "testtopic"
	idx := uint64(21)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Subscribe_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetTopic(topic))
	sid, err := m.NewSubscriptionId()
	require.NoError(t, err)
	sid.SetId(idx)

	resMsg := testApp.handleSubscribe(59, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(59))
	require.True(t, respSuccess.HasSubscribe())
	_, err = respSuccess.Subscribe()
	require.NoError(t, err)

	_, has := testApp.Topics[topic]
	require.True(t, has)
	_, has = testApp.Subs[idx]
	require.True(t, has)
	return testApp, topic, idx
}

func TestSubscribe(t *testing.T) {
	_, _, _ = testSubscribeImpl(t)
}

func TestUnsubscribe(t *testing.T) {
	var err error
	testApp, _, idx := testSubscribeImpl(t)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Unsubscribe_Request(seg)
	require.NoError(t, err)
	sid, err := m.NewSubscriptionId()
	require.NoError(t, err)
	sid.SetId(idx)

	resMsg := testApp.handleUnsubscribe(7739, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(7739))
	require.True(t, respSuccess.HasUnsubscribe())
	_, err = respSuccess.Unsubscribe()
	require.NoError(t, err)

	_, has := testApp.Subs[idx]
	require.False(t, has)
}

func TestValidationPush(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	ipcValResults := []ipc.ValidationResult{
		ipc.ValidationResult_accept,
		ipc.ValidationResult_reject,
		ipc.ValidationResult_ignore,
	}

	pubsubValResults := []pubsub.ValidationResult{
		pubsub.ValidationAccept,
		pubsub.ValidationReject,
		pubsub.ValidationIgnore,
	}

	for i := 0; i < len(ipcValResults); i++ {
		result := ValidationUnknown
		seqno := uint64(i)
		status := &validationStatus{
			Completion: make(chan pubsub.ValidationResult),
		}
		testApp.Validators[seqno] = status
		go func() {
			result = <-status.Completion
		}()
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		require.NoError(t, err)
		m, err := ipc.NewRootLibp2pHelperInterface_Validation(seg)
		require.NoError(t, err)
		m.SetValidationSeqNumber(seqno)
		m.SetResult(ipcValResults[i])
		testApp.handleValidation(m)
		require.NoError(t, err)
		require.Equal(t, pubsubValResults[i], result)
		_, has := testApp.Validators[seqno]
		require.False(t, has)
	}
}

func TestGenerateKeypair(t *testing.T) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_GenerateKeypair_Request(seg)
	require.NoError(t, err)

	testApp, _ := newTestApp(t, nil, true)
	resMsg := testApp.handleGenerateKeypair(7839, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(7839))
	require.True(t, respSuccess.HasGenerateKeypair())
	res, err := respSuccess.GenerateKeypair()
	require.NoError(t, err)
	r, err := res.Result()
	require.NoError(t, err)

	sk, err := r.PrivateKey()
	require.NoError(t, err)
	pk, err := r.PublicKey()
	require.NoError(t, err)
	pid, err := r.PeerId()
	require.NoError(t, err)
	peerId, err := pid.Id()
	require.NoError(t, err)

	// extra 4 bytes due to key type byte + protobuf encoding
	require.Equal(t, len(sk), 68)
	// extra 3 bytes due to key type byte + protobuf encoding
	require.Equal(t, len(pk), 36)
	require.Greater(t, len(peerId), 0)
}

func mkPeerInfo(t *testing.T, app *app, appPort uint16) codaPeerInfo {
	expectedHost, err := app.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	return codaPeerInfo{
		Libp2pPort: appPort,
		Host:       expectedHost,
		PeerID:     app.P2p.Host.ID().String(),
	}
}

func testOpenStreamImplDo(t *testing.T, appA *app, appB *app, appBPort uint16, rpcSeqno uint64, streamId uint64, protocol string) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_OpenStream_Request(seg)
	require.NoError(t, err)

	require.NoError(t, m.SetProtocolId(protocol))
	require.NoError(t, m.SetPeer(appB.P2p.Host.ID().String()))

	go func() {
		seqs <- streamId
	}()

	resMsg := appA.handleOpenStream(rpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasOpenStream())
	res, err := respSuccess.OpenStream()
	require.NoError(t, err)
	sid, err := res.StreamId()
	require.NoError(t, err)
	respStreamId := sid.Id()
	peerInfo, err := res.Peer()
	require.NoError(t, err)
	actual, err := readPeerInfo(peerInfo)
	require.NoError(t, err)

	expected := mkPeerInfo(t, appB, appBPort)

	require.Equal(t, respStreamId, streamId)
	require.Equal(t, expected, *actual)
}

func testOpenStreamImpl(t *testing.T, rpcSeqno uint64, streamId uint64, protocol string) *app {
	appA, _ := newTestApp(t, nil, true)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, appBPort := newTestApp(t, appAInfos, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	testOpenStreamImplDo(t, appA, appB, appBPort, rpcSeqno, streamId, protocol)
	return appA
}

func TestOpenStream(t *testing.T) {
	_ = testOpenStreamImpl(t, 9982, 4, string(testProtocol))
}

func TestCloseStream(t *testing.T) {
	appA := testOpenStreamImpl(t, 9983, 2, string(testProtocol))

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_CloseStream_Request(seg)
	require.NoError(t, err)
	sid, err := m.NewStreamId()
	require.NoError(t, err)
	sid.SetId(2)

	resMsg := appA.handleCloseStream(4778, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(4778))
	require.True(t, respSuccess.HasCloseStream())
	_, err = respSuccess.CloseStream()
	require.NoError(t, err)

	_, has := appA.Streams[1]
	require.False(t, has)
}

func TestResetStream(t *testing.T) {
	appA := testOpenStreamImpl(t, 9984, 2, string(testProtocol))

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_ResetStream_Request(seg)
	require.NoError(t, err)
	sid, err := m.NewStreamId()
	require.NoError(t, err)
	sid.SetId(2)

	resMsg := appA.handleResetStream(11458, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(11458))
	require.True(t, respSuccess.HasResetStream())
	_, err = respSuccess.ResetStream()
	require.NoError(t, err)

	_, has := appA.Streams[1]
	require.False(t, has)
}

func TestSendStream(t *testing.T) {
	appA := testOpenStreamImpl(t, 9985, 2, string(testProtocol))

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SendStream_Request(seg)
	require.NoError(t, err)
	msg, err := m.NewMsg()
	require.NoError(t, err)
	sid, err := msg.NewStreamId()
	require.NoError(t, err)
	sid.SetId(2)
	require.NoError(t, msg.SetData([]byte("somedata")))

	var sendRpcSeqno uint64 = 4458
	resMsg := appA.handleSendStream(sendRpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, sendRpcSeqno)
	require.True(t, respSuccess.HasSendStream())
	_, err = respSuccess.SendStream()
	require.NoError(t, err)

	_, has := appA.Streams[1]
	require.False(t, has)
}

func testAddStreamHandler(t *testing.T, protocol string) (*app, *app, uint16) {
	appA, _ := newTestApp(t, nil, true)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, appBPort := newTestApp(t, appAInfos, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_AddStreamHandler_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetProtocol(protocol))

	doASH := func(app *app, rpcSeqno uint64) {
		resMsg := app.handleAddStreamHandler(rpcSeqno, m)
		seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
		require.Equal(t, seqno, rpcSeqno)
		require.True(t, respSuccess.HasAddStreamHandler())
		_, err = respSuccess.AddStreamHandler()
		require.NoError(t, err)
	}

	doASH(appA, 19092)
	doASH(appB, 19093)
	return appA, appB, appBPort
}

func TestAddStreamHandler(t *testing.T) {
	newProtocol := "/mina/99"
	appA, appB, appBPort := testAddStreamHandler(t, newProtocol)
	testOpenStreamImplDo(t, appA, appB, appBPort, 9988, 8, newProtocol)
}

func TestRemoveStreamHandler(t *testing.T) {
	newProtocol := "/mina/99"

	appA, appB, _ := testAddStreamHandler(t, newProtocol)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	rsh, err := ipc.NewRootLibp2pHelperInterface_RemoveStreamHandler_Request(seg)
	require.NoError(t, err)
	require.NoError(t, rsh.SetProtocol(newProtocol))
	var rshRpcSeqno uint64 = 1023
	resMsg := appB.handleRemoveStreamHandler(rshRpcSeqno, rsh)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, rshRpcSeqno)
	require.True(t, respSuccess.HasRemoveStreamHandler())
	_, err = respSuccess.RemoveStreamHandler()
	require.NoError(t, err)

	_, seg, err = capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	os, err := ipc.NewRootLibp2pHelperInterface_OpenStream_Request(seg)
	require.NoError(t, err)
	require.NoError(t, os.SetProtocolId(newProtocol))
	require.NoError(t, os.SetPeer(appB.P2p.Host.ID().String()))

	go func() {
		seqs <- 1
		seqs <- 2
	}()

	var osRpcSeqno uint64 = 1026
	osResMsg := appA.handleOpenStream(osRpcSeqno, os)
	osRpcSeqno_, errMsg := checkRpcResponseError(t, osResMsg)
	require.Equal(t, osRpcSeqno, osRpcSeqno_)
	require.Equal(t, "libp2p error: protocol not supported", errMsg)
}

func ToStringList(vs []ma.Multiaddr) []string {
	vsm := make([]string, len(vs))
	for i, v := range vs {
		vsm[i] = v.String()
	}
	return vsm
}

func TestGetListeningAddrs(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_GetListeningAddrs_Request(seg)
	require.NoError(t, err)
	var mRpcSeqno uint64 = 1024
	resMsg := testApp.handleGetListeningAddrs(mRpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasGetListeningAddrs())
	ls, err := respSuccess.GetListeningAddrs()
	require.NoError(t, err)
	addrsL, err := ls.Result()
	res, err := readMultiaddrList(addrsL)
	require.NoError(t, err)
	require.Equal(t, ToStringList(testApp.P2p.Host.Addrs()), res)
}

func testAddPeerImpl(t *testing.T) (*app, uint16, *app) {
	appA, appAPort := newTestApp(t, nil, true)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, _ := newTestApp(t, appAInfos, true)

	addr := fmt.Sprintf("%s/p2p/%s", appAInfos[0].Addrs[0], appAInfos[0].ID)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_AddPeer_Request(seg)
	require.NoError(t, err)
	ma, err := m.NewMultiaddr()
	require.NoError(t, err)
	require.NoError(t, ma.SetRepresentation(addr))
	m.SetIsSeed(false)

	var mRpcSeqno uint64 = 2000
	resMsg := appB.handleAddPeer(mRpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasAddPeer())
	_, err = respSuccess.AddPeer()
	require.NoError(t, err)

	addrs := appB.P2p.Host.Peerstore().Addrs(appA.P2p.Host.ID())
	require.NotEqual(t, 0, len(addrs))

	return appA, appAPort, appB
}

func TestAddPeer(t *testing.T) {
	_, _, _ = testAddPeerImpl(t)
}

func TestFindPeer(t *testing.T) {
	appA, appAPort, appB := testAddPeerImpl(t)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_FindPeer_Request(seg)
	require.NoError(t, err)
	pid, err := m.NewPeerId()
	require.NoError(t, err)
	peerId := appA.P2p.Host.ID().String()
	require.NoError(t, pid.SetId(peerId))

	var mRpcSeqno uint64 = 2001
	resMsg := appB.handleFindPeer(mRpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasFindPeer())
	resp, err := respSuccess.FindPeer()
	require.NoError(t, err)
	res, err := resp.Result()
	require.NoError(t, err)

	actual, err := readPeerInfo(res)
	require.NoError(t, err)

	expected := mkPeerInfo(t, appA, appAPort)
	require.Equal(t, expected, *actual)
}

func TestListPeers(t *testing.T) {
	appA, appAPort, appB := testAddPeerImpl(t)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_ListPeers_Request(seg)
	require.NoError(t, err)

	var mRpcSeqno uint64 = 2002
	resMsg := appB.handleListPeers(mRpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasListPeers())
	resp, err := respSuccess.ListPeers()
	require.NoError(t, err)
	res, err := resp.Result()
	require.NoError(t, err)
	require.Equal(t, 1, res.Len())
	actual, err := readPeerInfo(res.At(0))
	require.NoError(t, err)

	expected := mkPeerInfo(t, appA, appAPort)
	require.Equal(t, expected, *actual)
}

func TestSetGatingConfig(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	allowedID := "12D3KooWJDGPa2hiYCJ2o7XPqEq2tjrWpFJzqa4dy538Gfs7Vn2r"
	allowedMultiaddr, err := ma.NewMultiaddr("/ip4/7.8.9.0/tcp/7000")
	require.NoError(t, err)

	bannedID := "12D3KooWGnQ4vat8EybAeFEK3jk78vmwDu9qMhZzcyQBPb16VCnS"
	bannedMultiaddr, err := ma.NewMultiaddr("/ip4/1.2.3.4/tcp/7000")
	require.NoError(t, err)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SetGatingConfig_Request(seg)
	require.NoError(t, err)

	gc, err := m.NewGatingConfig()
	require.NoError(t, err)
	bIps, err := gc.NewBannedIps(1)
	require.NoError(t, err)
	bPids, err := gc.NewBannedPeerIds(1)
	require.NoError(t, err)
	tIps, err := gc.NewTrustedIps(1)
	require.NoError(t, err)
	tPids, err := gc.NewTrustedPeerIds(1)
	require.NoError(t, err)
	require.NoError(t, bIps.Set(0, "1.2.3.4"))
	require.NoError(t, bPids.At(0).SetId(bannedID))
	require.NoError(t, tIps.Set(0, "7.8.9.0"))
	require.NoError(t, tPids.At(0).SetId(allowedID))
	gc.SetIsolate(false)

	var mRpcSeqno uint64 = 2003
	resMsg := testApp.handleSetGatingConfig(mRpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasSetGatingConfig())
	_, err = respSuccess.SetGatingConfig()
	require.NoError(t, err)

	ok := testApp.P2p.GatingState.InterceptPeerDial(peer.ID(bannedID))
	require.False(t, ok)

	ok = testApp.P2p.GatingState.InterceptPeerDial(peer.ID(allowedID))
	require.True(t, ok)

	ok = testApp.P2p.GatingState.InterceptAddrDial(peer.ID(bannedID), bannedMultiaddr)
	require.False(t, ok)

	ok = testApp.P2p.GatingState.InterceptAddrDial(peer.ID(bannedID), allowedMultiaddr)
	require.False(t, ok)

	ok = testApp.P2p.GatingState.InterceptAddrDial(peer.ID(allowedID), allowedMultiaddr)
	require.True(t, ok)
}

func TestPeerExchange(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	// only allow peer count of 2 for node A
	maxCount := 2
	appAPort := testPort
	testPort++
	appA := newTestAppWithMaxConns(t, nil, true, maxCount, appAPort)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, _ := newTestApp(t, nil, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC, _ := newTestApp(t, nil, true)
	err = appC.P2p.Host.Connect(appC.Ctx, appAInfos[0])
	require.NoError(t, err)

	// appD will try to connect to appA, appA will send peer msg containing B and C and disconnect
	appD, _ := newTestApp(t, appAInfos, true)
	err = appD.P2p.Host.Connect(appD.Ctx, appAInfos[0])
	require.NoError(t, err)

	t.Logf("a=%s", appA.P2p.Host.ID())
	t.Logf("b=%s", appB.P2p.Host.ID())
	t.Logf("c=%s", appC.P2p.Host.ID())
	t.Logf("d=%s", appD.P2p.Host.ID())

	done := make(chan struct{})

	go func() {
		for {
			// check if appC is connected to appB
			for _, peer := range appD.P2p.Host.Network().Peers() {
				if peer == appB.P2p.Host.ID() || peer == appC.P2p.Host.ID() {
					close(done)
					return
				}
			}
			time.Sleep(time.Millisecond * 100)
		}
	}()

	select {
	case <-time.After(testTimeout):
		t.Fatal("D did not connect to B or C via A")
	case <-done:
	}

	time.Sleep(time.Second)
	require.Equal(t, maxCount, len(appA.P2p.Host.Network().Peers()))
}

func TestGetPeerNodeStatus(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	// only allow peer count of 1 for node A
	maxCount := 1
	port := testPort
	testPort++
	appA := newTestAppWithMaxConns(t, nil, true, maxCount, port)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	appA.P2p.NodeStatus = []byte("testdata")

	appB, _ := newTestApp(t, nil, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC, _ := newTestApp(t, nil, true)
	appC.P2p.Host.Peerstore().AddAddrs(appA.P2p.Host.ID(), appAInfos[0].Addrs, peerstore.ConnectedAddrTTL)

	maStrs := multiaddrs(appA.P2p.Host)
	addr := maStrs[0].String()

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_GetPeerNodeStatus_Request(seg)
	require.NoError(t, err)
	ma, err := m.NewPeer()
	require.NoError(t, err)
	require.NoError(t, ma.SetRepresentation(addr))

	var mRpcSeqno uint64 = 18900
	resMsg := appB.handleGetPeerNodeStatus(mRpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasGetPeerNodeStatus())
	resp, err := respSuccess.GetPeerNodeStatus()
	require.NoError(t, err)
	status, err := resp.Result()
	require.NoError(t, err)
	require.Equal(t, appA.P2p.NodeStatus, status)
}

func sendStreamMessage(t *testing.T, from *app, to *app, msg []byte) {
	stream, err := from.P2p.Host.NewStream(context.Background(), to.P2p.Host.ID(), testProtocol)
	_, err = stream.Write(msg)
	require.NoError(t, err)
	err = stream.Close()
	require.NoError(t, err)
}

func waitForMessages(t *testing.T, app *app, numExpectedMessages int) [][]byte {
	done := make(chan struct{})
	msgStates := make(map[uint64][]byte)
	receivedMsgs := make([][]byte, 0, numExpectedMessages)

	go (func() {
		awaiting := numExpectedMessages
		for {
			rawMsg := <-app.OutChan
			imsg, err := ipc.ReadRootDaemonInterface_Message(rawMsg)
			require.NoError(t, err)
			if !imsg.HasPushMessage() {
				continue
			}
			pmsg, err := imsg.PushMessage()
			require.NoError(t, err)
			if pmsg.HasStreamComplete() {
				smc, err := pmsg.StreamComplete()
				require.NoError(t, err)
				sid, err := smc.StreamId()
				streamId := sid.Id()
				require.NoError(t, err)
				receivedMsgs = append(receivedMsgs, msgStates[streamId])
				awaiting -= 1
				if awaiting <= 0 {
					close(done)
					return
				}
			} else if pmsg.HasStreamMessageReceived() {
				smr, err := pmsg.StreamMessageReceived()
				require.NoError(t, err)
				msg, err := smr.Msg()
				require.NoError(t, err)
				sid, err := msg.StreamId()
				require.NoError(t, err)
				streamId := sid.Id()
				data, err := msg.Data()
				require.NoError(t, err)
				msgStates[streamId] = append(msgStates[streamId], data...)
			}
		}
	})()

	select {
	case <-time.After(testTimeout):
		t.Fatal("did not receive all expected messages")
	case <-done:
	}

	return receivedMsgs
}

func TestMplex_SendMultipleMessage(t *testing.T) {
	// assert we are able to send and receive multiple messages with size up to 1 << 10 bytes
	appA, _ := newTestApp(t, nil, false)
	appA.NoDHT = true
	defer appA.P2p.Host.Close()

	appB, _ := newTestApp(t, nil, false)
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	var streamIdx uint64 = 0
	handler := func(stream net.Stream) {
		handleStreamReads(appB, stream, streamIdx)
		streamIdx++
	}

	appB.P2p.Host.SetStreamHandler(testProtocol, handler)

	// Send multiple messages from A to B
	msg := createMessage(1 << 10)
	sendStreamMessage(t, appA, appB, msg)
	sendStreamMessage(t, appA, appB, msg)
	sendStreamMessage(t, appA, appB, msg)

	// Assert all messages were received intact
	receivedMsgs := waitForMessages(t, appB, 3)
	require.Equal(t, [][]byte{msg, msg, msg}, receivedMsgs)
}

func TestLibp2pMetrics(t *testing.T) {
	// assert we are able to get the correct metrics of libp2p node
	appA, _ := newTestApp(t, nil, false)
	appA.NoDHT = true
	defer appA.P2p.Host.Close()

	appB, _ := newTestApp(t, nil, false)
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	var streamIdx uint64 = 0
	handler := func(stream net.Stream) {
		handleStreamReads(appB, stream, streamIdx)
		streamIdx++
	}

	appB.P2p.Host.SetStreamHandler(testProtocol, handler)

	server := http.NewServeMux()
	server.Handle("/metrics", promhttp.Handler())
	go http.ListenAndServe(":9001", server)

	go appB.checkPeerCount()
	go appB.checkMessageStats()

	// Send multiple messages from A to B
	sendStreamMessage(t, appA, appB, createMessage(maxStatsMsg))
	sendStreamMessage(t, appA, appB, createMessage(minStatsMsg))
	waitForMessages(t, appB, 2)

	time.Sleep(5 * time.Second) // Wait for metrics to be reported.

	avgStatsMsg := (maxStatsMsg + minStatsMsg) / 2 // Total message sent count
	expectedPeerCount := len(appB.P2p.Host.Network().Peers())
	expectedCurrentConnCount := appB.P2p.ConnectionManager.GetInfo().ConnCount

	resp, err := http.Get("http://localhost:9001/metrics")
	require.NoError(t, err)
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	require.NoError(t, err)

	respBody := string(body)
	peerCount := getMetricsValue(t, respBody, "\nMina_libp2p_peer_count")
	require.Equal(t, strconv.Itoa(expectedPeerCount), peerCount)

	connectedPeerCount := getMetricsValue(t, respBody, "\nMina_libp2p_connected_peer_count")
	require.Equal(t, strconv.Itoa(expectedCurrentConnCount), connectedPeerCount)

	maxStats := getMetricsValue(t, respBody, "\nMina_libp2p_message_max_stats")
	require.Equal(t, strconv.Itoa(maxStatsMsg), maxStats)

	avgStats := getMetricsValue(t, respBody, "\nMina_libp2p_message_avg_stats")
	require.Equal(t, strconv.Itoa(avgStatsMsg), avgStats)

	minStats := getMetricsValue(t, respBody, "\nMina_libp2p_message_min_stats")
	require.Equal(t, strconv.Itoa(minStatsMsg), minStats)
}

func getMetricsValue(t *testing.T, str string, pattern string) string {
	t.Helper()

	indx := strings.Index(str, pattern)
	endIdx := strings.Index(str[indx+len(pattern):], "\n")
	endIdx = endIdx + indx + len(pattern)

	u := str[indx+1 : endIdx]
	metricsData := strings.Split(u, " ")
	require.Len(t, metricsData, 2)

	return metricsData[1]
}
