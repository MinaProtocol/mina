package main

import (
	"testing"

	capnp "capnproto.org/go/capnp/v3"
	ipc "libp2p_ipc"

	"github.com/stretchr/testify/require"
)

// Regression test: the SetNodeStatus handler must copy the status bytes out
// of the request's capnp arena. Storing the arena-backed slice directly keeps
// the whole arena alive (a large memory leak) and aliases memory the arena
// owner may reuse.
func TestSetNodeStatusCopiesOutOfArena(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_SetNodeStatus_Request(seg)
	require.NoError(t, err)
	original := []byte("status_bytes_owned_by_arena")
	require.NoError(t, m.SetStatus(original))

	resMsg, _ := SetNodeStatusReq(m).handle(testApp, 77)
	_, respSuccess := checkRpcResponseSuccess(t, resMsg, "setNodeStatus")
	require.True(t, respSuccess.HasSetNodeStatus())
	require.Equal(t, original, testApp.P2p.NodeStatus)

	// Corrupt the arena-backed bytes; a stored alias would see the change.
	arenaBytes, err := m.Status()
	require.NoError(t, err)
	for i := range arenaBytes {
		arenaBytes[i] = 'X'
	}
	require.Equal(t, original, testApp.P2p.NodeStatus,
		"NodeStatus must not alias the capnp arena")
}
