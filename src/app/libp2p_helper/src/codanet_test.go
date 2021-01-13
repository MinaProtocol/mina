package codanet

import (
	"testing"

	peer "github.com/libp2p/go-libp2p-core/peer"
	ma "github.com/multiformats/go-multiaddr"

	"github.com/stretchr/testify/require"
)

func TestConnectionGating(t *testing.T) {
	gs := NewCodaGatingState(nil, nil, nil)

	testMa, err := ma.NewMultiaddr("/ip4/10.0.0.1/tcp/80")
	require.NoError(t, err)

	testInfo := &peer.AddrInfo{
		ID:    peer.ID("testid"),
		Addrs: []ma.Multiaddr{testMa},
	}
	allowed := gs.InterceptAddrDial(testInfo.ID, testMa)
	require.False(t, allowed)

	gs.AllowedPeers.Add(testInfo.ID)
	allowed = gs.InterceptAddrDial(testInfo.ID, testMa)
	require.True(t, allowed)
}
