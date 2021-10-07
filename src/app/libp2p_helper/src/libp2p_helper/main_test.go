package main

import (
	"context"
<<<<<<< HEAD
	crand "crypto/rand"
	"encoding/json"
	"fmt"
=======
	"io"
>>>>>>> origin/compatible
	"io/ioutil"
	"os"
	"strings"
	"testing"
	"time"

	"codanet"

<<<<<<< HEAD
	logging "github.com/ipfs/go-log"
=======
>>>>>>> origin/compatible
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"net/http"
	"strconv"

<<<<<<< HEAD
	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/host"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	peerstore "github.com/libp2p/go-libp2p-core/peerstore"
	protocol "github.com/libp2p/go-libp2p-core/protocol"
	pubsub "github.com/libp2p/go-libp2p-pubsub"

	ma "github.com/multiformats/go-multiaddr"
=======
	logging "github.com/ipfs/go-log"

	net "github.com/libp2p/go-libp2p-core/network"
>>>>>>> origin/compatible

	"github.com/stretchr/testify/require"
	ipc "libp2p_ipc"
)

<<<<<<< HEAD
var (
	testTimeout  = 30 * time.Second
	testProtocol = protocol.ID("/mina/")
)

var port = 7000

=======
>>>>>>> origin/compatible
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

<<<<<<< HEAD
func createMessage(size int) []byte {
	return make([]byte, size)
}

func newTestKey(t *testing.T) crypto.PrivKey {
	r := crand.Reader
	key, _, err := crypto.GenerateEd25519Key(r)
	require.NoError(t, err)

	return key
}

func testStreamHandler(_ net.Stream) {}

func newTestAppWithMaxConns(t *testing.T, seeds []peer.AddrInfo, noUpcalls bool, maxConns int) *app {
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
		P2p:                helper,
		Ctx:                context.Background(),
		Subs:               make(map[int]subscription),
		Topics:             make(map[string]*pubsub.Topic),
		ValidatorMutex:     &sync.Mutex{},
		Validators:         make(map[int]*validationStatus),
		Streams:            make(map[int]net.Stream),
		StreamStates:       make(map[int]streamState),
		OutChan:            make(chan interface{}),
		MetricsRefreshTime: time.Second * 2,
		NoUpcalls:          noUpcalls,
		messageBufferPool:  newMessageBufferPool(),
	}
}

func newTestApp(t *testing.T, seeds []peer.AddrInfo, noUpcalls bool) *app {
	return newTestAppWithMaxConns(t, seeds, noUpcalls, 50)
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
	appA := newTestApp(t, nil, true)
	appA.NoMDNS = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos, true)
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
	appA := newTestApp(t, nil, true)
	appA.NoMDNS = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos, true)
	appB.NoMDNS = true

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC := newTestApp(t, appAInfos, true)
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
	appA := newTestApp(t, nil, true)
	appA.NoDHT = true

	appB := newTestApp(t, nil, true)
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
		MetricsPort:         "",
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

	testApp := newTestApp(t, nil, true)

	msg := &listenMsg{
		Iface: addrStr,
	}

	addrs, err := msg.run(testApp)
	require.NoError(t, err)
=======
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

	msgSize := uint64(1 << 30)

	withTimeoutAsync(t, func(done chan interface{}) {
		// create handler that reads `msgSize` bytes
		handler := func(stream net.Stream) {
			r := bufio.NewReader(stream)
			i := uint64(0)

			for {
				_, err := r.ReadByte()
				if err == io.EOF {
					break
				}
>>>>>>> origin/compatible

				i++
				if i == msgSize {
					close(done)
					return
				}
			}
		}

		appB.P2p.Host.SetStreamHandler(testProtocol, handler)

		// send large message from A to B
		msg := createMessage(msgSize)

		stream, err := appA.P2p.Host.NewStream(context.Background(), appB.P2p.Host.ID(), testProtocol)
		require.NoError(t, err)

		_, err = stream.Write(msg)
		require.NoError(t, err)
	}, "B did not receive a large message from A")
}

func createMessage(size uint64) []byte {
	return make([]byte, size)
}

func TestPeerExchange(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	// only allow peer count of 2 for node A
	maxCount := 2
	appAPort := nextPort()
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

	withTimeout(t, func() {
		for {
			// check if appC is connected to appB
			for _, peer := range appD.P2p.Host.Network().Peers() {
				if peer == appB.P2p.Host.ID() || peer == appC.P2p.Host.ID() {
					return
				}
			}
			time.Sleep(time.Millisecond * 100)
		}
	}, "D did not connect to B or C via A")

	time.Sleep(time.Second)
	require.Equal(t, maxCount, len(appA.P2p.Host.Network().Peers()))
}

<<<<<<< HEAD
func TestGetNodeStatus(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	// only allow peer count of 1 for node A
	maxCount := 1
	appA := newTestAppWithMaxConns(t, nil, true, maxCount)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	appA.P2p.NodeStatus = "testdata"

	appB := newTestApp(t, nil, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC := newTestApp(t, nil, true)
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

func testDirectionalStream(t *testing.T, from *app, to *app, f func(net.Stream)) {
	done := make(chan struct{})
	to.P2p.Host.SetStreamHandler(testProtocol, func(stream net.Stream) {
		handleStreamReads(to, stream, 0)
		close(done)
	})

=======
func sendStreamMessage(t *testing.T, from *app, to *app, msg []byte) {
>>>>>>> origin/compatible
	stream, err := from.P2p.Host.NewStream(context.Background(), to.P2p.Host.ID(), testProtocol)
	require.NoError(t, err)

<<<<<<< HEAD
	f(stream)

	err = stream.Close()
	require.NoError(t, err)

	select {
	case <-time.After(testTimeout):
		t.Fatal("stream did not close within allotted time")
	case <-done:
	}
}

func sendStreamMessage(t *testing.T, stream net.Stream, msg []byte) {
	lenBytes := uint64ToLEB128(uint64(len(msg)))
	encodedMsg := make([]byte, len(lenBytes)+len(msg))
	for i, b := range lenBytes {
		encodedMsg[i] = b
	}
	_, err := stream.Write(encodedMsg)
	require.NoError(t, err)
}

func waitForMessage(t *testing.T, app *app, expectedMessageSize int) []byte {
	receivedMessage := make([]byte, 0)
	for len(receivedMessage) < expectedMessageSize {
		msg := <-app.OutChan
		require.NotEmpty(t, msg)

		bytes, err := json.Marshal(msg)
		require.NoError(t, err)

		var result map[string]interface{}
		err = json.Unmarshal(bytes, &result)
		require.NoError(t, err)

		upcall, ok := result["upcall"]
		require.True(t, ok)
		require.Equal(t, upcall, "incomingStreamMsg")

		data, ok := result["data"]
		require.True(t, ok)

		decodedData, err := codaDecode(data.(string))
		require.NoError(t, err)

		receivedMessage = append(receivedMessage, decodedData...)
	}

	require.Equal(t, len(receivedMessage), expectedMessageSize)
	return receivedMessage
}

func TestMplex_SendLargeMessage(t *testing.T) {
	// assert we are able to send and receive a message with size up to 1 << 30 bytes
	appA := newTestApp(t, nil, false)
	appA.NoDHT = true
	appB := newTestApp(t, nil, false)
	appB.NoDHT = true

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	// send large message from A to B
	msgSize := 1 << 30
	msg := createMessage(msgSize)
=======
func waitForMessages(t *testing.T, app *app, numExpectedMessages int) [][]byte {
	msgStates := make(map[uint64][]byte)
	receivedMsgs := make([][]byte, 0, numExpectedMessages)

	withTimeout(t, func() {
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
	}, "did not receive all expected messages")
>>>>>>> origin/compatible

	testDirectionalStream(t, appA, appB, func(stream net.Stream) {
		appB.StreamStates[0] = STREAM_DATA_EXPECTED
		sendStreamMessage(t, stream, msg)
		require.Equal(t, msg, waitForMessage(t, appB, msgSize))
	})
}

func TestMplex_SendMultipleMessage(t *testing.T) {
	// assert we are able to send and receive multiple messages with size up to 1 << 10 bytes
	appA, _ := newTestApp(t, nil, false)
	appA.NoDHT = true
	defer appA.P2p.Host.Close()
<<<<<<< HEAD
	appB := newTestApp(t, nil, false)
=======

	appB, _ := newTestApp(t, nil, false)
>>>>>>> origin/compatible
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

<<<<<<< HEAD
	msgSize := 1 << 10
	msg := createMessage(msgSize)
=======
	handler := func(stream net.Stream) {
		handleStreamReads(appB, stream, appB.NextId())
	}
>>>>>>> origin/compatible

	testDirectionalStream(t, appA, appB, func(stream net.Stream) {
		appB.StreamStates[0] = STREAM_DATA_EXPECTED
		sendStreamMessage(t, stream, msg)
		require.Equal(t, msg, waitForMessage(t, appB, msgSize))
		appB.StreamStates[0] = STREAM_DATA_EXPECTED
		sendStreamMessage(t, stream, msg)
		require.Equal(t, msg, waitForMessage(t, appB, msgSize))
		appB.StreamStates[0] = STREAM_DATA_EXPECTED
		sendStreamMessage(t, stream, msg)
		require.Equal(t, msg, waitForMessage(t, appB, msgSize))
	})
}

func TestLibp2pMetrics(t *testing.T) {
	// assert we are able to get the correct metrics of libp2p node
	appA, _ := newTestApp(t, nil, false)
	appA.NoDHT = true
	defer appA.P2p.Host.Close()
<<<<<<< HEAD
	appB := newTestApp(t, nil, false)
=======

	appB, _ := newTestApp(t, nil, false)
>>>>>>> origin/compatible
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

<<<<<<< HEAD
=======
	var streamIdx uint64 = 0
	handler := func(stream net.Stream) {
		handleStreamReads(appB, stream, streamIdx)
		streamIdx++
	}

	appB.P2p.Host.SetStreamHandler(testProtocol, handler)

>>>>>>> origin/compatible
	server := http.NewServeMux()
	server.Handle("/metrics", promhttp.Handler())
	go http.ListenAndServe(":9001", server)

	go appB.checkPeerCount()
	go appB.checkMessageStats()

	// Send multiple messages from A to B
	testDirectionalStream(t, appA, appB, func(stream net.Stream) {
		appB.StreamStates[0] = STREAM_DATA_EXPECTED
		sendStreamMessage(t, stream, createMessage(maxStatsMsg))
		waitForMessage(t, appB, maxStatsMsg)
		appB.StreamStates[0] = STREAM_DATA_EXPECTED
		sendStreamMessage(t, stream, createMessage(minStatsMsg))
		waitForMessage(t, appB, minStatsMsg)
	})

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
