package main

import (
	"bufio"
	"context"
	cryptorand "crypto/rand"
	"fmt"
	"io"
	"math"
	"os"
	"strconv"
	"sync"
	"time"

	"codanet"

	"github.com/go-errors/errors"
	crypto "github.com/libp2p/go-libp2p-core/crypto"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	peerstore "github.com/libp2p/go-libp2p-core/peerstore"
	protocol "github.com/libp2p/go-libp2p-core/protocol"
	discovery "github.com/libp2p/go-libp2p-discovery"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	mdns "github.com/libp2p/go-libp2p/p2p/discovery"
	"github.com/multiformats/go-multiaddr"
	"github.com/prometheus/client_golang/prometheus"
)

var seqs = make(chan int)

func newApp() *app {
	return &app{
		P2p:                      nil,
		Ctx:                      context.Background(),
		Subs:                     make(map[int]subscription),
		Topics:                   make(map[string]*pubsub.Topic),
		ValidatorMutex:           &sync.Mutex{},
		Validators:               make(map[int]*validationStatus),
		Streams:                  make(map[int]net.Stream),
		OutChan:                  make(chan interface{}, 4096),
		Out:                      bufio.NewWriter(os.Stdout),
		AddedPeers:               []peer.AddrInfo{},
		MetricsRefreshTime:       time.Minute,
		metricsCollectionStarted: false,
	}
}

func parseMultiaddrWithID(ma multiaddr.Multiaddr, id peer.ID) (*codaPeerInfo, error) {
	ipComponent, tcpMaddr := multiaddr.SplitFirst(ma)
	if !(ipComponent.Protocol().Code == multiaddr.P_IP4 || ipComponent.Protocol().Code == multiaddr.P_IP6) {
		return nil, badRPC(errors.New(fmt.Sprintf("only IP connections are supported right now, how did this peer connect?: %s", ma.String())))
	}

	tcpComponent, _ := multiaddr.SplitFirst(tcpMaddr)
	if tcpComponent.Protocol().Code != multiaddr.P_TCP {
		return nil, badRPC(errors.New("only TCP connections are supported right now, how did this peer connect?"))
	}

	port, err := strconv.Atoi(tcpComponent.Value())
	if err != nil {
		return nil, err
	}

	return &codaPeerInfo{Libp2pPort: port, Host: ipComponent.Value(), PeerID: peer.Encode(id)}, nil
}

func addrInfoOfString(maddr string) (*peer.AddrInfo, error) {
	multiaddr, err := multiaddr.NewMultiaddr(maddr)
	if err != nil {
		return nil, err
	}
	info, err := peer.AddrInfoFromP2pAddr(multiaddr)
	if err != nil {
		return nil, err
	}

	return info, nil
}

func (app *app) writeMsg(msg interface{}) {
	if app.NoUpcalls {
		return
	}

	app.OutChan <- msg
}

func (app *app) updateConnectionMetrics() {
	info := app.P2p.ConnectionManager.GetInfo()
	connectionCountMetric.Set(float64(info.ConnCount))
}

// TODO: {peer,protocol}-{min,max,avg}
func (app *app) checkBandwidth() {
	totalIn := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_total_bandwidth_in",
		Help: "The total incoming bandwidth used",
	})
	totalOut := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_total_bandwidth_out",
		Help: "The total outgoing bandwidth used",
	})
	rateIn := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_bandwidth_rate_in",
		Help: "The incoming bandwidth rate",
	})
	rateOut := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_bandwidth_rate_out",
		Help: "The outging bandwidth rate",
	})

	var err error

	err = prometheus.Register(totalIn)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register total_bandwidth_in; perhaps we've already done so", err.Error())
		return
	}

	err = prometheus.Register(totalOut)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register total_bandwidth_out; perhaps we've already done so", err.Error())
		return
	}

	err = prometheus.Register(rateIn)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register bandwidth_rate_in; perhaps we've already done so", err.Error())
		return
	}

	err = prometheus.Register(rateOut)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register bandwidth_rate_out; perhaps we've already done so", err.Error())
		return
	}

	for {
		stats := app.P2p.BandwidthCounter.GetBandwidthTotals()
		totalIn.Set(float64(stats.TotalIn))
		totalOut.Set(float64(stats.TotalOut))
		rateIn.Set(stats.RateIn)
		rateOut.Set(stats.RateOut)

		time.Sleep(app.MetricsRefreshTime)
	}
}

func (app *app) checkPeerCount() {
	peerCount := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_peer_count",
		Help: "The total number of peers in our network",
	})
	connectedPeerCount := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_connected_peer_count",
		Help: "The total number of peers we are actively connected to",
	})

	var err error

	err = prometheus.Register(peerCount)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register peer_count; perhaps we've already done so", err.Error())
		return
	}

	err = prometheus.Register(connectedPeerCount)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register connected_peer_count; perhaps we've already done so", err.Error())
		return
	}

	for {
		peerCount.Set(float64(len(app.P2p.Host.Network().Peers())))
		connectedPeerCount.Set(float64(app.P2p.ConnectionManager.GetInfo().ConnCount))

		time.Sleep(app.MetricsRefreshTime)
	}
}

func (app *app) checkMessageStats() {
	msgMax := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_message_max_stats",
		Help: "The max size of network message received",
	})
	msgAvg := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_message_avg_stats",
		Help: "The average size of network message received",
	})
	msgMin := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_message_min_stats",
		Help: "The min size of network message received",
	})

	err := prometheus.Register(msgMax)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register message_max_stats; perhaps we've already done so", err.Error())
		return
	}

	err = prometheus.Register(msgAvg)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register message_avg_stats; perhaps we've already done so", err.Error())
		return
	}

	err = prometheus.Register(msgMin)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register message_min_stats; perhaps we've already done so", err.Error())
		return
	}

	for {
		msgStats := app.P2p.MsgStats.GetStats()
		msgMin.Set(msgStats.Min)
		msgAvg.Set(msgStats.Avg)
		msgMax.Set(msgStats.Max)

		time.Sleep(app.MetricsRefreshTime)
	}
}

func (app *app) checkLatency() {
	latencyMin := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_latency_min",
		Help: fmt.Sprintf("The minimum latency (recorded over %s)", latencyMeasurementTime),
	})
	latencyMax := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_latency_max",
		Help: fmt.Sprintf("The maximum latency (recorded over %s)", latencyMeasurementTime),
	})
	latencyAvg := prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "Mina_libp2p_latency_avg",
		Help: fmt.Sprintf("The average latency (recorded over %s)", latencyMeasurementTime),
	})

	var err error

	err = prometheus.Register(latencyMin)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register latency_min; perhaps we've already done so", err.Error())
		return
	}

	err = prometheus.Register(latencyMax)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register latency_max; perhaps we've already done so", err.Error())
		return
	}

	err = prometheus.Register(latencyAvg)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register latency_avg; perhaps we've already done so", err.Error())
		return
	}

	for {
		peers := app.P2p.Host.Peerstore().Peers()
		if len(peers) > 0 {
			sum := 0.0
			minimum := math.MaxFloat64
			maximum := 0.0

			for _, peer := range peers {
				app.P2p.Host.Peerstore().RecordLatency(peer, latencyMeasurementTime)
				latency := float64(app.P2p.Host.Peerstore().LatencyEWMA(peer))

				sum += latency
				minimum = math.Min(minimum, latency)
				maximum = math.Max(maximum, latency)
			}

			latencyMin.Set(minimum)
			latencyMax.Set(maximum)
			latencyAvg.Set(sum / float64(len(peers)))
		} else {
			latencyMin.Set(0.0)
			latencyMax.Set(0.0)
			latencyAvg.Set(0.0)
		}

		time.Sleep(app.MetricsRefreshTime)
	}
}

func (ap *findPeerMsg) run(app *app) (interface{}, error) {
	id, err := peer.Decode(ap.PeerID)
	if err != nil {
		return nil, err
	}

	maybePeer, err := findPeerInfo(app, id)

	if err != nil {
		return nil, err
	}

	return *maybePeer, nil
}

func (m *setNodeStatusMsg) run(app *app) (interface{}, error) {
	app.P2p.NodeStatus = m.Data
	return "setNodeStatus success", nil
}

func (m *getPeerNodeStatusMsg) run(app *app) (interface{}, error) {
	ctx, _ := context.WithTimeout(app.Ctx, codanet.NodeStatusTimeout)

	addrInfo, err := addrInfoOfString(m.PeerMultiaddr)
	if err != nil {
		return nil, err
	}

	app.P2p.Host.Peerstore().AddAddrs(addrInfo.ID, addrInfo.Addrs, peerstore.ConnectedAddrTTL)

	// Open a "get node status" stream on m.PeerID,
	// block until you can read the response, return that.
	s, err := app.P2p.Host.NewStream(ctx, addrInfo.ID, codanet.NodeStatusProtocolID)
	if err != nil {
		app.P2p.Logger.Error("failed to open stream: ", err)
		return nil, err
	}

	defer func() {
		_ = s.Close()
	}()

	errCh := make(chan error)
	responseCh := make(chan string)

	go func() {
		// 1 megabyte
		size := 1048576

		data := make([]byte, size)
		n, err := s.Read(data)
		if err != nil && err != io.EOF {
			app.P2p.Logger.Errorf("failed to decode node status data: err=%s", err)
			errCh <- err
			return
		}

		if n == size && err == nil {
			errCh <- fmt.Errorf("node status data was greater than %d bytes", size)
			return
		}

		responseCh <- string(data[:n])
	}()

	select {
	case <-ctx.Done():
		s.Reset()
		return nil, errors.New("timed out requesting node status data from peer")
	case err := <-errCh:
		return nil, err
	case response := <-responseCh:
		return response, nil
	}
}

func (lp *listPeersMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	connsHere := app.P2p.Host.Network().Conns()

	peerInfos := make([]codaPeerInfo, 0, len(connsHere))

	for _, conn := range connsHere {
		maybePeer, err := parseMultiaddrWithID(conn.RemoteMultiaddr(), conn.RemotePeer())
		if err != nil {
			app.P2p.Logger.Warning("skipping maddr ", conn.RemoteMultiaddr().String(), " because it failed to parse: ", err.Error())
			continue
		}
		peerInfos = append(peerInfos, *maybePeer)
	}

	return peerInfos, nil
}

func (gc *setGatingConfigMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	newState, err := gatingConfigFromJson(gc, app.AddedPeers)
	if err != nil {
		return nil, badRPC(err)
	}

	app.P2p.GatingState = newState

	return "ok", nil
}

func (m *configureMsg) run(app *app) (interface{}, error) {
	app.UnsafeNoTrustIP = m.UnsafeNoTrustIP
	privkBytes, err := codaDecode(m.Privk)
	if err != nil {
		return nil, badRPC(err)
	}
	privk, err := crypto.UnmarshalPrivateKey(privkBytes)
	if err != nil {
		return nil, badRPC(err)
	}
	maddrs := make([]multiaddr.Multiaddr, len(m.ListenOn))
	for i, v := range m.ListenOn {
		res, err := multiaddr.NewMultiaddr(v)
		if err != nil {
			return nil, badRPC(err)
		}
		maddrs[i] = res
	}

	seeds := make([]peer.AddrInfo, 0, len(m.SeedPeers))
	for _, v := range m.SeedPeers {
		addr, err := addrInfoOfString(v)
		if err != nil {
			// TODO: this isn't necessarily an RPC error. Perhaps the encoded multiaddr
			// isn't supported by this version of libp2p.
			// But more likely, it is an RPC error.
			return nil, badRPC(err)
		}
		seeds = append(seeds, *addr)
	}

	app.AddedPeers = append(app.AddedPeers, seeds...)

	directPeers := make([]peer.AddrInfo, 0, len(m.DirectPeers))
	for _, v := range m.DirectPeers {
		addr, err := addrInfoOfString(v)
		if err != nil {
			// TODO: this isn't necessarily an RPC error. Perhaps the encoded multiaddr
			// isn't supported by this version of libp2p.
			// But more likely, it is an RPC error.
			return nil, badRPC(err)
		}
		directPeers = append(directPeers, *addr)
	}

	externalMaddr, err := multiaddr.NewMultiaddr(m.External)
	if err != nil {
		return nil, badAddr(err)
	}

	gatingConfig, err := gatingConfigFromJson(&(m.GatingConfig), app.AddedPeers)
	if err != nil {
		return nil, badRPC(err)
	}

	helper, err := codanet.MakeHelper(app.Ctx, maddrs, externalMaddr, m.Statedir, privk, m.NetworkID, seeds, gatingConfig, m.MaxConnections, m.MinaPeerExchange)
	if err != nil {
		return nil, badHelper(err)
	}

	// SOMEDAY:
	// - stop putting block content on the mesh.
	// - bigger than 32MiB block size?
	opts := []pubsub.Option{pubsub.WithMaxMessageSize(1024 * 1024 * 32),
		pubsub.WithPeerExchange(m.PeerExchange),
		pubsub.WithFloodPublish(m.Flood),
		pubsub.WithDirectPeers(directPeers),
		pubsub.WithValidateQueueSize(m.ValidationQueueSize),
	}

	var ps *pubsub.PubSub
	ps, err = pubsub.NewGossipSub(app.Ctx, helper.Host, opts...)
	if err != nil {
		return nil, badHelper(err)
	}

	helper.Pubsub = ps
	app.P2p = helper

	app.P2p.Logger.Infof("here are the seeds: %v", seeds)

	if metricsServer != nil && metricsServer.port != m.MetricsPort {
		metricsServer.Shutdown()
	}
	if len(m.MetricsPort) > 0 {
		metricsServer = startMetricsServer(m.MetricsPort)
		if !app.metricsCollectionStarted {
			go app.checkBandwidth()
			go app.checkPeerCount()
			go app.checkMessageStats()
			go app.checkLatency()
			app.metricsCollectionStarted = true
		}
	}

	return "configure success", nil
}

func (m *listenMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	ma, err := multiaddr.NewMultiaddr(m.Iface)
	if err != nil {
		return nil, badp2p(err)
	}
	if err := app.P2p.Host.Network().Listen(ma); err != nil {
		return nil, badp2p(err)
	}
	return app.P2p.Host.Addrs(), nil
}

func (m *listeningAddrsMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	return app.P2p.Host.Addrs(), nil
}

func (t *publishMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	if app.P2p.Dht == nil {
		return nil, needsDHT()
	}

	data, err := codaDecode(t.Data)
	if err != nil {
		return nil, badRPC(err)
	}

	var topic *pubsub.Topic
	var has bool

	if topic, has = app.Topics[t.Topic]; !has {
		topic, err = app.P2p.Pubsub.Join(t.Topic)
		if err != nil {
			return nil, badp2p(err)
		}
		app.Topics[t.Topic] = topic
	}

	if err := topic.Publish(app.Ctx, data); err != nil {
		return nil, badp2p(err)
	}

	return "publish success", nil
}

func (s *subscribeMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	if app.P2p.Dht == nil {
		return nil, needsDHT()
	}

	topic, err := app.P2p.Pubsub.Join(s.Topic)
	if err != nil {
		return nil, badp2p(err)
	}

	app.Topics[s.Topic] = topic

	err = app.P2p.Pubsub.RegisterTopicValidator(s.Topic, func(ctx context.Context, id peer.ID, msg *pubsub.Message) pubsub.ValidationResult {
		if id == app.P2p.Me {
			// messages from ourself are valid.
			app.P2p.Logger.Info("would have validated but it's from us!")
			return pubsub.ValidationAccept
		}

		seqno := <-seqs
		ch := make(chan string)
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

		app.writeMsg(validateUpcall{
			Sender:     sender,
			Expiration: deadline.UnixNano(),
			Data:       codaEncode(msg.Data),
			Seqno:      seqno,
			Upcall:     "validate",
			Idx:        s.Subscription,
		})

		// Wait for the validation response, but be sure to honor any timeout/deadline in ctx
		select {
		case <-ctx.Done():
			// XXX: do 🅽🅾🆃  delete app.Validators[seqno] here! the ocaml side doesn't
			// care about the timeout and will validate it anyway.
			// validationComplete will remove app.Validators[seqno] once the
			// coda process gets around to it.
			app.P2p.Logger.Error("validation timed out :(")

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
			switch res {
			case rejectResult:
				app.P2p.Logger.Info("why u fail to validate :(")
				return pubsub.ValidationReject
			case acceptResult:
				app.P2p.Logger.Info("validated!")
				return pubsub.ValidationAccept
			case ignoreResult:
				app.P2p.Logger.Info("ignoring valid message!")
				return pubsub.ValidationIgnore
			default:
				app.P2p.Logger.Info("ignoring message that falled off the end!")
				return pubsub.ValidationIgnore
			}
		}
	}, pubsub.WithValidatorTimeout(validationTimeout))

	if err != nil {
		return nil, badp2p(err)
	}

	sub, err := topic.Subscribe()
	if err != nil {
		return nil, badp2p(err)
	}

	ctx, cancel := context.WithCancel(app.Ctx)
	app.Subs[s.Subscription] = subscription{
		Sub:    sub,
		Idx:    s.Subscription,
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
	return "subscribe success", nil
}

func (u *unsubscribeMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	if sub, ok := app.Subs[u.Subscription]; ok {
		sub.Sub.Cancel()
		sub.Cancel()
		delete(app.Subs, u.Subscription)
		return "unsubscribe success", nil
	}
	return nil, badRPC(errors.New("subscription not found"))
}

func (r *validationCompleteMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	app.ValidatorMutex.Lock()
	defer app.ValidatorMutex.Unlock()
	if st, ok := app.Validators[r.Seqno]; ok {
		st.Completion <- r.Valid
		if st.TimedOutAt != nil {
			app.P2p.Logger.Errorf("validation for item %d took %d seconds", r.Seqno, time.Now().Add(validationTimeout).Sub(*st.TimedOutAt))
		}
		delete(app.Validators, r.Seqno)
		return "validationComplete success", nil
	}
	return nil, badRPC(errors.New("validation seqno unknown"))
}

func (*generateKeypairMsg) run(app *app) (interface{}, error) {
	privk, pubk, err := crypto.GenerateEd25519Key(cryptorand.Reader)
	if err != nil {
		return nil, badp2p(err)
	}
	privkBytes, err := crypto.MarshalPrivateKey(privk)
	if err != nil {
		return nil, badRPC(err)
	}

	pubkBytes, err := crypto.MarshalPublicKey(pubk)
	if err != nil {
		return nil, badRPC(err)
	}

	peerID, err := peer.IDFromPublicKey(pubk)
	if err != nil {
		return nil, badp2p(err)
	}

	return generatedKeypair{Private: codaEncode(privkBytes), Public: codaEncode(pubkBytes), PeerID: peer.Encode(peerID)}, nil
}

func handleStreamReads(app *app, stream net.Stream, idx int) {
	go func() {
		defer func() {
			_ = stream.Close()
		}()

		buf := make([]byte, 4096)
		tot := uint64(0)
		for {
			len, err := stream.Read(buf)

			if len != 0 {
				app.writeMsg(incomingMsgUpcall{
					Upcall:    "incomingStreamMsg",
					Data:      codaEncode(buf[:len]),
					StreamIdx: idx,
				})
			}

			if err != nil && err != io.EOF {
				app.writeMsg(streamLostUpcall{
					Upcall:    "streamLost",
					StreamIdx: idx,
					Reason:    fmt.Sprintf("read failure: %s", err.Error()),
				})
				break
			}

			tot += uint64(len)

			if err == io.EOF {
				app.P2p.MsgStats.UpdateMetrics(tot)
				break
			}
		}
		app.writeMsg(streamReadCompleteUpcall{
			Upcall:    "streamReadComplete",
			StreamIdx: idx,
		})
	}()
}

func (o *openStreamMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	streamIdx := <-seqs

	peer, err := peer.Decode(o.Peer)
	if err != nil {
		// TODO: this isn't necessarily an RPC error. Perhaps the encoded Peer ID
		// isn't supported by this version of libp2p.
		return nil, badRPC(err)
	}

	ctx, cancel := context.WithTimeout(app.Ctx, 30*time.Second)
	defer cancel()

	stream, err := app.P2p.Host.NewStream(ctx, peer, protocol.ID(o.ProtocolID))
	if err != nil {
		return nil, badp2p(err)
	}

	maybePeer, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())
	if err != nil {
		_ = stream.Reset()
		return nil, badp2p(err)
	}

	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	app.Streams[streamIdx] = stream
	go func() {
		// FIXME HACK: allow time for the openStreamResult to get printed before we start inserting stream events
		time.Sleep(250 * time.Millisecond)
		// Note: It is _very_ important that we call handleStreamReads here -- this is how the "caller" side of the stream starts listening to the responses from the RPCs. Do not remove.
		handleStreamReads(app, stream, streamIdx)
	}()
	return openStreamResult{StreamIdx: streamIdx, Peer: *maybePeer}, nil
}

func (cs *closeStreamMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[cs.StreamIdx]; ok {
		delete(app.Streams, cs.StreamIdx)
		err := stream.Close()
		if err != nil {
			return nil, badp2p(err)
		}
		return "closeStream success", nil
	}
	return nil, badRPC(errors.New("unknown stream_idx"))
}

func (cs *resetStreamMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[cs.StreamIdx]; ok {
		err := stream.Reset()
		delete(app.Streams, cs.StreamIdx)
		if err != nil {
			return nil, badp2p(err)
		}
		return "resetStream success", nil
	}
	return nil, badRPC(errors.New("unknown stream_idx"))
}

func (cs *sendStreamMsgMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	data, err := codaDecode(cs.Data)
	if err != nil {
		return nil, badRPC(err)
	}

	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[cs.StreamIdx]; ok {
		n, err := stream.Write(data)
		if err != nil {
			return nil, wrapError(badp2p(err), fmt.Sprintf("only wrote %d out of %d bytes", n, len(data)))
		}
		return "sendStreamMsg success", nil
	}
	return nil, badRPC(errors.New("unknown stream_idx"))
}

func (as *addStreamHandlerMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	app.P2p.Host.SetStreamHandler(protocol.ID(as.Protocol), func(stream net.Stream) {
		peerinfo, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())
		if err != nil {
			app.P2p.Logger.Errorf("failed to parse remote connection information, silently dropping stream: %s", err.Error())
			return
		}
		streamIdx := <-seqs
		app.StreamsMutex.Lock()
		defer app.StreamsMutex.Unlock()
		app.Streams[streamIdx] = stream
		app.writeMsg(incomingStreamUpcall{
			Upcall:    "incomingStream",
			Peer:      *peerinfo,
			StreamIdx: streamIdx,
			Protocol:  as.Protocol,
		})
		handleStreamReads(app, stream, streamIdx)
	})

	return "addStreamHandler success", nil
}

func (rs *removeStreamHandlerMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	app.P2p.Host.RemoveStreamHandler(protocol.ID(rs.Protocol))

	return "removeStreamHandler success", nil
}

func (ap *addPeerMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	info, err := addrInfoOfString(ap.Multiaddr)
	if err != nil {
		return nil, err
	}

	app.AddedPeers = append(app.AddedPeers, *info)
	app.P2p.GatingState.TrustedPeers.Add(info.ID)

	if app.Bootstrapper != nil {
		app.Bootstrapper.Close()
	}

	app.P2p.Logger.Error("addPeer Trying to connect to: ", info)

	if ap.Seed {
		app.P2p.Seeds = append(app.P2p.Seeds, *info)
	}

	err = app.P2p.Host.Connect(app.Ctx, *info)
	if err != nil {
		return nil, badp2p(err)
	}

	return "addPeer success", nil
}

func beginMDNS(app *app, foundPeerCh chan peerDiscovery) error {
	mdns, err := mdns.NewMdnsService(app.Ctx, app.P2p.Host, time.Minute, "_coda-discovery._udp.local")
	if err != nil {
		return err
	}
	app.P2p.Mdns = &mdns
	l := &mdnsListener{
		FoundPeer: foundPeerCh,
		app:       app,
	}
	mdns.RegisterNotifee(l)

	return nil
}

func (ap *beginAdvertisingMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	for _, info := range app.AddedPeers {
		app.P2p.Logger.Debug("Trying to connect to: ", info)
		err := app.P2p.Host.Connect(app.Ctx, info)
		if err != nil {
			app.P2p.Logger.Error("failed to connect to peer: ", info, err.Error())
			continue
		}
	}

	foundPeerCh := make(chan peerDiscovery)

	validPeer := func(who peer.ID) bool {
		return who.Validate() == nil && who != app.P2p.Me
	}

	// report discovery peers local and remote
	go func() {
		for discovery := range foundPeerCh {
			if validPeer(discovery.info.ID) {
				app.P2p.Logger.Debugf("discovered peer %v via %v; processing", discovery.info.ID, discovery.source)
				app.P2p.Host.Peerstore().AddAddrs(discovery.info.ID, discovery.info.Addrs, peerstore.ConnectedAddrTTL)

				if discovery.source == PEER_DISCOVERY_SOURCE_MDNS {
					for _, addr := range discovery.info.Addrs {
						app.P2p.GatingState.MarkPrivateAddrAsKnown(addr)
					}
				}

				// now connect to the peer we discovered
				connInfo := app.P2p.ConnectionManager.GetInfo()
				if connInfo.ConnCount < connInfo.LowWater {
					err := app.P2p.Host.Connect(app.Ctx, discovery.info)
					if err != nil {
						app.P2p.Logger.Error("failed to connect to peer after discovering it: ", discovery.info, err.Error())
						continue
					}
				}
			} else {
				app.P2p.Logger.Debugf("discovered peer %v via %v; not processing as it is not a valid peer", discovery.info.ID, discovery.source)
			}
		}
	}()

	if !app.NoMDNS {
		app.P2p.Logger.Infof("beginning mDNS discovery")
		err := beginMDNS(app, foundPeerCh)
		if err != nil {
			app.P2p.Logger.Error("failed to connect to begin mdns: ", err.Error())
			return nil, badp2p(err)
		}
	}

	if !app.NoDHT {
		app.P2p.Logger.Infof("beginning DHT discovery")
		routingDiscovery := discovery.NewRoutingDiscovery(app.P2p.Dht)
		if routingDiscovery == nil {
			return nil, errors.New("failed to create routing discovery")
		}

		app.P2p.Discovery = routingDiscovery

		err := app.P2p.Dht.Bootstrap(app.Ctx)
		if err != nil {
			app.P2p.Logger.Error("failed to dht bootstrap: ", err.Error())
			return nil, badp2p(err)
		}

		time.Sleep(time.Millisecond * 100)
		app.P2p.Logger.Debugf("beginning DHT advertising")

		_, err = routingDiscovery.Advertise(app.Ctx, app.P2p.Rendezvous)
		if err != nil {
			app.P2p.Logger.Error("failed to routing advertise: ", err.Error())
			return nil, badp2p(err)
		}

		go func() {
			peerCh, err := routingDiscovery.FindPeers(app.Ctx, app.P2p.Rendezvous)
			if err != nil {
				app.P2p.Logger.Error("error while trying to find some peers: ", err.Error())
			}

			for peer := range peerCh {
				foundPeerCh <- peerDiscovery{
					info:   peer,
					source: PEER_DISCOVERY_SOURCE_ROUTING,
				}
			}
		}()
	}

	app.P2p.ConnectionManager.OnConnect = func(net net.Network, c net.Conn) {
		app.updateConnectionMetrics()

		id := c.RemotePeer()

		app.writeMsg(peerConnectionUpcall{
			ID:     peer.Encode(id),
			Upcall: "peerConnected",
		})
	}

	app.P2p.ConnectionManager.OnDisconnect = func(net net.Network, c net.Conn) {
		app.updateConnectionMetrics()

		id := c.RemotePeer()

		app.writeMsg(peerConnectionUpcall{
			ID:     peer.Encode(id),
			Upcall: "peerDisconnected",
		})
	}

	return "beginAdvertising success", nil
}

func findPeerInfo(app *app, id peer.ID) (*codaPeerInfo, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	conns := app.P2p.Host.Network().ConnsToPeer(id)

	if len(conns) == 0 {
		if app.UnsafeNoTrustIP {
			app.P2p.Logger.Info("UnsafeNoTrustIP: pretending it's localhost")
			return &codaPeerInfo{Libp2pPort: 0, Host: "127.0.0.1", PeerID: peer.Encode(id)}, nil
		}
		return nil, badp2p(errors.New("tried to find peer info but no open connections to that peer ID"))
	}

	conn := conns[0]

	maybePeer, err := parseMultiaddrWithID(conn.RemoteMultiaddr(), conn.RemotePeer())
	if err != nil {
		return nil, err
	}
	return maybePeer, nil
}
