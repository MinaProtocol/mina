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

const MAX_MESSAGE_LENGTH uint64 = 2 << 30  // 2gb
const MESSAGE_BUFFER_SIZE uint64 = 2 << 20 // 2mb

type streamState int

const (
	STREAM_DATA_UNEXPECTED streamState = iota
	STREAM_DATA_EXPECTED
)

type messageBuffer [MESSAGE_BUFFER_SIZE]byte

type messageBufferPool struct {
	pool sync.Pool
}

func newMessageBufferPool() messageBufferPool {
	return messageBufferPool{
		pool: sync.Pool{
			New: func() interface{} {
				return new(messageBuffer)
			},
		},
	}
}

func (p *messageBufferPool) Get() *messageBuffer {
	return p.pool.Get().(*messageBuffer)
}

func (p *messageBufferPool) Put(buffer *messageBuffer) {
	p.pool.Put(buffer)
}

type app struct {
	P2p                      *codanet.Helper
	Ctx                      context.Context
	Subs                     map[uint64]subscription
	Topics                   map[string]*pubsub.Topic
	Validators               map[uint64]*validationStatus
	ValidatorMutex           *sync.Mutex
	Streams                  map[uint64]net.Stream
	StreamStates             map[uint64]streamState
	StreamsMutex             sync.Mutex
	Out                      *bufio.Writer
	OutChan                  chan *capnp.Message
	Bootstrapper             io.Closer
	AddedPeers               []peer.AddrInfo
	UnsafeNoTrustIP          bool
	MetricsRefreshTime       time.Duration
	metricsCollectionStarted bool

	messageBufferPool messageBufferPool

	// development configuration options
	NoMDNS        bool
	NoDHT         bool
	NoUpcalls     bool
	metricsServer *codaMetricsServer

	// Counter for id generation
	counter uint64
	// Mutex for id generation
	counterMutex sync.Mutex
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

func uint64ToLEB128(in uint64) []byte {
	var out []byte
	for {
		b := uint8(in & 0x7f)
		in >>= 7
		if in != 0 {
			b |= 0x80
		}
		out = append(out, b)
		if in == 0 {
			break
		}
	}
	return out
}

func readLEB128ToUint64(r io.Reader) (uint64, error) {
	buffer := make([]byte, 1)
	var out uint64
	var shift uint
	for {
		_, err := io.ReadFull(r, buffer)
		if err != nil {
			return 0, err
		}
		b := buffer[0]
		out |= uint64(0x7F&b) << shift
		if b&0x80 == 0 {
			break
		}
		shift += 7
	}
	return out, nil
}
