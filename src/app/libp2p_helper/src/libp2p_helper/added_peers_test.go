package main

import (
	"testing"

	capnp "capnproto.org/go/capnp/v3"
	ipc "libp2p_ipc"

	"github.com/libp2p/go-libp2p/core/peer"
	ma "github.com/multiformats/go-multiaddr"
	"github.com/stretchr/testify/require"
)

// Regression test: repeated AddPeers calls for the same peer ID (e.g.
// reconnect loops) must not grow _addedPeers unboundedly.
func TestAddPeersDedupesByID(t *testing.T) {
	testApp := &app{}
	addr1 := ma.StringCast("/ip4/127.0.0.1/tcp/7000")
	addr2 := ma.StringCast("/ip4/127.0.0.1/tcp/7001")

	for i := 0; i < 100; i++ {
		testApp.AddPeers(peer.AddrInfo{ID: peer.ID("peer-a"), Addrs: []ma.Multiaddr{addr1}})
	}
	testApp.AddPeers(peer.AddrInfo{ID: peer.ID("peer-b"), Addrs: []ma.Multiaddr{addr1}})
	// Re-adding peer-a with a new address updates in place.
	testApp.AddPeers(peer.AddrInfo{ID: peer.ID("peer-a"), Addrs: []ma.Multiaddr{addr2}})

	added := testApp.GetAddedPeers()
	require.Len(t, added, 2)
	require.Equal(t, peer.ID("peer-a"), added[0].ID)
	require.Equal(t, []ma.Multiaddr{addr2}, added[0].Addrs, "latest AddrInfo must win")
	require.Equal(t, peer.ID("peer-b"), added[1].ID)
}

func TestGetAddedPeersReturnsCopy(t *testing.T) {
	testApp := &app{}
	testApp.AddPeers(peer.AddrInfo{ID: peer.ID("peer-a")})

	snapshot := testApp.GetAddedPeers()
	testApp.AddPeers(peer.AddrInfo{ID: peer.ID("peer-a"), Addrs: []ma.Multiaddr{ma.StringCast("/ip4/127.0.0.1/tcp/7000")}})

	require.Empty(t, snapshot[0].Addrs, "snapshot must not observe later in-place updates")
}

// Regression test: readGatingConfig must honor the cleanAddedPeers flag from
// the daemon. Added peers are trusted only while the flag is unset — the
// daemon's gating pushes (e.g. on ban expiry) do not re-send runtime-added
// peers, so the helper must keep merging them itself.
func TestReadGatingConfigRespectsCleanAddedPeers(t *testing.T) {
	mkGatingConfig := func(clean bool) ipc.GatingConfig {
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		require.NoError(t, err)
		m, err := ipc.NewRootLibp2pHelperInterface_SetGatingConfig_Request(seg)
		require.NoError(t, err)
		gc, err := m.NewGatingConfig()
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
		gc.SetCleanAddedPeers(clean)
		return gc
	}

	addedPeers := []peer.AddrInfo{{ID: peer.ID("added-peer")}}

	cfg, err := readGatingConfig(mkGatingConfig(false), addedPeers)
	require.NoError(t, err)
	_, trusted := cfg.TrustedPeers[peer.ID("added-peer")]
	require.True(t, trusted, "added peers must stay trusted when cleanAddedPeers=false")

	cfg, err = readGatingConfig(mkGatingConfig(true), addedPeers)
	require.NoError(t, err)
	_, trusted = cfg.TrustedPeers[peer.ID("added-peer")]
	require.False(t, trusted, "added peers must be excluded when cleanAddedPeers=true")
}
