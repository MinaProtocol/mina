package main

import (
	"context"
	crand "crypto/rand"
	"fmt"
	"io/ioutil"
	"os"
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
	testTimeout  = 10 * time.Second
	testProtocol = protocol.ID("/mina/")
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

func newTestAppWithMaxConns(t *testing.T, seeds []peer.AddrInfo, noUpcalls bool, minConns, maxConns int, port uint16) *app {
	return newTestAppWithMaxConnsAndCtx(t, newTestKey(t), seeds, noUpcalls, minConns, maxConns, true, port, context.Background())
}
func newTestAppWithMaxConnsAndCtx(t *testing.T, privkey crypto.PrivKey, seeds []peer.AddrInfo, noUpcalls bool, minConns, maxConns int, minaPeerExchange bool, port uint16, ctx context.Context) *app {
	return newTestAppWithMaxConnsAndCtxAndGrace(t, privkey, seeds, noUpcalls, minConns, maxConns, minaPeerExchange, port, ctx, 10*time.Second)
}
func newTestAppWithMaxConnsAndCtxAndGrace(t *testing.T, privkey crypto.PrivKey, seeds []peer.AddrInfo, noUpcalls bool, minConns, maxConns int, minaPeerExchange bool, port uint16, ctx context.Context, gracePeriod time.Duration) *app {
	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	addr, err := ma.NewMultiaddr(fmt.Sprintf("/ip4/0.0.0.0/tcp/%d", port))
	require.NoError(t, err)

	helper, err := codanet.MakeHelper(ctx,
		[]ma.Multiaddr{addr},
		nil,
		dir,
		privkey,
		string(testProtocol),
		seeds,
		&codanet.CodaGatingConfig{},
		minConns,
		maxConns,
		minaPeerExchange,
		gracePeriod,
		nil,
	)
	require.NoError(t, err)

	helper.ResetGatingConfigTrustedAddrFilters()
	helper.Host.SetStreamHandler(testProtocol, testStreamHandler)

	t.Cleanup(func() {
		panicOnErr(os.RemoveAll(dir))
		panicOnErr(helper.Host.Close())
	})
	outChan := make(chan *capnp.Message, 64)
	bitswapCtx := NewBitswapCtx(ctx, outChan)
	bitswapCtx.engine = helper.Bitswap
	bitswapCtx.storage = helper.BitswapStorage

	return &app{
		P2p:                      helper,
		Ctx:                      ctx,
		Subs:                     make(map[uint64]subscription),
		Topics:                   make(map[string]*pubsub.Topic),
		ValidatorMutex:           &sync.Mutex{},
		Validators:               make(map[uint64]*validationStatus),
		Streams:                  make(map[uint64]net.Stream),
		AddedPeers:               make([]peer.AddrInfo, 0, 512),
		OutChan:                  outChan,
		MetricsRefreshTime:       time.Second * 2,
		NoUpcalls:                noUpcalls,
		metricsServer:            nil,
		metricsCollectionStarted: false,
		bitswapCtx:               bitswapCtx,
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
	return newTestAppWithMaxConns(t, seeds, noUpcalls, 20, 50, port), port
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
	seqno, err := header.SequenceNumber()
	require.NoError(t, err)
	respError, err := resp.Error()
	require.NoError(t, err)
	return seqno.Seqno(), respError
}

func checkRpcResponseSuccess(t *testing.T, resMsg *capnp.Message, request string) (uint64, ipc.Libp2pHelperInterface_RpcResponseSuccess) {
	msg, err := ipc.ReadRootDaemonInterface_Message(resMsg)
	require.NoError(t, err)
	require.True(t, msg.HasRpcResponse())
	resp, err := msg.RpcResponse()
	require.NoError(t, err)
	if !resp.HasSuccess() {
		if resp.HasError() {
			str, _ := resp.Error()
			t.Logf("Got error on %s: %s", request, str)
		} else {
			t.Logf("Neither Error nor Success on %s", request)
		}
		t.FailNow()
	}
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

func beginAdvertisingSendAndCheckDo(app *app, rpcSeqno uint64) (*capnp.Message, error) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	if err != nil {
		return nil, err
	}
	m, err := ipc.NewRootLibp2pHelperInterface_BeginAdvertising_Request(seg)
	if err != nil {
		return nil, err
	}
	return BeginAdvertisingReq(m).handle(app, rpcSeqno), nil
}

func checkBeginAdvertisingResponse(t *testing.T, rpcSeqno uint64, resMsg *capnp.Message) {
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "beginAdvertising")
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasBeginAdvertising())
	_, err := respSuccess.BeginAdvertising()
	require.NoError(t, err)
}

func beginAdvertisingSendAndCheck(t *testing.T, app *app) {
	var rpcSeqno uint64 = 123
	resMsg, err := beginAdvertisingSendAndCheckDo(app, rpcSeqno)
	require.NoError(t, err)
	checkBeginAdvertisingResponse(t, rpcSeqno, resMsg)
}

func withTimeout(t *testing.T, run func(), timeoutMsg string) {
	success := withCustomTimeout(run, testTimeout)
	if !success {
		t.Fatal(timeoutMsg)
	}
}

func withCustomTimeout(run func(), timeout time.Duration) bool {
	return withCustomTimeoutAsync(func(done chan interface{}) {
		run()
		select {
		case <-done:
		default:
			close(done)
		}
	}, timeout)
}

func withTimeoutAsync(t *testing.T, registerDone func(done chan interface{}), timeoutMsg string) {
	success := withCustomTimeoutAsync(registerDone, testTimeout)
	if !success {
		t.Fatal(timeoutMsg)
	}
}
func withCustomTimeoutAsync(registerDone func(done chan interface{}), timeout time.Duration) bool {
	done := make(chan interface{})
	go registerDone(done)
	select {
	case <-time.After(timeout):
		select {
		case <-done:
		default:
			close(done)
		}
		return false
	case <-done:
		return true
	}
}

func handleErrChan(t *testing.T, errChan chan error, ctxCancel context.CancelFunc) {
	go func() {
		err, has := <-errChan
		if has {
			ctxCancel()
			errChan <- err
		}
	}()
	t.Cleanup(func() {
		ctxCancel()
		close(errChan)
		for err := range errChan {
			t.Errorf("failed with %s", err)
		}
	})
}
