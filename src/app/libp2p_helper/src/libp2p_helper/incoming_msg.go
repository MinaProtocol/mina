package main

import (
	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
)

var rpcRequestExtractors = map[ipc.Libp2pHelperInterface_RpcRequest_Which]extractRequest{
	ipc.Libp2pHelperInterface_RpcRequest_Which_configure:               fromConfigureReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_setGatingConfig:         fromSetGatingConfigReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_listen:                  fromListenReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_getListeningAddrs:       fromGetListeningAddrsReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_beginAdvertising:        fromBeginAdvertisingReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_addPeer:                 fromAddPeerReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_listPeers:               fromListPeersReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_bandwidthInfo:           fromBandwidthInfoReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_generateKeypair:         fromGenerateKeypairReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_publish:                 fromPublishReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_subscribe:               fromSubscribeReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_unsubscribe:             fromUnsubscribeReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_addStreamHandler:        fromAddStreamHandlerReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_removeStreamHandler:     fromRemoveStreamHandlerReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_openStream:              fromOpenStreamReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_closeStream:             fromCloseStreamReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_resetStream:             fromResetStreamReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_sendStream:              fromSendStreamReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_setNodeStatus:           fromSetNodeStatusReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_getPeerNodeStatus:       fromGetPeerNodeStatusReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_testDecodeBitswapBlocks: fromTestDecodeBitswapBlocksReq,
	ipc.Libp2pHelperInterface_RpcRequest_Which_testEncodeBitswapBlocks: fromTestEncodeBitswapBlocksReq,
}

var pushMesssageExtractors = map[ipc.Libp2pHelperInterface_PushMessage_Which]extractPushMessage{
	ipc.Libp2pHelperInterface_PushMessage_Which_addResource:      fromAddResourcePush,
	ipc.Libp2pHelperInterface_PushMessage_Which_deleteResource:   fromDeleteResourcePush,
	ipc.Libp2pHelperInterface_PushMessage_Which_downloadResource: fromDownloadResourcePush,
	ipc.Libp2pHelperInterface_PushMessage_Which_validation:       fromValidationPush,
}

func (app *app) handleIncomingMsg(msg *ipc.Libp2pHelperInterface_Message) {
	if msg.HasRpcRequest() {
		resp, err := func() (*capnp.Message, error) {
			req, err := msg.RpcRequest()
			if err != nil {
				return nil, err
			}
			h, err := req.Header()
			if err != nil {
				return nil, err
			}
			seqnoO, err := h.SequenceNumber()
			if err != nil {
				return nil, err
			}
			seqno := seqnoO.Seqno()
			extractor, foundHandler := rpcRequestExtractors[req.Which()]
			if !foundHandler {
				return nil, errors.New("Received rpc message of an unknown type")
			}
			req2, err := extractor(req)
			if err != nil {
				return nil, err
			}
			return req2.handle(app, seqno), nil
		}()
		if err == nil {
			app.writeMsg(resp)
		} else {
			app.P2p.Logger.Errorf("Failed to process rpc message: %w", err)
		}
	} else if msg.HasPushMessage() {
		err := func() error {
			push, err := msg.PushMessage()
			if err != nil {
				return err
			}
			_, err = push.Header()
			if err != nil {
				return err
			}
			extractor, foundHandler := pushMesssageExtractors[push.Which()]
			if !foundHandler {
				return errors.New("Received push message of an unknown type")
			}
			push_, err := extractor(push)
			if err != nil {
				return err
			}
			push_.handle(app)
			return nil
		}()
		if err != nil {
			app.P2p.Logger.Errorf("Failed to process push message: %w", err)
		}
	} else {
		app.P2p.Logger.Error("Received message of an unknown type")
	}
}
