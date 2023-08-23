package main

import (
	"context"
	"fmt"
	"io"

	"codanet"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
	peer "github.com/libp2p/go-libp2p-core/peer"
	peerstore "github.com/libp2p/go-libp2p-core/peerstore"
)

type AddPeerReqT = ipc.Libp2pHelperInterface_AddPeer_Request
type AddPeerReq AddPeerReqT

func fromAddPeerReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.AddPeer()
	return AddPeerReq(i), err
}
func (m AddPeerReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}

	maddr, err := AddPeerReqT(m).Multiaddr()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	maRepr, err := maddr.Representation()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	info, err := addrInfoOfString(maRepr)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	app.AddedPeers = append(app.AddedPeers, *info)
	app.P2p.GatingState().TrustedPeers.Add(info.ID)

	if app.Bootstrapper != nil {
		app.Bootstrapper.Close()
	}

	app.P2p.Logger.Info("addPeer Trying to connect to: ", info)

	if AddPeerReqT(m).IsSeed() {
		app.P2p.Seeds = append(app.P2p.Seeds, *info)
	}

	err = app.P2p.Host.Connect(app.Ctx, *info)
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewAddPeer()
		panicOnErr(err)
	})
}

type GetPeerNodeStatusReqT = ipc.Libp2pHelperInterface_GetPeerNodeStatus_Request
type GetPeerNodeStatusReq GetPeerNodeStatusReqT

func fromGetPeerNodeStatusReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.GetPeerNodeStatus()
	return GetPeerNodeStatusReq(i), err
}
func (m GetPeerNodeStatusReq) handle(app *app, seqno uint64) *capnp.Message {
	ctx, cancel := context.WithTimeout(app.Ctx, codanet.NodeStatusTimeout)
	defer cancel()
	pma, err := GetPeerNodeStatusReqT(m).Peer()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	pmaRepr, err := pma.Representation()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	addrInfo, err := addrInfoOfString(pmaRepr)
	if err != nil {
		return mkRpcRespError(seqno, err)
	}
	app.P2p.Host.Peerstore().AddAddrs(addrInfo.ID, addrInfo.Addrs, peerstore.ConnectedAddrTTL)

	// Open a "get node status" stream on m.PeerID,
	// block until you can read the response, return that.
	s, err := app.P2p.Host.NewStream(ctx, addrInfo.ID, codanet.NodeStatusProtocolID)
	if err != nil {
		return mkRpcRespError(seqno, err)
	}

	defer func() {
		_ = s.Close()
	}()

	errCh := make(chan error)
	responseCh := make(chan []byte)

	go func() {
		// 1 megabyte
		size := 1048576

		data := make([]byte, size)
		n, err := s.Read(data)
		// TODO will the whole status be read or we can "accidentally" read only
		// part of it?
		if err != nil && err != io.EOF {
			app.P2p.Logger.Errorf("failed to decode node status data: err=%s", err)
			errCh <- err
			return
		}

		if n == size && err == nil {
			errCh <- fmt.Errorf("node status data was greater than %d bytes", size)
			return
		}

		responseCh <- data[:n]
	}()

	select {
	case <-ctx.Done():
		s.Reset()
		err := errors.New("timed out requesting node status data from peer")
		return mkRpcRespError(seqno, err)
	case err := <-errCh:
		return mkRpcRespError(seqno, err)
	case response := <-responseCh:
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			r, err := m.NewGetPeerNodeStatus()
			panicOnErr(err)
			r.SetResult(response)
		})
	}
}

type ListPeersReqT = ipc.Libp2pHelperInterface_ListPeers_Request
type ListPeersReq ListPeersReqT

func fromListPeersReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.ListPeers()
	return ListPeersReq(i), err
}
func (msg ListPeersReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}

	connsHere := app.P2p.Host.Network().Conns()

	peerInfos := make([]codaPeerInfo, 0, len(connsHere))

	for _, conn := range connsHere {
		maybePeer, err := parseMultiaddrWithID(conn.RemoteMultiaddr(), conn.RemotePeer())
		if err != nil {
			app.P2p.Logger.Warn("skipping maddr ", conn.RemoteMultiaddr().String(), " because it failed to parse: ", err.Error())
			continue
		}
		peerInfos = append(peerInfos, *maybePeer)
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		r, err := m.NewListPeers()
		panicOnErr(err)
		lst, err := r.NewResult(int32(len(peerInfos)))
		panicOnErr(err)
		setPeerInfoList(lst, peerInfos)
	})
}

type HeartbeatPeerPushT = ipc.Libp2pHelperInterface_HeartbeatPeer
type HeartbeatPeerPush HeartbeatPeerPushT

func fromHeartbeatPeerPush(m ipcPushMessage) (pushMessage, error) {
	i, err := m.HeartbeatPeer()
	return HeartbeatPeerPush(i), err
}

func (m HeartbeatPeerPush) handle(app *app) {
	id1, err := HeartbeatPeerPushT(m).Id()
	var id2 string
	var peerID peer.ID
	if err == nil {
		id2, err = id1.Id()
	}
	if err == nil {
		peerID, err = peer.Decode(id2)
	}
	if err != nil {
		app.P2p.Logger.Errorf("HeartbeatPeerPush.handle: error %w", err)
		return
	}
	app.P2p.HeartbeatPeer(peerID)
}
