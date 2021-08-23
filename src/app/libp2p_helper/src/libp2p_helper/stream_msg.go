package main

import (
	"context"
	"fmt"
	"time"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	protocol "github.com/libp2p/go-libp2p-core/protocol"
	ipc "libp2p_ipc"
)

func (app *app) handleAddStreamHandler(seqno uint64, m ipc.Libp2pHelperInterface_AddStreamHandler_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	protocolId, err := m.Protocol()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.P2p.Host.SetStreamHandler(protocol.ID(protocolId), func(stream net.Stream) {
		peerinfo, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())
		if err != nil {
			app.P2p.Logger.Errorf("failed to parse remote connection information, silently dropping stream: %s", err.Error())
			return
		}
		streamIdx := app.NextId()
		app.StreamsMutex.Lock()
		defer app.StreamsMutex.Unlock()
		app.Streams[streamIdx] = stream
		app.writeMsg(mkIncomingStreamUpcall(peerinfo, streamIdx, protocolId))
		handleStreamReads(app, stream, streamIdx)
	})

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewAddStreamHandler()
		panicOnErr(err)
	})
}

func (app *app) handleCloseStream(seqno uint64, m ipc.Libp2pHelperInterface_CloseStream_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	sid, err := m.StreamId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	streamId := sid.Id()
	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[streamId]; ok {
		delete(app.Streams, streamId)
		err := stream.Close()
		if err != nil {
			return mkRpcRespError(seqno, badp2p(err))
		}
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			_, err := m.NewCloseStream()
			panicOnErr(err)
		})
	}
	return mkRpcRespError(seqno, badRPC(errors.New("unknown stream_idx")))
}

func (app *app) handleOpenStream(seqno uint64, m ipc.Libp2pHelperInterface_OpenStream_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}

	streamIdx := app.NextId()

	peerStr, err := m.Peer()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	peerDecoded, err := peer.Decode(peerStr)
	if err != nil {
		// TODO: this isn't necessarily an RPC error. Perhaps the encoded Peer ID
		// isn't supported by this version of libp2p.
		return mkRpcRespError(seqno, badRPC(err))
	}

	ctx, cancel := context.WithTimeout(app.Ctx, 30*time.Second)
	defer cancel()

	protocolId, err := m.ProtocolId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	stream, err := app.P2p.Host.NewStream(ctx, peerDecoded, protocol.ID(protocolId))
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	peer, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())
	if err != nil {
		_ = stream.Reset()
		return mkRpcRespError(seqno, badp2p(err))
	}

	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	app.Streams[streamIdx] = stream
	go func() {
		// FIXME HACK: allow time for the openStreamResult to get printed before we start inserting stream events
		time.Sleep(250 * time.Millisecond)
		// Note: It is _very_ important that we call handleStreamReads here -- this is how the "caller" side of the stream starts listening to the responses from the RPCs. Do not remove.
		handleStreamReads(app, stream, streamIdx)
	}()
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		resp, err := m.NewOpenStream()
		panicOnErr(err)
		sid, err := resp.NewStreamId()
		panicOnErr(err)
		sid.SetId(streamIdx)
		pi, err := resp.NewPeer()
		panicOnErr(err)
		setPeerInfo(pi, peer)
	})
}

func (app *app) handleRemoveStreamHandler(seqno uint64, m ipc.Libp2pHelperInterface_RemoveStreamHandler_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	protocolId, err := m.Protocol()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.P2p.Host.RemoveStreamHandler(protocol.ID(protocolId))

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewRemoveStreamHandler()
		panicOnErr(err)
	})
}

func (app *app) handleResetStream(seqno uint64, m ipc.Libp2pHelperInterface_ResetStream_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	sid, err := m.StreamId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	streamId := sid.Id()
	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[streamId]; ok {
		err := stream.Reset()
		delete(app.Streams, streamId)
		if err != nil {
			return mkRpcRespError(seqno, badp2p(err))
		}
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			_, err := m.NewResetStream()
			panicOnErr(err)
		})
	}
	return mkRpcRespError(seqno, badRPC(errors.New("unknown stream_idx")))
}

func (app *app) handleSendStream(seqno uint64, m ipc.Libp2pHelperInterface_SendStream_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	msg, err := m.Msg()
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

	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[streamId]; ok {
		n, err := stream.Write(data)
		if err != nil {
			// TODO check that it's correct to error out, not repeat writing
			return mkRpcRespError(seqno, wrapError(badp2p(err), fmt.Sprintf("only wrote %d out of %d bytes", n, len(data))))
		}
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			_, err := m.NewSendStream()
			panicOnErr(err)
		})
	}
	return mkRpcRespError(seqno, badRPC(errors.New("unknown stream_idx")))
}
