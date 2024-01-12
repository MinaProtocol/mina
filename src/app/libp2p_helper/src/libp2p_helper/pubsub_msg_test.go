package main

import (
	"math/rand"
	"testing"

	"github.com/stretchr/testify/require"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
)

func testPublishDo(t *testing.T, app *app, topic string, data []byte, rpcSeqno uint64) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Publish_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetTopic(topic))
	require.NoError(t, m.SetData(data))

	resMsg, _ := PublishReq(m).handle(app, rpcSeqno)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "publish")
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasPublish())
	_, err = respSuccess.Publish()
	require.NoError(t, err)

	_, has := app._topics[topic]
	require.True(t, has)
}

func TestPublish(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)
	require.NoError(t, configurePubsub(testApp, 32, nil, nil))
	testPublishDo(t, testApp, "testtopic", []byte("testdata"), 48)
}

func testSubscribeDo(t *testing.T, app *app, topic string, subId uint64, rpcSeqno uint64) {
	_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
	require.NoError(t, err)
	m, err := ipc.NewRootLibp2pHelperInterface_Subscribe_Request(seg)
	require.NoError(t, err)
	require.NoError(t, m.SetTopic(topic))
	sid, err := m.NewSubscriptionId()
	require.NoError(t, err)
	sid.SetId(subId)

	resMsg, _ := SubscribeReq(m).handle(app, rpcSeqno)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "subscribe")
	require.Equal(t, seqno, rpcSeqno)
	require.True(t, respSuccess.HasSubscribe())
	_, err = respSuccess.Subscribe()
	require.NoError(t, err)

	_, has := app._topics[topic]
	require.True(t, has)
	_, has = app._subs[subId]
	require.True(t, has)
}

func testSubscribeImpl(t *testing.T) (*app, string, uint64) {
	testApp, _ := newTestApp(t, nil, true)
	require.NoError(t, configurePubsub(testApp, 32, nil, nil))

	topic := "testtopic"
	idx := uint64(21)

	testSubscribeDo(t, testApp, topic, idx, 58)

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

	resMsg, _ := UnsubscribeReq(m).handle(testApp, 7739)
	require.NoError(t, err)
	seqno, respSuccess := checkRpcResponseSuccess(t, resMsg, "unsubscribe")
	require.Equal(t, seqno, uint64(7739))
	require.True(t, respSuccess.HasUnsubscribe())
	_, err = respSuccess.Unsubscribe()
	require.NoError(t, err)

	_, has := testApp._subs[idx]
	require.False(t, has)
}

func TestValidationPush(t *testing.T) {
	testApp, _ := newTestApp(t, nil, true)

	ipc2Pubsub := map[ipc.ValidationResult]pubsub.ValidationResult{
		ipc.ValidationResult_accept: pubsub.ValidationAccept,
		ipc.ValidationResult_reject: pubsub.ValidationReject,
		ipc.ValidationResult_ignore: pubsub.ValidationIgnore,
	}

	for resIpc, resPS := range ipc2Pubsub {
		seqno := rand.Uint64()
		status := &validationStatus{
			Completion: make(chan pubsub.ValidationResult, 1),
		}
		testApp._validators[seqno] = status
		_, seg, err := capnp.NewMessage(capnp.SingleSegment(nil))
		require.NoError(t, err)
		m, err := ipc.NewRootLibp2pHelperInterface_Validation(seg)
		require.NoError(t, err)
		validationId, err := m.NewValidationId()
		validationId.SetId(seqno)
		m.SetResult(resIpc)
		ValidationPush(m).handle(testApp)
		require.NoError(t, err)
		result := <-status.Completion
		require.Equal(t, resPS, result)
		_, has := testApp._validators[seqno]
		require.False(t, has)
	}
}
