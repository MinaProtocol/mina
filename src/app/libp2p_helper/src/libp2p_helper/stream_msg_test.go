package main

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/libp2p/go-libp2p-core/host"
)

func testAddStreamHandlerDo(t *testing.T, protocol string, app *app, rpcSeqno uint64) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_AddStreamHandler_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetProtocol(protocol))

	resMsg := AddStreamHandlerReq(m).handle(app, rpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "addStreamHandler")
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasAddStreamHandler())
	_, err = respSuccess.AddStreamHandler()
	require.NoError(t, err)
}

func testAddStreamHandlerImpl(t *testing.T, protocol string) (*app, *app, uint16) {
	appA, _ := newTestApp(t, nil, true)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, appBPort := newTestApp(t, appAInfos, true)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	testAddStreamHandlerDo(t, protocol, appA, 10990)
	testAddStreamHandlerDo(t, protocol, appB, 10991)
	return appA, appB, appBPort
}

func TestAddStreamHandler(t *testing.T) {
	newProtocol := "/mina/99"
	appA, appB, appBPort := testAddStreamHandlerImpl(t, newProtocol)
	_ = testOpenStreamDo(t, appA, appB.P2p.Host, appBPort, 9900, newProtocol)
}

func testOpenStreamDo(t *testing.T, appA *app, appBHost host.Host, appBPort uint16, rpcSeqno uint64, protocol string) uint64 {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_OpenStream_Request(seg)
	require.NoError(t, err)

	require.NoError(t, m.SetProtocolId(protocol))
	pid, err := m.NewPeer()
	require.NoError(t, pid.SetId(appBHost.ID().String()))
	require.NoError(t, err)

	resMsg := OpenStreamReq(m).handle(appA, rpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "openStream")
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

	checkPeerInfo(t, actual, appBHost, appBPort)

	require.Equal(t, appA.counter, respStreamId)

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

	return appA, testOpenStreamDo(t, appA, appB.P2p.Host, appBPort, rpcSeqno, protocol)
}

func testCloseStreamDo(t *testing.T, app *app, streamId uint64, rpcSeqno uint64) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_CloseStream_Request(seg)
	require.NoError(t, err)
	sid, err := m.NewStreamId()
	require.NoError(t, err)
	sid.SetId(streamId)

	resMsg := CloseStreamReq(m).handle(app, rpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "closeStream")
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasCloseStream())
	_, err = respSuccess.CloseStream()
	require.NoError(t, err)

	_, has := app.Streams[streamId]
	require.False(t, has)
}

func TestCloseStream(t *testing.T) {
	appA, streamId := testOpenStreamImpl(t, 9901, string(testProtocol))
	testCloseStreamDo(t, appA, streamId, 4778)
}

func TestOpenStream(t *testing.T) {
	_, _ = testOpenStreamImpl(t, 9904, string(testProtocol))
}

func TestRemoveStreamHandler(t *testing.T) {
	newProtocol := "/mina/99"

	appA, appB, _ := testAddStreamHandlerImpl(t, newProtocol)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	rsh, err := ipc.NewRootLibp2pHelperInterface_RemoveStreamHandler_Request(seg)
	require.NoError(t, err)
	require.NoError(t, rsh.SetProtocol(newProtocol))
	var rshRpcSeqno uint64 = 1023
	resMsg := RemoveStreamHandlerReq(rsh).handle(appB, rshRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "removeStreamHandler")
	require.Equal(t, seqno, rshRpcSeqno)
	require.True(t, respSuccess.HasRemoveStreamHandler())
	_, err = respSuccess.RemoveStreamHandler()
	require.NoError(t, err)

	_, seg, err = capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	os, err := ipc.NewRootLibp2pHelperInterface_OpenStream_Request(seg)
	require.NoError(t, err)
	require.NoError(t, os.SetProtocolId(newProtocol))
	pid, err := os.NewPeer()
	require.NoError(t, pid.SetId(appB.P2p.Host.ID().String()))
	require.NoError(t, err)

	var osRpcSeqno uint64 = 1026
	osResMsg := OpenStreamReq(os).handle(appA, osRpcSeqno)
	osRpcSeqno_, errMsg := checkRpcResponseError(t, osResMsg)
	require.Equal(t, osRpcSeqno, osRpcSeqno_)
	require.Equal(t, "libp2p error: protocol not supported", errMsg)
}

func testResetStreamDo(t *testing.T, app *app, streamId uint64, rpcSeqno uint64) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_ResetStream_Request(seg)
	require.NoError(t, err)
	sid, err := m.NewStreamId()
	require.NoError(t, err)
	sid.SetId(streamId)

	resMsg := ResetStreamReq(m).handle(app, rpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "resetStream")
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasResetStream())
	_, err = respSuccess.ResetStream()
	require.NoError(t, err)

	_, has := app.Streams[streamId]
	require.False(t, has)
}

func TestResetStream(t *testing.T) {
	appA, streamId := testOpenStreamImpl(t, 9902, string(testProtocol))
	testResetStreamDo(t, appA, streamId, 114558)
}

func testSendStreamDo(t *testing.T, app *app, streamId uint64, msgBytes []byte, rpcSeqno uint64) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SendStream_Request(seg)
	require.NoError(t, err)
	msg, err := m.NewMsg()
	require.NoError(t, err)
	sid, err := msg.NewStreamId()
	require.NoError(t, err)
	sid.SetId(streamId)
	require.NoError(t, msg.SetData(msgBytes))

	resMsg := SendStreamReq(m).handle(app, rpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "sendStream")
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasSendStream())
	_, err = respSuccess.SendStream()
	require.NoError(t, err)

	_, has := app.Streams[streamId]
	require.True(t, has)
}

func TestSendStream(t *testing.T) {
	appA, streamId := testOpenStreamImpl(t, 9903, string(testProtocol))
	testSendStreamDo(t, appA, streamId, []byte("somedata"), 4458)
}

func TestOpenStreamBeforeAndAfterSetGatingConfig(t *testing.T) {
	ctx, ctxCancel := context.WithCancel(context.Background())
	defer ctxCancel()

	appA, _ := newTestApp(t, nil, false)
	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	aTrap := newUpcallTrap("appA", 64, upcallDropAllMask^(1<<StreamLostChan))
	aUpcallErrChan := make(chan error)
	launchFeedUpcallTrap(appA.P2p.Logger, appA.OutChan, aTrap, aUpcallErrChan, ctx)

	appB, appBPort := newTestApp(t, appAInfos, false)
	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)
	bTrap := newUpcallTrap("appB", 64, upcallDropAllMask^(1<<StreamMessageReceivedChan))
	bUpcallErrChan := make(chan error)
	launchFeedUpcallTrap(appB.P2p.Logger, appB.OutChan, bTrap, bUpcallErrChan, ctx)
	testAddStreamHandlerDo(t, string(testProtocol), appB, 10990)

	streamId := testOpenStreamDo(t, appA, appB.P2p.Host, appBPort, 9905, string(testProtocol))
	testSendStreamDo(t, appA, streamId, []byte("somedata"), 4458)

	select {
	case err := <-aUpcallErrChan:
		require.NoError(t, err)
	case err := <-bUpcallErrChan:
		require.NoError(t, err)
	case <-bTrap.StreamMessageReceived:
	}

	{
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		require.NoError(t, err)
		m, err := ipc.NewRootLibp2pHelperInterface_SetGatingConfig_Request(seg)
		require.NoError(t, err)

		gc, err := m.NewGatingConfig()
		require.NoError(t, err)
		_, err = gc.NewBannedIps(0)
		require.NoError(t, err)
		bPids, err := gc.NewBannedPeerIds(1)
		require.NoError(t, err)
		_, err = gc.NewTrustedIps(0)
		require.NoError(t, err)
		_, err = gc.NewTrustedPeerIds(0)
		require.NoError(t, err)
		require.NoError(t, bPids.At(0).SetId(appA.P2p.Me.String()))
		gc.SetIsolate(false)

		var mRpcSeqno uint64 = 2003
		resMsg := SetGatingConfigReq(m).handle(appB, mRpcSeqno)
		seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "setGatingConfig")
		require.Equal(t, seqno, mRpcSeqno)
		require.True(t, respSuccess.HasSetGatingConfig())
		_, err = respSuccess.SetGatingConfig()
		require.NoError(t, err)
	}

	select {
	case err := <-bUpcallErrChan:
		require.NoError(t, err)
	case err := <-aUpcallErrChan:
		require.NoError(t, err)
	case msg := <-aTrap.StreamLost:
		sid, err := msg.StreamId()
		require.NoError(t, err)
		require.Equal(t, streamId, sid.Id())
	}

	// We try to open a stream again, but it should fail because the peer is banned.
	{
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		require.NoError(t, err)
		m, err := ipc.NewRootLibp2pHelperInterface_OpenStream_Request(seg)
		require.NoError(t, err)

		require.NoError(t, m.SetProtocolId(string(testProtocol)))
		pid, err := m.NewPeer()
		require.NoError(t, pid.SetId(appB.P2p.Host.ID().String()))
		require.NoError(t, err)

		resMsg := OpenStreamReq(m).handle(appA, 9905)
		seqno, _ := checkRpcResponseError(t, resMsg)
		require.Equal(t, uint64(9905), seqno)
	}
}
