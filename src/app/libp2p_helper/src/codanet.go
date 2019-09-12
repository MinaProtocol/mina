package codanet

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"os"
	"path"
	"strconv"
	"time"

	dsb "github.com/ipfs/go-ds-badger"
	logging "github.com/ipfs/go-log"
	p2p "github.com/libp2p/go-libp2p"
	crypto "github.com/libp2p/go-libp2p-core/crypto"
	host "github.com/libp2p/go-libp2p-core/host"
	"github.com/libp2p/go-libp2p-core/peer"
	"github.com/libp2p/go-libp2p-core/peerstore"
	routing "github.com/libp2p/go-libp2p-core/routing"
	discovery "github.com/libp2p/go-libp2p-discovery"
	kad "github.com/libp2p/go-libp2p-kad-dht"
	kadopts "github.com/libp2p/go-libp2p-kad-dht/opts"
	"github.com/libp2p/go-libp2p-peerstore/pstoreds"
	pnet "github.com/libp2p/go-libp2p-pnet"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	record "github.com/libp2p/go-libp2p-record"
	secio "github.com/libp2p/go-libp2p-secio"
	p2pconfig "github.com/libp2p/go-libp2p/config"
	mdns "github.com/libp2p/go-libp2p/p2p/discovery"
	tcp "github.com/libp2p/go-tcp-transport"
	ws "github.com/libp2p/go-ws-transport"
	"github.com/multiformats/go-multiaddr"
	"golang.org/x/crypto/blake2b"
)

// Helper contains all the daemon state
type Helper struct {
	Host            host.Host
	Mdns            mdns.Service
	Dht             *kad.IpfsDHT
	Ctx             context.Context
	Pubsub          *pubsub.PubSub
	Logger          logging.EventLogger
	DiscoveredPeers chan peer.AddrInfo
	Rendezvous      string
	Discovery       *discovery.RoutingDiscovery
}

type mdnsListener struct {
	FoundPeer chan peer.AddrInfo
}

func (l *mdnsListener) HandlePeerFound(info peer.AddrInfo) {
	l.FoundPeer <- info
}

type customValidator struct {
	Base record.Validator
}

func (cv customValidator) Validate(key string, value []byte) error {
	log.Printf("DHT Validating: %s = %s", key, value)
	return cv.Base.Validate(key, value)
}

func (cv customValidator) Select(key string, values [][]byte) (int, error) {
	log.Printf("DHT Selecting Among: %s = %s", key, bytes.Join(values, []byte("; ")))
	return cv.Base.Select(key, values)
}

// MakeHelper does all the initialization to run one host
func MakeHelper(ctx context.Context, listenOn []multiaddr.Multiaddr, statedir string, pk crypto.PrivKey, networkID string) (*Helper, error) {
	logger := logging.Logger("codanet.Helper")
	dso := dsb.DefaultOptions

	bp := path.Join(statedir, strconv.Itoa(os.Getpid()))
	os.MkdirAll(bp, 0700)

	ds, err := dsb.NewDatastore(path.Join(statedir, strconv.Itoa(os.Getpid()), "libp2p-peerstore-v0"), &dso)
	if err != nil {
		return nil, err
	}

	dsoDht := dsb.DefaultOptions
	dsDht, err := dsb.NewDatastore(path.Join(statedir, strconv.Itoa(os.Getpid()), "libp2p-dht-v0"), &dsoDht)
	if err != nil {
		return nil, err
	}

	ps, err := pstoreds.NewPeerstore(ctx, ds, pstoreds.DefaultOpts())
	if err != nil {
		return nil, err
	}

	rendezvousString := fmt.Sprintf("/coda/0.0.1/%s", networkID)

	pnetKey := blake2b.Sum256([]byte(rendezvousString))
	prot, err := pnet.NewV1ProtectorFromBytes(&pnetKey)
	if err != nil {
		return nil, err
	}

	rv := customValidator{Base: record.NamespacedValidator{"pk": record.PublicKeyValidator{}}}

	// gross hack to exfiltrate a channel from the side effect of option evaluation
	kadch := make(chan *kad.IpfsDHT)

	// Make sure this doesn't get too out of sync with the defaults,
	// NewWithoutDefaults is considered unstable.
	host, err := p2p.NewWithoutDefaults(ctx,
		p2p.Transport(tcp.NewTCPTransport),
		p2p.Transport(ws.New),
		p2p.Muxer("/mplex/6.7.0", DefaultMplexTransport),
		p2p.Security(secio.ID, secio.New),
		p2p.Identity(pk),
		p2p.Peerstore(ps),
		p2p.DisableRelay(),
		p2p.ListenAddrs(listenOn...),
		p2p.Routing(
			p2pconfig.RoutingC(func(host host.Host) (routing.PeerRouting, error) {
				kad, err := kad.New(ctx, host, kadopts.Datastore(dsDht), kadopts.Validator(rv))
				go func() { kadch <- kad }()
				return kad, err
			})),
		p2p.PrivateNetwork(prot))

	if err != nil {
		return nil, err
	}

	mdns, err := mdns.NewMdnsService(ctx, host, time.Minute, "_coda-discovery._udp.local")
	if err != nil {
		return nil, err
	}
	l := &mdnsListener{FoundPeer: make(chan peer.AddrInfo)}
	mdns.RegisterNotifee(l)

	kad := <-kadch

	if err = kad.Bootstrap(ctx); err != nil {
		return nil, err
	}
	routingDiscovery := discovery.NewRoutingDiscovery(kad)

	log.Println("Announcing ourselves for", rendezvousString)

	discovered := make(chan peer.AddrInfo)

	foundPeer := func(info peer.AddrInfo, source string) {
		if info.ID != "" {
			ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
			defer cancel()
			if err := host.Connect(ctx, info); err != nil {
				logger.Warning("couldn't connect to %s peer %v (maybe the network ID mismatched?): %v", source, info.Loggable(), err)
			} else {
				logger.Info("Found a %s peer: %s", source, info.Loggable())
				host.Peerstore().AddAddrs(info.ID, info.Addrs, peerstore.ConnectedAddrTTL)
				discovered <- info
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
			// have to explicitly search once?
			dhtpeers, err := routingDiscovery.FindPeers(ctx, rendezvousString)
			if err != nil {
				logger.Error("failed to find DHT peers: ", err)
			}
			for info := range dhtpeers {
				foundPeer(info, "dht")
			}
		}
	}()

	pubsub, err := pubsub.NewFloodSub(ctx, host, pubsub.WithStrictSignatureVerification(true), pubsub.WithMessageSigning(true))
	if err != nil {
		return nil, err
	}

	return &Helper{
		Host:            host,
		Ctx:             ctx,
		Mdns:            mdns,
		Dht:             kad,
		Pubsub:          pubsub,
		Logger:          logger,
		DiscoveredPeers: discovered,
		Rendezvous:      rendezvousString,
		Discovery:       routingDiscovery,
	}, nil
}
