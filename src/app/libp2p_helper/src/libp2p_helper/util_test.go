package main

import (
	"context"
	crand "crypto/rand"
	"fmt"
	"io/ioutil"
	"sync"
	"testing"
	"time"

	"codanet"

	"github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/host"
	net "github.com/libp2p/go-libp2p-core/network"
	"github.com/libp2p/go-libp2p-core/peer"
	"github.com/libp2p/go-libp2p-core/protocol"
	pubsub "github.com/libp2p/go-libp2p-pubsub"

	ma "github.com/multiformats/go-multiaddr"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/stretchr/testify/require"
)

var (
	defaultTestTimeout = 10 * time.Second
	testProtocol       = protocol.ID("/mina/")
)

var testPort uint16 = 7000
var testPortMutex sync.Mutex

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
		StreamStates:             make(map[uint64]streamState),
		StreamsMutex:             sync.Mutex{},
		AddedPeers:               make([]peer.AddrInfo, 0, 512),
		OutChan:                  make(chan *capnp.Message, 64),
		MetricsRefreshTime:       time.Second * 2,
		NoUpcalls:                noUpcalls,
		messageBufferPool:        newMessageBufferPool(),
		metricsServer:            nil,
		metricsCollectionStarted: false,
	}
}

func nextPort() uint16 {
	testPortMutex.Lock()
	testPort++
	defer testPortMutex.Unlock()
	return testPort
}

func newTestApp(t *testing.T, seeds []peer.AddrInfo, noUpcalls bool) (*app, uint16) {
	port := nextPort()
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

func testDirectionalStream(t *testing.T, from *app, to *app, f func(net.Stream)) {
	done := make(chan struct{})
	to.P2p.Host.SetStreamHandler(testProtocol, func(stream net.Stream) {
		handleStreamReads(to, stream, 0)
		close(done)
	})

	stream, err := from.P2p.Host.NewStream(context.Background(), to.P2p.Host.ID(), testProtocol)
	require.NoError(t, err)

	f(stream)

	err = stream.Close()
	require.NoError(t, err)

	<-done
}

func encodeStreamMessage(msg []byte) []byte {
	lenBytes := uint64ToLEB128(uint64(len(msg)))
	encodedMsg := make([]byte, len(lenBytes)+len(msg))
	copy(encodedMsg[:len(lenBytes)], lenBytes)
	copy(encodedMsg[len(lenBytes):], msg)
	return encodedMsg
}

func sendStreamMessage(t *testing.T, stream net.Stream, msg []byte) {
	_, err := stream.Write(encodeStreamMessage(msg))
	require.NoError(t, err)
}

func waitForMessage(t *testing.T, app *app, expectedMessageSize uint64) []byte {
	receivedMessage := make([]byte, 0)
	withTimeout(t, func() {
		for uint64(len(receivedMessage)) < expectedMessageSize {
			rawMsg := <-app.OutChan
			require.NotEmpty(t, rawMsg)
			imsg, err := ipc.ReadRootDaemonInterface_Message(rawMsg)
			require.NoError(t, err)
			if !imsg.HasPushMessage() {
				continue
			}
			pmsg, err := imsg.PushMessage()
			require.NoError(t, err)
			if pmsg.HasStreamComplete() {
				return
			} else if pmsg.HasStreamMessageReceived() {
				smr, err := pmsg.StreamMessageReceived()
				require.NoError(t, err)
				msg, err := smr.Msg()
				require.NoError(t, err)
				data, err := msg.Data()
				require.NoError(t, err)
				receivedMessage = append(receivedMessage, data...)
			}
		}

		require.Equal(t, uint64(len(receivedMessage)), expectedMessageSize)
	}, "did not receive all expected messages")

	return receivedMessage
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
	seqno, err := header.SequenceNumber()
	require.NoError(t, err)
	respError, err := resp.Error()
	require.NoError(t, err)
	return seqno.Seqno(), respError
}

func checkRpcResponseSuccess(t *testing.T, resMsg *capnp.Message) (uint64, ipc.Libp2pHelperInterface_RpcResponseSuccess) {
	msg, err := ipc.ReadRootDaemonInterface_Message(resMsg)
	require.NoError(t, err)
	require.True(t, msg.HasRpcResponse())
	resp, err := msg.RpcResponse()
	require.NoError(t, err)
	if resp.HasError() {
		respError, err := resp.Error()
		require.NoError(t, err)
		require.FailNowf(t, "unexpected RPC error", respError)
	} else if !resp.HasSuccess() {
		require.FailNow(t, "received invalid RPC response")
	}

	require.True(t, resp.HasSuccess())
	header, err := resp.Header()
	require.NoError(t, err)
	seqno, err := header.SequenceNumber()
	require.NoError(t, err)
	respSuccess, err := resp.Success()
	require.NoError(t, err)
	return seqno.Seqno(), respSuccess
}

func checkPeerInfo(t *testing.T, actual *codaPeerInfo, host host.Host, port uint16) {
	// Check of host is commented out as sometimes it's 127.0.0.1,
	// sometimes it's some other IP of the machine
	// expectedHost, err := host.Addrs()[0].ValueForProtocol(4)
	require.Equal(t, port, actual.Libp2pPort)
	require.Equal(t, host.ID().String(), actual.PeerID)
}

func beginAdvertisingSendAndCheck(t *testing.T, app *app) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_BeginAdvertising_Request(seg)
	require.NoError(t, err)
	var rpcSeqno uint64 = 123
	resMsg := BeginAdvertisingReq(m).handle(app, rpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasBeginAdvertising())
	_, err = respSuccess.BeginAdvertising()
	require.NoError(t, err)
}

func withTimeout(t *testing.T, run func(), timeoutMsg string) {
	withSpecificTimeout(t, run, defaultTestTimeout, timeoutMsg)
}

func withSpecificTimeout(t *testing.T, run func(), timeout time.Duration, timeoutMsg string) {
	withSpecificTimeoutAsync(t, func(done chan interface{}) {
		defer close(done)
		run()
	}, timeout, timeoutMsg)
}

func withTimeoutAsync(t *testing.T, registerDone func(done chan interface{}), timeoutMsg string) {
	withSpecificTimeoutAsync(t, registerDone, defaultTestTimeout, timeoutMsg)
}

func withSpecificTimeoutAsync(t *testing.T, registerDone func(done chan interface{}), timeout time.Duration, timeoutMsg string) {
	done := make(chan interface{})
	go registerDone(done)
	select {
	case <-time.After(timeout):
		close(done)
		t.Fatal(timeoutMsg)
	case <-done:
	}
}
