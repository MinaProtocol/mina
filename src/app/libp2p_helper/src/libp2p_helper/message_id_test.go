package main

import (
	"context"
	"testing"
	"time"

	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/stretchr/testify/require"
)

// This file contains test for the use of message id function

func testPubsubMsgIdFun(t *testing.T, topic string) {
	newProtocol := "/mina/97"
	var mask uint32 = upcallDropAllMask ^ (1 << IncomingStreamChan) ^ (1 << GossipReceivedChan)
	errChan := make(chan error, 3)
	ctx, ctxCancel := context.WithCancel(context.Background())
	handleErrChan(t, errChan, ctxCancel)

	alice, appAPort := newTestApp(t, nil, false)
	alice.SetConnectionHandlers()
	appAInfos, err := addrInfos(alice.P2p.Host)
	require.NoError(t, err)
	trapA := newUpcallTrap("a", 64, mask)
	launchFeedUpcallTrap(alice.P2p.Logger, alice.OutChan, trapA, errChan, ctx)
	testAddStreamHandlerDo(t, newProtocol, alice, 10990)

	bob, _ := newTestApp(t, appAInfos, false)
	trapB := newUpcallTrap("b", 64, mask)
	launchFeedUpcallTrap(bob.P2p.Logger, bob.OutChan, trapB, errChan, ctx)
	err = bob.P2p.Host.Connect(bob.Ctx, appAInfos[0])
	require.NoError(t, err)

	carol, _ := newTestApp(t, appAInfos, false)
	trapC := newUpcallTrap("c", 64, mask)
	launchFeedUpcallTrap(carol.P2p.Logger, carol.OutChan, trapC, errChan, ctx)
	err = carol.P2p.Host.Connect(carol.Ctx, appAInfos[0])
	require.NoError(t, err)

	gossipSubp := pubsub.DefaultGossipSubParams()
	gossipSubp.D = 4
	gossipSubp.Dlo = 2
	gossipSubp.Dhi = 6
	require.NoError(t, configurePubsub(alice, 100, nil, nil, pubsub.WithGossipSubParams(gossipSubp)))
	require.NoError(t, configurePubsub(bob, 100, nil, nil, pubsub.WithGossipSubParams(gossipSubp)))
	require.NoError(t, configurePubsub(carol, 100, nil, nil, pubsub.WithGossipSubParams(gossipSubp)))

	// Subscribe to the topic
	testSubscribeDo(t, alice, topic, 21, 58)
	testSubscribeDo(t, bob, topic, 21, 58)
	testSubscribeDo(t, carol, topic, 21, 58)

	_ = testOpenStreamDo(t, bob, alice.P2p.Host, appAPort, 9900, string(newProtocol))
	_ = testOpenStreamDo(t, carol, alice.P2p.Host, appAPort, 9900, string(newProtocol))
	<-trapA.IncomingStream
	<-trapA.IncomingStream

	msg := []byte("hello world")
	testPublishDo(t, alice, topic, msg, 21)
	testPublishDo(t, bob, topic, msg, 21)

	time.Sleep(time.Millisecond * 100)

	n := 0
loop:
	for {
		select {
		case <-trapC.GossipReceived:
		default:
			break loop
		}
		n++
	}
	require.Equal(t, 1, n)
}

func TestPubsubMsgIdFun(t *testing.T) {
	testPubsubMsgIdFun(t, "test")
}

func TestPubsubMsgIdFunLongTopic(t *testing.T) {
	testPubsubMsgIdFun(t, "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789")
}
