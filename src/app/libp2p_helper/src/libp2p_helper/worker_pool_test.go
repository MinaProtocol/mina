package main

import (
	"testing"
	"time"

	capnp "capnproto.org/go/capnp/v3"
	ipc "libp2p_ipc"

	"github.com/stretchr/testify/require"
)

func mkSetNodeStatusMsg(t *testing.T, seqno uint64, status []byte) *ipc.Libp2pHelperInterface_Message {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	msg, err := ipc.NewRootLibp2pHelperInterface_Message(seg)
	require.NoError(t, err)
	req, err := msg.NewRpcRequest()
	require.NoError(t, err)
	h, err := req.NewHeader()
	require.NoError(t, err)
	sn, err := h.NewSequenceNumber()
	require.NoError(t, err)
	sn.SetSeqno(seqno)
	sns, err := req.NewSetNodeStatus()
	require.NoError(t, err)
	require.NoError(t, sns.SetStatus(status))
	return &msg
}

// Regression test: when the worker pool is full, incoming messages must be
// queued via backpressure, never dropped. Every message is an RPC request or
// push from the daemon; a dropped RPC request leaves the daemon waiting
// forever on a response that will never arrive.
func TestDispatchBackpressureDoesNotDropMessages(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	testApp.NoUpcalls = false
	// Unbuffered out channel: handlers block in writeMsg until the test
	// reads, keeping the pool saturated while further messages arrive.
	testApp.OutChan = make(chan *capnp.Message)
	testApp.workerSem = make(chan struct{}, 2)

	const total = 10
	msgs := make([]*ipc.Libp2pHelperInterface_Message, total)
	for i := 0; i < total; i++ {
		msgs[i] = mkSetNodeStatusMsg(t, uint64(i), []byte("status"))
	}

	go func() {
		for _, m := range msgs {
			testApp.dispatchIncoming(m)
		}
	}()

	deadline := time.After(15 * time.Second)
	for i := 0; i < total; i++ {
		select {
		case <-testApp.OutChan:
		case <-deadline:
			t.Fatalf("received only %d of %d responses; messages were dropped", i, total)
		}
	}
}

func TestInitIntEnvRejectsInvalid(t *testing.T) {
	t.Setenv("LIBP2P_TEST_INT_ENV", "bogus")
	require.Equal(t, 256, initIntEnv("LIBP2P_TEST_INT_ENV", 256))
	t.Setenv("LIBP2P_TEST_INT_ENV", "-1")
	require.Equal(t, 256, initIntEnv("LIBP2P_TEST_INT_ENV", 256))
	t.Setenv("LIBP2P_TEST_INT_ENV", "0")
	require.Equal(t, 256, initIntEnv("LIBP2P_TEST_INT_ENV", 256))
	t.Setenv("LIBP2P_TEST_INT_ENV", "512")
	require.Equal(t, 512, initIntEnv("LIBP2P_TEST_INT_ENV", 256))
}
