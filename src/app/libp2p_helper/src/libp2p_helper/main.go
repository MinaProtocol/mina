package main

import (
	"bufio"
	"codanet"
	"context"
	cryptorand "crypto/rand"
	"encoding/json"
	"fmt"
	"io"
	"log"
	gonet "net"
	"os"
	"runtime/debug"
	"strconv"
	"sync"
	"time"

	"encoding/base64"

	"github.com/go-errors/errors"
	"github.com/ipfs/go-ipfs/core/bootstrap"
	logging "github.com/ipfs/go-log/v2"
	crypto "github.com/libp2p/go-libp2p-core/crypto"
	"github.com/libp2p/go-libp2p-core/event"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	protocol "github.com/libp2p/go-libp2p-core/protocol"
	"github.com/libp2p/go-libp2p-discovery"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	mdns "github.com/libp2p/go-libp2p/p2p/discovery"
	filter "github.com/libp2p/go-maddr-filter"
	"github.com/multiformats/go-multiaddr"
)

type subscription struct {
	Sub    *pubsub.Subscription
	Idx    int
	Ctx    context.Context
	Cancel context.CancelFunc
}

type validationStatus struct {
	Completion chan bool
	TimedOutAt *time.Time
}

type app struct {
	P2p             *codanet.Helper
	Ctx             context.Context
	Subs            map[int]subscription
	Validators      map[int]*validationStatus
	ValidatorMutex  *sync.Mutex
	Streams         map[int]net.Stream
	StreamsMutex    sync.Mutex
	Out             *bufio.Writer
	OutChan         chan interface{}
	Bootstrapper    io.Closer
	AddedPeers      []peer.AddrInfo
	UnsafeNoTrustIP bool
}

var seqs = make(chan int)

type methodIdx int

const (
	// when editing this block, see the README for how to update methodidx_jsonenum
	configure methodIdx = iota
	listen
	publish
	subscribe
	unsubscribe
	validationComplete
	generateKeypair
	openStream
	closeStream
	resetStream
	sendStreamMsg
	removeStreamHandler
	addStreamHandler
	listeningAddrs
	addPeer
	beginAdvertising
	findPeer
	listPeers
	banIP
	unbanIP
)

const validationTimeout = 5 * time.Minute

type codaPeerInfo struct {
	Libp2pPort int    `json:"libp2p_port"`
	Host       string `json:"host"`
	PeerID     string `json:"peer_id"`
}

type envelope struct {
	Method methodIdx   `json:"method"`
	Seqno  int         `json:"seqno"`
	Body   interface{} `json:"body"`
}

func (app *app) writeMsg(msg interface{}) {
	app.OutChan <- msg
}

type action interface {
	run(app *app) (interface{}, error)
}

// TODO: wrap these in a new type, encode them differently in the rpc mainloop

type wrappedError struct {
	e   error
	tag string
}

func (w wrappedError) Error() string {
	return fmt.Sprintf("%s error: %s", w.tag, w.e.Error())
}

func wrapError(e error, tag string) error { return wrappedError{e: e, tag: tag} }

func badRPC(e error) error {
	return wrapError(e, "internal RPC error")
}

func badp2p(e error) error {
	return wrapError(e, "libp2p error")
}

func badHelper(e error) error {
	return wrapError(e, "initializing helper")
}

func badAddr(e error) error {
	return wrapError(e, "initializing external addr")
}

func needsConfigure() error {
	return badRPC(errors.New("helper not yet configured"))
}

func needsDHT() error {
	return badRPC(errors.New("helper not yet joined to pubsub"))
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

	return &codaPeerInfo{Libp2pPort: port, Host: ipComponent.Value(), PeerID: peer.IDB58Encode(id)}, nil
}

func findPeerInfo(app *app, id peer.ID) (*codaPeerInfo, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	conns := app.P2p.Host.Network().ConnsToPeer(id)

	if len(conns) == 0 {
		if app.UnsafeNoTrustIP {
			app.P2p.Logger.Info("UnsafeNoTrustIP: pretending it's localhost")
			return &codaPeerInfo{Libp2pPort: 0, Host: "127.0.0.1", PeerID: peer.IDB58Encode(id)}, nil
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

type configureMsg struct {
	Statedir        string   `json:"statedir"`
	Privk           string   `json:"privk"`
	NetworkID       string   `json:"network_id"`
	ListenOn        []string `json:"ifaces"`
	External        string   `json:"external_maddr"`
	UnsafeNoTrustIP bool     `json:"unsafe_no_trust_ip"`
	GossipType      string   `json:"gossip_type"`
}

type discoveredPeerUpcall struct {
	ID     string   `json:"peer_id"`
	Addrs  []string `json:"multiaddrs"`
	Upcall string   `json:"upcall"`
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

	externalMaddr, err := multiaddr.NewMultiaddr(m.External)
	if err != nil {
		return nil, badAddr(err)
	}
	helper, err := codanet.MakeHelper(app.Ctx, maddrs, externalMaddr, m.Statedir, privk, m.NetworkID)
	if err != nil {
		return nil, badHelper(err)
	}

	// SOMEDAY:
	// - stop putting block content on the mesh.
	// - bigger than 16MiB block size?
	opts := pubsub.WithMaxMessageSize(1024 * 1024 * 16)
	var ps *pubsub.PubSub
	if m.GossipType == "gossipsub" {
		ps, err = pubsub.NewGossipSub(app.Ctx, helper.Host, opts)
	} else if m.GossipType == "flood" {
		ps, err = pubsub.NewFloodSub(app.Ctx, helper.Host, opts)
	} else if m.GossipType == "random" {
		// networks of size 100 aren't very large, but we shouldn't be using randomsub!
		ps, err = pubsub.NewRandomSub(app.Ctx, helper.Host, 10, opts)
	} else {
		return nil, badHelper(errors.New("unknown gossip type"))
	}

	if err != nil {
		return nil, badHelper(err)
	}

	helper.Pubsub = ps
	app.P2p = helper

	return "configure success", nil
}

type listenMsg struct {
	Iface string `json:"iface"`
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

type listeningAddrsMsg struct {
}

func (m *listeningAddrsMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	return app.P2p.Host.Addrs(), nil
}

type publishMsg struct {
	Topic string `json:"topic"`
	Data  string `json:"data"`
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
	if err := app.P2p.Pubsub.Publish(t.Topic, data); err != nil {
		return nil, badp2p(err)
	}
	return "publish success", nil
}

type subscribeMsg struct {
	Topic        string `json:"topic"`
	Subscription int    `json:"subscription_idx"`
}

type publishUpcall struct {
	Upcall       string        `json:"upcall"`
	Subscription int           `json:"subscription_idx"`
	Data         string        `json:"data"`
	Sender       *codaPeerInfo `json:"sender"`
}

// we use base64 for encoding blobs in our JSON protocol. there are more
// efficient options but this one is easy to reach to.

func codaEncode(data []byte) string {
	return base64.StdEncoding.EncodeToString(data)
}

func codaDecode(data string) ([]byte, error) {
	return base64.StdEncoding.DecodeString(data)
}

func (s *subscribeMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	if app.P2p.Dht == nil {
		return nil, needsDHT()
	}
	app.P2p.Pubsub.Join(s.Topic)
	err := app.P2p.Pubsub.RegisterTopicValidator(s.Topic, func(ctx context.Context, id peer.ID, msg *pubsub.Message) bool {
		if id == app.P2p.Me {
			// messages from ourself are valid.
			app.P2p.Logger.Info("would have validated but it's from us!")
			return true
		}

		seqno := <-seqs
		ch := make(chan bool, 1)
		app.ValidatorMutex.Lock()
		app.Validators[seqno] = new(validationStatus)
		(*app.Validators[seqno]).Completion = ch
		app.ValidatorMutex.Unlock()

		app.P2p.Logger.Info("validating a new pubsub message ...")

		sender, err := findPeerInfo(app, id)

		if err != nil && !app.UnsafeNoTrustIP {
			app.P2p.Logger.Errorf("failed to connect to peer %s that just sent us a pubsub message, dropping it", peer.IDB58Encode(id))
			app.ValidatorMutex.Lock()
			defer app.ValidatorMutex.Unlock()
			delete(app.Validators, seqno)
			return false
		}

		app.writeMsg(validateUpcall{
			Sender: sender,
			Data:   codaEncode(msg.Data),
			Seqno:  seqno,
			Upcall: "validate",
			Idx:    s.Subscription,
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

			(*app.Validators[seqno]).TimedOutAt = new(time.Time)
			*((*app.Validators[seqno]).TimedOutAt) = time.Now()

			app.ValidatorMutex.Unlock()

			if app.UnsafeNoTrustIP {
				app.P2p.Logger.Info("validated anyway!")
				return true
			}
			app.P2p.Logger.Info("unvalidated :(")
			return false
		case res := <-ch:
			if !res {
				app.P2p.Logger.Info("why u fail to validate :(")
			} else {
				app.P2p.Logger.Info("validated!")
			}
			return res
		}
	}, pubsub.WithValidatorTimeout(validationTimeout))

	if err != nil {
		return nil, badp2p(err)
	}

	sub, err := app.P2p.Pubsub.Subscribe(s.Topic)
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
			msg, err := sub.Next(ctx)
			if err == nil {
				// sender, err := findPeerInfo(app, msg.ReceivedFrom)
				if err != nil && !app.UnsafeNoTrustIP {
					app.P2p.Logger.Errorf("failed to connect to peer %s that just sent us an already-validated pubsub message, dropping it", peer.IDB58Encode(msg.ReceivedFrom))
				} else {
					/* Don't bother informing the helper about this message; it ignores it
										   and we don't want to block here or else we might lose messages
					            data := codaEncode(msg.Data)
					            app.writeMsg(publishUpcall{
					              Upcall:       "publish",
					              Subscription: s.Subscription,
					              Data:         data,
					              Sender:       sender,
					            })
					*/
				}
			} else {
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

type unsubscribeMsg struct {
	Subscription int `json:"subscription_idx"`
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

type validateUpcall struct {
	Sender *codaPeerInfo `json:"sender"`
	Data   string        `json:"data"`
	Seqno  int           `json:"seqno"`
	Upcall string        `json:"upcall"`
	Idx    int           `json:"subscription_idx"`
}

type validationCompleteMsg struct {
	Seqno int  `json:"seqno"`
	Valid bool `json:"is_valid"`
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

type generateKeypairMsg struct {
}

type generatedKeypair struct {
	Private string `json:"sk"`
	Public  string `json:"pk"`
	PeerID  string `json:"peer_id"`
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

	return generatedKeypair{Private: codaEncode(privkBytes), Public: codaEncode(pubkBytes), PeerID: peer.IDB58Encode(peerID)}, nil
}

type streamLostUpcall struct {
	Upcall    string `json:"upcall"`
	StreamIdx int    `json:"stream_idx"`
	Reason    string `json:"reason"`
}

type streamReadCompleteUpcall struct {
	Upcall    string `json:"upcall"`
	StreamIdx int    `json:"stream_idx"`
}

type openStreamMsg struct {
	Peer       string `json:"peer"`
	ProtocolID string `json:"protocol"`
}

type incomingMsgUpcall struct {
	Upcall    string `json:"upcall"`
	StreamIdx int    `json:"stream_idx"`
	Data      string `json:"data"`
}

func handleStreamReads(app *app, stream net.Stream, idx int) {
	go func() {
		buf := make([]byte, 4096)
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

			if err == io.EOF {
				break
			}
		}
		app.writeMsg(streamReadCompleteUpcall{
			Upcall:    "streamReadComplete",
			StreamIdx: idx,
		})
	}()
}

type openStreamResult struct {
	StreamIdx int          `json:"stream_idx"`
	Peer      codaPeerInfo `json:"peer"`
}

func (o *openStreamMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	streamIdx := <-seqs
	peer, err := peer.IDB58Decode(o.Peer)
	if err != nil {
		// TODO: this isn't necessarily an RPC error. Perhaps the encoded Peer ID
		// isn't supported by this version of libp2p.
		return nil, badRPC(err)
	}

	stream, err := app.P2p.Host.NewStream(app.Ctx, peer, protocol.ID(o.ProtocolID))

	if err != nil {
		return nil, badp2p(err)
	}

	maybePeer, err := parseMultiaddrWithID(stream.Conn().RemoteMultiaddr(), stream.Conn().RemotePeer())

	if err != nil {
		stream.Reset()
		return nil, badp2p(err)
	}

	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	app.Streams[streamIdx] = stream
	go func() {
		// FIXME HACK: allow time for the openStreamResult to get printed before we start inserting stream events
		time.Sleep(250 * time.Millisecond)
		handleStreamReads(app, stream, streamIdx)
	}()
	return openStreamResult{StreamIdx: streamIdx, Peer: *maybePeer}, nil
}

type closeStreamMsg struct {
	StreamIdx int `json:"stream_idx"`
}

func (cs *closeStreamMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	app.StreamsMutex.Lock()
	defer app.StreamsMutex.Unlock()
	if stream, ok := app.Streams[cs.StreamIdx]; ok {
		err := stream.Close()
		if err != nil {
			return nil, badp2p(err)
		}
		return "closeStream success", nil
	}
	return nil, badRPC(errors.New("unknown stream_idx"))
}

type resetStreamMsg struct {
	StreamIdx int `json:"stream_idx"`
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

type sendStreamMsgMsg struct {
	StreamIdx int    `json:"stream_idx"`
	Data      string `json:"data"`
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

type addStreamHandlerMsg struct {
	Protocol string `json:"protocol"`
}

type incomingStreamUpcall struct {
	Upcall    string       `json:"upcall"`
	Peer      codaPeerInfo `json:"peer"`
	StreamIdx int          `json:"stream_idx"`
	Protocol  string       `json:"protocol"`
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

type removeStreamHandlerMsg struct {
	Protocol string `json:"protocol"`
}

func (rs *removeStreamHandlerMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	app.P2p.Host.RemoveStreamHandler(protocol.ID(rs.Protocol))

	return "removeStreamHandler success", nil
}

type addPeerMsg struct {
	Multiaddr string `json:"multiaddr"`
}

func (ap *addPeerMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	multiaddr, err := multiaddr.NewMultiaddr(ap.Multiaddr)
	if err != nil {
		// TODO: this isn't necessarily an RPC error. Perhaps the encoded multiaddr
		// isn't supported by this version of libp2p.
		// But more likely, it is an RPC error.
		return nil, badRPC(err)
	}
	info, err := peer.AddrInfoFromP2pAddr(multiaddr)
	if err != nil {
		// TODO: this isn't necessarily an RPC error. Perhaps the contained peer ID
		// isn't supported by this version of libp2p.
		// But more likely, it is an RPC error.
		return nil, badRPC(err)
	}

	app.AddedPeers = append(app.AddedPeers, *info)
	if app.Bootstrapper != nil {
		app.Bootstrapper.Close()
	}
	app.Bootstrapper, err = bootstrap.Bootstrap(app.P2p.Me, app.P2p.Host, app.P2p.Dht, bootstrap.BootstrapConfigWithPeers(app.AddedPeers))

	if err != nil {
		return nil, badp2p(err)
	}

	return "addPeer success", nil
}

type beginAdvertisingMsg struct {
}

type mdnsListener struct {
	FoundPeer chan peer.AddrInfo
}

func (l *mdnsListener) HandlePeerFound(info peer.AddrInfo) {
	l.FoundPeer <- info
}

func (ap *beginAdvertisingMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	mdns, err := mdns.NewMdnsService(app.Ctx, app.P2p.Host, time.Minute, "_coda-discovery._udp.local")
	if err != nil {
		return nil, err
	}
	app.P2p.Mdns = &mdns
	l := &mdnsListener{FoundPeer: make(chan peer.AddrInfo)}
	mdns.RegisterNotifee(l)

	routingDiscovery := discovery.NewRoutingDiscovery(app.P2p.Dht)

	if routingDiscovery == nil {
		return nil, errors.New("failed to create routing discovery")
	}

	app.P2p.Discovery = routingDiscovery

	discovered := make(chan peer.AddrInfo)
	app.P2p.DiscoveredPeers = discovered

	foundPeer := func(who peer.ID) {
		addrs := app.P2p.Host.Peerstore().Addrs(who)
		addrStrings := make([]string, len(addrs))
		for i, a := range addrs {
			addrStrings[i] = a.String()
		}

		app.writeMsg(discoveredPeerUpcall{
			ID:     peer.IDB58Encode(who),
			Addrs:  addrStrings,
			Upcall: "discoveredPeer",
		})
	}

	app.Bootstrapper, err = bootstrap.Bootstrap(app.P2p.Me, app.P2p.Host, app.P2p.Dht, bootstrap.BootstrapConfigWithPeers(app.AddedPeers))
	if err != nil {
		return nil, badp2p(err)
	}

	// report local discovery peers
	go func() {
		for info := range l.FoundPeer {
			foundPeer(info.ID)
		}
	}()

	discovery.Advertise(app.Ctx, routingDiscovery, app.P2p.Rendezvous)

	bus := app.P2p.Host.EventBus()
	// report new peers we find peers
	go func() {
		sub, err := bus.Subscribe(new(event.EvtPeerConnectednessChanged))
		if err != nil {
			panic(err)
		}

		for evt := range sub.Out() {
			e := evt.(event.EvtPeerConnectednessChanged)
			foundPeer(e.Peer)
		}
	}()

	return "beginAdvertising success", nil
}

type findPeerMsg struct {
	PeerID string `json:"peer_id"`
}

func (ap *findPeerMsg) run(app *app) (interface{}, error) {
	id, err := peer.IDB58Decode(ap.PeerID)
	if err != nil {
		return nil, err
	}

	maybePeer, err := findPeerInfo(app, id)

	if err != nil {
		return nil, err
	}

	return *maybePeer, nil
}

type listPeersMsg struct {
}

func (lp *listPeersMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	connsHere := app.P2p.Host.Network().Conns()

	peerInfos := make([]codaPeerInfo, len(connsHere))

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

type banIPMsg struct {
	IP string `json:"ip"`
}

func (ban *banIPMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	ip := gonet.ParseIP(ban.IP).To4()

	if ip == nil {
		// TODO: how to compute mask for IPv6?
		return nil, badRPC(errors.New("unparsable IP or IPv6"))
	}

	ipnet := gonet.IPNet{Mask: gonet.IPv4Mask(255, 255, 255, 255), IP: ip}

	currentAction, isFromRule := app.P2p.Filters.ActionForFilter(ipnet)

	app.P2p.Filters.AddFilter(ipnet, filter.ActionDeny)

	if currentAction == filter.ActionDeny && isFromRule {
		return "banIP already banned", nil
	}
	return "banIP success", nil
}

type unbanIPMsg struct {
	IP string `json:"ip"`
}

func (unban *unbanIPMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}

	ip := gonet.ParseIP(unban.IP).To4()

	if ip == nil {
		// TODO: how to compute mask for IPv6?
		return nil, badRPC(errors.New("unparsable IP or IPv6"))
	}

	ipnet := gonet.IPNet{Mask: gonet.IPv4Mask(255, 255, 255, 255), IP: ip}

	currentAction, isFromRule := app.P2p.Filters.ActionForFilter(ipnet)

	if !isFromRule || currentAction == filter.ActionAccept {
		return "unbanIP not banned", nil
	}

	app.P2p.Filters.RemoveLiteral(ipnet)

	return "unbanIP success", nil
}

var msgHandlers = map[methodIdx]func() action{
	configure:           func() action { return &configureMsg{} },
	listen:              func() action { return &listenMsg{} },
	publish:             func() action { return &publishMsg{} },
	subscribe:           func() action { return &subscribeMsg{} },
	unsubscribe:         func() action { return &unsubscribeMsg{} },
	validationComplete:  func() action { return &validationCompleteMsg{} },
	generateKeypair:     func() action { return &generateKeypairMsg{} },
	openStream:          func() action { return &openStreamMsg{} },
	closeStream:         func() action { return &closeStreamMsg{} },
	resetStream:         func() action { return &resetStreamMsg{} },
	sendStreamMsg:       func() action { return &sendStreamMsgMsg{} },
	removeStreamHandler: func() action { return &removeStreamHandlerMsg{} },
	addStreamHandler:    func() action { return &addStreamHandlerMsg{} },
	listeningAddrs:      func() action { return &listeningAddrsMsg{} },
	addPeer:             func() action { return &addPeerMsg{} },
	beginAdvertising:    func() action { return &beginAdvertisingMsg{} },
	findPeer:            func() action { return &findPeerMsg{} },
	listPeers:           func() action { return &listPeersMsg{} },
	banIP:               func() action { return &banIPMsg{} },
	unbanIP:             func() action { return &unbanIPMsg{} },
}

type errorResult struct {
	Seqno  int    `json:"seqno"`
	Errorr string `json:"error"`
}

type successResult struct {
	Seqno    int             `json:"seqno"`
	Success  json.RawMessage `json:"success"`
	Duration string          `json:"duration"`
}

func main() {
	logging.SetupLogging(logging.Config{
		Format: logging.JSONOutput,
		Stderr: true,
		Stdout: false,
		Level:  logging.LevelInfo,
		File:   "",
	})
	helperLog := logging.Logger("helper top-level JSON handling")

	go func() {
		i := 0
		for {
			seqs <- i
			i++
		}
	}()

	lines := bufio.NewScanner(os.Stdin)
	// 22MiB buffer size, larger than the 21.33MB minimum for 16MiB to be b64'd
	// 4 * (2^24/3) / 2^20 = 21.33
	bufsize := (1024 * 1024) * 22
	lines.Buffer(make([]byte, bufsize), bufsize)
	out := bufio.NewWriter(os.Stdout)

	app := &app{
		P2p:            nil,
		Ctx:            context.Background(),
		Subs:           make(map[int]subscription),
		ValidatorMutex: &sync.Mutex{},
		Validators:     make(map[int]*validationStatus),
		Streams:        make(map[int]net.Stream),
		OutChan:        make(chan interface{}, 4096),
		Out:            out,
		AddedPeers:     make([]peer.AddrInfo, 512),
	}

	go func() {
		for {
			msg := <-app.OutChan
			bytes, err := json.Marshal(msg)
			if err == nil {
				n, err := app.Out.Write(bytes)
				if err != nil {
					panic(err)
				}
				if n != len(bytes) {
					// TODO: handle this correctly.
					panic("short write :(")
				}
				app.Out.WriteByte(0x0a)
				if err := app.Out.Flush(); err != nil {
					panic(err)
				}
			} else {
				panic(err)
			}
		}
	}()

	var line string

	defer func() {
		if r := recover(); r != nil {
			helperLog.Error("While handling RPC:", line, "\nThe following panic occurred: ", r, "\nstack:\n", string(debug.Stack()))
		}
	}()

	for lines.Scan() {
		line = lines.Text()
		var raw json.RawMessage
		env := envelope{
			Body: &raw,
		}
		if err := json.Unmarshal([]byte(line), &env); err != nil {
			log.Print("when unmarshaling the envelope...")
			log.Panic(err)
		}
		msg := msgHandlers[env.Method]()
		if err := json.Unmarshal(raw, msg); err != nil {
			log.Print("when unmarshaling the method invocation...")
			log.Panic(err)
		}
		start := time.Now()
		res, err := msg.run(app)
		if err == nil {
			res, err := json.Marshal(res)
			if err == nil {
				app.writeMsg(successResult{Seqno: env.Seqno, Success: res, Duration: time.Now().Sub(start).String()})
			} else {
				app.writeMsg(errorResult{Seqno: env.Seqno, Errorr: err.Error()})
			}
		} else {
			app.writeMsg(errorResult{Seqno: env.Seqno, Errorr: err.Error()})
		}
	}
	app.writeMsg(errorResult{Seqno: 0, Errorr: fmt.Sprintf("helper stdin scanning stopped because %v", lines.Err())})
	// we never want the helper to get here, it should be killed or gracefully
	// shut down instead of stdin closed.
	os.Exit(1)
}

var _ json.Marshaler = (*methodIdx)(nil)
