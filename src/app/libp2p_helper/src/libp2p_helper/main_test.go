package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"os"
	"strings"
	"testing"
	"time"

	"codanet"

	"net/http"
	"strconv"

	"github.com/prometheus/client_golang/prometheus/promhttp"

	logging "github.com/ipfs/go-log/v2"

	net "github.com/libp2p/go-libp2p-core/network"

	ipc "libp2p_ipc"

	"github.com/stretchr/testify/require"
)

func TestMain(m *testing.M) {
	for i := 0; i < 100; i++ {
		logging.Logger(fmt.Sprintf("node%d", i))
	}
	// Uncomment for more logging (ERROR by default)
	// _ = logging.SetLogLevel("mina.helper.bitswap", "WARN")
	// _ = logging.SetLogLevel("engine", "DEBUG")
	// _ = logging.SetLogLevel("codanet.Helper", "WARN")
	// _ = logging.SetLogLevel("codanet.CodaGatingState", "WARN")
	// for i := 0; i < 100; i++ {
	// 	logging.SetLogLevel(fmt.Sprintf("node%d", i), "WARN")
	// }
	// _ = logging.SetLogLevel("dht", "debug")
	// _ = logging.SetLogLevel("connmgr", "debug")
	// _ = logging.SetLogLevel("*", "debug")
	codanet.WithPrivate = true

	os.Exit(m.Run())
}

const (
	maxStatsMsg = 1 << 6
	minStatsMsg = 1 << 3
)

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
	// only allow peer count of 2 for node A
	maxCount := 2
	appAPort := nextPort()
	appA := newTestAppWithMaxConnsAndCtxAndGrace(t, newTestKey(t), nil, true, maxCount, maxCount, true, appAPort, context.Background(), time.Second)
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

	ctx, cancelF := context.WithTimeout(context.Background(), time.Minute)
	go func() {
		for {
			// check if appC is connected to appB
			for _, peer := range appD.P2p.Host.Network().Peers() {
				if peer == appB.P2p.Host.ID() || peer == appC.P2p.Host.ID() {
					cancelF()
					return
				}
			}
			time.Sleep(time.Millisecond * 100)
		}
	}()

	<-ctx.Done()

	if ctx.Err() == context.DeadlineExceeded {
		t.Fatal("D did not connect to B or C via A")
	}
	time.Sleep(time.Second * 2)
	appA.P2p.TrimOpenConns(context.Background())
	time.Sleep(time.Second)

	require.LessOrEqual(t, len(appA.P2p.Host.Network().Peers()), maxCount)
}

func sendStreamMessage(t *testing.T, from *app, to *app, msg []byte) {
	stream, err := from.P2p.Host.NewStream(context.Background(), to.P2p.Host.ID(), testProtocol)
	require.NoError(t, err)
	_, err = stream.Write(msg)
	require.NoError(t, err)
	err = stream.Close()
	require.NoError(t, err)
}

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

	handler := func(stream net.Stream) {
		handleStreamReads(appB, stream, appB.NextId())
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
