package codanet

import (
	gonet "net"
	"testing"

	peer "github.com/libp2p/go-libp2p-core/peer"
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

	gs.TrustedPeers.Add(testInfo.ID)
	allowed = gs.InterceptAddrDial(testInfo.ID, testMa)
	require.True(t, allowed)
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
