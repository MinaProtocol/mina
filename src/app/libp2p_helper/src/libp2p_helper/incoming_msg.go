package main

import (
	capnp "capnproto.org/go/capnp/v3"
	ipc "libp2p_ipc"
)

func (app *app) handleIncomingMsg(msg *ipc.Libp2pHelperInterface_Message) {
	if msg.HasRpcRequest() {
		req, err := msg.RpcRequest()
		panicOnErr(err)
		h, err := req.Header()
		panicOnErr(err)
		seqno := h.SeqNumber()
		var resp *capnp.Message
		if req.HasConfigure() {
			r, err := req.Configure()
			panicOnErr(err)
			resp = app.handleConfigure(seqno, r)
		} else if req.HasSetGatingConfig() {
			r, err := req.SetGatingConfig()
			panicOnErr(err)
			resp = app.handleSetGatingConfig(seqno, r)
		} else if req.HasListen() {
			r, err := req.Listen()
			panicOnErr(err)
			resp = app.handleListen(seqno, r)
		} else if req.HasGetListeningAddrs() {
			r, err := req.GetListeningAddrs()
			panicOnErr(err)
			resp = app.handleGetListeningAddrs(seqno, r)
		} else if req.HasBeginAdvertising() {
			r, err := req.BeginAdvertising()
			panicOnErr(err)
			resp = app.handleBeginAdvertising(seqno, r)
		} else if req.HasAddPeer() {
			r, err := req.AddPeer()
			panicOnErr(err)
			resp = app.handleAddPeer(seqno, r)
		} else if req.HasListPeers() {
			r, err := req.ListPeers()
			panicOnErr(err)
			resp = app.handleListPeers(seqno, r)
		} else if req.HasGenerateKeypair() {
			r, err := req.GenerateKeypair()
			panicOnErr(err)
			resp = app.handleGenerateKeypair(seqno, r)
		} else if req.HasPublish() {
			r, err := req.Publish()
			panicOnErr(err)
			resp = app.handlePublish(seqno, r)
		} else if req.HasSubscribe() {
			r, err := req.Subscribe()
			panicOnErr(err)
			resp = app.handleSubscribe(seqno, r)
		} else if req.HasUnsubscribe() {
			r, err := req.Unsubscribe()
			panicOnErr(err)
			resp = app.handleUnsubscribe(seqno, r)
		} else if req.HasAddStreamHandler() {
			r, err := req.AddStreamHandler()
			panicOnErr(err)
			resp = app.handleAddStreamHandler(seqno, r)
		} else if req.HasRemoveStreamHandler() {
			r, err := req.RemoveStreamHandler()
			panicOnErr(err)
			resp = app.handleRemoveStreamHandler(seqno, r)
		} else if req.HasOpenStream() {
			r, err := req.OpenStream()
			panicOnErr(err)
			resp = app.handleOpenStream(seqno, r)
		} else if req.HasCloseStream() {
			r, err := req.CloseStream()
			panicOnErr(err)
			resp = app.handleCloseStream(seqno, r)
		} else if req.HasResetStream() {
			r, err := req.ResetStream()
			panicOnErr(err)
			resp = app.handleResetStream(seqno, r)
		} else if req.HasSendStream() {
			r, err := req.SendStream()
			panicOnErr(err)
			resp = app.handleSendStream(seqno, r)
		} else if req.HasSetNodeStatus() {
			r, err := req.SetNodeStatus()
			panicOnErr(err)
			resp = app.handleSetNodeStatus(seqno, r)
		} else if req.HasGetPeerNodeStatus() {
			r, err := req.GetPeerNodeStatus()
			panicOnErr(err)
			resp = app.handleGetPeerNodeStatus(seqno, r)
		} else {
			app.P2p.Logger.Error("Received rpc message of an unknown type")
			return
		}
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
