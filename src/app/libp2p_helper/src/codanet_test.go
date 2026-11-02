package codanet

import (
	"context"
	crand "crypto/rand"
	gonet "net"
	"path"
	"testing"
	"time"

	dsb "github.com/ipfs/go-ds-badger"
	"github.com/libp2p/go-libp2p/core/crypto"
	peer "github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/peerstore"
	"github.com/libp2p/go-libp2p/p2p/host/peerstore/pstoreds"
	ma "github.com/multiformats/go-multiaddr"

	"github.com/stretchr/testify/require"
)

func TestTrustedPrivateConnectionGating(t *testing.T) {
	initPrivateIpFilter()

	_, totalIpNet, err := gonet.ParseCIDR("0.0.0.0/0")
	require.NoError(t, err)
	knownPrivateAddrFilters := ma.NewFilters()
	knownPrivateAddrFilters.AddFilter(*totalIpNet, ma.ActionDeny)

	trustedAddrFilters := ma.NewFilters()
	trustedAddrFilters.AddFilter(*totalIpNet, ma.ActionDeny)

	gs := NewCodaGatingState(&CodaGatingConfig{TrustedAddrFilters: trustedAddrFilters}, knownPrivateAddrFilters)

	testMa, err := ma.NewMultiaddr("/ip4/10.0.0.1/tcp/80")
	require.NoError(t, err)

	testInfo := &peer.AddrInfo{
		ID:    peer.ID("testid"),
		Addrs: []ma.Multiaddr{testMa},
	}

	require.True(t, isPrivateAddr(testMa))
	require.Equal(t, Undecided, gs.checkAddrTrusted(testMa))

	allowed := gs.InterceptAddrDial(testInfo.ID, testMa)
	require.False(t, allowed)

	gs.TrustPeer(testInfo.ID)
	allowed = gs.InterceptAddrDial(testInfo.ID, testMa)
	require.True(t, allowed)
}

func newTestPeerID(t *testing.T) peer.ID {
	key, _, err := crypto.GenerateEd25519Key(crand.Reader)
	require.NoError(t, err)
	id, err := peer.IDFromPrivateKey(key)
	require.NoError(t, err)
	return id
}

func TestMakeHelperForgetsPersistedBannedPeers(t *testing.T) {
	ctx := context.Background()
	statedir := t.TempDir()

	bannedPid := newTestPeerID(t)
	otherPid := newTestPeerID(t)
	bannedMa, err := ma.NewMultiaddr("/ip4/1.2.3.4/tcp/8302")
	require.NoError(t, err)
	otherMa, err := ma.NewMultiaddr("/ip4/5.6.7.8/tcp/8302")
	require.NoError(t, err)

	// Persist both peers' addresses, as a previous run of the node would.
	dso := dsb.DefaultOptions
	ds, err := dsb.NewDatastore(path.Join(statedir, "libp2p-peerstore-v0"), &dso)
	require.NoError(t, err)
	ps, err := pstoreds.NewPeerstore(ctx, ds, pstoreds.DefaultOpts())
	require.NoError(t, err)
	ps.AddAddr(bannedPid, bannedMa, peerstore.ConnectedAddrTTL)
	ps.AddAddr(otherPid, otherMa, peerstore.ConnectedAddrTTL)
	require.NoError(t, ps.Close())
	require.NoError(t, ds.Close())

	key, _, err := crypto.GenerateEd25519Key(crand.Reader)
	require.NoError(t, err)
	listenOn, err := ma.NewMultiaddr("/ip4/127.0.0.1/tcp/0")
	require.NoError(t, err)

	h, err := MakeHelper(ctx, []ma.Multiaddr{listenOn}, nil, statedir, key, "test", nil,
		&CodaGatingConfig{BannedPeers: map[peer.ID]struct{}{bannedPid: {}}},
		1, 10, 0.2, time.Second, nil)
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, h.Host.Close()) })

	require.Empty(t, h.Host.Peerstore().Addrs(bannedPid))
	require.Equal(t, []ma.Multiaddr{otherMa}, h.Host.Peerstore().Addrs(otherPid))
}

/*
func TestAcceptedPrivateConnectionGating(t *testing.T) {
  initPrivateIpFilter()
	gs := NewCodaGatingState(nil, nil, nil, nil)

	testMa, err := ma.NewMultiaddr("/ip4/10.0.0.1/tcp/80")
	require.NoError(t, err)

	testInfo := &peer.AddrInfo{
		ID:    peer.ID("testid"),
		Addrs: []ma.Multiaddr{testMa},
	}

	allowed := gs.InterceptAddrDial(testInfo.ID, testMa)
	require.False(t, allowed)

  allowed = gs.InterceptAccept(testMa)
	require.True(t, allowed)

	allowed = gs.InterceptAddrDial(testInfo.ID, testMa)
	require.True(t, allowed)
}
*/
