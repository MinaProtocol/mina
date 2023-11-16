package main

import (
	"context"
	"time"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
	net "github.com/libp2p/go-libp2p/core/network"
	peer "github.com/libp2p/go-libp2p/core/peer"
	protocol "github.com/libp2p/go-libp2p/core/protocol"
)

type AddStreamHandlerReqT = ipc.Libp2pHelperInterface_AddStreamHandler_Request
type AddStreamHandlerReq AddStreamHandlerReqT

func fromAddStreamHandlerReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.AddStreamHandler()
	return AddStreamHandlerReq(i), err
}
func (m AddStreamHandlerReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	protocolId, err := AddStreamHandlerReqT(m).Protocol()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.P2p.Host.SetStreamHandler(protocol.ID(protocolId), func(stream net.Stream) {
		peerinfo, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())
		if err != nil {
			app.P2p.Logger.Errorf("failed to parse remote connection information, silently dropping stream: %s", err.Error())
			return
		}
		streamIdx := app.AddStream(stream)
		app.writeMsg(mkIncomingStreamUpcall(peerinfo, streamIdx, protocolId))
		handleStreamReads(app, stream, streamIdx)
	})

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewAddStreamHandler()
		panicOnErr(err)
	})
}

type CloseStreamReqT = ipc.Libp2pHelperInterface_CloseStream_Request
type CloseStreamReq CloseStreamReqT

func fromCloseStreamReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.CloseStream()
	return CloseStreamReq(i), err
}
func (m CloseStreamReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	sid, err := CloseStreamReqT(m).StreamId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	streamId := sid.Id()
	if stream, found := app.RemoveStream(streamId); found {
		if err2 := stream.Close(); err2 != nil {
			err = badp2p(err2)
		}
	} else {
		err = badRPC(errors.New("unknown stream_idx"))
	}
	if err != nil {
		return mkRpcRespError(seqno, err)
	}
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewCloseStream()
		panicOnErr(err)
	})
}

type OpenStreamReqT = ipc.Libp2pHelperInterface_OpenStream_Request
type OpenStreamReq OpenStreamReqT

func fromOpenStreamReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.OpenStream()
	return OpenStreamReq(i), err
}
func (m OpenStreamReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}

	var peerDecoded peer.ID
	var protocolId string
	err := func() error {
		peerId, err := OpenStreamReqT(m).Peer()
		if err != nil {
			return err
		}
		peerStr, err := peerId.Id()
		if err != nil {
			return err
		}
		peerDecoded, err = peer.Decode(peerStr)
		if err != nil {
			return err
		}
		protocolId, err = OpenStreamReqT(m).ProtocolId()
		return err
	}()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	ctx, cancel := context.WithTimeout(app.Ctx, 30*time.Second)
	defer cancel()

	stream, err := app.P2p.Host.NewStream(ctx, peerDecoded, protocol.ID(protocolId))
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	peer, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())
	if err != nil {
		err = stream.Reset()
		if err != nil {
			app.P2p.Logger.Errorf("handleOpenStream: failed to reset stream: %s", err.Error())
		}
		return mkRpcRespError(seqno, badp2p(err))
	}

	streamIdx := app.AddStream(stream)
	mkResponse := func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		resp, err := m.NewOpenStream()
		panicOnErr(err)
		sid, err := resp.NewStreamId()
		panicOnErr(err)
		sid.SetId(streamIdx)
		pi, err := resp.NewPeer()
		panicOnErr(err)
		setPeerInfo(pi, peer)
	}
	return mkRpcRespSuccessNoFunc(seqno, mkResponse), func() {
		handleStreamReads(app, stream, streamIdx)
	}
}

type RemoveStreamHandlerReqT = ipc.Libp2pHelperInterface_RemoveStreamHandler_Request
type RemoveStreamHandlerReq RemoveStreamHandlerReqT

func fromRemoveStreamHandlerReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.RemoveStreamHandler()
	return RemoveStreamHandlerReq(i), err
}
func (m RemoveStreamHandlerReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	protocolId, err := RemoveStreamHandlerReqT(m).Protocol()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.P2p.Host.RemoveStreamHandler(protocol.ID(protocolId))

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewRemoveStreamHandler()
		panicOnErr(err)
	})
}

type ResetStreamReqT = ipc.Libp2pHelperInterface_ResetStream_Request
type ResetStreamReq ResetStreamReqT

func fromResetStreamReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.ResetStream()
	return ResetStreamReq(i), err
}
func (m ResetStreamReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	sid, err := ResetStreamReqT(m).StreamId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	streamId := sid.Id()
	if stream, found := app.RemoveStream(streamId); found {
		if err2 := stream.Reset(); err2 != nil {
			err = badp2p(err2)
		}
	} else {
		err = badRPC(errors.New("unknown stream_idx"))
	}
	if err != nil {
		return mkRpcRespError(seqno, err)
	}
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewResetStream()
		panicOnErr(err)
	})
}

type SendStreamReqT = ipc.Libp2pHelperInterface_SendStream_Request
type SendStreamReq SendStreamReqT

func fromSendStreamReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.SendStream()
	return SendStreamReq(i), err
}
func (m SendStreamReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	msg, err := SendStreamReqT(m).Msg()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	data, err := msg.Data()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	sid, err := msg.StreamId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	streamId := sid.Id()

	err = app.WriteStream(streamId, data)

	if err != nil {
		return mkRpcRespError(seqno, err)
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewSendStream()
		panicOnErr(err)
	})
}
