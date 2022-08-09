package main

import (
	cryptorand "crypto/rand"
	"fmt"
	gonet "net"
	"sync"
	"time"

	"codanet"

	ipc "libp2p_ipc"

	capnp "capnproto.org/go/capnp/v3"
	"github.com/go-errors/errors"
	crypto "github.com/libp2p/go-libp2p-core/crypto"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	peerstore "github.com/libp2p/go-libp2p-core/peerstore"
	discovery "github.com/libp2p/go-libp2p-discovery"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	pb "github.com/libp2p/go-libp2p-pubsub/pb"
	"github.com/multiformats/go-multiaddr"
)

type BeginAdvertisingReqT = ipc.Libp2pHelperInterface_BeginAdvertising_Request
type BeginAdvertisingReq BeginAdvertisingReqT

func fromBeginAdvertisingReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.BeginAdvertising()
	return BeginAdvertisingReq(i), err
}
func (msg BeginAdvertisingReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	app.SetConnectionHandlers()
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
						app.P2p.GatingState().MarkPrivateAddrAsKnown(addr)
					}
				}

				// now connect to the peer we discovered
				connInfo := app.P2p.ConnectionManager.GetInfo()
				if connInfo.ConnCount < connInfo.LowWater {
					err := app.P2p.Host.Connect(app.Ctx, discovery.info)
					if err != nil {
						app.P2p.Logger.Errorf("failed to connect to peer after discovering it: ", discovery.info, err.Error())
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
			return mkRpcRespError(seqno, badp2p(err))
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

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewBeginAdvertising()
		panicOnErr(err)
	})
}

func configurePubsub(app *app, validationQueueSize int, directPeers []peer.AddrInfo, topicLevel topicLevelConf, opts ...pubsub.Option) error {
	if len(topicLevel) > 0 {
		f := &leveledSubscriptionFilter{
			topicLevel: topicLevel,
			peerLevel:  make(map[peer.ID]int),
			localPeer:  app.P2p.Me,
		}
		opts = append(opts, pubsub.WithSubscriptionFilter(f))
		app.P2p.ConnectionManager.AddOnDisconnectHandler(func(net net.Network, c net.Conn) {
			f.OnDisconnect(c.RemotePeer())
		})
	}

	// SOMEDAY:
	// - stop putting block content on the mesh.
	// - bigger than 32MiB block size?
	ps, err := pubsub.NewGossipSub(app.Ctx, app.P2p.Host,
		append([]pubsub.Option{
			pubsub.WithMaxMessageSize(1024 * 1024 * 32),
			pubsub.WithDirectPeers(directPeers),
			pubsub.WithValidateQueueSize(validationQueueSize),
		}, opts...)...,
	)
	app.P2p.Pubsub = ps
	return err
}

func readTopicLevels(lst ipc.TopicLevel_List) (topicLevelConf, error) {
	res := make(topicLevelConf)
	for i := 0; i < lst.Len(); i++ {
		tl := lst.At(i)
		topics, err := tl.Topics()
		if err != nil {
			return nil, err
		}
		for j := 0; j < topics.Len(); j++ {
			topic, err := topics.At(j)
			if err != nil {
				return nil, err
			}
			l, has := res[topic]
			if has {
				if i == l.maxLevel+1 {
					res[topic] = topicLevelEntry{
						minLevel: l.minLevel,
						maxLevel: i,
					}
				} else {
					return nil, fmt.Errorf("duplicate topic on level %d: %s (minL: %d, maxL: %d)", i, topic, l.minLevel, l.maxLevel)
				}
			} else {
				res[topic] = topicLevelEntry{minLevel: i, maxLevel: i}
			}
		}
	}
	return res, nil
}

type topicLevelConf map[string]topicLevelEntry

type topicLevelEntry struct {
	minLevel int
	maxLevel int
}

// leveledSubscriptionFilter is a filter that takes topic level parameter
// which lists topics for each level.
// Then, for each peer we monitor topics being used and discard
// subscriptions from topics of lower level than the max level
// observed for the node.
// Filter keeps a record per each connected node that subscribed to some topic,
// and cleans up the record when the node disconnects.
type leveledSubscriptionFilter struct {
	topicLevel topicLevelConf
	peerLevel  map[peer.ID]int
	lock       sync.RWMutex
	localPeer  peer.ID
}

func (f *leveledSubscriptionFilter) CanSubscribe(topic string) bool {
	_, has := f.topicLevel[topic]
	return has
}
func (f *leveledSubscriptionFilter) FilterIncomingSubscriptions(pid peer.ID, subs []*pb.RPC_SubOpts) ([]*pb.RPC_SubOpts, error) {
	f.lock.RLock()
	pl, hasPl := f.peerLevel[pid]
	f.lock.RUnlock()
	initHasPl := hasPl
	peerLevel := pl
	for _, sub := range subs {
		l, hasL := f.topicLevel[sub.GetTopicid()]
		if !hasL {
			continue
		}
		if !hasPl || pl < l.minLevel {
			hasPl = true
			pl = l.minLevel
		}
	}
	if !hasPl {
		// all subs are irrelevant
		return nil, nil
	}
	if !initHasPl || peerLevel < pl {
		f.lock.Lock()
		peerLevel, initHasPl = f.peerLevel[pid]
		if !initHasPl || peerLevel < pl {
			f.peerLevel[pid] = pl
			peerLevel = pl
		}
		f.lock.Unlock()
	}
	res := pubsub.FilterSubscriptions(subs, func(topic string) bool {
		l, hasL := f.topicLevel[topic]
		return hasL && l.minLevel <= peerLevel && peerLevel <= l.maxLevel
	})
	// Uncomment lines below to debug the filter
	// initTopics := make([]string, 0, len(subs))
	// resTopics := make([]string, 0, len(res))
	// for _, sub := range subs {
	// 	initTopics = append(initTopics, fmt.Sprintf("%s:%v", sub.GetTopicid(), sub.GetSubscribe()))
	// }
	// for _, sub := range res {
	// 	resTopics = append(resTopics, fmt.Sprintf("%s:%v", sub.GetTopicid(), sub.GetSubscribe()))
	// }
	// fmt.Printf("%s subscribes to %s: {%s} -> {%s}\n", pid.Pretty(), f.localPeer.Pretty(), strings.Join(initTopics, ", "), strings.Join(resTopics, ", "))
	return res, nil
}

func (f *leveledSubscriptionFilter) OnDisconnect(p peer.ID) {
	f.lock.RLock()
	_, has := f.peerLevel[p]
	f.lock.RUnlock()
	if has {
		f.lock.Lock()
		delete(f.peerLevel, p)
		f.lock.Unlock()
	}
}

type ConfigureReqT = ipc.Libp2pHelperInterface_Configure_Request
type ConfigureReq ConfigureReqT

func fromConfigureReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.Configure()
	return ConfigureReq(i), err
}
func (msg ConfigureReq) handle(app *app, seqno uint64) *capnp.Message {
	m, err := ConfigureReqT(msg).Config()
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
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
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
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
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
	var topicLevel topicLevelConf
	if m.HasTopicConfig() {
		tc, err := m.TopicConfig()
		if err == nil {
			topicLevel, err = readTopicLevels(tc)
		}
		if err != nil {
			return mkRpcRespError(seqno, badRPC(err))
		}
	}

	knownPrivateIpNetsRaw, err := m.KnownPrivateIpNets()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	knownPrivateIpNets := make([]gonet.IPNet, 0, knownPrivateIpNetsRaw.Len())
	err = textListForeach(knownPrivateIpNetsRaw, func(v string) error {
		_, addr, err := gonet.ParseCIDR(v)
		if err == nil {
			knownPrivateIpNets = append(knownPrivateIpNets, *addr)
		}
		return err
	})
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	helper, err := codanet.MakeHelper(
		app.Ctx,
		listenOn,
		externalMaddr,
		stateDir,
		privk,
		netId,
		seeds,
		gatingConfig,
		int(m.MinConnections()),
		int(m.MaxConnections()),
		m.MinaPeerExchange(),
		time.Second*15,
		knownPrivateIpNets,
	)
	if err != nil {
		return mkRpcRespError(seqno, badHelper(err))
	}

	app.P2p = helper
	app.bitswapCtx.engine = helper.Bitswap
	app.bitswapCtx.storage = helper.BitswapStorage

	opts := []pubsub.Option{
		pubsub.WithFloodPublish(m.Flood()),
		pubsub.WithPeerExchange(m.PeerExchange()),
	}

	err = configurePubsub(app, int(m.ValidationQueueSize()), directPeers, topicLevel, opts...)

	if err != nil {
		return mkRpcRespError(seqno, badHelper(err))
	}

	app.P2p.Logger.Infof("here are the seeds: %v", seeds)

	metricsServer := app.metricsServer
	if metricsServer != nil && metricsServer.port != m.MetricsPort() {
		metricsServer.Shutdown()
	}
	if m.MetricsPort() > 0 {
		app.metricsServer = startMetricsServer(m.MetricsPort())
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

type GetListeningAddrsReq ipc.Libp2pHelperInterface_GetListeningAddrs_Request

func fromGetListeningAddrsReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.GetListeningAddrs()
	return GetListeningAddrsReq(i), err
}
func (msg GetListeningAddrsReq) handle(app *app, seqno uint64) *capnp.Message {
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

type GenerateKeypairReqT = ipc.Libp2pHelperInterface_GenerateKeypair_Request
type GenerateKeypairReq GenerateKeypairReqT

func fromGenerateKeypairReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.GenerateKeypair()
	return GenerateKeypairReq(i), err
}
func (msg GenerateKeypairReq) handle(app *app, seqno uint64) *capnp.Message {
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
		panicOnErr(err)
		panicOnErr(pid.SetId(peer.Encode(peerID)))
	})
}

type ListenReqT = ipc.Libp2pHelperInterface_Listen_Request
type ListenReq ListenReqT

func fromListenReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.Listen()
	return ListenReq(i), err
}
func (m ListenReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	ma, err := func() (multiaddr.Multiaddr, error) {
		iface, err := ListenReqT(m).Iface()
		if err != nil {
			return nil, err
		}
		ifaceRepr, err := iface.Representation()
		if err != nil {
			return nil, err
		}
		return multiaddr.NewMultiaddr(ifaceRepr)
	}()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
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

type SetGatingConfigReqT = ipc.Libp2pHelperInterface_SetGatingConfig_Request
type SetGatingConfigReq SetGatingConfigReqT

func fromSetGatingConfigReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.SetGatingConfig()
	return SetGatingConfigReq(i), err
}
func (m SetGatingConfigReq) handle(app *app, seqno uint64) *capnp.Message {
	if app.P2p == nil {
		return mkRpcRespError(seqno, needsConfigure())
	}
	var gatingConfig *codanet.CodaGatingConfig
	gc, err := SetGatingConfigReqT(m).GatingConfig()
	if err == nil {
		gatingConfig, err = readGatingConfig(gc, app.AddedPeers)
	}
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}

	app.P2p.SetGatingState(gatingConfig)

	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewSetGatingConfig()
		panicOnErr(err)
	})
}

type SetNodeStatusReqT = ipc.Libp2pHelperInterface_SetNodeStatus_Request
type SetNodeStatusReq SetNodeStatusReqT

func fromSetNodeStatusReq(req ipcRpcRequest) (rpcRequest, error) {
	i, err := req.SetNodeStatus()
	return SetNodeStatusReq(i), err
}
func (m SetNodeStatusReq) handle(app *app, seqno uint64) *capnp.Message {
	status, err := SetNodeStatusReqT(m).Status()
	if err != nil {
		return mkRpcRespError(seqno, badRPC(err))
	}
	app.P2p.NodeStatus = status
	return mkRpcRespSuccess(seqno, func(m *ipc.Libp2pHelperInterface_RpcResponseSuccess) {
		_, err := m.NewSetNodeStatus()
		panicOnErr(err)
	})
}
