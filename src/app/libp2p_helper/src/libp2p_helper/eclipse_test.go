package main

import (
	"context"
	ipc "libp2p_ipc"
	"math/rand"
	"testing"
	"time"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/stretchr/testify/require"
)

const ECLIPSE_NODES = 30

func TestEclipse(t *testing.T) {
	newProtocol := "/mina/97"
	errChan := make(chan error, 3)
	ctx, ctxCancel := context.WithCancel(context.Background())
	handleErrChan(t, errChan, ctxCancel)

	nodes_, _, ports_ := initNodes(t, ECLIPSE_NODES+2, upcallDropAllMask^(1<<StreamMessageReceivedChan)^(1<<StreamLostChan)^(1<<IncomingStreamChan), DISTANT_PEERS, true)
	trapB := nodes_[0].trap
	bob := nodes_[0].node
	bobPort := ports_[0]
	testAddStreamHandlerDo(t, newProtocol, bob, 10990)
	appBInfos, err := addrInfos(bob.P2p.Host)
	require.NoError(t, err)

	carol := nodes_[1].node
	trapC := nodes_[1].trap

	t.Logf("Bob: %s", bob.P2p.Host.ID().Pretty())
	t.Logf("Carol: %s", carol.P2p.Host.ID().Pretty())

	nodes := nodes_[2:]

	seed := time.Now().Unix()
	t.Logf("Seed: %d", seed)
	r := rand.New(rand.NewSource(seed))

	for i := range nodes {
		delay := time.Duration(r.Intn(1000)) * time.Millisecond
		go func(i int) {
			node := nodes[i].node
			time.Sleep(delay)
			for j := 0; j < 13; j++ {
				if ctx.Err() != nil {
					return
				}
				_ = node.P2p.Host.Connect(node.Ctx, appBInfos[0])
				time.Sleep(time.Second)
			}
		}(i)
	}
	time.Sleep(70 * time.Second)
	err = carol.P2p.Host.Connect(carol.Ctx, appBInfos[0])
	require.NoError(t, err)

	time.Sleep(2 * time.Second)
	carolToBobSid := testOpenStreamDo(t, carol, bob.P2p.Host, bobPort, 9900, string(newProtocol))
	<-trapB.IncomingStream
	time.Sleep(500 * time.Millisecond)

	{
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		require.NoError(t, err)
		m, err := ipc.NewRootLibp2pHelperInterface_SendStream_Request(seg)
		require.NoError(t, err)
		msg, err := m.NewMsg()
		require.NoError(t, err)
		sid, err := msg.NewStreamId()
		require.NoError(t, err)
		sid.SetId(carolToBobSid)
		require.NoError(t, msg.SetData([]byte("hello")))
		resMsg := SendStreamReq(m).handle(carol, 102788)
		_, _ = checkRpcResponseError(t, resMsg)
	}

	// TODO it should actually be other way around:
	// Carol would be able to communicate for not less than 10 seconds (as the grace period in tests
	// is 10 seconds) and hence Bob would be able to respond
	// However we have custom logic in the code which is preventing this from happening by dropping
	// Carol's connection after 400ms.
	select {
	case <-trapB.StreamMessageReceived:
		t.Fatal("Carol received a reply on stream: connection should have been dropped")
		// TODO instead of fatal, repeat the test after the grace period: Carol's conncetion would
		// replace one of the old inactive connections (now they are all protected due to k-bucket)
	case <-trapC.StreamLost:
	}
}
