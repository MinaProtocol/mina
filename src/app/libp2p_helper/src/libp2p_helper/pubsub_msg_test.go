package main

import (
	"github.com/stretchr/testify/require"
	"testing"

	capnp "capnproto.org/go/capnp/v3"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	ipc "libp2p_ipc"
)

func TestPublish(t *testing.T) {
	var err error
	testApp, _ := newTestApp(t, nil, true)
	testApp.P2p.Pubsub, err = pubsub.NewGossipSub(testApp.Ctx, testApp.P2p.Host)
	require.NoError(t, err)

	topic := "testtopic"
	data := []byte("testdata")

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Publish_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetTopic(topic))
	require.NoError(t, m.SetData(data))

	resMsg := testApp.handlePublish(39, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(39))
	require.True(t, respSuccess.HasPublish())
	_, err = respSuccess.Publish()
	require.NoError(t, err)

	_, has := testApp.Topics[topic]
	require.True(t, has)
}

func testSubscribeImpl(t *testing.T) (*app, string, uint64) {
	var err error
	testApp, _ := newTestApp(t, nil, true)
	testApp.P2p.Pubsub, err = pubsub.NewGossipSub(testApp.Ctx, testApp.P2p.Host)
	require.NoError(t, err)

	topic := "testtopic"
	idx := uint64(21)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Subscribe_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetTopic(topic))
	sid, err := m.NewSubscriptionId()
	require.NoError(t, err)
	sid.SetId(idx)

	resMsg := testApp.handleSubscribe(59, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(59))
	require.True(t, respSuccess.HasSubscribe())
	_, err = respSuccess.Subscribe()
	require.NoError(t, err)

	_, has := testApp.Topics[topic]
	require.True(t, has)
	_, has = testApp.Subs[idx]
	require.True(t, has)
	return testApp, topic, idx
}

func TestSubscribe(t *testing.T) {
	_, _, _ = testSubscribeImpl(t)
}

func TestUnsubscribe(t *testing.T) {
	var err error
	testApp, _, idx := testSubscribeImpl(t)

	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Unsubscribe_Request(seg)
	require.NoError(t, err)
	sid, err := m.NewSubscriptionId()
	require.NoError(t, err)
	sid.SetId(idx)

	resMsg := testApp.handleUnsubscribe(7739, m)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg)
	require.Equal(t, seqno, uint64(7739))
	require.True(t, respSuccess.HasUnsubscribe())
	_, err = respSuccess.Unsubscribe()
	require.NoError(t, err)

	_, has := testApp.Subs[idx]
	require.False(t, has)
}

func TestValidationPush(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	ipcValResults := []ipc.ValidationResult{
		ipc.ValidationResult_accept,
		ipc.ValidationResult_reject,
		ipc.ValidationResult_ignore,
	}

	pubsubValResults := []pubsub.ValidationResult{
		pubsub.ValidationAccept,
		pubsub.ValidationReject,
		pubsub.ValidationIgnore,
	}

	for i := 0; i < len(ipcValResults); i++ {
		result := ValidationUnknown
		seqno := uint64(i)
		status := &validationStatus{
			Completion: make(chan pubsub.ValidationResult),
		}
		testApp.Validators[seqno] = status
		go func() {
			result = <-status.Completion
		}()
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		require.NoError(t, err)
		m, err := ipc.NewRootLibp2pHelperInterface_Validation(seg)
		require.NoError(t, err)
		m.SetValidationSeqNumber(seqno)
		m.SetResult(ipcValResults[i])
		testApp.handleValidation(m)
		require.NoError(t, err)
		require.Equal(t, pubsubValResults[i], result)
		_, has := testApp.Validators[seqno]
		require.False(t, has)
	}
}
