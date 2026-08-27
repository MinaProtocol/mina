package main

import (
	"crypto/rand"
	"io/ioutil"
	"path/filepath"
	"testing"
	"time"

	"codanet"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/libp2p/go-libp2p/core/crypto"
	peer "github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
	"github.com/stretchr/testify/require"
)

const (
	testBanPID = "12D3KooWJDGPa2hiYCJ2o7XPqEq2tjrWpFJzqa4dy538Gfs7Vn2r"
	testBanIP  = "1.2.3.4"
)

func newBanManagerForApp(t *testing.T, app *app) *codanet.BanManager {
	bm, err := codanet.NewBanManager(filepath.Join(t.TempDir(), "libp2p_banlist.json"), app.P2p.Logger)
	require.NoError(t, err)
	app.P2p.GatingState().SetBanManager(bm)
	return bm
}

func newBanPeerRequest(t *testing.T, pidStr, ip string, manual bool) ipc.Libp2pHelperInterface_BanPeer_Request {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_BanPeer_Request(seg)
	require.NoError(t, err)
	p, err := m.NewPeerId()
	require.NoError(t, err)
	require.NoError(t, p.SetId(pidStr))
	if ip != "" {
		require.NoError(t, m.SetIp(ip))
	}
	m.SetManual(manual)
	return m
}

type entryRead struct {
	kind       ipc.PeerKind
	identity   string
	hasUntil   bool
	untilNanos int64
}

func readPeerEntries(t *testing.T, lst ipc.PeerEntry_List) []entryRead {
	var res []entryRead
	for i := 0; i < lst.Len(); i++ {
		pe := lst.At(i)
		ident, err := pe.Identity()
		require.NoError(t, err)
		e := entryRead{kind: pe.Kind(), identity: ident, hasUntil: pe.HasUntil()}
		if e.hasUntil {
			u, err := pe.Until()
			require.NoError(t, err)
			e.untilNanos = u.NanoSec()
		}
		res = append(res, e)
	}
	return res
}

func TestBanPeerManual(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)

	var mRpcSeqno uint64 = 21001
	resMsg, _ := BanPeerReq(newBanPeerRequest(t, testBanPID, testBanIP, true)).handle(testApp, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "banPeer")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasBanPeer())

	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)
	require.True(t, bm.IsBanned(pid, testBanIP))
	require.True(t, bm.IsBanned(pid, ""))
	require.True(t, bm.IsBanned(peer.ID("someone-else"), testBanIP), "IP ban applies to other peer IDs")
}

func TestBanPeerAuto(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)

	var mRpcSeqno uint64 = 21002
	resMsg, _ := BanPeerReq(newBanPeerRequest(t, testBanPID, testBanIP, false)).handle(testApp, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "banPeer")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasBanPeer())

	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)
	require.True(t, bm.IsBanned(pid, testBanIP))
}

func TestBanPeerMissingIPResolvedFromConnections(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)

	// Ban with no IP: for a peer with no live connections the entry is
	// peer_id-only, which still bans the peer.
	var mRpcSeqno uint64 = 21003
	resMsg, _ := BanPeerReq(newBanPeerRequest(t, testBanPID, "", true)).handle(testApp, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "banPeer")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasBanPeer())

	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)
	require.True(t, bm.IsBanned(pid, ""))
}

func TestBanPeerTrustedRejection(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)
	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)
	require.NoError(t, bm.AddTrustedPeer(pid, testBanIP))

	var mRpcSeqno uint64 = 21004
	resMsg, _ := BanPeerReq(newBanPeerRequest(t, testBanPID, testBanIP, true)).handle(testApp, mRpcSeqno)
	_, errMsg := checkRpcResponseError(t, resMsg)
	require.Contains(t, errMsg, "trusted peers cannot be banned")
	require.False(t, bm.IsBanned(pid, testBanIP))
}

func TestUnbanPeer(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)
	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)
	require.NoError(t, bm.BanPeer(pid, testBanIP, true))

	var mRpcSeqno uint64 = 21005
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_UnbanPeer_Request(seg)
	require.NoError(t, err)
	p, err := m.NewPeerId()
	require.NoError(t, err)
	require.NoError(t, p.SetId(testBanPID))
	require.NoError(t, m.SetIp(testBanIP))

	resMsg, _ := UnbanPeerReq(m).handle(testApp, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "unbanPeer")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasUnbanPeer())
	require.False(t, bm.IsBanned(pid, testBanIP))
}

func TestGetBansShape(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)
	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)

	// One manual ban (pid + ip) and one auto ban (pid + ip): both write
	// peer_id and IP entries, so there are 4 entries in total.
	require.NoError(t, bm.BanPeer(pid, testBanIP, true))
	require.NoError(t, bm.BanPeer(peer.ID("auto-peer"), "5.6.7.8", false))

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_GetBans_Request(seg)
	require.NoError(t, err)
	var mRpcSeqno uint64 = 21006
	resMsg, _ := GetBansReq(m).handle(testApp, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "getBans")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasGetBans())
	resp, err := respSuccess.GetBans()
	require.NoError(t, err)
	lst, err := resp.Result()
	require.NoError(t, err)
	entries := readPeerEntries(t, lst)
	require.Len(t, entries, 4)

	byIdentity := map[string]entryRead{}
	for _, e := range entries {
		byIdentity[e.identity] = e
	}
	// Manual entries: kind set, until null.
	require.Equal(t, ipc.PeerKind_peerId, byIdentity[testBanPID].kind)
	require.False(t, byIdentity[testBanPID].hasUntil)
	require.Equal(t, ipc.PeerKind_ip, byIdentity[testBanIP].kind)
	require.False(t, byIdentity[testBanIP].hasUntil)
	// Auto entries: until present.
	autoIdent := peer.Encode(peer.ID("auto-peer"))
	require.Equal(t, ipc.PeerKind_peerId, byIdentity[autoIdent].kind)
	require.True(t, byIdentity[autoIdent].hasUntil)
	require.Equal(t, ipc.PeerKind_ip, byIdentity["5.6.7.8"].kind)
	require.True(t, byIdentity["5.6.7.8"].hasUntil)
}

func TestGetTrustedPeersShape(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)
	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)
	require.NoError(t, bm.AddTrustedPeer(pid, testBanIP))

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_GetTrustedPeers_Request(seg)
	require.NoError(t, err)
	var mRpcSeqno uint64 = 21007
	resMsg, _ := GetTrustedPeersReq(m).handle(testApp, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "getTrustedPeers")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasGetTrustedPeers())
	resp, err := respSuccess.GetTrustedPeers()
	require.NoError(t, err)
	lst, err := resp.Result()
	require.NoError(t, err)
	entries := readPeerEntries(t, lst)
	require.Len(t, entries, 2)
	for _, e := range entries {
		require.False(t, e.hasUntil, "trusted entries always have nil until")
	}
}

func TestAddRemoveTrustedPeer(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)
	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)

	// Add
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_AddTrustedPeer_Request(seg)
	require.NoError(t, err)
	p, err := m.NewPeerId()
	require.NoError(t, err)
	require.NoError(t, p.SetId(testBanPID))
	require.NoError(t, m.SetIp(testBanIP))
	var mRpcSeqno uint64 = 21008
	resMsg, _ := AddTrustedPeerReq(m).handle(testApp, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "addTrustedPeer")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasAddTrustedPeer())
	require.True(t, bm.IsTrusted(pid, testBanIP))

	// Remove
	_, seg, err = capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m2, err := ipc.NewRootLibp2pHelperInterface_RemoveTrustedPeer_Request(seg)
	require.NoError(t, err)
	p2, err := m2.NewPeerId()
	require.NoError(t, err)
	require.NoError(t, p2.SetId(testBanPID))
	require.NoError(t, m2.SetIp(testBanIP))
	mRpcSeqno = 21009
	resMsg, _ = RemoveTrustedPeerReq(m2).handle(testApp, mRpcSeqno)
	seqno, respSuccess = checkRpcResponseSuccess(t, resMsg, "removeTrustedPeer")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasRemoveTrustedPeer())
	require.False(t, bm.IsTrusted(pid, testBanIP))
}

func TestBanPeerActivelyDisconnects(t *testing.T) {
	appA, _ := newTestApp(t, nil, true)
	appA.NoDHT = true
	newBanManagerForApp(t, appA)

	appB, _ := newTestApp(t, nil, true)
	appB.NoDHT = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)
	require.NoError(t, appB.P2p.Host.Connect(appB.Ctx, appAInfos[0]))
	require.Eventually(t, func() bool {
		return len(appA.P2p.Host.Network().ConnsToPeer(appB.P2p.Host.ID())) > 0
	}, 5*time.Second, 50*time.Millisecond, "appB did not connect to appA")

	// Ban appB from appA's side: the handler must actively disconnect it.
	var mRpcSeqno uint64 = 21010
	resMsg, _ := BanPeerReq(newBanPeerRequest(t, appB.P2p.Host.ID().String(), "", true)).handle(appA, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "banPeer")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasBanPeer())

	require.Eventually(t, func() bool {
		return len(appA.P2p.Host.Network().ConnsToPeer(appB.P2p.Host.ID())) == 0
	}, 5*time.Second, 50*time.Millisecond, "banned peer was not actively disconnected")
}

func TestConfigureWiresBanManager(t *testing.T) {
	testApp := newApp()
	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	// Pre-seed a banlist with a manual ban and a trusted peer.
	banlistPath := filepath.Join(dir, "libp2p_banlist.json")
	pid := testBanPID
	trustedPID := "12D3KooWGnQ4vat8EybAeFEK3jk78vmwDu9qMhZzcyQBPb16VCnS"
	content := `{"version": 1, "banned": {"peerIds": ["` + pid + `"], "ips": ["1.2.3.4"]}, "trusted": {"peerIds": ["` + trustedPID + `"], "ips": ["9.9.9.9"]}}`
	require.NoError(t, ioutil.WriteFile(banlistPath, []byte(content), 0644))

	key, _, err := crypto.GenerateEd25519Key(rand.Reader)
	require.NoError(t, err)
	keyBytes, err := crypto.MarshalPrivateKey(key)
	require.NoError(t, err)

	external := "/ip4/0.0.0.0/tcp/7000"
	self := "/ip4/127.0.0.1/tcp/7000"

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Configure_Request(seg)
	require.NoError(t, err)
	c, err := m.NewConfig()
	require.NoError(t, err)

	require.NoError(t, c.SetStatedir(dir))
	require.NoError(t, c.SetBanlistPath(banlistPath))
	require.NoError(t, c.SetPrivateKey(keyBytes))
	require.NoError(t, c.SetNetworkId(string(testProtocol)))
	lon, err := c.NewListenOn(1)
	require.NoError(t, err)
	require.NoError(t, lon.At(0).SetRepresentation(self))
	c.SetMetricsPort(0)
	ema, err := c.NewExternalMultiaddr()
	require.NoError(t, err)
	require.NoError(t, ema.SetRepresentation(external))
	c.SetUnsafeNoTrustIp(false)
	c.SetFlood(false)
	c.SetPeerExchange(false)
	c.SetPeerProtectionRatio(.2)
	_, err = c.NewDirectPeers(0)
	require.NoError(t, err)
	_, err = c.NewSeedPeers(0)
	require.NoError(t, err)
	c.SetMinConnections(20)
	c.SetMaxConnections(50)
	c.SetValidationQueueSize(16)
	gc, err := c.NewGatingConfig()
	require.NoError(t, err)
	_, err = gc.NewBannedIps(0)
	require.NoError(t, err)
	_, err = gc.NewBannedPeerIds(0)
	require.NoError(t, err)
	_, err = gc.NewTrustedIps(0)
	require.NoError(t, err)
	_, err = gc.NewTrustedPeerIds(0)
	require.NoError(t, err)
	gc.SetIsolate(false)

	resMsg, _ := ConfigureReq(m).handle(testApp, 239)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "configure")
	require.Equal(t, seqno, uint64(239))
	require.True(t, respSuccess.HasConfigure())

	bm := testApp.P2p.GatingState().BanManager()
	require.NotNil(t, bm, "Configure must install the ban manager into the gating state")
	bannedPID, err := peer.Decode(pid)
	require.NoError(t, err)
	require.True(t, bm.IsBanned(bannedPID, "1.2.3.4"))
	trustedPID_, err := peer.Decode(trustedPID)
	require.NoError(t, err)
	require.True(t, bm.IsTrusted(trustedPID_, "9.9.9.9"))
}

func TestBanManagerGatingOrCombined(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	bm := newBanManagerForApp(t, testApp)
	pid, err := peer.Decode(testBanPID)
	require.NoError(t, err)
	testMaddr, err := ma.NewMultiaddr("/ip4/1.2.3.4/tcp/7000")
	require.NoError(t, err)

	// Legacy gating config: peer is allowed.
	ok := testApp.P2p.GatingState().InterceptAddrDial(pid, testMaddr)
	require.True(t, ok)

	// Ban via the ban manager: gating denies immediately.
	require.NoError(t, bm.BanPeer(pid, "1.2.3.4", true))
	ok = testApp.P2p.GatingState().InterceptAddrDial(pid, testMaddr)
	require.False(t, ok)

	// Trusted wins over banned: adding the peer to the trusted list lifts
	// gating again.
	require.NoError(t, bm.AddTrustedPeer(pid, "1.2.3.4"))
	ok = testApp.P2p.GatingState().InterceptAddrDial(pid, testMaddr)
	require.True(t, ok)
}
