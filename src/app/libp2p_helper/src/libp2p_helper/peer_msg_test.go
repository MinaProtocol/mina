package main

import (
	"fmt"
	"github.com/stretchr/testify/require"
	"testing"

	"codanet"

	capnp "capnproto.org/go/capnp/v3"
	peerstore "github.com/libp2p/go-libp2p-core/peerstore"
	ipc "libp2p_ipc"
)

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

func TestGetPeerNodeStatus(t *testing.T) {
	codanet.NoDHT = true
	defer func() {
		codanet.NoDHT = false
	}()

	// only allow peer count of 1 for node A
	maxCount := 1
	port := nextPort()
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
