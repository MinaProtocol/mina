package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"math"
	"os"
	"strconv"
	"time"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	net "github.com/libp2p/go-libp2p/core/network"
	peer "github.com/libp2p/go-libp2p/core/peer"
	mdns "github.com/libp2p/go-libp2p/p2p/discovery/mdns"
	"github.com/multiformats/go-multiaddr"
	"github.com/prometheus/client_golang/prometheus"
)

func newApp() *app {
	outChan := make(chan *capnp.Message, 1<<12) // 4096 messages stacked
	ctx := context.Background()
	return &app{
		P2p:                      nil,
		Ctx:                      ctx,
		_subs:                    make(map[uint64]subscription),
		_topics:                  make(map[string]*pubsub.Topic),
		_validators:              make(map[uint64]*validationStatus),
		_streams:                 make(map[uint64]*stream),
		OutChan:                  outChan,
		Out:                      bufio.NewWriter(os.Stdout),
		_addedPeers:              []peer.AddrInfo{},
		MetricsRefreshTime:       time.Minute,
		metricsCollectionStarted: false,
		metricsServer:            nil,
		bitswapCtx:               NewBitswapCtx(ctx, outChan),
	}
}

func (app *app) SetConnectionHandlers() {
	app.setConnectionHandlersOnce.Do(func() {
		app.P2p.ConnectionManager.AddOnConnectHandler(func(net net.Network, c net.Conn) {
			app.updateConnectionMetrics()
			app.writeMsg(mkPeerConnectedUpcall(c.RemotePeer().String()))
		})
		app.P2p.ConnectionManager.AddOnDisconnectHandler(func(net net.Network, c net.Conn) {
			app.updateConnectionMetrics()
			app.writeMsg(mkPeerDisconnectedUpcall(c.RemotePeer().String()))
		})
	})
}

func (app *app) NextId() uint64 {
	app.counterMutex.Lock()
	defer app.counterMutex.Unlock()
	app.counter = app.counter + 1
	return app.counter
}

func (app *app) AddPeers(infos ...peer.AddrInfo) {
	app.addedPeersMutex.Lock()
	defer app.addedPeersMutex.Unlock()
	app._addedPeers = append(app._addedPeers, infos...)
}

// GetAddedPeers returns list of peers
//
// Elements of returned slice should never be modified!
func (app *app) GetAddedPeers() []peer.AddrInfo {
	app.addedPeersMutex.RLock()
	defer app.addedPeersMutex.RUnlock()
	return app._addedPeers
}

func (app *app) ResetAddedPeers() {
	app.addedPeersMutex.Lock()
	defer app.addedPeersMutex.Unlock()
	app._addedPeers = nil
}

func (app *app) AddStream(stream_ net.Stream) uint64 {
	streamIdx := app.NextId()
	app.streamsMutex.Lock()
	defer app.streamsMutex.Unlock()
	app._streams[streamIdx] = &stream{stream: stream_}
	return streamIdx
}

func (app *app) RemoveStream(streamId uint64) (*stream, bool) {
	app.streamsMutex.Lock()
	defer app.streamsMutex.Unlock()
	stream, ok := app._streams[streamId]
	delete(app._streams, streamId)
	return stream, ok
}

func (app *app) getStream(streamId uint64) (*stream, bool) {
	app.streamsMutex.RLock()
	defer app.streamsMutex.RUnlock()
	s, has := app._streams[streamId]
	return s, has
}

func (app *app) WriteStream(streamId uint64, data []byte) error {
	if stream, ok := app.getStream(streamId); ok {
		stream.mutex.Lock()
		defer stream.mutex.Unlock()

		if n, err := stream.stream.Write(data); err != nil {
			// TODO check that it's correct to error out, not repeat writing
			_, has := app.RemoveStream(streamId)
			if has {
				// If stream is no longer in the *app, it means it is closed or soon to be closed by
				// another goroutine
				close_err := stream.stream.Close()
				if close_err != nil {
					app.P2p.Logger.Debugf("failed to close stream %d after encountering write failure (%s): %s", streamId, err.Error(), close_err.Error())
				}
			}
			return wrapError(badp2p(err), fmt.Sprintf("only wrote %d out of %d bytes", n, len(data)))
		}
		return nil
	}
	return badRPC(errors.New("unknown stream_idx"))
}

func (app *app) AddValidator() (uint64, chan pubsub.ValidationResult) {
	seqno := app.NextId()
	ch := make(chan pubsub.ValidationResult)
	app.validatorMutex.Lock()
	defer app.validatorMutex.Unlock()
	app._validators[seqno] = new(validationStatus)
	app._validators[seqno].Completion = ch
	return seqno, ch
}

func (app *app) TimeoutValidator(seqno uint64) {
	now := time.Now()
	app.validatorMutex.Lock()
	defer app.validatorMutex.Unlock()
	app._validators[seqno].TimedOutAt = &now
}

func (app *app) RemoveValidator(seqno uint64) (*validationStatus, bool) {
	app.validatorMutex.Lock()
	defer app.validatorMutex.Unlock()
	st, ok := app._validators[seqno]
	delete(app._validators, seqno)
	return st, ok
}

func (app *app) AddTopic(topicName string, topic *pubsub.Topic) {
	app.topicsMutex.Lock()
	defer app.topicsMutex.Unlock()
	app._topics[topicName] = topic
}

func (app *app) GetTopic(topicName string) (*pubsub.Topic, bool) {
	app.topicsMutex.RLock()
	defer app.topicsMutex.RUnlock()
	topic, has := app._topics[topicName]
	return topic, has
}

func (app *app) AddSubscription(subId uint64, sub subscription) {
	app.subsMutex.Lock()
	defer app.subsMutex.Unlock()
	app._subs[subId] = sub
}

func (app *app) RemoveSubscription(subId uint64) (subscription, bool) {
	app.subsMutex.Lock()
	defer app.subsMutex.Unlock()
	sub, ok := app._subs[subId]
	delete(app._subs, subId)
	return sub, ok
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

	return &codaPeerInfo{Libp2pPort: uint16(port), Host: ipComponent.Value(), PeerID: peer.Encode(id)}, nil
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

// Writes a message back to the OCaml node
func (app *app) writeMsg(msg *capnp.Message) {
	if app.NoUpcalls {
		return
	}
	select {
	case <-app.Ctx.Done():
		app.P2p.Logger.Debug("Droping message for sending, context closed")
	case app.OutChan <- msg:
	default:
		app.P2p.Logger.Warn("Couldn't stack message for sending, blocking...")
		select {
		case <-app.Ctx.Done():
			app.P2p.Logger.Debug("Droping message for sending, context closed (unblocked)")
		case app.OutChan <- msg:
			app.P2p.Logger.Info("Stacked message, unblocked...")
		}
	}
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
		app.P2p.Logger.Debugf("couldn't register peer_count; perhaps we've already done so: %s", err)
		return
	}

	err = prometheus.Register(connectedPeerCount)
	if err != nil {
		app.P2p.Logger.Debugf("couldn't register connected_peer_count; perhaps we've already done so: %s", err)
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

func setPeerInfoList(m ipc.PeerInfo_List, peerInfos []codaPeerInfo) {
	// TODO check that it works
	for i := 0; i < len(peerInfos); i++ {
		setPeerInfo(m.At(i), &peerInfos[i])
	}
}

func setMultiaddrList(m ipc.Multiaddr_List, addrs []multiaddr.Multiaddr) {
	// TODO check that it works
	for i := 0; i < len(addrs); i++ {
		panicOnErr(m.At(i).SetRepresentation(addrs[i].String()))
	}
}

func handleStreamReads(app *app, stream net.Stream, idx uint64) {
	go func() {
		buf := make([]byte, 1<<17) // 128kb
		tot := uint64(0)
		for {
			n, err := stream.Read(buf)

			if n != 0 {
				app.writeMsg(mkStreamMessageReceivedUpcall(idx, buf[:n]))
			}

			if err != nil && err != io.EOF {
				app.writeMsg(mkStreamLostUpcall(idx, fmt.Sprintf("read failure: %s", err.Error())))
				return
			}

			tot += uint64(n)

			if err == io.EOF {
				app.P2p.MsgStats.UpdateMetrics(tot)
				break
			}
		}
		app.writeMsg(mkStreamCompleteUpcall(idx))
		err := stream.Close()
		if err != nil {
			app.P2p.Logger.Warn("Error while closing the stream: ", err.Error())
		}
	}()
}

func beginMDNS(app *app, foundPeerCh chan peerDiscovery) error {
	l := &mdnsListener{
		FoundPeer: foundPeerCh,
		app:       app,
	}
	mdns := mdns.NewMdnsService(app.P2p.Host, "_coda-discovery._udp.local", l)
	app.P2p.Mdns = mdns
	return mdns.Start()
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
