package main

import (
	"context"
	"time"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
	peer "github.com/libp2p/go-libp2p-core/peer"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
)

type ValidationPushT = ipc.Libp2pHelperInterface_Validation
type ValidationPush ValidationPushT

func fromValidationPush(m ipcPushMessage) (pushMessage, error) {
	i, err := m.Validation()
	return ValidationPush(i), err
}

// Helper type to distinguish from integer default value `0`
// pointing to a correct validation status. Value `-1000` is
// used because `-1` is already reserved by the libp2p library
const ValidationUnknown = pubsub.ValidationResult(-1000)

func (m ValidationPush) handle(app *app) {
	if app.P2p == nil {
		app.P2p.Logger.Error("handleValidation: P2p not configured")
		return
	}
	vid, err := ValidationPushT(m).ValidationId()
	if err != nil {
		app.P2p.Logger.Errorf("handleValidation: error %w", err)
		return
	}
	seqno := vid.Id()
	app.ValidatorMutex.Lock()
	defer app.ValidatorMutex.Unlock()
	if st, ok := app.Validators[seqno]; ok {
		res := ValidationUnknown
		switch ValidationPushT(m).Result() {
		case ipc.ValidationResult_accept:
			res = pubsub.ValidationAccept
		case ipc.ValidationResult_reject:
			res = pubsub.ValidationReject
		case ipc.ValidationResult_ignore:
			res = pubsub.ValidationIgnore
		default:
			app.P2p.Logger.Warnf("handleValidation: unknown validation result %d", ValidationPushT(m).Result())
		}
		st.Completion <- res
		if st.TimedOutAt != nil {
			app.P2p.Logger.Errorf("validation for item %d took %d seconds", seqno, time.Now().Add(validationTimeout).Sub(*st.TimedOutAt))
		}
		delete(app.Validators, seqno)
	} else {
		app.P2p.Logger.Warnf("handleValidation: validation seqno %d unknown", seqno)
	}
}

type PublishReqT = ipc.Libp2pHelperInterface_Publish_Request
type PublishReq PublishReqT

func fromPublishReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.Publish()
	return PublishReq(i), err
}
func (m PublishReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	if app.P2p.Dht == nil {
		return mkRpcRespError(seqno, needsDHT())
	}

	var topic *pubsub.Topic
	var has bool

	topicName, err := PublishReqT(m).Topic()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	data, err := PublishReqT(m).Data()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	if topic, has = app.Topics[topicName]; !has {
		topic, err = app.P2p.Pubsub.Join(topicName)
		if err != nil {
			return mkRpcRespError(seqno, badp2p(err))
		}
		app.Topics[topicName] = topic
	}

	if err := topic.Publish(app.Ctx, data); err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewPublish()
		panicOnErr(err)
	})
}

type SubscribeReqT = ipc.Libp2pHelperInterface_Subscribe_Request
type SubscribeReq SubscribeReqT

func fromSubscribeReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.Subscribe()
	return SubscribeReq(i), err
}
func (m SubscribeReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	if app.P2p.Dht == nil {
		return mkRpcRespError(seqno, needsDHT())
	}

	topicName, err := SubscribeReqT(m).Topic()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	subId_, err := SubscribeReqT(m).SubscriptionId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	subId := subId_.Id()

	// Join is a misleading name, it actually only creates a new topic handle
	topic, err := app.P2p.Pubsub.Join(topicName)
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	app.Topics[topicName] = topic

	err = app.P2p.Pubsub.RegisterTopicValidator(topicName, func(ctx context.Context, id peer.ID, msg *pubsub.Message) pubsub.ValidationResult {
		app.P2p.Logger.Debugf("Received gossip message on topic %s from %s", topicName, id.Pretty())
		if id == app.P2p.Me {
			// messages from ourself are valid.
			app.P2p.Logger.Info("would have validated but it's from us!")
			return pubsub.ValidationAccept
		}

		seenAt := time.Now()

		seqno := app.NextId()
		ch := make(chan pubsub.ValidationResult)
		app.ValidatorMutex.Lock()
		app.Validators[seqno] = new(validationStatus)
		app.Validators[seqno].Completion = ch
		app.ValidatorMutex.Unlock()

		app.P2p.Logger.Info("validating a new pubsub message ...")

		sender, err := findPeerInfo(app, id)

		if err != nil && !app.UnsafeNoTrustIP {
			app.P2p.Logger.Errorf("failed to connect to peer %s that just sent us a pubsub message, dropping it", peer.Encode(id))
			app.ValidatorMutex.Lock()
			defer app.ValidatorMutex.Unlock()
			delete(app.Validators, seqno)
			return pubsub.ValidationIgnore
		}

		deadline, ok := ctx.Deadline()
		if !ok {
			app.P2p.Logger.Errorf("no deadline set on validation context")
			defer app.ValidatorMutex.Unlock()
			delete(app.Validators, seqno)
			return pubsub.ValidationIgnore
		}
		app.writeMsg(mkGossipReceivedUpcall(sender, deadline, seenAt, msg.Data, seqno, subId))

		// Wait for the validation response, but be sure to honor any timeout/deadline in ctx
		select {
		case <-ctx.Done():
			// XXX: do 🅽🅾🆃  delete app.Validators[seqno] here! the ocaml side doesn't
			// care about the timeout and will validate it anyway.
			// validationComplete will remove app.Validators[seqno] once the
			// coda process gets around to it.
			app.P2p.Logger.Error("validation timed out :(")

			validationTimeoutMetric.Inc()

			app.ValidatorMutex.Lock()

			now := time.Now()
			app.Validators[seqno].TimedOutAt = &now

			app.ValidatorMutex.Unlock()

			if app.UnsafeNoTrustIP {
				app.P2p.Logger.Info("validated anyway!")
				return pubsub.ValidationAccept
			}
			app.P2p.Logger.Info("unvalidated :(")
			return pubsub.ValidationReject
		case res := <-ch:
			validationTime := time.Since(deadline)
			validationTimeMetric.Set(float64(validationTime.Nanoseconds()))
			switch res {
			case pubsub.ValidationReject:
				app.P2p.Logger.Info("why u fail to validate :(")
			case pubsub.ValidationAccept:
				app.P2p.Logger.Info("validated!")
			case pubsub.ValidationIgnore:
				app.P2p.Logger.Info("ignoring valid message!")
			default:
				app.P2p.Logger.Info("unknown validation result")
				res = pubsub.ValidationIgnore
			}
			return res
		}
	}, pubsub.WithValidatorTimeout(validationTimeout))

	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	sub, err := topic.Subscribe()
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	ctx, cancel := context.WithCancel(app.Ctx)
	app.Subs[subId] = subscription{
		Sub:    sub,
		Idx:    subId,
		Ctx:    ctx,
		Cancel: cancel,
	}
	go func() {
		for {
			_, err = sub.Next(ctx)
			if err != nil {
				if ctx.Err() != context.Canceled {
					app.P2p.Logger.Error("sub.Next failed: ", err)
				} else {
					break
				}
			}
		}
	}()
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewSubscribe()
		panicOnErr(err)
	})
}

type UnsubscribeReqT = ipc.Libp2pHelperInterface_Unsubscribe_Request
type UnsubscribeReq UnsubscribeReqT

func fromUnsubscribeReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.Unsubscribe()
	return UnsubscribeReq(i), err
}
func (m UnsubscribeReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	subId_, err := UnsubscribeReqT(m).SubscriptionId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	subId := subId_.Id()
	if sub, ok := app.Subs[subId]; ok {
		sub.Sub.Cancel()
		sub.Cancel()
		delete(app.Subs, subId)
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			_, err := m.NewUnsubscribe()
			panicOnErr(err)
		})
	}
	return mkRpcRespError(seqno, badRPC(errors.New("subscription not found")))
}
