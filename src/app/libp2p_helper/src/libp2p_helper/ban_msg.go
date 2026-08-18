package main

import (
	"codanet"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
	peer "github.com/libp2p/go-libp2p/core/peer"
)

// Ban peer RPCs. The BanManager is the single owner of ban semantics; these
// handlers only parse the request, delegate, and (on a newly-banned peer)
// actively disconnect its live connections.

type BanPeerReqT = ipc.Libp2pHelperInterface_BanPeer_Request
type BanPeerReq BanPeerReqT

func fromBanPeerReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.BanPeer()
	return BanPeerReq(i), err
}
func (m BanPeerReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	req := BanPeerReqT(m)
	pid, ip, manual, err := parseBanRequest(req, app)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	bm := app.P2p.GatingState().BanManager()
	if bm == nil {
		return mkRpcRespError(seqno, badRPC(errors.New("ban manager not configured")))
	}
	wasBanned := bm.IsBanned(pid, ip)
	if err := bm.BanPeer(pid, ip, manual); err != nil {
		return mkRpcRespError(seqno, err)
	}
	if !wasBanned {
		// Actively disconnect the peer's live connections. Gating will
		// prevent reconnection.
		if err := app.P2p.Host.Network().ClosePeer(pid); err != nil {
			app.P2p.Logger.Infof("failed to close banned peer %v: %v", pid, err)
		}
	}
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewBanPeer()
		panicOnErr(err)
	})
}

type UnbanPeerReqT = ipc.Libp2pHelperInterface_UnbanPeer_Request
type UnbanPeerReq UnbanPeerReqT

func fromUnbanPeerReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.UnbanPeer()
	return UnbanPeerReq(i), err
}
func (m UnbanPeerReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	req := UnbanPeerReqT(m)
	pid, ip, err := parseBanTarget(func() (ipc.PeerId, error) { return req.PeerId() }, req.HasIp(), func() (string, error) { return req.Ip() }, app)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	bm := app.P2p.GatingState().BanManager()
	if bm == nil {
		return mkRpcRespError(seqno, badRPC(errors.New("ban manager not configured")))
	}
	bm.UnbanPeer(pid, ip)
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewUnbanPeer()
		panicOnErr(err)
	})
}

type GetBansReqT = ipc.Libp2pHelperInterface_GetBans_Request
type GetBansReq GetBansReqT

func fromGetBansReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.GetBans()
	return GetBansReq(i), err
}
func (m GetBansReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	bm := app.P2p.GatingState().BanManager()
	if bm == nil {
		return mkRpcRespError(seqno, badRPC(errors.New("ban manager not configured")))
	}
	entries := bm.GetBans()
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		r, err := m.NewGetBans()
		panicOnErr(err)
		lst, err := r.NewResult(int32(len(entries)))
		panicOnErr(err)
		panicOnErr(setPeerEntryList(lst, entries))
	})
}

type AddTrustedPeerReqT = ipc.Libp2pHelperInterface_AddTrustedPeer_Request
type AddTrustedPeerReq AddTrustedPeerReqT

func fromAddTrustedPeerReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.AddTrustedPeer()
	return AddTrustedPeerReq(i), err
}
func (m AddTrustedPeerReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	req := AddTrustedPeerReqT(m)
	pid, ip, err := parseBanTarget(func() (ipc.PeerId, error) { return req.PeerId() }, req.HasIp(), func() (string, error) { return req.Ip() }, app)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	bm := app.P2p.GatingState().BanManager()
	if bm == nil {
		return mkRpcRespError(seqno, badRPC(errors.New("ban manager not configured")))
	}
	if err := bm.AddTrustedPeer(pid, ip); err != nil {
		return mkRpcRespError(seqno, err)
	}
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewAddTrustedPeer()
		panicOnErr(err)
	})
}

type RemoveTrustedPeerReqT = ipc.Libp2pHelperInterface_RemoveTrustedPeer_Request
type RemoveTrustedPeerReq RemoveTrustedPeerReqT

func fromRemoveTrustedPeerReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.RemoveTrustedPeer()
	return RemoveTrustedPeerReq(i), err
}
func (m RemoveTrustedPeerReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	req := RemoveTrustedPeerReqT(m)
	pid, ip, err := parseBanTarget(func() (ipc.PeerId, error) { return req.PeerId() }, req.HasIp(), func() (string, error) { return req.Ip() }, app)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	bm := app.P2p.GatingState().BanManager()
	if bm == nil {
		return mkRpcRespError(seqno, badRPC(errors.New("ban manager not configured")))
	}
	bm.RemoveTrustedPeer(pid, ip)
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewRemoveTrustedPeer()
		panicOnErr(err)
	})
}

type GetTrustedPeersReqT = ipc.Libp2pHelperInterface_GetTrustedPeers_Request
type GetTrustedPeersReq GetTrustedPeersReqT

func fromGetTrustedPeersReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.GetTrustedPeers()
	return GetTrustedPeersReq(i), err
}
func (m GetTrustedPeersReq) handle(app *app, seqno uint64) (*capnp.Message, func()) {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	bm := app.P2p.GatingState().BanManager()
	if bm == nil {
		return mkRpcRespError(seqno, badRPC(errors.New("ban manager not configured")))
	}
	entries := bm.GetTrustedPeers()
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		r, err := m.NewGetTrustedPeers()
		panicOnErr(err)
		lst, err := r.NewResult(int32(len(entries)))
		panicOnErr(err)
		panicOnErr(setPeerEntryList(lst, entries))
	})
}

// parseBanRequest decodes a BanPeer request: peer id (required), ip
// (optional), manual flag. A missing ip is resolved from the
// peerstore/connection table when possible.
func parseBanRequest(req ipc.Libp2pHelperInterface_BanPeer_Request, app *app) (peer.ID, string, bool, error) {
	pid, ip, err := parseBanTarget(func() (ipc.PeerId, error) { return req.PeerId() }, req.HasIp(), func() (string, error) { return req.Ip() }, app)
	if err != nil {
		return "", "", false, err
	}
	return pid, ip, req.Manual(), nil
}

// parseBanTarget decodes the peer id and optional ip of a ban/unban/trusted
// request. A missing ip is resolved from the peerstore/connection table via
// findPeerInfo when possible.
func parseBanTarget(pidField func() (ipc.PeerId, error), hasIP bool, getIP func() (string, error), app *app) (peer.ID, string, error) {
	pid_, err := pidField()
	if err != nil {
		return "", "", err
	}
	pidStr, err := pid_.Id()
	if err != nil {
		return "", "", err
	}
	pid, err := peer.Decode(pidStr)
	if err != nil {
		return "", "", err
	}
	ip := ""
	if hasIP {
		ip, err = getIP()
		if err != nil {
			return "", "", err
		}
	}
	if ip == "" {
		if info, err := findPeerInfo(app, pid); err == nil {
			ip = info.Host
		}
	}
	return pid, ip, nil
}

// setPeerEntryList fills a capnp PeerEntry list from codanet.PeerEntry values.
func setPeerEntryList(lst ipc.PeerEntry_List, entries []codanet.PeerEntry) error {
	for i, e := range entries {
		pe := lst.At(i)
		switch e.Kind {
		case codanet.PeerEntryPeerID:
			pe.SetKind(ipc.PeerKind_peerId)
		case codanet.PeerEntryIP:
			pe.SetKind(ipc.PeerKind_ip)
		}
		if err := pe.SetIdentity(e.Identity); err != nil {
			return err
		}
		if e.Until != nil {
			u, err := pe.NewUntil()
			if err != nil {
				return err
			}
			u.SetNanoSec(e.Until.UnixNano())
		}
	}
	return nil
}
