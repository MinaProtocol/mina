package main

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/require"

	"codanet"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/libp2p/go-libp2p-core/peer"
	"github.com/libp2p/go-libp2p-core/peerstore"
)

func testAddPeerImplDo(t *testing.T, node *app, peerAddr peer.AddrInfo, isSeed bool) {
	addr := fmt.Sprintf("%s/p2p/%s", peerAddr.Addrs[0], peerAddr.ID)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_AddPeer_Request(seg)
	require.NoError(t, err)
	ma, err := m.NewMultiaddr()
	require.NoError(t, err)
	require.NoError(t, ma.SetRepresentation(addr))
	m.SetIsSeed(isSeed)

	var mRpcSeqno uint64 = 2000
	resMsg := AddPeerReq(m).handle(node, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "addPeer")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasAddPeer())
	_, err = respSuccess.AddPeer()
	require.NoError(t, err)
}

func testAddPeerImpl(t *testing.T) (*app, uint16, *app) {
	appA, appAPort := newTestApp(t, nil, true)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, _ := newTestApp(t, appAInfos, true)

	testAddPeerImplDo(t, appB, appAInfos[0], false)

	addrs := appB.P2p.Host.Peerstore().Addrs(appA.P2p.Host.ID())
	require.NotEqual(t, 0, len(addrs))

	return appA, appAPort, appB
}

func TestAddPeer(t *testing.T) {
	_, _, _ = testAddPeerImpl(t)
}

func TestGetPeerNodeStatus(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	// only allow peer count of 1 for node A
	maxCount := 1
	port := nextPort()
	appA := newTestAppWithMaxConns(t, nil, true, maxCount, maxCount, port)
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
	resMsg := GetPeerNodeStatusReq(m).handle(appB, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "getPeerNodeStatus")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasGetPeerNodeStatus())
	resp, err := respSuccess.GetPeerNodeStatus()
	require.NoError(t, err)
	status, err := resp.Result()
	require.NoError(t, err)
	require.Equal(t, appA.P2p.NodeStatus, status)
}

func TestListPeers(t *testing.T) {
	appA, appAPort, appB := testAddPeerImpl(t)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_ListPeers_Request(seg)
	require.NoError(t, err)

	var mRpcSeqno uint64 = 2002
	resMsg := ListPeersReq(m).handle(appB, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "listPeers")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasListPeers())
	resp, err := respSuccess.ListPeers()
	require.NoError(t, err)
	res, err := resp.Result()
	require.NoError(t, err)
	require.Greater(t, res.Len(), 0)
	for i := 0; i < res.Len(); i++ {
		pi, err := readPeerInfo(res.At(i))
		if err == nil {
			require.Equal(t, pi.Libp2pPort, appAPort)
			require.Equal(t, pi.PeerID, appA.P2p.Host.ID().String())
		} else {
			t.Errorf("failed to read peer info %d: %v", i, err)
		}
	}
}
