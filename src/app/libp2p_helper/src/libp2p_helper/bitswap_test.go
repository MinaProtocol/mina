package main

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

const CONNS_LO = 3
const CONNS_HI = 6

func TestBitswap(t *testing.T) {
	firstNode := newTestAppWithMaxConns(t, nil, false, CONNS_LO, CONNS_HI, nextPort())
	// firstNode.NoMDNS = true

	infos, err := addrInfos(firstNode.P2p.Host)
	require.NoError(t, err)

	nodes := []*app{}

	for i := 0; i < 10; i++ {
		node := newTestAppWithMaxConns(t, nil, false, CONNS_LO, CONNS_HI, nextPort())
		// node.NoMDNS = true
		node.AddedPeers = infos
		infos, err = addrInfos(node.P2p.Host)
		require.NoError(t, err)
		nodes = append(nodes, node)
		beginAdvertisingSendAndCheck(t, node)
	}

	// for _, node := range nodes {
	// }

	time.Sleep(time.Second)
}
