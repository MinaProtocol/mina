package main

import (
	"bufio"
	"codanet"
	"context"
	crand "crypto/rand"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"sync"
	"testing"
	"time"

	logging "github.com/ipfs/go-log"
	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/host"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	peerstore "github.com/libp2p/go-libp2p-core/peerstore"
	protocol "github.com/libp2p/go-libp2p-core/protocol"

	"github.com/libp2p/go-libp2p-pubsub"
	ma "github.com/multiformats/go-multiaddr"

	"github.com/stretchr/testify/require"
)

var (
	testTimeout  = 10 * time.Second
	testProtocol = protocol.ID("/mina/")
)

var port = 7000

func TestMain(m *testing.M) {
	_ = logging.SetLogLevel("codanet.Helper", "debug")
	_ = logging.SetLogLevel("codanet.CodaGatingState", "debug")
	codanet.WithPrivate = true

	os.Exit(m.Run())
}

func newTestKey(t *testing.T) crypto.PrivKey {
	r := crand.Reader
	key, _, err := crypto.GenerateEd25519Key(r)
	require.NoError(t, err)

	return key
}

func testStreamHandler(_ net.Stream) {}

func newTestAppWithMaxConns(t *testing.T, seeds []peer.AddrInfo, maxConns int) *app {
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
	port++

	helper.GatingState.TrustedAddrFilters = ma.NewFilters()
	helper.Host.SetStreamHandler(testProtocol, testStreamHandler)

	t.Cleanup(func() {
		err := helper.Host.Close()
		if err != nil {
			panic(err)
		}
	})

	return &app{
		P2p:            helper,
		Ctx:            context.Background(),
		Subs:           make(map[int]subscription),
		Topics:         make(map[string]*pubsub.Topic),
		ValidatorMutex: &sync.Mutex{},
		Validators:     make(map[int]*validationStatus),
		Streams:        make(map[int]net.Stream),
		AddedPeers:     make([]peer.AddrInfo, 0, 512),
		NoUpcalls:      true,
	}
}

func newTestApp(t *testing.T, seeds []peer.AddrInfo) *app {
	return newTestAppWithMaxConns(t, seeds, 50)
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

func TestDHTDiscovery_TwoNodes(t *testing.T) {
	appA := newTestApp(t, nil)
	appA.NoMDNS = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	appB.AddedPeers = appAInfos
	appB.NoMDNS = true

	// begin appB and appC's DHT advertising
	ret, err := new(beginAdvertisingMsg).run(appB)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	ret, err = new(beginAdvertisingMsg).run(appA)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	time.Sleep(time.Second)
}

func TestDHTDiscovery_ThreeNodes(t *testing.T) {
	appA := newTestApp(t, nil)
	appA.NoMDNS = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	appB.NoMDNS = true

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC := newTestApp(t, appAInfos)
	appC.NoMDNS = true

	err = appC.P2p.Host.Connect(appC.Ctx, appAInfos[0])
	require.NoError(t, err)

	time.Sleep(time.Second)

	// begin appB and appC's DHT advertising
	ret, err := new(beginAdvertisingMsg).run(appB)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	ret, err = new(beginAdvertisingMsg).run(appC)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

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
	appA := newTestApp(t, nil)
	appA.NoDHT = true

	appB := newTestApp(t, nil)
	appB.NoDHT = true

	// begin appA and appB's mDNS advertising
	ret, err := new(beginAdvertisingMsg).run(appB)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	ret, err = new(beginAdvertisingMsg).run(appA)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

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

func createLargeMessage() []byte {
	return make([]byte, (1 << 30))
}

func TestMplex_SendLargeMessage(t *testing.T) {
	// assert we are able to send and receive a message with size up to 1 << 30 bytes
	appA := newTestApp(t, nil)
	appA.NoDHT = true

	appB := newTestApp(t, nil)
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
	msg := createLargeMessage()

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

func TestConfigurationMsg(t *testing.T) {
	testApp := newApp()

	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	key, _, err := crypto.GenerateEd25519Key(crand.Reader)
	require.NoError(t, err)
	keyBytes, err := key.Bytes()
	require.NoError(t, err)
	keyEnc := codaEncode(keyBytes)

	external := "/ip4/0.0.0.0/tcp/7000"

	msg := &configureMsg{
		Statedir:            dir,
		Privk:               keyEnc,
		NetworkID:           string(testProtocol),
		ListenOn:            []string{"/ip4/127.0.0.1/tcp/7000"},
		MetricsPort:         "9000",
		External:            external,
		ValidationQueueSize: 16,
	}

	ret, err := msg.run(testApp)
	require.NoError(t, err)
	require.Equal(t, "configure success", ret)
}

func TestListenMsg(t *testing.T) {
	addrStr := "/ip4/127.0.0.2/tcp/8000"

	addr, err := ma.NewMultiaddr(addrStr)
	require.NoError(t, err)

	testApp := newTestApp(t, nil)

	msg := &listenMsg{
		Iface: addrStr,
	}

	addrs, err := msg.run(testApp)
	require.NoError(t, err)

	found := false
	for _, a := range addrs.([]ma.Multiaddr) {
		if a.Equal(addr) {
			found = true
			break
		}
	}

	require.True(t, found)
}

func TestPublishMsg(t *testing.T) {
	var err error
	testApp := newTestApp(t, nil)
	testApp.P2p.Pubsub, err = pubsub.NewGossipSub(testApp.Ctx, testApp.P2p.Host)
	require.NoError(t, err)

	topic := "testtopic"
	data := "testdata"

	msg := &publishMsg{
		Topic: topic,
		Data:  data,
	}

	ret, err := msg.run(testApp)
	require.NoError(t, err)
	require.Equal(t, "publish success", ret)

	_, has := testApp.Topics[topic]
	require.True(t, has)
}

func TestSubscribeMsg(t *testing.T) {
	var err error
	testApp := newTestApp(t, nil)
	testApp.P2p.Pubsub, err = pubsub.NewGossipSub(testApp.Ctx, testApp.P2p.Host)
	require.NoError(t, err)

	topic := "testtopic"
	idx := 0

	msg := &subscribeMsg{
		Topic:        topic,
		Subscription: idx,
	}

	ret, err := msg.run(testApp)
	require.NoError(t, err)
	require.Equal(t, "subscribe success", ret)

	_, has := testApp.Topics[topic]
	require.True(t, has)
	_, has = testApp.Subs[idx]
	require.True(t, has)
}

func TestUnsubscribeMsg(t *testing.T) {
	var err error
	testApp := newTestApp(t, nil)
	testApp.P2p.Pubsub, err = pubsub.NewGossipSub(testApp.Ctx, testApp.P2p.Host)
	require.NoError(t, err)

	topic := "testtopic"
	idx := 0

	msg := &subscribeMsg{
		Topic:        topic,
		Subscription: idx,
	}

	ret, err := msg.run(testApp)
	require.NoError(t, err)
	require.Equal(t, "subscribe success", ret)

	_, has := testApp.Topics[topic]
	require.True(t, has)
	_, has = testApp.Subs[idx]
	require.True(t, has)

	unsubMsg := &unsubscribeMsg{
		Subscription: idx,
	}
	ret, err = unsubMsg.run(testApp)
	require.NoError(t, err)
	require.Equal(t, "unsubscribe success", ret)

	_, has = testApp.Subs[idx]
	require.False(t, has)
}

func TestValidationCompleteMsg(t *testing.T) {
	testApp := newTestApp(t, nil)

	var result string
	idx := 0
	status := &validationStatus{
		Completion: make(chan string),
	}

	testApp.Validators[idx] = status

	go func() {
		result = <-status.Completion
	}()

	msg := &validationCompleteMsg{
		Seqno: idx,
		Valid: acceptResult,
	}

	ret, err := msg.run(testApp)
	require.NoError(t, err)
	require.Equal(t, "validationComplete success", ret)
	require.Equal(t, acceptResult, result)
}

func TestGenerateKeypairMsg(t *testing.T) {
	testApp := newTestApp(t, nil)

	ret, err := (&generateKeypairMsg{}).run(testApp)
	require.NoError(t, err)

	kp, ok := ret.(generatedKeypair)
	require.True(t, ok)
	require.NotEqual(t, "", kp.Private)
	require.NotEqual(t, "", kp.Public)
	require.NotEqual(t, "", kp.PeerID)
}

func TestOpenStreamMsg(t *testing.T) {
	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	msg := &openStreamMsg{
		Peer:       appB.P2p.Host.ID().String(),
		ProtocolID: string(testProtocol),
	}

	go func() {
		seqs <- 1
	}()

	ret, err := msg.run(appA)
	require.NoError(t, err)

	expectedHost, err := appB.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	expectedPort := port - 1
	expected := codaPeerInfo{
		Libp2pPort: expectedPort,
		Host:       expectedHost,
		PeerID:     appB.P2p.Host.ID().String(),
	}

	res, ok := ret.(openStreamResult)
	require.True(t, ok)
	require.Equal(t, res.StreamIdx, 1)
	require.Equal(t, res.Peer, expected)
}

func TestCloseStreamMsg(t *testing.T) {
	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	msg := &openStreamMsg{
		Peer:       appB.P2p.Host.ID().String(),
		ProtocolID: string(testProtocol),
	}

	go func() {
		seqs <- 1
	}()

	ret, err := msg.run(appA)
	require.NoError(t, err)

	expectedHost, err := appB.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	expectedPort := port - 1
	expected := codaPeerInfo{
		Libp2pPort: expectedPort,
		Host:       expectedHost,
		PeerID:     appB.P2p.Host.ID().String(),
	}

	res, ok := ret.(openStreamResult)
	require.True(t, ok)
	require.Equal(t, res.StreamIdx, 1)
	require.Equal(t, res.Peer, expected)

	closeMsg := &closeStreamMsg{
		StreamIdx: 1,
	}

	ret, err = closeMsg.run(appA)
	require.NoError(t, err)
	require.Equal(t, "closeStream success", ret)

	_, has := appA.Streams[1]
	require.False(t, has)
}

func TestResetStreamMsg(t *testing.T) {
	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	msg := &openStreamMsg{
		Peer:       appB.P2p.Host.ID().String(),
		ProtocolID: string(testProtocol),
	}

	go func() {
		seqs <- 1
	}()

	ret, err := msg.run(appA)
	require.NoError(t, err)

	expectedHost, err := appB.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	expectedPort := port - 1
	expected := codaPeerInfo{
		Libp2pPort: expectedPort,
		Host:       expectedHost,
		PeerID:     appB.P2p.Host.ID().String(),
	}

	res, ok := ret.(openStreamResult)
	require.True(t, ok)
	require.Equal(t, res.StreamIdx, 1)
	require.Equal(t, res.Peer, expected)

	resetMsg := &resetStreamMsg{
		StreamIdx: 1,
	}

	ret, err = resetMsg.run(appA)
	require.NoError(t, err)
	require.Equal(t, "resetStream success", ret)

	_, has := appA.Streams[1]
	require.False(t, has)
}

func TestSendStreamMsg(t *testing.T) {
	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	msg := &openStreamMsg{
		Peer:       appB.P2p.Host.ID().String(),
		ProtocolID: string(testProtocol),
	}

	go func() {
		seqs <- 1
	}()

	ret, err := msg.run(appA)
	require.NoError(t, err)

	expectedHost, err := appB.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	expectedPort := port - 1
	expected := codaPeerInfo{
		Libp2pPort: expectedPort,
		Host:       expectedHost,
		PeerID:     appB.P2p.Host.ID().String(),
	}

	res, ok := ret.(openStreamResult)
	require.True(t, ok)
	require.Equal(t, res.StreamIdx, 1)
	require.Equal(t, res.Peer, expected)

	sendMsg := &sendStreamMsgMsg{
		StreamIdx: 1,
		Data:      "somedata",
	}

	ret, err = sendMsg.run(appA)
	require.NoError(t, err)
	require.Equal(t, "sendStreamMsg success", ret)
}

func TestAddStreamHandlerMsg(t *testing.T) {
	newProtocol := "/mina/99"

	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	addMsg := &addStreamHandlerMsg{
		Protocol: newProtocol,
	}

	ret, err := addMsg.run(appA)
	require.NoError(t, err)
	require.Equal(t, "addStreamHandler success", ret)
	ret, err = addMsg.run(appB)
	require.NoError(t, err)
	require.Equal(t, "addStreamHandler success", ret)

	msg := &openStreamMsg{
		Peer:       appB.P2p.Host.ID().String(),
		ProtocolID: newProtocol,
	}

	go func() {
		seqs <- 1
	}()

	ret, err = msg.run(appA)
	require.NoError(t, err)

	expectedHost, err := appB.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	expectedPort := port - 1
	expected := codaPeerInfo{
		Libp2pPort: expectedPort,
		Host:       expectedHost,
		PeerID:     appB.P2p.Host.ID().String(),
	}

	res, ok := ret.(openStreamResult)
	require.True(t, ok)
	require.Equal(t, res.StreamIdx, 1)
	require.Equal(t, res.Peer, expected)
}

func TestRemoveStreamHandlerMsg(t *testing.T) {
	newProtocol := "/mina/99"

	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	addMsg := &addStreamHandlerMsg{
		Protocol: newProtocol,
	}

	ret, err := addMsg.run(appA)
	require.NoError(t, err)
	require.Equal(t, "addStreamHandler success", ret)
	ret, err = addMsg.run(appB)
	require.NoError(t, err)
	require.Equal(t, "addStreamHandler success", ret)

	removeMsg := &removeStreamHandlerMsg{
		Protocol: newProtocol,
	}
	ret, err = removeMsg.run(appB)
	require.NoError(t, err)
	require.Equal(t, "removeStreamHandler success", ret)

	msg := &openStreamMsg{
		Peer:       appB.P2p.Host.ID().String(),
		ProtocolID: newProtocol,
	}

	go func() {
		seqs <- 1
		seqs <- 2
	}()

	_, err = msg.run(appA)
	require.Equal(t, "protocol not supported", err.(wrappedError).Unwrap().Error())
}

func TestListeningAddrsMsg(t *testing.T) {
	testApp := newTestApp(t, nil)

	ret, err := (&listeningAddrsMsg{}).run(testApp)
	require.NoError(t, err)
	require.Equal(t, testApp.P2p.Host.Addrs(), ret)
}

func TestAddPeerMsg(t *testing.T) {
	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)

	msg := &addPeerMsg{
		Multiaddr: fmt.Sprintf("%s/p2p/%s", appAInfos[0].Addrs[0], appAInfos[0].ID),
	}

	ret, err := msg.run(appB)
	require.NoError(t, err)
	require.Equal(t, "addPeer success", ret)

	addrs := appB.P2p.Host.Peerstore().Addrs(appA.P2p.Host.ID())
	require.NotEqual(t, 0, len(addrs))
}

func TestFindPeerMsg(t *testing.T) {
	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)

	msg := &addPeerMsg{
		Multiaddr: fmt.Sprintf("%s/p2p/%s", appAInfos[0].Addrs[0], appAInfos[0].ID),
	}

	ret, err := msg.run(appB)
	require.NoError(t, err)
	require.Equal(t, "addPeer success", ret)

	addrs := appB.P2p.Host.Peerstore().Addrs(appA.P2p.Host.ID())
	require.NotEqual(t, 0, len(addrs))

	findMsg := &findPeerMsg{
		PeerID: appA.P2p.Host.ID().String(),
	}

	expectedHost, err := appA.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	expectedPort := port - 2
	expected := codaPeerInfo{
		Libp2pPort: expectedPort,
		Host:       expectedHost,
		PeerID:     appA.P2p.Host.ID().String(),
	}

	ret, err = findMsg.run(appB)
	require.NoError(t, err)
	require.Equal(t, expected, ret)
}

func TestListPeersMsg(t *testing.T) {
	appA := newTestApp(t, nil)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)

	msg := &addPeerMsg{
		Multiaddr: fmt.Sprintf("%s/p2p/%s", appAInfos[0].Addrs[0], appAInfos[0].ID),
	}

	ret, err := msg.run(appB)
	require.NoError(t, err)
	require.Equal(t, "addPeer success", ret)

	addrs := appB.P2p.Host.Peerstore().Addrs(appA.P2p.Host.ID())
	require.NotEqual(t, 0, len(addrs))

	expectedHost, err := appA.P2p.Host.Addrs()[0].ValueForProtocol(4)
	require.NoError(t, err)
	expectedPort := port - 2
	expected := codaPeerInfo{
		Libp2pPort: expectedPort,
		Host:       expectedHost,
		PeerID:     appA.P2p.Host.ID().String(),
	}

	ret, err = (&listPeersMsg{}).run(appB)
	require.NoError(t, err)
	infos := ret.([]codaPeerInfo)
	require.Equal(t, 1, len(infos))
	require.Equal(t, expected, infos[0])
}

func TestSetGatingConfigMsg(t *testing.T) {
	testApp := newTestApp(t, nil)

	allowedID := "12D3KooWJDGPa2hiYCJ2o7XPqEq2tjrWpFJzqa4dy538Gfs7Vn2r"
	allowedMultiaddr, err := ma.NewMultiaddr("/ip4/7.8.9.0/tcp/7000")
	require.NoError(t, err)

	bannedID := "12D3KooWGnQ4vat8EybAeFEK3jk78vmwDu9qMhZzcyQBPb16VCnS"
	bannedMultiaddr, err := ma.NewMultiaddr("/ip4/1.2.3.4/tcp/7000")
	require.NoError(t, err)

	msg := &setGatingConfigMsg{
		BannedIPs:      []string{"1.2.3.4"},
		BannedPeerIDs:  []string{bannedID},
		TrustedPeerIDs: []string{allowedID},
		TrustedIPs:     []string{"7.8.9.0"},
	}

	ret, err := msg.run(testApp)
	require.NoError(t, err)
	require.Equal(t, "ok", ret)

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

func TestGetPeerMessage(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	// only allow peer count of 2 for node A
	maxCount := 2
	appA := newTestAppWithMaxConns(t, nil, maxCount)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, nil)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC := newTestApp(t, nil)
	err = appC.P2p.Host.Connect(appC.Ctx, appAInfos[0])
	require.NoError(t, err)

	// appD will try to connect to appA, appA will send peer msg containing B and C and disconnect
	appD := newTestApp(t, appAInfos)
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

func TestGetNodeStatus(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	// only allow peer count of 1 for node A
	maxCount := 1
	appA := newTestAppWithMaxConns(t, nil, maxCount)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	appA.P2p.NodeStatus = "testdata"

	appB := newTestApp(t, nil)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC := newTestApp(t, nil)
	appC.P2p.Host.Peerstore().AddAddrs(appA.P2p.Host.ID(), appAInfos[0].Addrs, peerstore.ConnectedAddrTTL)

	maStrs := multiaddrs(appA.P2p.Host)

	// ensure we can receive data before being disconnected
	msg := &getPeerNodeStatusMsg{
		PeerMultiaddr: maStrs[0].String(),
	}

	ret, err := msg.run(appC)
	require.NoError(t, err)
	require.Equal(t, appA.P2p.NodeStatus, ret)
}
