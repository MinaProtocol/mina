package main

import (
	"context"
	crand "crypto/rand"
	"errors"
	"io/ioutil"
	"os"
	"testing"
	"time"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/libp2p/go-libp2p-core/crypto"
	peer "github.com/libp2p/go-libp2p-core/peer"
	ma "github.com/multiformats/go-multiaddr"

	"github.com/stretchr/testify/require"
)

func maToStringList(vs []ma.Multiaddr) []string {
	vsm := make([]string, len(vs))
	for i, v := range vs {
		vsm[i] = v.String()
	}
	return vsm
}

/*
  Tests for BeginAdvertising message and
  various discovery mechanisms
*/

func TestDHTDiscovery_TwoNodes(t *testing.T) {
	appA, _ := newTestApp(t, nil, true)
	appA.NoMDNS = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, _ := newTestApp(t, appAInfos, true)
	appB.AddedPeers = appAInfos
	appB.NoMDNS = true

	// begin appB and appA's DHT advertising
	beginAdvertisingSendAndCheck(t, appB)
	beginAdvertisingSendAndCheck(t, appA)

	time.Sleep(time.Second)
}

func TestDHTDiscovery_ThreeNodes(t *testing.T) {
	appA, _ := newTestApp(t, nil, true)
	appA.NoMDNS = true

	appAInfos, err := addrInfos(appA.P2p.Host)
	require.NoError(t, err)

	appB, _ := newTestApp(t, appAInfos, true)
	appB.NoMDNS = true

	err = appB.P2p.Host.Connect(appB.Ctx, appAInfos[0])
	require.NoError(t, err)

	appC, _ := newTestApp(t, appAInfos, true)
	appC.NoMDNS = true

	err = appC.P2p.Host.Connect(appC.Ctx, appAInfos[0])
	require.NoError(t, err)

	time.Sleep(time.Second)

	// begin appB and appC's DHT advertising
	beginAdvertisingSendAndCheck(t, appB)
	beginAdvertisingSendAndCheck(t, appC)

	withTimeout(t, func() {
		for {
			// check if peerB knows about peerC
			addrs := appB.P2p.Host.Peerstore().Addrs(appC.P2p.Host.ID())
			if len(addrs) != 0 {
				// send a stream message
				// then exit
				return
			}
			time.Sleep(time.Millisecond * 100)
		}
	}, "B did not discover C via DHT")

	time.Sleep(time.Second)
}

func TestMDNSDiscovery(t *testing.T) {
	if os.Getenv("NO_MDNS_TEST") != "" {
		return
	}
	appA, appAPort := newTestApp(t, nil, true)
	appA.NoDHT = true

	appB, appBPort := newTestApp(t, nil, true)
	appB.NoDHT = true

	t.Logf("Using libp2p ports: %d and %d", appAPort, appBPort)

	// begin appA and appB's mDNS advertising
	beginAdvertisingSendAndCheck(t, appB)
	beginAdvertisingSendAndCheck(t, appA)

	ctx, cancel := context.WithTimeout(context.Background(), time.Second*10)

	go func() {
		defer cancel()
		for {
			// check if peerB knows about peerA
			addrs := appB.P2p.Host.Peerstore().Addrs(appA.P2p.Host.ID())
			if len(addrs) != 0 {
				return
			}
			time.Sleep(time.Millisecond * 100)
		}
	}()
	<-ctx.Done()
	switch ctx.Err() {
	case context.DeadlineExceeded:
		t.Error("B did not discover A via mDNS")
	}
}

func TestConfigure(t *testing.T) {
	testApp := newApp()

	dir, err := ioutil.TempDir("", "mina_test_*")
	require.NoError(t, err)

	key, _, err := crypto.GenerateEd25519Key(crand.Reader)
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
	require.NoError(t, c.SetPrivateKey(keyBytes))
	require.NoError(t, c.SetNetworkId(string(testProtocol)))
	lon, err := c.NewListenOn(1)
	require.NoError(t, err)
	require.NoError(t, lon.At(0).SetRepresentation(self))
	err = multiaddrListForeach(lon, func(v string) error {
		if v != self {
			return errors.New("Failed to iterate over freshly created listenOn list")
		}
		return nil
	})
	require.NoError(t, err)
	require.True(t, lon.Len() == 1)
	c.SetMetricsPort(0)
	ema, err := c.NewExternalMultiaddr()
	require.NoError(t, err)
	require.NoError(t, ema.SetRepresentation(external))
	c.SetUnsafeNoTrustIp(false)
	c.SetFlood(false)
	c.SetPeerExchange(false)
	_, err = c.NewDirectPeers(0)
	require.NoError(t, err)
	_, err = c.NewSeedPeers(0)
	require.NoError(t, err)
	c.SetMinConnections(20)
	c.SetMaxConnections(50)
	c.SetValidationQueueSize(16)
	c.SetMinaPeerExchange(false)

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

	resMsg := ConfigureReq(m).handle(testApp, 239)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "configure")
	require.Equal(t, seqno, uint64(239))
	require.True(t, respSuccess.HasConfigure())
	_, err = respSuccess.Configure()
	require.NoError(t, err)
}

func TestGenerateKeypair(t *testing.T) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_GenerateKeypair_Request(seg)
	require.NoError(t, err)

	testApp, _ := newTestApp(t, nil, true)
	resMsg := GenerateKeypairReq(m).handle(testApp, 7839)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "generateKeypair")
	require.Equal(t, seqno, uint64(7839))
	require.True(t, respSuccess.HasGenerateKeypair())
	res, err := respSuccess.GenerateKeypair()
	require.NoError(t, err)
	r, err := res.Result()
	require.NoError(t, err)

	sk, err := r.PrivateKey()
	require.NoError(t, err)
	pk, err := r.PublicKey()
	require.NoError(t, err)
	pid, err := r.PeerId()
	require.NoError(t, err)
	peerId, err := pid.Id()
	require.NoError(t, err)

	// extra 4 bytes due to key type byte + protobuf encoding
	require.Equal(t, len(sk), 68)
	// extra 3 bytes due to key type byte + protobuf encoding
	require.Equal(t, len(pk), 36)
	require.Greater(t, len(peerId), 0)
}

func TestGetListeningAddrs(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_GetListeningAddrs_Request(seg)
	require.NoError(t, err)
	var mRpcSeqno uint64 = 1024
	resMsg := GetListeningAddrsReq(m).handle(testApp, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "getListeningAddrs")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasGetListeningAddrs())
	ls, err := respSuccess.GetListeningAddrs()
	require.NoError(t, err)
	addrsL, err := ls.Result()
	require.NoError(t, err)
	res, err := readMultiaddrList(addrsL)
	require.NoError(t, err)
	require.Equal(t, maToStringList(testApp.P2p.Host.Addrs()), res)
}

func TestListen(t *testing.T) {
	addrStr := "/ip4/127.0.0.2/tcp/8000"

	testApp, _ := newTestApp(t, nil, true)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Listen_Request(seg)
	require.NoError(t, err)
	iface, err := m.NewIface()
	require.NoError(t, iface.SetRepresentation(addrStr))
	require.NoError(t, err)

	resMsg := ListenReq(m).handle(testApp, 1239)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "listen")
	require.Equal(t, seqno, uint64(1239))
	require.True(t, respSuccess.HasListen())
	lresp, err := respSuccess.Listen()
	require.NoError(t, err)
	l, err := lresp.Result()
	require.NoError(t, err)
	found := false
	err = multiaddrListForeach(l, func(v string) error {
		if v == addrStr {
			found = true
		}
		return nil
	})
	require.NoError(t, err)
	require.True(t, found)
}

func setGatingConfigImpl(t *testing.T, app *app, allowedIps, allowedIds, bannedIps, bannedIds []string) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SetGatingConfig_Request(seg)
	require.NoError(t, err)

	gc, err := m.NewGatingConfig()
	require.NoError(t, err)
	bIps, err := gc.NewBannedIps(int32(len(bannedIps)))
	require.NoError(t, err)
	bPids, err := gc.NewBannedPeerIds(int32(len(bannedIds)))
	require.NoError(t, err)
	tIps, err := gc.NewTrustedIps(int32(len(allowedIps)))
	require.NoError(t, err)
	tPids, err := gc.NewTrustedPeerIds(int32(len(allowedIds)))
	require.NoError(t, err)
	for i, v := range bannedIps {
		require.NoError(t, bIps.Set(i, v))
	}
	for i, v := range bannedIds {
		require.NoError(t, bPids.At(i).SetId(v))
	}
	for i, v := range allowedIps {
		require.NoError(t, tIps.Set(i, v))
	}
	for i, v := range allowedIds {
		require.NoError(t, tPids.At(i).SetId(v))
	}
	gc.SetIsolate(false)

	var mRpcSeqno uint64 = 2003
	resMsg := SetGatingConfigReq(m).handle(app, mRpcSeqno)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "setGatingConfig")
	require.Equal(t, seqno, mRpcSeqno)
	require.True(t, respSuccess.HasSetGatingConfig())
	_, err = respSuccess.SetGatingConfig()
	require.NoError(t, err)
}

func TestSetGatingConfig(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	allowedID := "12D3KooWJDGPa2hiYCJ2o7XPqEq2tjrWpFJzqa4dy538Gfs7Vn2r"
	allowedMultiaddr, err := ma.NewMultiaddr("/ip4/7.8.9.0/tcp/7000")
	require.NoError(t, err)

	bannedID := "12D3KooWGnQ4vat8EybAeFEK3jk78vmwDu9qMhZzcyQBPb16VCnS"
	bannedMultiaddr, err := ma.NewMultiaddr("/ip4/1.2.3.4/tcp/7000")
	require.NoError(t, err)

	setGatingConfigImpl(t, testApp, []string{"1.2.3.4"}, []string{allowedID}, []string{"7.8.9.1"}, []string{bannedID})

	allowedPid, err := peer.Decode(allowedID)
	require.NoError(t, err)

	bannedPid, err := peer.Decode(bannedID)
	require.NoError(t, err)

	ok := testApp.P2p.GatingState().InterceptPeerDial(bannedPid)
	require.False(t, ok)

	ok = testApp.P2p.GatingState().InterceptPeerDial(allowedPid)
	require.True(t, ok)

	ok = testApp.P2p.GatingState().InterceptAddrDial(bannedPid, bannedMultiaddr)
	require.False(t, ok)

	ok = testApp.P2p.GatingState().InterceptAddrDial(bannedPid, allowedMultiaddr)
	require.False(t, ok)

	ok = testApp.P2p.GatingState().InterceptAddrDial(allowedPid, allowedMultiaddr)
	require.True(t, ok)
}

func TestSetNodeStatus(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SetNodeStatus_Request(seg)
	require.NoError(t, err)
	testStatus := []byte("test_node_status")
	require.NoError(t, m.SetStatus(testStatus))

	resMsg := SetNodeStatusReq(m).handle(testApp, 11239)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "setNodeStatus")
	require.Equal(t, seqno, uint64(11239))
	require.True(t, respSuccess.HasSetNodeStatus())
	_, err = respSuccess.SetNodeStatus()
	require.NoError(t, err)

	require.Equal(t, testStatus, testApp.P2p.NodeStatus)
}
