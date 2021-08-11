package main

import (
	"encoding/base64"
	"encoding/json"
	gonet "net"

	"codanet"

	"github.com/go-errors/errors"
	peer "github.com/libp2p/go-libp2p-core/peer"
	ma "github.com/multiformats/go-multiaddr"
)

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
	setGatingConfig
	setNodeStatus
	getPeerNodeStatus
)

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

type configureMsg struct {
	Statedir            string             `json:"statedir"`
	Privk               string             `json:"privk"`
	NetworkID           string             `json:"network_id"`
	ListenOn            []string           `json:"ifaces"`
	MetricsPort         string             `json:"metrics_port"`
	External            string             `json:"external_maddr"`
	UnsafeNoTrustIP     bool               `json:"unsafe_no_trust_ip"`
	Flood               bool               `json:"flood"`
	PeerExchange        bool               `json:"peer_exchange"`
	DirectPeers         []string           `json:"direct_peers"`
	SeedPeers           []string           `json:"seed_peers"`
	GatingConfig        setGatingConfigMsg `json:"gating_config"`
	MaxConnections      int                `json:"max_connections"`
	ValidationQueueSize int                `json:"validation_queue_size"`
	MinaPeerExchange    bool               `json:"mina_peer_exchange"`
}

type peerConnectionUpcall struct {
	ID     string `json:"peer_id"`
	Upcall string `json:"upcall"`
}

type listenMsg struct {
	Iface string `json:"iface"`
}

type publishMsg struct {
	Topic string `json:"topic"`
	Data  string `json:"data"`
}

type subscribeMsg struct {
	Topic        string `json:"topic"`
	Subscription int    `json:"subscription_idx"`
}

// we use base64 for encoding blobs in our JSON protocol. there are more
// efficient options but this one is easy to reach to.

func codaEncode(data []byte) string {
	return base64.StdEncoding.EncodeToString(data)
}

func codaDecode(data string) ([]byte, error) {
	return base64.StdEncoding.DecodeString(data)
}

var (
	acceptResult = "accept"
	rejectResult = "reject"
	ignoreResult = "ignore"
)

type validateUpcall struct {
	Sender     *codaPeerInfo `json:"sender"`
	Expiration int64         `json:"expiration"`
	Data       string        `json:"data"`
	Seqno      int           `json:"seqno"`
	Upcall     string        `json:"upcall"`
	Idx        int           `json:"subscription_idx"`
}

type validationCompleteMsg struct {
	Seqno int    `json:"seqno"`
	Valid string `json:"is_valid"`
}

type unsubscribeMsg struct {
	Subscription int `json:"subscription_idx"`
}

type generatedKeypair struct {
	Private string `json:"sk"`
	Public  string `json:"pk"`
	PeerID  string `json:"peer_id"`
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

type incomingMsgUpcall struct {
	Upcall    string `json:"upcall"`
	StreamIdx int    `json:"stream_idx"`
	Data      string `json:"data"`
}

type openStreamMsg struct {
	Peer       string `json:"peer"`
	ProtocolID string `json:"protocol"`
}

type openStreamResult struct {
	StreamIdx int          `json:"stream_idx"`
	Peer      codaPeerInfo `json:"peer"`
}

type closeStreamMsg struct {
	StreamIdx int `json:"stream_idx"`
}

type resetStreamMsg struct {
	StreamIdx int `json:"stream_idx"`
}

type sendStreamMsgMsg struct {
	StreamIdx int    `json:"stream_idx"`
	Data      string `json:"data"`
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

type removeStreamHandlerMsg struct {
	Protocol string `json:"protocol"`
}

type addPeerMsg struct {
	Multiaddr string `json:"multiaddr"`
	Seed      bool   `json:"seed"`
}

type findPeerMsg struct {
	PeerID string `json:"peer_id"`
}

type setNodeStatusMsg struct {
	Data string `json:"data"`
}

type getPeerNodeStatusMsg struct {
	PeerMultiaddr string `json:"peer_multiaddr"`
}

type setGatingConfigMsg struct {
	BannedIPs      []string `json:"banned_ips"`
	BannedPeerIDs  []string `json:"banned_peers"`
	TrustedPeerIDs []string `json:"trusted_peers"`
	TrustedIPs     []string `json:"trusted_ips"`
	Isolate        bool     `json:"isolate"`
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

type generateKeypairMsg struct {
}

type listPeersMsg struct {
}

type listeningAddrsMsg struct {
}

type beginAdvertisingMsg struct {
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
	setGatingConfig:     func() action { return &setGatingConfigMsg{} },
	setNodeStatus:       func() action { return &setNodeStatusMsg{} },
	getPeerNodeStatus:   func() action { return &getPeerNodeStatusMsg{} },
}

type action interface {
	run(app *app) (interface{}, error)
}

func filterIPString(filters *ma.Filters, ip string, action ma.Action) error {
	realIP := gonet.ParseIP(ip).To4()

	if realIP == nil {
		// TODO: how to compute mask for IPv6?
		return badRPC(errors.New("unparsable IP or IPv6"))
	}

	ipnet := gonet.IPNet{Mask: gonet.IPv4Mask(255, 255, 255, 255), IP: realIP}

	filters.AddFilter(ipnet, action)

	return nil
}

func gatingConfigFromJson(gc *setGatingConfigMsg, addedPeers []peer.AddrInfo) (*codanet.CodaGatingState, error) {
	_, totalIpNet, err := gonet.ParseCIDR("0.0.0.0/0")
	if err != nil {
		return nil, err
	}

	// TODO: perhaps the isolate option should just be passed down to the gating state instead
	bannedAddrFilters := ma.NewFilters()
	if gc.Isolate {
		bannedAddrFilters.AddFilter(*totalIpNet, ma.ActionDeny)
	}
	for _, ip := range gc.BannedIPs {
		err := filterIPString(bannedAddrFilters, ip, ma.ActionDeny)
		if err != nil {
			return nil, err
		}
	}

	trustedAddrFilters := ma.NewFilters()
	trustedAddrFilters.AddFilter(*totalIpNet, ma.ActionDeny)
	for _, ip := range gc.TrustedIPs {
		err := filterIPString(trustedAddrFilters, ip, ma.ActionAccept)
		if err != nil {
			return nil, err
		}
	}

	bannedPeers := peer.NewSet()
	for _, peerID := range gc.BannedPeerIDs {
		id := peer.ID(peerID)
		bannedPeers.Add(id)
	}

	trustedPeers := peer.NewSet()
	for _, peerID := range gc.TrustedPeerIDs {
		id := peer.ID(peerID)
		trustedPeers.Add(id)
	}
	for _, peer := range addedPeers {
		trustedPeers.Add(peer.ID)
	}

	return codanet.NewCodaGatingState(bannedAddrFilters, trustedAddrFilters, bannedPeers, trustedPeers), nil
}
