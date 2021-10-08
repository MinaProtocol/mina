package main

import (
	"io/ioutil"
	"os"
	"strings"
	"testing"
	"time"

	"codanet"

	"net/http"
	"strconv"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	logging "github.com/ipfs/go-log"

	net "github.com/libp2p/go-libp2p-core/network"

	"github.com/stretchr/testify/require"
)

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

func TestMplex_SendLargeMessage(t *testing.T) {
	// assert we are able to send and receive a message with size up to 1 << 30 bytes
	appA, _ := newTestApp(t, nil, false)
	appA.NoDHT = true

	appB, _ := newTestApp(t, nil, false)
	appB.NoDHT = true

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	// send large message from A to B
	msgSize := uint64(1 << 30)
	msg := createMessage(msgSize)

	withSpecificTimeout(t, func() {
		testDirectionalStream(t, appA, appB, func(stream net.Stream) {
			appB.StreamStates[0] = STREAM_DATA_EXPECTED
			sendStreamMessage(t, stream, msg)
			require.Equal(t, msg, waitForMessage(t, appB, msgSize))
		})
	}, 30*time.Second, "B did not receive a large message from A")
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

	msgSize := uint64(1 << 10)
	msg := createMessage(msgSize)

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

	appB, _ := newTestApp(t, nil, false)
	appB.NoDHT = true
	defer appB.P2p.Host.Close()

	// connect the two nodes
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

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
