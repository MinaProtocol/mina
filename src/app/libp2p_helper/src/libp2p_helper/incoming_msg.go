package main

import (
	capnp "capnproto.org/go/capnp/v3"
	ipc "libp2p_ipc"
)

type rpcRequest = ipc.Libp2pHelperInterface_RpcRequest
type rpcRequestHandler = func(*app, uint64, rpcRequest) *capnp.Message

var rpcRequestHandlers = map[ipc.Libp2pHelperInterface_RpcRequest_Which]rpcRequestHandler{
	ipc.Libp2pHelperInterface_RpcRequest_Which_configure: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.Configure()
		panicOnErr(err)
		return app.handleConfigure(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_setGatingConfig: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.SetGatingConfig()
		panicOnErr(err)
		return app.handleSetGatingConfig(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_listen: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.Listen()
		panicOnErr(err)
		return app.handleListen(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_getListeningAddrs: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.GetListeningAddrs()
		panicOnErr(err)
		return app.handleGetListeningAddrs(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_beginAdvertising: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.BeginAdvertising()
		panicOnErr(err)
		return app.handleBeginAdvertising(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_addPeer: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.AddPeer()
		panicOnErr(err)
		return app.handleAddPeer(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_listPeers: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.ListPeers()
		panicOnErr(err)
		return app.handleListPeers(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_generateKeypair: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.GenerateKeypair()
		panicOnErr(err)
		return app.handleGenerateKeypair(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_publish: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.Publish()
		panicOnErr(err)
		return app.handlePublish(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_subscribe: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.Subscribe()
		panicOnErr(err)
		return app.handleSubscribe(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_unsubscribe: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.Unsubscribe()
		panicOnErr(err)
		return app.handleUnsubscribe(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_addStreamHandler: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.AddStreamHandler()
		panicOnErr(err)
		return app.handleAddStreamHandler(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_removeStreamHandler: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.RemoveStreamHandler()
		panicOnErr(err)
		return app.handleRemoveStreamHandler(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_openStream: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.OpenStream()
		panicOnErr(err)
		return app.handleOpenStream(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_closeStream: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.CloseStream()
		panicOnErr(err)
		return app.handleCloseStream(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_resetStream: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.ResetStream()
		panicOnErr(err)
		return app.handleResetStream(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_sendStream: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.SendStream()
		panicOnErr(err)
		return app.handleSendStream(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_setNodeStatus: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.SetNodeStatus()
		panicOnErr(err)
		return app.handleSetNodeStatus(seqno, r)
	},
	ipc.Libp2pHelperInterface_RpcRequest_Which_getPeerNodeStatus: func(app *app, seqno uint64, req rpcRequest) *capnp.Message {
		r, err := req.GetPeerNodeStatus()
		panicOnErr(err)
		return app.handleGetPeerNodeStatus(seqno, r)
	},
}

func (app *app) handleIncomingMsg(msg *ipc.Libp2pHelperInterface_Message) {
	if msg.HasRpcRequest() {
		req, err := msg.RpcRequest()
		panicOnErr(err)
		h, err := req.Header()
		panicOnErr(err)
		seqno := h.SeqNumber()
		handler, foundHandler := rpcRequestHandlers[req.Which()]
		if !foundHandler {
			app.P2p.Logger.Error("Received rpc message of an unknown type")
			return
		}
		resp := handler(app, seqno, req)
		if resp == nil {
			app.P2p.Logger.Error("Failed to process rpc message")
		} else {
			app.writeMsg(resp)
		}
	} else if msg.HasPushMessage() {
		req, err := msg.PushMessage()
		panicOnErr(err)
		h, err := req.Header()
		panicOnErr(err)
		_ = h
		if req.HasValidation() {
			r, err := req.Validation()
			panicOnErr(err)
			app.handleValidation(r)
		} else {
			app.P2p.Logger.Error("Received push message of an unknown type")
		}
	} else {
		app.P2p.Logger.Error("Received message of an unknown type")
	}
}
