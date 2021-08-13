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

	capnp "capnproto.org/go/capnp/v3"
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
	ipc "libp2p_ipc"
)

var seqs = make(chan uint64)

func newApp() *app {
	return &app{
		P2p:                      nil,
		Ctx:                      context.Background(),
		Subs:                     make(map[uint64]subscription),
		Topics:                   make(map[string]*pubsub.Topic),
		ValidatorMutex:           &sync.Mutex{},
		Validators:               make(map[uint64]*validationStatus),
		Streams:                  make(map[uint64]net.Stream),
		OutChan:                  make(chan *capnp.Message, 64),
		Out:                      bufio.NewWriter(os.Stdout),
		AddedPeers:               []peer.AddrInfo{},
		MetricsRefreshTime:       time.Minute,
		metricsCollectionStarted: false,
		metricsServer:            nil,
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

func (app *app) writeMsg(msg *capnp.Message) {
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

const ValidationUnknown = pubsub.ValidationResult(-3)

func (app *app) handleValidation(m ipc.Libp2pHelperInterface_Validation) {
	if app.P2p == nil {
		app.P2p.Logger.Error("handleValidation: P2p not configured")
		return
	}
	seqno := m.ValidationSeqNumber()
	app.ValidatorMutex.Lock()
	defer app.ValidatorMutex.Unlock()
	if st, ok := app.Validators[seqno]; ok {
		res := ValidationUnknown
		switch m.Result() {
		case ipc.ValidationResult_accept:
			res = pubsub.ValidationAccept
		case ipc.ValidationResult_reject:
			res = pubsub.ValidationReject
		case ipc.ValidationResult_ignore:
			res = pubsub.ValidationIgnore
		default:
			app.P2p.Logger.Warningf("handleValidation: unknown validation result %d", m.Result())
		}
		st.Completion <- res
		if st.TimedOutAt != nil {
			app.P2p.Logger.Errorf("validation for item %d took %d seconds", seqno, time.Now().Add(validationTimeout).Sub(*st.TimedOutAt))
		}
		delete(app.Validators, seqno)
	}
	app.P2p.Logger.Warningf("handleValidation: validation seqno %d unknown", seqno)
}

func (app *app) handleFindPeer(seqno uint64, m ipc.Libp2pHelperInterface_FindPeer_Request) *capnp.Message {
	pid, err := m.PeerId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	peerId, err := pid.Id()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	id, err := peer.Decode(peerId)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	peerInfo, err := findPeerInfo(app, id)

	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		r, err := m.NewFindPeer()
		panicOnErr(err)
		res, err := r.NewResult()
		panicOnErr(err)
		setPeerInfo(res, peerInfo)
	})
}

func (app *app) handleSetNodeStatus(seqno uint64, m ipc.Libp2pHelperInterface_SetNodeStatus_Request) *capnp.Message {
	status, err := m.Status()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.P2p.NodeStatus = status
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewSetNodeStatus()
		panicOnErr(err)
	})
}

func (app *app) handleGetPeerNodeStatus(seqno uint64, m ipc.Libp2pHelperInterface_GetPeerNodeStatus_Request) *capnp.Message {
	ctx, _ := context.WithTimeout(app.Ctx, codanet.NodeStatusTimeout)
	pma, err := m.Peer()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	pmaRepr, err := pma.Representation()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	addrInfo, err := addrInfoOfString(pmaRepr)
	if err != nil {
		return mkRpcRespError(seqno, err)
	}
	app.P2p.Host.Peerstore().AddAddrs(addrInfo.ID, addrInfo.Addrs, peerstore.ConnectedAddrTTL)

	// Open a "get node status" stream on m.PeerID,
	// block until you can read the response, return that.
	s, err := app.P2p.Host.NewStream(ctx, addrInfo.ID, codanet.NodeStatusProtocolID)
	if err != nil {
		app.P2p.Logger.Error("failed to open stream: ", err)
		return mkRpcRespError(seqno, err)
	}

	defer func() {
		_ = s.Close()
	}()

	errCh := make(chan error)
	responseCh := make(chan []byte)

	go func() {
		// 1 megabyte
		size := 1048576

		data := make([]byte, size)
		n, err := s.Read(data)
		// TODO will the whole status be read or we can "accidentally" read only
		// part of it?
		if err != nil && err != io.EOF {
			app.P2p.Logger.Errorf("failed to decode node status data: err=%s", err)
			errCh <- err
			return
		}

		if n == size && err == nil {
			errCh <- fmt.Errorf("node status data was greater than %d bytes", size)
			return
		}

		responseCh <- data[:n]
	}()

	select {
	case <-ctx.Done():
		s.Reset()
		err := errors.New("timed out requesting node status data from peer")
		return mkRpcRespError(seqno, err)
	case err := <-errCh:
		return mkRpcRespError(seqno, err)
	case response := <-responseCh:
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			r, err := m.NewGetPeerNodeStatus()
			panicOnErr(err)
			r.SetResult(response)
		})
	}
}

func (app *app) handleListPeers(seqno uint64, m ipc.Libp2pHelperInterface_ListPeers_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
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

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		r, err := m.NewListPeers()
		panicOnErr(err)
		lst, err := r.NewResult(int32(len(peerInfos)))
		panicOnErr(err)
		setPeerInfoList(lst, peerInfos)
	})
}

func (app *app) handleSetGatingConfig(seqno uint64, m ipc.Libp2pHelperInterface_SetGatingConfig_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	gc, err := m.GatingConfig()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	newState, err := readGatingConfig(gc, app.AddedPeers)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	app.P2p.GatingState = newState

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewSetGatingConfig()
		panicOnErr(err)
	})
}

func (app *app) handleConfigure(seqno uint64, msg ipc.Libp2pHelperInterface_Configure_Request) *capnp.Message {
	m, err := msg.Config()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.UnsafeNoTrustIP = m.UnsafeNoTrustIp()
	listenOnMaList, err := m.ListenOn()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	listenOn := make([]multiaddr.Multiaddr, 0, listenOnMaList.Len())
	err = multiaddrListForeach(listenOnMaList, func(v string) error {
		res, err := multiaddr.NewMultiaddr(v)
		if err == nil {
			listenOn = append(listenOn, res)
		}
		return err
	})
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	seedPeersMaList, err := m.SeedPeers()
	seeds := make([]peer.AddrInfo, 0, seedPeersMaList.Len())
	err = multiaddrListForeach(seedPeersMaList, func(v string) error {
		addr, err := addrInfoOfString(v)
		if err == nil {
			seeds = append(seeds, *addr)
		}
		return err
	})
	// TODO: this isn't necessarily an RPC error. Perhaps the encoded multiaddr
	// isn't supported by this version of libp2p.
	// But more likely, it is an RPC error.
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	app.AddedPeers = append(app.AddedPeers, seeds...)

	directPeersMaList, err := m.DirectPeers()
	directPeers := make([]peer.AddrInfo, 0, directPeersMaList.Len())
	err = multiaddrListForeach(directPeersMaList, func(v string) error {
		addr, err := addrInfoOfString(v)
		if err == nil {
			directPeers = append(directPeers, *addr)
		}
		return err
	})
	// TODO: this isn't necessarily an RPC error. Perhaps the encoded multiaddr
	// isn't supported by this version of libp2p.
	// But more likely, it is an RPC error.
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	externalMa, err := m.ExternalMultiaddr()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	externalMaRepr, err := externalMa.Representation()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	externalMaddr, err := multiaddr.NewMultiaddr(externalMaRepr)
	if err != nil {
		return mkRpcRespError(seqno, badAddr(err))
	}

	gc, err := m.GatingConfig()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	gatingConfig, err := readGatingConfig(gc, app.AddedPeers)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	stateDir, err := m.Statedir()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	netId, err := m.NetworkId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	privkBytes, err := m.PrivateKey()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	privk, err := crypto.UnmarshalPrivateKey(privkBytes)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	helper, err := codanet.MakeHelper(app.Ctx, listenOn, externalMaddr, stateDir, privk, netId, seeds, gatingConfig, int(m.MaxConnections()), m.MinaPeerExchange())
	if err != nil {
		return mkRpcRespError(seqno, badHelper(err))
	}

	// SOMEDAY:
	// - stop putting block content on the mesh.
	// - bigger than 32MiB block size?
	opts := []pubsub.Option{pubsub.WithMaxMessageSize(1024 * 1024 * 32),
		pubsub.WithPeerExchange(m.PeerExchange()),
		pubsub.WithFloodPublish(m.Flood()),
		pubsub.WithDirectPeers(directPeers),
		pubsub.WithValidateQueueSize(int(m.ValidationQueueSize())),
	}

	var ps *pubsub.PubSub
	ps, err = pubsub.NewGossipSub(app.Ctx, helper.Host, opts...)
	if err != nil {
		return mkRpcRespError(seqno, badHelper(err))
	}

	helper.Pubsub = ps
	app.P2p = helper

	app.P2p.Logger.Infof("here are the seeds: %v", seeds)

	metricsServer := app.metricsServer
	if metricsServer != nil && metricsServer.port != m.MetricsPort() {
		metricsServer.Shutdown()
	}
	if m.MetricsPort() > 0 {
		metricsServer = startMetricsServer(m.MetricsPort())
		if !app.metricsCollectionStarted {
			go app.checkBandwidth()
			go app.checkPeerCount()
			go app.checkMessageStats()
			go app.checkLatency()
			app.metricsCollectionStarted = true
		}
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewConfigure()
		panicOnErr(err)
	})
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

func (app *app) handleListen(seqno uint64, m ipc.Libp2pHelperInterface_Listen_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	iface, err := m.Iface()
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}
	ma, err := multiaddr.NewMultiaddr(iface)
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}
	if err := app.P2p.Host.Network().Listen(ma); err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}
	addrs := app.P2p.Host.Addrs()
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		r, err := m.NewListen()
		panicOnErr(err)
		lst, err := r.NewResult(int32(len(addrs)))
		panicOnErr(err)
		setMultiaddrList(lst, addrs)
	})
}

func (app *app) handleGetListeningAddrs(seqno uint64, m ipc.Libp2pHelperInterface_GetListeningAddrs_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	addrs := app.P2p.Host.Addrs()
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		r, err := m.NewGetListeningAddrs()
		panicOnErr(err)
		lst, err := r.NewResult(int32(len(addrs)))
		panicOnErr(err)
		setMultiaddrList(lst, addrs)
	})
}

func (app *app) handlePublish(seqno uint64, m ipc.Libp2pHelperInterface_Publish_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	if app.P2p.Dht == nil {
		return mkRpcRespError(seqno, needsDHT())
	}

	var topic *pubsub.Topic
	var has bool

	topicName, err := m.Topic()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	data, err := m.Data()
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

func (app *app) handleSubscribe(seqno uint64, m ipc.Libp2pHelperInterface_Subscribe_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	if app.P2p.Dht == nil {
		return mkRpcRespError(seqno, needsDHT())
	}

	topicName, err := m.Topic()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	subId_, err := m.SubscriptionId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	subId := subId_.Id()

	topic, err := app.P2p.Pubsub.Join(topicName)
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	app.Topics[topicName] = topic

	err = app.P2p.Pubsub.RegisterTopicValidator(topicName, func(ctx context.Context, id peer.ID, msg *pubsub.Message) pubsub.ValidationResult {
		if id == app.P2p.Me {
			// messages from ourself are valid.
			app.P2p.Logger.Info("would have validated but it's from us!")
			return pubsub.ValidationAccept
		}

		seenAt := time.Now()

		seqno := <-seqs
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
		app.writeMsg(mkValidateUpcall(sender, deadline, seenAt, msg.Data, seqno, subId))

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

func (app *app) handleUnsubscribe(seqno uint64, m ipc.Libp2pHelperInterface_Unsubscribe_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	subId_, err := m.SubscriptionId()
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

func (app *app) handleGenerateKeypair(seqno uint64, m ipc.Libp2pHelperInterface_GenerateKeypair_Request) *capnp.Message {
	privk, pubk, err := crypto.GenerateEd25519Key(cryptorand.Reader)
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}
	privkBytes, err := crypto.MarshalPrivateKey(privk)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	pubkBytes, err := crypto.MarshalPublicKey(pubk)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	peerID, err := peer.IDFromPublicKey(pubk)
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		resp, err := m.NewGenerateKeypair()
		panicOnErr(err)
		res, err := resp.NewResult()
		panicOnErr(err)
		panicOnErr(res.SetPrivateKey(privkBytes))
		panicOnErr(res.SetPublicKey(pubkBytes))
		pid, err := res.NewPeerId()
		panicOnErr(pid.SetId(peer.Encode(peerID)))
	})
}

func handleStreamReads(app *app, stream net.Stream, idx uint64) {
	go func() {
		defer func() {
			_ = stream.Close()
		}()

		buf := make([]byte, 4096)
		tot := uint64(0)
		for {
			len, err := stream.Read(buf)

			if len != 0 {
				app.writeMsg(mkIncomingMsgUpcall(idx, buf[:len]))
			}

			if err != nil && err != io.EOF {
				app.writeMsg(mkStreamLostUpcall(idx, fmt.Sprintf("read failure: %s", err.Error())))
				break
			}

			tot += uint64(len)

			if err == io.EOF {
				app.P2p.MsgStats.UpdateMetrics(tot)
				break
			}
		}
		app.writeMsg(mkStreamReadCompleteUpcall(idx))
	}()
}

func (app *app) handleOpenStream(seqno uint64, m ipc.Libp2pHelperInterface_OpenStream_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}

	streamIdx := <-seqs

	peerStr, err := m.Peer()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	peerDecoded, err := peer.Decode(peerStr)
	if err != nil {
		// TODO: this isn't necessarily an RPC error. Perhaps the encoded Peer ID
		// isn't supported by this version of libp2p.
		return mkRpcRespError(seqno, badRPC(err))
	}

	ctx, cancel := context.WithTimeout(app.Ctx, 30*time.Second)
	defer cancel()

	protocolId, err := m.ProtocolId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	stream, err := app.P2p.Host.NewStream(ctx, peerDecoded, protocol.ID(protocolId))
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	peer, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())
	if err != nil {
		_ = stream.Reset()
		return mkRpcRespError(seqno, badp2p(err))
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
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		resp, err := m.NewOpenStream()
		panicOnErr(err)
		sid, err := resp.NewStreamId()
		panicOnErr(err)
		sid.SetId(streamIdx)
		pi, err := resp.NewPeer()
		panicOnErr(err)
		setPeerInfo(pi, peer)
	})
}

func (app *app) handleCloseStream(seqno uint64, m ipc.Libp2pHelperInterface_CloseStream_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	sid, err := m.StreamId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	streamId := sid.Id()
	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[streamId]; ok {
		delete(app.Streams, streamId)
		err := stream.Close()
		if err != nil {
			return mkRpcRespError(seqno, badp2p(err))
		}
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			_, err := m.NewCloseStream()
			panicOnErr(err)
		})
	}
	return mkRpcRespError(seqno, badRPC(errors.New("unknown stream_idx")))
}

func (app *app) handleResetStream(seqno uint64, m ipc.Libp2pHelperInterface_ResetStream_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	sid, err := m.StreamId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	streamId := sid.Id()
	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[streamId]; ok {
		err := stream.Reset()
		delete(app.Streams, streamId)
		if err != nil {
			return mkRpcRespError(seqno, badp2p(err))
		}
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			_, err := m.NewResetStream()
			panicOnErr(err)
		})
	}
	return mkRpcRespError(seqno, badRPC(errors.New("unknown stream_idx")))
}

func (app *app) handleSendStream(seqno uint64, m ipc.Libp2pHelperInterface_SendStream_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	msg, err := m.Msg()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	data, err := msg.Data()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	sid, err := msg.StreamId()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	streamId := sid.Id()

	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[streamId]; ok {
		n, err := stream.Write(data)
		if err != nil {
			// TODO check that it's correct to error out, not repeat writing
			return mkRpcRespError(seqno, wrapError(badp2p(err), fmt.Sprintf("only wrote %d out of %d bytes", n, len(data))))
		}
		return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
			_, err := m.NewSendStream()
			panicOnErr(err)
		})
	}
	return mkRpcRespError(seqno, badRPC(errors.New("unknown stream_idx")))
}

func (app *app) handleAddStreamHandler(seqno uint64, m ipc.Libp2pHelperInterface_AddStreamHandler_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	protocolId, err := m.Protocol()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.P2p.Host.SetStreamHandler(protocol.ID(protocolId), func(stream net.Stream) {
		peerinfo, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())
		if err != nil {
			app.P2p.Logger.Errorf("failed to parse remote connection information, silently dropping stream: %s", err.Error())
			return
		}
		streamIdx := <-seqs
		app.StreamsMutex.Lock()
		defer app.StreamsMutex.Unlock()
		app.Streams[streamIdx] = stream
		app.writeMsg(mkIncomingStreamUpcall(peerinfo, streamIdx, protocolId))
		handleStreamReads(app, stream, streamIdx)
	})

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewAddStreamHandler()
		panicOnErr(err)
	})
}

func (app *app) handleRemoveStreamHandler(seqno uint64, m ipc.Libp2pHelperInterface_RemoveStreamHandler_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	protocolId, err := m.Protocol()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.P2p.Host.RemoveStreamHandler(protocol.ID(protocolId))

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewRemoveStreamHandler()
		panicOnErr(err)
	})
}

func (app *app) handleAddPeer(seqno uint64, m ipc.Libp2pHelperInterface_AddPeer_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}

	maddr, err := m.Multiaddr()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	maRepr, err := maddr.Representation()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	info, err := addrInfoOfString(maRepr)
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	app.AddedPeers = append(app.AddedPeers, *info)
	app.P2p.GatingState.TrustedPeers.Add(info.ID)

	if app.Bootstrapper != nil {
		app.Bootstrapper.Close()
	}

	app.P2p.Logger.Info("addPeer Trying to connect to: ", info)

	if m.IsSeed() {
		app.P2p.Seeds = append(app.P2p.Seeds, *info)
	}

	err = app.P2p.Host.Connect(app.Ctx, *info)
	if err != nil {
		return mkRpcRespError(seqno, badp2p(err))
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewAddPeer()
		panicOnErr(err)
	})
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

func (app *app) handleBeginAdvertising(seqno uint64, m ipc.Libp2pHelperInterface_BeginAdvertising_Request) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
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
			return mkRpcRespError(seqno, badp2p(err))
		}
	}

	if !app.NoDHT {
		app.P2p.Logger.Infof("beginning DHT discovery")
		routingDiscovery := discovery.NewRoutingDiscovery(app.P2p.Dht)
		if routingDiscovery == nil {
			err := errors.New("failed to create routing discovery")
			return mkRpcRespError(seqno, err)
		}

		app.P2p.Discovery = routingDiscovery

		err := app.P2p.Dht.Bootstrap(app.Ctx)
		if err != nil {
			app.P2p.Logger.Error("failed to dht bootstrap: ", err.Error())
			return mkRpcRespError(seqno, badp2p(err))
		}

		time.Sleep(time.Millisecond * 100)
		app.P2p.Logger.Debugf("beginning DHT advertising")

		_, err = routingDiscovery.Advertise(app.Ctx, app.P2p.Rendezvous)
		if err != nil {
			app.P2p.Logger.Error("failed to routing advertise: ", err.Error())
			return mkRpcRespError(seqno, badp2p(err))
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

		app.writeMsg(mkPeerDisconnectedUpcall(peer.Encode(id)))
	}

	app.P2p.ConnectionManager.OnDisconnect = func(net net.Network, c net.Conn) {
		app.updateConnectionMetrics()

		id := c.RemotePeer()

		app.writeMsg(mkPeerConnectedUpcall(peer.Encode(id)))
	}

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewBeginAdvertising()
		panicOnErr(err)
	})
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

func (app *app) handleIncomingMsg(msg *ipc.Libp2pHelperInterface_Message) {
	if msg.HasRpcRequest() {
		req, err := msg.RpcRequest()
		panicOnErr(err)
		h, err := req.Header()
		panicOnErr(err)
		seqno := h.SeqNumber()
		var resp *capnp.Message
		if req.HasConfigure() {
			r, err := req.Configure()
			panicOnErr(err)
			resp = app.handleConfigure(seqno, r)
		} else if req.HasSetGatingConfig() {
			r, err := req.SetGatingConfig()
			panicOnErr(err)
			resp = app.handleSetGatingConfig(seqno, r)
		} else if req.HasListen() {
			r, err := req.Listen()
			panicOnErr(err)
			resp = app.handleListen(seqno, r)
		} else if req.HasGetListeningAddrs() {
			r, err := req.GetListeningAddrs()
			panicOnErr(err)
			resp = app.handleGetListeningAddrs(seqno, r)
		} else if req.HasBeginAdvertising() {
			r, err := req.BeginAdvertising()
			panicOnErr(err)
			resp = app.handleBeginAdvertising(seqno, r)
		} else if req.HasAddPeer() {
			r, err := req.AddPeer()
			panicOnErr(err)
			resp = app.handleAddPeer(seqno, r)
		} else if req.HasListPeers() {
			r, err := req.ListPeers()
			panicOnErr(err)
			resp = app.handleListPeers(seqno, r)
		} else if req.HasGenerateKeypair() {
			r, err := req.GenerateKeypair()
			panicOnErr(err)
			resp = app.handleGenerateKeypair(seqno, r)
		} else if req.HasPublish() {
			r, err := req.Publish()
			panicOnErr(err)
			resp = app.handlePublish(seqno, r)
		} else if req.HasSubscribe() {
			r, err := req.Subscribe()
			panicOnErr(err)
			resp = app.handleSubscribe(seqno, r)
		} else if req.HasUnsubscribe() {
			r, err := req.Unsubscribe()
			panicOnErr(err)
			resp = app.handleUnsubscribe(seqno, r)
		} else if req.HasAddStreamHandler() {
			r, err := req.AddStreamHandler()
			panicOnErr(err)
			resp = app.handleAddStreamHandler(seqno, r)
		} else if req.HasRemoveStreamHandler() {
			r, err := req.RemoveStreamHandler()
			panicOnErr(err)
			resp = app.handleRemoveStreamHandler(seqno, r)
		} else if req.HasOpenStream() {
			r, err := req.OpenStream()
			panicOnErr(err)
			resp = app.handleOpenStream(seqno, r)
		} else if req.HasCloseStream() {
			r, err := req.CloseStream()
			panicOnErr(err)
			resp = app.handleCloseStream(seqno, r)
		} else if req.HasResetStream() {
			r, err := req.ResetStream()
			panicOnErr(err)
			resp = app.handleResetStream(seqno, r)
		} else if req.HasSendStream() {
			r, err := req.SendStream()
			panicOnErr(err)
			resp = app.handleSendStream(seqno, r)
		} else if req.HasSetNodeStatus() {
			r, err := req.SetNodeStatus()
			panicOnErr(err)
			resp = app.handleSetNodeStatus(seqno, r)
		} else if req.HasGetPeerNodeStatus() {
			r, err := req.GetPeerNodeStatus()
			panicOnErr(err)
			resp = app.handleGetPeerNodeStatus(seqno, r)
		} else {
			app.P2p.Logger.Error("Received rpc message of an unknown type")
			return
		}
		if resp == nil {
			app.P2p.Logger.Error("Failed to process rpc message")
		} else {
			app.writeMsg(resp)
		}
	} else if msg.HasPushMessage() {
		req, err := msg.PushMessage()
		panicOnErr(err)
		h, err := req.Header()
		panicOnErr(err)
		_ = h
		if req.HasValidation() {
			r, err := req.Validation()
			panicOnErr(err)
			app.handleValidation(r)
		} else {
			app.P2p.Logger.Error("Received push message of an unknown type")
		}
	} else {
		app.P2p.Logger.Error("Received message of an unknown type")
	}
}
