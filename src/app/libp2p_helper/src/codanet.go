package codanet

import (
	"bytes"
	"context"
	"fmt"
	dsb "github.com/ipfs/go-ds-badger"
	p2p "github.com/libp2p/go-libp2p"
	crypto "github.com/libp2p/go-libp2p-crypto"
	discovery "github.com/libp2p/go-libp2p-discovery"
	host "github.com/libp2p/go-libp2p-host"
	kad "github.com/libp2p/go-libp2p-kad-dht"
	kadopts "github.com/libp2p/go-libp2p-kad-dht/opts"
	"github.com/libp2p/go-libp2p-peerstore"
	"github.com/libp2p/go-libp2p-peerstore/pstoreds"
	pnet "github.com/libp2p/go-libp2p-pnet"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/libp2p/go-libp2p-record"
	routing "github.com/libp2p/go-libp2p-routing"
	secio "github.com/libp2p/go-libp2p-secio"
	p2pconfig "github.com/libp2p/go-libp2p/config"
	mdns "github.com/libp2p/go-libp2p/p2p/discovery"
	tcp "github.com/libp2p/go-tcp-transport"
	ws "github.com/libp2p/go-ws-transport"
	"github.com/multiformats/go-multiaddr"
	"golang.org/x/crypto/blake2b"
	"log"
	"os"
	"path"
	"strconv"
	"time"
)

// Helper contains all the daemon state
type Helper struct {
	Host   host.Host
	Mdns   mdns.Service
	Dht    *kad.IpfsDHT
	Ctx    context.Context
	Pubsub *pubsub.PubSub
}

type mdnsListener struct {
	FoundPeer chan peerstore.PeerInfo
}

func (l *mdnsListener) HandlePeerFound(info peerstore.PeerInfo) {
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

	pnetKey := blake2b.Sum256([]byte("/coda/0.0.1"))
	prot, err := pnet.NewV1ProtectorFromBytes(&pnetKey)
	if err != nil {
		return nil, err
	}

	rv := customValidator{Base: record.NamespacedValidator{"pk": record.PublicKeyValidator{}}}

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

	rendezvousString := fmt.Sprintf("/coda/0.0.1/%s", networkID)

	mdns, err := mdns.NewMdnsService(ctx, host, time.Minute, "_coda-discovery._udp.local")
	if err != nil {
		return nil, err
	}
	l := &mdnsListener{FoundPeer: make(chan peerstore.PeerInfo)}
	mdns.RegisterNotifee(l)

	kad := <-kadch

	if err = kad.Bootstrap(ctx); err != nil {
		return nil, err
	}
	routingDiscovery := discovery.NewRoutingDiscovery(kad)

	log.Println("Announcing ourselves for", rendezvousString)
	discovery.Advertise(ctx, routingDiscovery, rendezvousString)

	// try and find some peers for this chain
	//dhtpeers, err := routingDiscovery.FindPeers(ctx, rendezvousString, discovery.Limit(16))
	//if err != nil {
	//	return nil, err
	//}

	foundPeer := func(info peerstore.PeerInfo, source string) {
		if info.ID != "" {
			ctx, cancel := context.WithTimeout(ctx, 15*time.Second)
			defer cancel()
			if err := host.Connect(ctx, info); err != nil {
				log.Printf("Warn: couldn't connect to %s peer %v (different chain?): %v", source, info.Loggable(), err)
			} else {
				log.Printf("Found a %s peer: %s", source, info.Loggable())
				host.Peerstore().AddAddrs(info.ID, info.Addrs, peerstore.PermanentAddrTTL)
			}
		}
	}

	go func() {
		for {
			info := <-l.FoundPeer
			foundPeer(info, "local")
		}
	}()

	pubsub, err := pubsub.NewFloodSub(ctx, host, pubsub.WithStrictSignatureVerification(true), pubsub.WithMessageSigning(true))
	if err != nil {
		return nil, err
	}

	return &Helper{
		Host:   host,
		Ctx:    ctx,
		Mdns:   mdns,
		Dht:    kad,
		Pubsub: pubsub,
	}, nil
}
