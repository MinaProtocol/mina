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
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	net "github.com/libp2p/go-libp2p/core/network"
	peer "github.com/libp2p/go-libp2p/core/peer"
)

// Stream with mutex
type stream struct {
	mutex  sync.Mutex
	stream net.Stream
}

func (s *stream) Reset() error {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	return s.stream.Reset()
}

func (s *stream) Close() error {
	s.mutex.Lock()
	defer s.mutex.Unlock()
	return s.stream.Close()
}

type app struct {
	P2p                      *codanet.Helper
	Ctx                      context.Context
	_subs                    map[uint64]subscription
	subsMutex                sync.Mutex
	_topics                  map[string]*pubsub.Topic
	topicsMutex              sync.RWMutex
	_validators              map[uint64]*validationStatus
	validatorMutex           sync.Mutex
	_streams                 map[uint64]*stream
	streamsMutex             sync.RWMutex
	Out                      *bufio.Writer
	OutChan                  chan *capnp.Message
	Bootstrapper             io.Closer
	addedPeersMutex          sync.RWMutex
	_addedPeers              []peer.AddrInfo
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
