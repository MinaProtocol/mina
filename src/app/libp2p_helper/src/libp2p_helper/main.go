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
	"os"
	"sync"
	"time"

	mdns "github.com/libp2p/go-libp2p/p2p/discovery"

	"github.com/go-errors/errors"
	logging "github.com/ipfs/go-log"
	logwriter "github.com/ipfs/go-log/writer"
	crypto "github.com/libp2p/go-libp2p-core/crypto"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	"github.com/libp2p/go-libp2p-core/peerstore"
	protocol "github.com/libp2p/go-libp2p-core/protocol"
	discovery "github.com/libp2p/go-libp2p-discovery"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	b58 "github.com/mr-tron/base58/base58"
	"github.com/multiformats/go-multiaddr"
	logging2 "github.com/whyrusleeping/go-logging"
)

type subscription struct {
	Sub    *pubsub.Subscription
	Idx    int
	Ctx    context.Context
	Cancel context.CancelFunc
}

type app struct {
	P2p        *codanet.Helper
	Ctx        context.Context
	Subs       map[int]subscription
	Validators map[int]chan bool
	Streams    map[int]net.Stream
	OutLock    sync.Mutex
	Out        *bufio.Writer
	RpcLock    sync.Mutex
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
)

type envelope struct {
	Method methodIdx   `json:"method"`
	Seqno  int         `json:"seqno"`
	Body   interface{} `json:"body"`
}

func (app *app) writeMsg(msg interface{}) {
	app.OutLock.Lock()
	defer app.OutLock.Unlock()
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

type configureMsg struct {
	Statedir  string   `json:"statedir"`
	Privk     string   `json:"privk"`
	NetworkID string   `json:"network_id"`
	ListenOn  []string `json:"ifaces"`
	External  string   `json:"external_maddr"`
}

type discoveredPeerUpcall struct {
	ID     string   `json:"peer_id"`
	Addrs  []string `json:"multiaddrs"`
	Upcall string   `json:"upcall"`
}

func (m *configureMsg) run(app *app) (interface{}, error) {
	privkBytes, err := b58.Decode(m.Privk)
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

	data, err := b58.Decode(t.Data)
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
	Upcall       string `json:"upcall"`
	Subscription int    `json:"subscription_idx"`
	Data         string `json:"data"`
}

func (s *subscribeMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	if app.P2p.Dht == nil {
		return nil, needsDHT()
	}
	err := app.P2p.Pubsub.RegisterTopicValidator(s.Topic, func(ctx context.Context, id peer.ID, msg *pubsub.Message) bool {
		seqno := <-seqs
		ch := make(chan bool)
		app.Validators[seqno] = ch
		app.writeMsg(validateUpcall{
			PeerID: id.Pretty(),
			Data:   b58.Encode(msg.Data),
			Seqno:  seqno,
			Upcall: "validate",
			Idx:    s.Subscription,
		})

		// Wait for the validation response, but be sure to honor any timeout/deadline in ctx
		select {
		case <-ctx.Done():
			// do NOT delete app.Validators[seqno] here! the ocaml side doesn't
			// care about the timeout and will validate it anyway.
			// validationComplete will remove app.Validators[seqno] once the
			// coda process gets around to it.
			return false
		case res := <-ch:
			return res
		}
	}, pubsub.WithValidatorConcurrency(1), pubsub.WithValidatorTimeout(5*time.Second))

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
				data := b58.Encode(msg.Data)
				app.writeMsg(publishUpcall{
					Upcall:       "publish",
					Subscription: s.Subscription,
					Data:         data,
				})
			} else {
				if ctx.Err() != context.Canceled {
					log.Print("sub.Next failed: ", err)
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
		return "unsubscribe success", nil
	}
	return nil, badRPC(errors.New("subscription not found"))
}

type validateUpcall struct {
	PeerID string `json:"peer_id"`
	Data   string `json:"data"`
	Seqno  int    `json:"seqno"`
	Upcall string `json:"upcall"`
	Idx    int    `json:"subscription_idx"`
}

type validationCompleteMsg struct {
	Seqno int  `json:"seqno"`
	Valid bool `json:"is_valid"`
}

func (r *validationCompleteMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	if ch, ok := app.Validators[r.Seqno]; ok {
		ch <- r.Valid
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

	return generatedKeypair{Private: b58.Encode(privkBytes), Public: b58.Encode(pubkBytes), PeerID: peer.IDB58Encode(peerID)}, nil
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
					Data:      b58.Encode(buf[:len]),
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
	StreamIdx    int    `json:"stream_idx"`
	RemoteAddr   string `json:"remote_addr"`
	RemotePeerID string `json:"remote_peerid"`
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

	app.Streams[streamIdx] = stream
	go func() {
		// FIXME HACK: allow time for the openStreamResult to get printed before we start inserting stream events
		time.Sleep(250 * time.Millisecond)
		handleStreamReads(app, stream, streamIdx)
	}()
	return openStreamResult{StreamIdx: streamIdx, RemoteAddr: stream.Conn().RemoteMultiaddr().String(), RemotePeerID: stream.Conn().RemotePeer().String()}, nil
}

type closeStreamMsg struct {
	StreamIdx int `json:"stream_idx"`
}

func (cs *closeStreamMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
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
	if stream, ok := app.Streams[cs.StreamIdx]; ok {
		err := stream.Reset()
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
	data, err := b58.Decode(cs.Data)
	if err != nil {
		return nil, badRPC(err)
	}

	if stream, ok := app.Streams[cs.StreamIdx]; ok {
		_, err := stream.Write(data)
		if err != nil {
			return nil, badp2p(err)
		}
		return "sendStreamMsg success", nil
	}
	return nil, badRPC(errors.New("unknown stream_idx"))
}

type addStreamHandlerMsg struct {
	Protocol string `json:"protocol"`
}

type incomingStreamUpcall struct {
	Upcall       string `json:"upcall"`
	RemoteAddr   string `json:"remote_addr"`
	RemotePeerID string `json:"remote_peerid"`
	StreamIdx    int    `json:"stream_idx"`
	Protocol     string `json:"protocol"`
}

func (as *addStreamHandlerMsg) run(app *app) (interface{}, error) {
	if app.P2p == nil {
		return nil, needsConfigure()
	}
	app.P2p.Host.SetStreamHandler(protocol.ID(as.Protocol), func(stream net.Stream) {
		streamIdx := <-seqs
		app.Streams[streamIdx] = stream
		app.writeMsg(incomingStreamUpcall{
			Upcall:       "incomingStream",
			RemoteAddr:   stream.Conn().RemoteMultiaddr().String(),
			RemotePeerID: stream.Conn().RemotePeer().String(),
			StreamIdx:    streamIdx,
			Protocol:     as.Protocol,
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

	// discovery should notice the connection event and do the dht thing
	err = app.P2p.Host.Connect(app.Ctx, *info)

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

	foundPeer := func(info peer.AddrInfo, source string) {
		if info.ID != "" && len(info.Addrs) != 0 {
			ctx, cancel := context.WithTimeout(app.Ctx, 15*time.Second)
			defer cancel()
			if err := app.P2p.Host.Connect(ctx, info); err != nil {
				app.P2p.Logger.Warning("couldn't connect to %s peer %v (maybe the network ID mismatched?): %v", source, info.Loggable(), err)
			} else {
				app.P2p.Logger.Info("Found a %s peer: %s", source, info.Loggable())
				app.P2p.Host.Peerstore().AddAddrs(info.ID, info.Addrs, peerstore.ConnectedAddrTTL)
				addrStrings := make([]string, len(info.Addrs))
				for i, a := range info.Addrs {
					addrStrings[i] = a.String()
				}
				app.writeMsg(discoveredPeerUpcall{
					ID:     peer.IDB58Encode(info.ID),
					Addrs:  addrStrings,
					Upcall: "discoveredPeer",
				})
			}
		}
	}

	// report local discovery peers
	go func() {
		for info := range l.FoundPeer {
			foundPeer(info, "local")
		}
	}()

	// report dht peers
	go func() {
		for {
			// default is to yield only 100 peers at a time. for now, always be
			// looking... TODO: Is there a better way to use discovery? Should we only
			// have to explicitly search once at startup?
			dhtpeers, err := routingDiscovery.FindPeers(app.Ctx, app.P2p.Rendezvous)
			if err != nil {
				app.P2p.Logger.Error("failed to find DHT peers: ", err)
			}
			for info := range dhtpeers {
				foundPeer(info, "dht")
			}
			time.Sleep(5 * time.Minute)
		}
	}()

	if err := app.P2p.Dht.Bootstrap(app.Ctx); err != nil {
		return nil, badp2p(err)
	}

	discovery.Advertise(app.Ctx, routingDiscovery, app.P2p.Rendezvous)

	return "beginAdvertising success", nil
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
}

type errorResult struct {
	Seqno  int    `json:"seqno"`
	Errorr string `json:"error"`
}

type successResult struct {
	Seqno   int             `json:"seqno"`
	Success json.RawMessage `json:"success"`
}

func main() {
	logwriter.Configure(logwriter.Output(os.Stderr), logwriter.LdJSONFormatter)
	log.SetOutput(os.Stderr)
	logging.SetAllLoggers(logging2.INFO)
	helperLog := logging.Logger("helper top-level JSON handling")

	go func() {
		i := 0
		for {
			seqs <- i
			i++
		}
	}()

	lines := bufio.NewScanner(os.Stdin)
	out := bufio.NewWriter(os.Stdout)

	app := &app{
		P2p:        nil,
		Ctx:        context.Background(),
		Subs:       make(map[int]subscription),
		Validators: make(map[int]chan bool),
		Streams:    make(map[int]net.Stream),
		// OutLock doesn't need to be initialized
		Out: out,
		// RpcLock doesn't need to be initialized
	}

	for lines.Scan() {
		line := lines.Text()
		var raw json.RawMessage
		env := envelope{
			Body: &raw,
		}
		if err := json.Unmarshal([]byte(line), &env); err != nil {
			log.Print("when unmarshaling the envelope...")
			log.Fatal(err)
		}
		msg := msgHandlers[env.Method]()
		if err := json.Unmarshal(raw, msg); err != nil {
			log.Print("when unmarshaling the method invocation...")
			log.Fatal(err)
		}
		defer func() {
			if r := recover(); r != nil {
				helperLog.Error("While handling RPC:", line, "\nThe following panic occurred: ", r)
			}
		}()
		res, err := msg.run(app)
		if err == nil {
			res, err := json.Marshal(res)
			if err == nil {
				app.writeMsg(successResult{Seqno: env.Seqno, Success: res})
			} else {
				app.writeMsg(errorResult{Seqno: env.Seqno, Errorr: err.Error()})
			}
		} else {
			app.writeMsg(errorResult{Seqno: env.Seqno, Errorr: err.Error()})
		}
	}
	os.Exit(0)
}

var _ json.Marshaler = (*methodIdx)(nil)
