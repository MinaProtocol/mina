package main

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"net/http"
	"sync"
	"time"

	// importing this automatically registers the pprof api to our metrics server
	_ "net/http/pprof"

	"codanet"

	capnp "capnproto.org/go/capnp/v3"
	net "github.com/libp2p/go-libp2p-core/network"
	peer "github.com/libp2p/go-libp2p-core/peer"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
)

type app struct {
	P2p                      *codanet.Helper
	Ctx                      context.Context
	Subs                     map[uint64]subscription
	Topics                   map[string]*pubsub.Topic
	Validators               map[uint64]*validationStatus
	ValidatorMutex           *sync.Mutex
	Streams                  map[uint64]net.Stream
	StreamsMutex             sync.Mutex
	Out                      *bufio.Writer
	OutChan                  chan *capnp.Message
	Bootstrapper             io.Closer
	AddedPeers               []peer.AddrInfo
	UnsafeNoTrustIP          bool
	MetricsRefreshTime       time.Duration
	metricsCollectionStarted bool

	// development configuration options
	NoMDNS        bool
	NoDHT         bool
	NoUpcalls     bool
	metricsServer *codaMetricsServer

	// Counter for id generation
	counter uint64
	// Mutex for id generation
	counterMutex sync.Mutex

	bitswapCtx                *BitswapCtx
	setConnectionHandlersOnce sync.Once
}

type subscription struct {
	Sub    *pubsub.Subscription
	Idx    uint64
	Ctx    context.Context
	Cancel context.CancelFunc
}

type validationStatus struct {
	Completion chan pubsub.ValidationResult
	TimedOutAt *time.Time
}

type codaMetricsServer struct {
	port   uint16
	server *http.Server
	done   *sync.WaitGroup
}

type peerDiscoverySource int

type peerDiscovery struct {
	info   peer.AddrInfo
	source peerDiscoverySource
}

type mdnsListener struct {
	FoundPeer chan peerDiscovery
	app       *app
}

func (l *mdnsListener) HandlePeerFound(info peer.AddrInfo) {
	l.FoundPeer <- peerDiscovery{
		info:   info,
		source: PEER_DISCOVERY_SOURCE_MDNS,
	}
}

const (
	PEER_DISCOVERY_SOURCE_MDNS peerDiscoverySource = iota
	PEER_DISCOVERY_SOURCE_ROUTING
)

func (source peerDiscoverySource) String() string {
	switch source {
	case PEER_DISCOVERY_SOURCE_MDNS:
		return "PEER_DISCOVERY_SOURCE_MDNS"
	case PEER_DISCOVERY_SOURCE_ROUTING:
		return "PEER_DISCOVERY_SOURCE_ROUTING"
	default:
		return fmt.Sprintf("%d", int(source))
	}
}
