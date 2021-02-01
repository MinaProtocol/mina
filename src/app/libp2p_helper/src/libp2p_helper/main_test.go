package main

import (
	"context"
	crand "crypto/rand"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"codanet"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/host"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	protocol "github.com/libp2p/go-libp2p-core/protocol"

	"github.com/libp2p/go-libp2p-pubsub"
	ma "github.com/multiformats/go-multiaddr"

	"github.com/stretchr/testify/require"
)

var (
	testTimeout  = 30 * time.Second
	testProtocol = protocol.ID("/mina/")
)

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

func newTestApp(t *testing.T, seeds []peer.AddrInfo) *app {
	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	helper, err := codanet.MakeHelper(context.Background(),
		[]ma.Multiaddr{},
		nil,
		dir,
		newTestKey(t),
		string(testProtocol),
		seeds,
		codanet.NewCodaGatingState(nil, nil, nil),
		50,
	)
	require.NoError(t, err)

	return &app{
		P2p:                helper,
		Ctx:                context.Background(),
		Subs:               make(map[int]subscription),
		Topics:             make(map[string]*pubsub.Topic),
		ValidatorMutex:     &sync.Mutex{},
		Validators:         make(map[int]*validationStatus),
		Streams:            make(map[int]net.Stream),
		AddedPeers:         make([]peer.AddrInfo, 0, 512),
		OutChan:            make(chan interface{}),
		MetricsRefreshTime: time.Second * 2,
	}
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
	defer appA.P2p.Host.Close()

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	appB.AddedPeers = appAInfos
	appB.NoMDNS = true
	defer appB.P2p.Host.Close()

	// begin appB and appC's DHT advertising
	ret, err := new(beginAdvertisingMsg).run(appB)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	ret, err = new(beginAdvertisingMsg).run(appA)
	require.NoError(t, err)
	require.Equal(t, ret, "beginAdvertising success")

	time.Sleep(time.Second)
}

func TestDHTDiscovery(t *testing.T) {
	appA := newTestApp(t, nil)
	appA.NoMDNS = true
	defer appA.P2p.Host.Close()

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB := newTestApp(t, appAInfos)
	appB.NoMDNS = true
	defer appB.P2p.Host.Close()

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC := newTestApp(t, appAInfos)
	appC.NoMDNS = true
	defer appC.P2p.Host.Close()

	err = appC.P2p.Host.Connect(appC.Ctx, appAInfos[0])
	require.NoError(t, err)

	time.Sleep(time.Second)

	go func() {
		<-appA.OutChan
	}()

	go func() {
		<-appB.OutChan
	}()

	go func() {
		<-appC.OutChan
	}()

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
	defer appA.P2p.Host.Close()

	appB := newTestApp(t, nil)
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

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

func createMessage(size uint64) []byte {
	return make([]byte, size)
}

func TestMplex_SendLargeMessage(t *testing.T) {
	// assert we are able to send and receive a message with size up to 1 << 30 bytes
	appA := newTestApp(t, nil)
	appA.NoDHT = true
	defer appA.P2p.Host.Close()

	appB := newTestApp(t, nil)
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	// send large message from A to B
	actualMessage := createMessage(1 << 30)

	// create handler that reads 1<<30 bytes
	done := make(chan struct{})
	handler := func(stream net.Stream) {
		handleStreamReads(appB, stream, 0)

		data := <-appB.OutChan
		require.NotEmpty(t, data)

		bytes, err := json.Marshal(data)
		require.NoError(t, err)

		var result map[string]interface{}
		err = json.Unmarshal(bytes, &result)
		require.NoError(t, err)

		data, ok := result["data"]
		require.True(t, ok)

		expectedMessage, err := codaDecode(data.(string))
		require.NoError(t, err)

		require.Equal(t, expectedMessage, actualMessage)
		close(done)
	}

	appB.P2p.Host.SetStreamHandler(testProtocol, handler)

	stream, err := appA.P2p.Host.NewStream(context.Background(), appB.P2p.Host.ID(), testProtocol)
	require.NoError(t, err)

	lenBytes := uint64ToLEB128(uint64(len(actualMessage)))
	msg := append(lenBytes, actualMessage...)

	_, err = stream.Write(msg)
	require.NoError(t, err)

	select {
	case <-time.After(testTimeout):
		t.Fatal("B did not receive a large message from A")
	case <-done:
	}
}

func TestMplex_SendMultipleMessage(t *testing.T) {
	// assert we are able to send and receive multiple messages with size up to 1 << 10 bytes
	appA := newTestApp(t, nil)
	appA.NoDHT = true
	defer appA.P2p.Host.Close()

	appB := newTestApp(t, nil)
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	// Send multiple messages from A to B
	actualMessage := createMessage(1 << 10)

	// create handler that reads 3 messages of size 1<<10 bytes
	done := make(chan struct{})
	handler := func(stream net.Stream) {
		handleStreamReads(appB, stream, 0)

		for i := 1; i <= 3; {
			data := <-appB.OutChan
			require.NotEmpty(t, data)

			bytes, err := json.Marshal(data)
			require.NoError(t, err)

			var result map[string]interface{}
			err = json.Unmarshal(bytes, &result)
			require.NoError(t, err)

			op, ok := result["upcall"]
			if op != "incomingStreamMsg" {
				continue
			}
			i++

			data, ok = result["data"]
			require.True(t, ok)

			expectedMessage, err := codaDecode(data.(string))
			require.NoError(t, err)

			require.Equal(t, expectedMessage, actualMessage)
		}
		close(done)
	}

	appB.P2p.Host.SetStreamHandler(testProtocol, handler)

	stream, err := appA.P2p.Host.NewStream(context.Background(), appB.P2p.Host.ID(), testProtocol)
	require.NoError(t, err)

	lenBytes := uint64ToLEB128(uint64(len(actualMessage)))
	msg := append(lenBytes, actualMessage...)

	_, err = stream.Write(msg)
	require.NoError(t, err)

	_, err = stream.Write(msg)
	require.NoError(t, err)

	_, err = stream.Write(msg)
	require.NoError(t, err)

	select {
	case <-time.After(testTimeout):
		t.Fatal("B did not receive a large message from A")
	case <-done:
	}
}

func TestLib2pMetrics(t *testing.T) {
	// assert we are able to get the correct metrics of libp2p node
	appA := newTestApp(t, nil)
	appA.NoDHT = true
	defer appA.P2p.Host.Close()

	appB := newTestApp(t, nil)
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	done := make(chan struct{})
	handler := func(stream net.Stream) {
		handleStreamReads(appB, stream, 0)
		// Wait for message to be read.
		for i := 1; i <= 4; i++ {
			data := <-appB.OutChan
			require.NotEmpty(t, data)
		}
		close(done)
	}

	appB.P2p.Host.SetStreamHandler(testProtocol, handler)

	stream, err := appA.P2p.Host.NewStream(context.Background(), appB.P2p.Host.ID(), testProtocol)
	require.NoError(t, err)

	server := http.NewServeMux()
	server.Handle("/metrics", promhttp.Handler())
	go http.ListenAndServe(":9001", server)

	go appA.checkPeerCount(appA.P2p.Me)
	go appA.checkMessageExchanged(appA.P2p.Me)
	go appB.checkMessageStats(appB.P2p.Me)

	// Send multiple messages from A to B
	message := createMessage(maxStatsMsg)
	lenBytes := uint64ToLEB128(maxStatsMsg)
	msg := append(lenBytes, message...)

	_, err = stream.Write(msg)
	require.NoError(t, err)

	smallMessage := createMessage(minStatsMsg)
	newMsgLen := uint64ToLEB128(minStatsMsg)
	newMsg := append(newMsgLen, smallMessage...)

	_, err = stream.Write(newMsg)
	require.NoError(t, err)

	select {
	case <-time.After(testTimeout):
		t.Fatal("B did not receive a large message from A")
	case <-done:
	}

	time.Sleep(5 * time.Second) // Wait for metrics to be reported.

	avgStatsMsg := (maxStatsMsg + minStatsMsg) / 2 // Total message sent count
	expectedPeerCount := appA.P2p.Host.Network().Peers()
	expectedCurrentConnCount := appA.P2p.ConnectionManager.GetInfo().ConnCount

	resp, err := http.Get("http://localhost:9001/metrics")
	require.NoError(t, err)
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	require.NoError(t, err)

	respBody := string(body)
	peerCount := getMetricsValue(t, respBody, "\npeer_count_"+appA.P2p.Me.String())
	require.Equal(t, strconv.Itoa(expectedCurrentConnCount), peerCount)

	peerConn := getMetricsValue(t, respBody, "\nmessage_exchanged_"+appA.P2p.Me.String())
	require.Equal(t, strconv.Itoa(len(expectedPeerCount)), peerConn)

	maxStats := getMetricsValue(t, respBody, "\nmessage_max_stats_"+appB.P2p.Me.String())
	require.Equal(t, strconv.Itoa(maxStatsMsg), maxStats)

	avgStats := getMetricsValue(t, respBody, "\nmessage_avg_stats_"+appB.P2p.Me.String())
	require.Equal(t, strconv.Itoa(avgStatsMsg), avgStats)

	minStats := getMetricsValue(t, respBody, "\nmessage_min_stats_"+appB.P2p.Me.String())
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
