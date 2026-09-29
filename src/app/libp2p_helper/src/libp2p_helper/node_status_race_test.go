package main

import (
	"sync"
	"testing"

	"codanet"

	capnp "capnproto.org/go/capnp/v3"
	ipc "libp2p_ipc"

	"github.com/stretchr/testify/require"
)

func setNodeStatusImpl(t *testing.T, testApp *app, status []byte) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SetNodeStatus_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetStatus(status))
	resMsg, _ := SetNodeStatusReq(m).handle(testApp, 1)
	_, respSuccess := checkRpcResponseSuccess(t, resMsg, "setNodeStatus")
	require.True(t, respSuccess.HasSetNodeStatus())
}

// Regression test: NodeStatus is written by the SetNodeStatus RPC handler
// while node-status streams concurrently read it to serve remote peers.
// Without synchronization this is a data race (run with -race).
func TestNodeStatusConcurrentSetAndServe(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	maxCount := 2
	port := nextPort()
	appA := newTestAppWithMaxConns(t, nil, true, maxCount, maxCount, port)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	setNodeStatusImpl(t, appA, []byte("initial status"))

	appB, _ := newTestApp(t, nil, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	addr := multiaddrs(appA.P2p.Host)[0].String()

	done := make(chan struct{})
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		i := 0
		for {
			select {
			case <-done:
				return
			default:
			}
			setNodeStatusImpl(t, appA, []byte{byte(i), byte(i >> 8)})
			i++
		}
	}()

	for i := 0; i < 5; i++ {
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		require.NoError(t, err)
		m, err := ipc.NewRootLibp2pHelperInterface_GetPeerNodeStatus_Request(seg)
		require.NoError(t, err)
		ma, err := m.NewPeer()
		require.NoError(t, err)
		require.NoError(t, ma.SetRepresentation(addr))
		resMsg, _ := GetPeerNodeStatusReq(m).handle(appB, uint64(100+i))
		_, respSuccess := checkRpcResponseSuccess(t, resMsg, "getPeerNodeStatus")
		require.True(t, respSuccess.HasGetPeerNodeStatus())
	}

	close(done)
	wg.Wait()
}
