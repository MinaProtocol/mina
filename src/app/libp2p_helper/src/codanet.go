package codanet

import (
	"bytes"
	"context"
	"fmt"
	"log"
	"path"

	dsb "github.com/ipfs/go-ds-badger"
	logging "github.com/ipfs/go-log"
	p2p "github.com/libp2p/go-libp2p"
	crypto "github.com/libp2p/go-libp2p-core/crypto"
	host "github.com/libp2p/go-libp2p-core/host"
	"github.com/libp2p/go-libp2p-core/peer"
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
	filters "github.com/libp2p/go-maddr-filter"
	tcp "github.com/libp2p/go-tcp-transport"
	ws "github.com/libp2p/go-ws-transport"
	ma "github.com/multiformats/go-multiaddr"
	"golang.org/x/crypto/blake2b"
)

// Helper contains all the daemon state
type Helper struct {
	Host            host.Host
	Mdns            *mdns.Service
	Dht             *kad.IpfsDHT
	Ctx             context.Context
	Pubsub          *pubsub.PubSub
	Logger          logging.EventLogger
	Filters         *filters.Filters
	DiscoveredPeers chan peer.AddrInfo
	Rendezvous      string
	Discovery       *discovery.RoutingDiscovery
	Me              peer.ID
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

// TODO: just put this into main.go?

// MakeHelper does all the initialization to run one host
func MakeHelper(ctx context.Context, listenOn []ma.Multiaddr, externalAddr ma.Multiaddr, statedir string, pk crypto.PrivKey, networkID string) (*Helper, error) {
	logger := logging.Logger("codanet.Helper")

	me, err := peer.IDFromPrivateKey(pk)
	if err != nil {
		return nil, err
	}

	dso := dsb.DefaultOptions

	ds, err := dsb.NewDatastore(path.Join(statedir, "libp2p-peerstore-v0"), &dso)
	if err != nil {
		return nil, err
	}

	dsoDht := dsb.DefaultOptions
	dsDht, err := dsb.NewDatastore(path.Join(statedir, "libp2p-dht-v0"), &dsoDht)
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

	// gross hack to exfiltrate the DHT from the side effect of option evaluation
	kadch := make(chan *kad.IpfsDHT)

	filters := filters.NewFilters()

	host, err := p2p.New(ctx,
		p2p.Transport(tcp.NewTCPTransport),
		p2p.Transport(ws.New),
		p2p.Muxer("/coda/mplex/1.0.0", DefaultMplexTransport),
		p2p.Security(secio.ID, secio.New),
		p2p.Identity(pk),
		p2p.Peerstore(ps),
		p2p.DisableRelay(),
		p2p.ListenAddrs(listenOn...),
		p2p.AddrsFactory(func(as []ma.Multiaddr) []ma.Multiaddr {
			as = append(as, externalAddr)
			return as
		}),
		p2p.Filters(filters),
		p2p.NATPortMap(),
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

	kad := <-kadch

	// nil fields are initialized by beginAdvertising
	return &Helper{
		Host:            host,
		Ctx:             ctx,
		Mdns:            nil,
		Dht:             kad,
		Pubsub:          nil,
		Logger:          logger,
		DiscoveredPeers: nil,
		Rendezvous:      rendezvousString,
		Filters:         filters,
		Discovery:       nil,
		Me:              me,
	}, nil
}
