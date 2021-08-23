package main

import (
	"github.com/stretchr/testify/require"
	"testing"

	capnp "capnproto.org/go/capnp/v3"
	ipc "libp2p_ipc"
)

func testAddStreamHandler(t *testing.T, protocol string) (*app, *app, uint16) {
	appA, _ := newTestApp(t, nil, true)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, appBPort := newTestApp(t, appAInfos, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_AddStreamHandler_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetProtocol(protocol))

	doASH := func(app *app, rpcSeqno uint64) {
		resMsg := app.handleAddStreamHandler(rpcSeqno, m)
		seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
		require.Equal(t, seqno, rpcSeqno)
		require.True(t, respSuccess.HasAddStreamHandler())
		_, err = respSuccess.AddStreamHandler()
		require.NoError(t, err)
	}

	doASH(appA, 19092)
	doASH(appB, 19093)
	return appA, appB, appBPort
}

func TestAddStreamHandler(t *testing.T) {
	newProtocol := "/mina/99"
	appA, appB, appBPort := testAddStreamHandler(t, newProtocol)
	_ = testOpenStreamImplDo(t, appA, appB, appBPort, 9900, newProtocol)
}

func testOpenStreamImplDo(t *testing.T, appA *app, appB *app, appBPort uint16, rpcSeqno uint64, protocol string) uint64 {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_OpenStream_Request(seg)
	require.NoError(t, err)

	require.NoError(t, m.SetProtocolId(protocol))
	require.NoError(t, m.SetPeer(appB.P2p.Host.ID().String()))

	resMsg := appA.handleOpenStream(rpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasOpenStream())
	res, err := respSuccess.OpenStream()
	require.NoError(t, err)
	sid, err := res.StreamId()
	require.NoError(t, err)
	respStreamId := sid.Id()
	peerInfo, err := res.Peer()
	require.NoError(t, err)
	actual, err := readPeerInfo(peerInfo)
	require.NoError(t, err)

	expected := mkPeerInfo(t, appB, appBPort)

	require.Equal(t, appA.counter, respStreamId)
	require.Equal(t, expected, *actual)

	_, has := appA.Streams[respStreamId]
	require.True(t, has)

	return respStreamId
}

func testOpenStreamImpl(t *testing.T, rpcSeqno uint64, protocol string) (*app, uint64) {
	appA, _ := newTestApp(t, nil, true)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, appBPort := newTestApp(t, appAInfos, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	return appA, testOpenStreamImplDo(t, appA, appB, appBPort, rpcSeqno, protocol)
}

func TestCloseStream(t *testing.T) {
	appA, streamId := testOpenStreamImpl(t, 9901, string(testProtocol))

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_CloseStream_Request(seg)
	require.NoError(t, err)
	sid, err := m.NewStreamId()
	require.NoError(t, err)
	sid.SetId(streamId)

	resMsg := appA.handleCloseStream(4778, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(4778))
	require.True(t, respSuccess.HasCloseStream())
	_, err = respSuccess.CloseStream()
	require.NoError(t, err)

	_, has := appA.Streams[streamId]
	require.False(t, has)
}

func TestOpenStream(t *testing.T) {
	_, _ = testOpenStreamImpl(t, 9904, string(testProtocol))
}

func TestRemoveStreamHandler(t *testing.T) {
	newProtocol := "/mina/99"

	appA, appB, _ := testAddStreamHandler(t, newProtocol)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	rsh, err := ipc.NewRootLibp2pHelperInterface_RemoveStreamHandler_Request(seg)
	require.NoError(t, err)
	require.NoError(t, rsh.SetProtocol(newProtocol))
	var rshRpcSeqno uint64 = 1023
	resMsg := appB.handleRemoveStreamHandler(rshRpcSeqno, rsh)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, rshRpcSeqno)
	require.True(t, respSuccess.HasRemoveStreamHandler())
	_, err = respSuccess.RemoveStreamHandler()
	require.NoError(t, err)

	_, seg, err = capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	os, err := ipc.NewRootLibp2pHelperInterface_OpenStream_Request(seg)
	require.NoError(t, err)
	require.NoError(t, os.SetProtocolId(newProtocol))
	require.NoError(t, os.SetPeer(appB.P2p.Host.ID().String()))

	var osRpcSeqno uint64 = 1026
	osResMsg := appA.handleOpenStream(osRpcSeqno, os)
	osRpcSeqno_, errMsg := checkRpcResponseError(t, osResMsg)
	require.Equal(t, osRpcSeqno, osRpcSeqno_)
	require.Equal(t, "libp2p error: protocol not supported", errMsg)
}

func TestResetStream(t *testing.T) {
	appA, streamId := testOpenStreamImpl(t, 9902, string(testProtocol))

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_ResetStream_Request(seg)
	require.NoError(t, err)
	sid, err := m.NewStreamId()
	require.NoError(t, err)
	sid.SetId(streamId)

	resMsg := appA.handleResetStream(11458, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(11458))
	require.True(t, respSuccess.HasResetStream())
	_, err = respSuccess.ResetStream()
	require.NoError(t, err)

	_, has := appA.Streams[streamId]
	require.False(t, has)
}

func TestSendStream(t *testing.T) {
	appA, streamId := testOpenStreamImpl(t, 9903, string(testProtocol))

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SendStream_Request(seg)
	require.NoError(t, err)
	msg, err := m.NewMsg()
	require.NoError(t, err)
	sid, err := msg.NewStreamId()
	require.NoError(t, err)
	sid.SetId(streamId)
	require.NoError(t, msg.SetData([]byte("somedata")))

	var sendRpcSeqno uint64 = 4458
	resMsg := appA.handleSendStream(sendRpcSeqno, m)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, sendRpcSeqno)
	require.True(t, respSuccess.HasSendStream())
	_, err = respSuccess.SendStream()
	require.NoError(t, err)

	_, has := appA.Streams[streamId]
	require.True(t, has)
}
