package codanet

import (
	"bytes"
	"context"
	"fmt"
	"math"
	gonet "net"
	"path"
	"sync"
	"time"

	"github.com/ipfs/boxo/bitswap"
	bitnet "github.com/ipfs/boxo/bitswap/network"
	dsb "github.com/ipfs/go-ds-badger"
	logging "github.com/ipfs/go-log/v2"
	p2p "github.com/libp2p/go-libp2p"

	dht "github.com/libp2p/go-libp2p-kad-dht"
	"github.com/libp2p/go-libp2p-kad-dht/dual"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	record "github.com/libp2p/go-libp2p-record"
	p2pconfig "github.com/libp2p/go-libp2p/config"
	"github.com/libp2p/go-libp2p/core/connmgr"
	"github.com/libp2p/go-libp2p/core/control"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/metrics"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/protocol"
	"github.com/libp2p/go-libp2p/core/routing"
	mdns "github.com/libp2p/go-libp2p/p2p/discovery/mdns"
	discovery "github.com/libp2p/go-libp2p/p2p/discovery/routing"
	"github.com/libp2p/go-libp2p/p2p/host/peerstore/pstoreds"
	libp2pyamux "github.com/libp2p/go-libp2p/p2p/muxer/yamux"
	p2pconnmgr "github.com/libp2p/go-libp2p/p2p/net/connmgr"
	"github.com/libp2p/go-libp2p/p2p/transport/tcp"
	ma "github.com/multiformats/go-multiaddr"
	manet "github.com/multiformats/go-multiaddr/net"
	"golang.org/x/crypto/blake2b"

	patcher "github.com/o1-labs/go-libp2p-kad-dht-patcher"
)

const NodeStatusTimeout = 10 * time.Second

func parseCIDR(cidr string) gonet.IPNet {
	_, ipnet, err := gonet.ParseCIDR(cidr)
	if err != nil {
		panic(err)
	}
	return *ipnet
}

var (
	logger      = logging.Logger("codanet.Helper")
	NoDHT       bool // option for testing to completely disable the DHT
	WithPrivate bool // option for testing to allow private IPs

	privateCIDRs = []string{
		"10.0.0.0/8",
		"172.16.0.0/12",
		"192.168.0.0/16",
		"100.64.0.0/10",
		"198.18.0.0/15",
		"169.254.0.0/16",
	}

	NodeStatusProtocolID = protocol.ID("/mina/node-status")
	BitSwapExchange      = protocol.ID("/mina/bitswap-exchange")

	privateIpFilter *ma.Filters = nil
)

func initPrivateIpFilter() {
	privateIpFilter = ma.NewFilters()
	if WithPrivate {
		return
	}

	for _, cidr := range privateCIDRs {
		privateIpFilter.AddFilter(parseCIDR(cidr), ma.ActionDeny)
	}
}

func isPrivateAddr(addr ma.Multiaddr) bool {
	return privateIpFilter.AddrBlocked(addr)
}

type CodaConnectionManager struct {
	p2pManager        *p2pconnmgr.BasicConnMgr
	onConnectMutex    sync.RWMutex
	onConnect         func(network.Network, network.Conn)
	onDisconnectMutex sync.RWMutex
	onDisconnect      func(network.Network, network.Conn)
	// protectedMirror is a map of protected peer ids/tags, mirroring the structure in
	// BasicConnMgr which is not accessible from CodaConnectionManager
	protectedMirror     map[peer.ID]map[string]interface{}
	protectedMirrorLock sync.Mutex
}

func (cm *CodaConnectionManager) AddOnConnectHandler(f func(network.Network, network.Conn)) {
	cm.onConnectMutex.Lock()
	defer cm.onConnectMutex.Unlock()
	prevOnConnect := cm.onConnect
	cm.onConnect = func(net network.Network, c network.Conn) {
		prevOnConnect(net, c)
		f(net, c)
	}
}

func (cm *CodaConnectionManager) AddOnDisconnectHandler(f func(network.Network, network.Conn)) {
	cm.onDisconnectMutex.Lock()
	defer cm.onDisconnectMutex.Unlock()
	prevOnDisconnect := cm.onDisconnect
	cm.onDisconnect = func(net network.Network, c network.Conn) {
		prevOnDisconnect(net, c)
		f(net, c)
	}
}

func newCodaConnectionManager(minConnections, maxConnections int, grace time.Duration) (*CodaConnectionManager, error) {
	noop := func(net network.Network, c network.Conn) {}
	connmgr, err := p2pconnmgr.NewConnManager(minConnections, maxConnections, p2pconnmgr.WithGracePeriod(grace))
	if err != nil {
		return nil, err
	}
	return &CodaConnectionManager{
		p2pManager:      connmgr,
		onConnect:       noop,
		onDisconnect:    noop,
		protectedMirror: make(map[peer.ID]map[string]interface{}),
	}, nil
}

// proxy connmgr.ConnManager interface to p2pconnmgr.BasicConnMgr
func (cm *CodaConnectionManager) TagPeer(p peer.ID, tag string, weight int) {
	cm.p2pManager.TagPeer(p, tag, weight)
}
func (cm *CodaConnectionManager) UntagPeer(p peer.ID, tag string) { cm.p2pManager.UntagPeer(p, tag) }
func (cm *CodaConnectionManager) UpsertTag(p peer.ID, tag string, upsert func(int) int) {
	cm.p2pManager.UpsertTag(p, tag, upsert)
}
func (cm *CodaConnectionManager) GetTagInfo(p peer.ID) *connmgr.TagInfo {
	return cm.p2pManager.GetTagInfo(p)
}
func (cm *CodaConnectionManager) TrimOpenConns(ctx context.Context) { cm.p2pManager.TrimOpenConns(ctx) }
func (cm *CodaConnectionManager) Protect(p peer.ID, tag string) {
	cm.p2pManager.Protect(p, tag)
	cm.protectedMirrorLock.Lock()
	defer cm.protectedMirrorLock.Unlock()
	pm := cm.protectedMirror
	pm_, has := pm[p]
	if !has {
		pm_ = make(map[string]interface{})
		pm[p] = pm_
	}
	pm_[tag] = nil
}
func (cm *CodaConnectionManager) Unprotect(p peer.ID, tag string) bool {
	res := cm.p2pManager.Unprotect(p, tag)
	cm.protectedMirrorLock.Lock()
	defer cm.protectedMirrorLock.Unlock()
	pm := cm.protectedMirror
	pm_, has := pm[p]
	if has {
		delete(pm_, tag)
	}
	return res
}
func (cm *CodaConnectionManager) ViewProtected(f func(map[peer.ID]map[string]interface{})) {
	cm.protectedMirrorLock.Lock()
	defer cm.protectedMirrorLock.Unlock()
	f(cm.protectedMirror)
}
func (cm *CodaConnectionManager) IsProtected(p peer.ID, tag string) bool {
	return cm.p2pManager.IsProtected(p, tag)
}
func (cm *CodaConnectionManager) Close() error { return cm.p2pManager.Close() }

// proxy connmgr.Decayer interface to p2pconnmgr.BasicConnMgr (which implements connmgr.Decayer via struct inheritance)
func (cm *CodaConnectionManager) RegisterDecayingTag(name string, interval time.Duration, decayFn connmgr.DecayFn, bumpFn connmgr.BumpFn) (connmgr.DecayingTag, error) {
	// casting to Decayer here should always succeed
	decayer, _ := interface{}(cm.p2pManager).(connmgr.Decayer)
	tag, err := decayer.RegisterDecayingTag(name, interval, decayFn, bumpFn)
	return tag, err
}

// redirect Notifee() to self for notification interception
func (cm *CodaConnectionManager) Notifee() network.Notifiee { return cm }

// proxy Notifee notifications to p2pconnmgr.BasicConnMgr, intercepting Connected and Disconnected
func (cm *CodaConnectionManager) Listen(net network.Network, addr ma.Multiaddr) {
	cm.p2pManager.Notifee().Listen(net, addr)
}
func (cm *CodaConnectionManager) ListenClose(net network.Network, addr ma.Multiaddr) {
	cm.p2pManager.Notifee().ListenClose(net, addr)
}

func (cm *CodaConnectionManager) onConnectHandler() func(net network.Network, c network.Conn) {
	cm.onConnectMutex.RLock()
	defer cm.onConnectMutex.RUnlock()
	return cm.onConnect
}

func (cm *CodaConnectionManager) Connected(net network.Network, c network.Conn) {
	logger.Debugf("%s connected to %s", c.LocalPeer(), c.RemotePeer())
	cm.onConnectHandler()(net, c)
	cm.p2pManager.Notifee().Connected(net, c)
}

func (cm *CodaConnectionManager) onDisconnectHandler() func(net network.Network, c network.Conn) {
	cm.onDisconnectMutex.RLock()
	defer cm.onDisconnectMutex.RUnlock()
	return cm.onDisconnect
}

func (cm *CodaConnectionManager) Disconnected(net network.Network, c network.Conn) {
	cm.onDisconnectHandler()(net, c)
	cm.p2pManager.Notifee().Disconnected(net, c)
}

// proxy remaining p2pconnmgr.BasicConnMgr methods for access
func (cm *CodaConnectionManager) GetInfo() p2pconnmgr.CMInfo {
	return cm.p2pManager.GetInfo()
}

// Helper contains all the daemon state
type Helper struct {
	Host              host.Host
	Bitswap           *bitswap.Bitswap
	BitswapStorage    BitswapStorage
	Mdns              mdns.Service
	Dht               *dual.DHT
	Ctx               context.Context
	Pubsub            *pubsub.PubSub
	Logger            logging.StandardLogger
	Rendezvous        string
	Discovery         *discovery.RoutingDiscovery
	Me                peer.ID
	gatingState       *CodaGatingState
	ConnectionManager *CodaConnectionManager
	BandwidthCounter  *metrics.BandwidthCounter
	MsgStats          *MessageStats
	NodeStatus        []byte
	HeartbeatPeer     func(peer.ID)
}

type MessageStats struct {
	min   uint64
	avg   uint64
	max   uint64
	total uint64
	sync.RWMutex
}

func (ms *MessageStats) UpdateMetrics(val uint64) {
	ms.Lock()
	defer ms.Unlock()
	if ms.max < val {
		ms.max = val
	}

	if ms.min > val {
		ms.min = val
	}

	ms.total++
	if ms.avg == 0 {
		ms.avg = val
	} else {
		ms.avg = (ms.avg*(ms.total-1) + val) / ms.total
	}
}

type safeStats struct {
	Min float64
	Max float64
	Avg float64
}

func (ms *MessageStats) GetStats() *safeStats {
	ms.RLock()
	defer ms.RUnlock()

	return &safeStats{
		Min: float64(ms.min),
		Max: float64(ms.max),
		Avg: float64(ms.avg),
	}
}

func (h *Helper) SetBannedPeers(newP map[peer.ID]struct{}) {
	h.gatingState.bannedPeersMutex.Lock()
	defer h.gatingState.bannedPeersMutex.Unlock()
	h.gatingState.bannedPeers = newP
}

func (h *Helper) SetTrustedPeers(newP map[peer.ID]struct{}) {
	h.gatingState.trustedPeersMutex.Lock()
	defer h.gatingState.trustedPeersMutex.Unlock()
	h.gatingState.trustedPeers = newP
}

func (h *Helper) SetTrustedAddrFilters(newF *ma.Filters) {
	h.gatingState.trustedAddrFiltersMutex.Lock()
	defer h.gatingState.trustedAddrFiltersMutex.Unlock()
	h.gatingState.trustedAddrFilters = newF
}

func (h *Helper) SetBannedAddrFilters(newF *ma.Filters) {
	h.gatingState.bannedAddrFiltersMutex.Lock()
	defer h.gatingState.bannedAddrFiltersMutex.Unlock()
	h.gatingState.bannedAddrFilters = newF
}

// this type implements the ConnectionGating interface
// https://godoc.org/github.com/libp2p/go-libp2p-core/connmgr#ConnectionGating
// the comments of the functions below are taken from those docs.
type CodaGatingState struct {
	logger                  logging.EventLogger
	KnownPrivateAddrFilters *ma.Filters
	bannedAddrFiltersMutex  sync.RWMutex
	bannedAddrFilters       *ma.Filters
	trustedAddrFiltersMutex sync.RWMutex
	trustedAddrFilters      *ma.Filters
	bannedPeersMutex        sync.RWMutex
	bannedPeers             map[peer.ID]struct{}
	trustedPeersMutex       sync.RWMutex
	trustedPeers            map[peer.ID]struct{}
}

type CodaGatingConfig struct {
	BannedAddrFilters  *ma.Filters
	TrustedAddrFilters *ma.Filters
	BannedPeers        map[peer.ID]struct{}
	TrustedPeers       map[peer.ID]struct{}
}

// NewCodaGatingState returns a new CodaGatingState
func NewCodaGatingState(config *CodaGatingConfig, knownPrivateAddrFilters *ma.Filters) *CodaGatingState {
	logger := logging.Logger("codanet.CodaGatingState")

	bannedAddrFilters := config.BannedAddrFilters
	if bannedAddrFilters == nil {
		bannedAddrFilters = ma.NewFilters()
	}

	trustedAddrFilters := config.TrustedAddrFilters
	if trustedAddrFilters == nil {
		trustedAddrFilters = ma.NewFilters()
	}

	bannedPeers := config.BannedPeers
	if bannedPeers == nil {
		bannedPeers = make(map[peer.ID]struct{})
	}

	trustedPeers := config.TrustedPeers
	if trustedPeers == nil {
		trustedPeers = make(map[peer.ID]struct{})
	}

	return &CodaGatingState{
		logger:                  logger,
		bannedAddrFilters:       bannedAddrFilters,
		trustedAddrFilters:      trustedAddrFilters,
		KnownPrivateAddrFilters: knownPrivateAddrFilters,
		bannedPeers:             bannedPeers,
		trustedPeers:            trustedPeers,
	}
}

func (h *Helper) GatingState() *CodaGatingState {
	return h.gatingState
}

func (h *Helper) SetGatingState(gs *CodaGatingConfig) {
	h.SetTrustedPeers(gs.TrustedPeers)
	h.SetBannedPeers(gs.BannedPeers)
	h.SetTrustedAddrFilters(gs.TrustedAddrFilters)
	h.SetBannedAddrFilters(gs.BannedAddrFilters)
	for _, c := range h.Host.Network().Conns() {
		pid := c.RemotePeer()
		maddr := c.RemoteMultiaddr()
		if h.gatingState.checkAllowedPeerWithAddr(pid, maddr).isDeny() {
			go func() {
				if err := h.Host.Network().ClosePeer(pid); err != nil {
					h.gatingState.logger.Infof("failed to close banned peer %v: %v", pid, err)
				}
			}()
		}
	}
}

func (gs *CodaGatingState) TrustPeer(p peer.ID) {
	gs.trustedPeersMutex.Lock()
	defer gs.trustedPeersMutex.Unlock()
	gs.trustedPeers[p] = struct{}{}
}

func (gs *CodaGatingState) MarkPrivateAddrAsKnown(addr ma.Multiaddr) {
	if isPrivateAddr(addr) && gs.KnownPrivateAddrFilters.AddrBlocked(addr) {
		gs.logger.Infof("marking private addr %v as known", addr)

		ip, err := manet.ToIP(addr)
		if err != nil {
			panic(err)
		}

		bits := len(ip) * 8
		ipNet := gonet.IPNet{
			IP:   ip,
			Mask: gonet.CIDRMask(bits, bits),
		}
		gs.KnownPrivateAddrFilters.AddFilter(ipNet, ma.ActionAccept)
	}
}

type connectionAllowance int

const (
	Undecided connectionAllowance = iota
	DenyUnknownPrivateAddress
	DenyBannedPeer
	DenyBannedAddress
	Accept
)

var connectionAllowanceStrings = map[connectionAllowance]string{
	Undecided:                 "Undecided",
	DenyUnknownPrivateAddress: "DenyUnknownPrivateAddress",
	DenyBannedPeer:            "DenyBannedPeer",
	DenyBannedAddress:         "DenyBannedAddress",
	Accept:                    "Allow",
}

func (ca connectionAllowance) String() string {
	return connectionAllowanceStrings[ca]
}

func (c connectionAllowance) isDeny() bool {
	return !(c == Accept || c == Undecided)
}

func (gs *CodaGatingState) checkPeerTrusted(p peer.ID) connectionAllowance {
	gs.trustedPeersMutex.RLock()
	defer gs.trustedPeersMutex.RUnlock()
	_, isTrusted := gs.trustedPeers[p]
	if isTrusted {
		return Accept
	}
	return Undecided
}

func (gs *CodaGatingState) checkPeerBanned(p peer.ID) connectionAllowance {
	gs.bannedPeersMutex.RLock()
	defer gs.bannedPeersMutex.RUnlock()
	_, isBanned := gs.bannedPeers[p]
	if isBanned {
		return DenyBannedPeer
	}
	return Undecided
}

// bothAccept makes sure neither allowance denies the connection
func bothAccept(a connectionAllowance, b connectionAllowance) connectionAllowance {
	if a == Undecided {
		return b
	}
	if a == Accept {
		if b == Undecided {
			return Accept
		}
		return b
	}
	return a
}

// unlessUndecided(a, b) returns `a` unless it is undecided, in which case it falls back to `b`
func unlessUndecided(a connectionAllowance, b connectionAllowance) connectionAllowance {
	if a == Undecided {
		return b
	}
	return a
}

// checks if a peer id is allowed to dial/accept
func (gs *CodaGatingState) checkAllowedPeer(p peer.ID) connectionAllowance {
	return unlessUndecided(gs.checkPeerTrusted(p), gs.checkPeerBanned(p))
}

func (gs *CodaGatingState) checkAddrTrusted(addr ma.Multiaddr) connectionAllowance {
	gs.trustedAddrFiltersMutex.RLock()
	defer gs.trustedAddrFiltersMutex.RUnlock()
	if !gs.trustedAddrFilters.AddrBlocked(addr) {
		return Accept
	}
	return Undecided
}

func (gs *CodaGatingState) checkAddrBanned(addr ma.Multiaddr) connectionAllowance {
	gs.bannedAddrFiltersMutex.RLock()
	defer gs.bannedAddrFiltersMutex.RUnlock()
	if gs.bannedAddrFilters.AddrBlocked(addr) {
		return DenyBannedAddress
	}
	return Undecided
}

// checks if an address is allowed to dial/accept
func (gs *CodaGatingState) checkAllowedAddr(addr ma.Multiaddr) connectionAllowance {
	if st := gs.checkAddrTrusted(addr); st != Undecided {
		return st
	}
	if isPrivateAddr(addr) && gs.KnownPrivateAddrFilters.AddrBlocked(addr) {
		return DenyUnknownPrivateAddress
	}
	return gs.checkAddrBanned(addr)
}

// checks if a peer is allowed to dial/accept; if the peer is in the trustlist, the address checks are overriden
func (gs *CodaGatingState) checkAllowedPeerWithAddr(p peer.ID, addr ma.Multiaddr) connectionAllowance {
	return unlessUndecided(gs.checkPeerTrusted(p), bothAccept(gs.checkAllowedPeer(p), gs.checkAllowedAddr(addr)))
}

func (gs *CodaGatingState) logGate() {
	gs.logger.Debugf("gated a connection with config: %+v", gs)
}

// InterceptPeerDial tests whether we're permitted to Dial the specified peer.
//
// This is called by the network.Network implementation when dialling a peer.
func (gs *CodaGatingState) InterceptPeerDial(p peer.ID) bool {
	allowance := gs.checkAllowedPeer(p)
	if allowance.isDeny() {
		gs.logger.Infof("disallowing peer dial to: %v (peer, %s)", p, allowance)
		gs.logGate()
		return false
	}
	return true
}

// InterceptAddrDial tests whether we're permitted to dial the specified
// multiaddr for the given peer.
//
// This is called by the network.Network implementation after it has
// resolved the peer's addrs, and prior to dialling each.
func (gs *CodaGatingState) InterceptAddrDial(id peer.ID, addr ma.Multiaddr) bool {
	allowance := gs.checkAllowedPeerWithAddr(id, addr)
	if allowance.isDeny() {
		gs.logger.Infof("disallowing peer dial to: %v + %v (peer + address, %s)", id, addr, allowance)
		gs.logGate()
		return false
	}
	return true
}

// InterceptAccept tests whether an incipient inbound connection is allowed.
//
// This is called by the upgrader, or by the transport directly (e.g. QUIC,
// Bluetooth), straight after it has accepted a connection from its socket.
func (gs *CodaGatingState) InterceptAccept(addrs network.ConnMultiaddrs) bool {
	remoteAddr := addrs.RemoteMultiaddr()
	allowance := unlessUndecided(gs.checkAddrTrusted(remoteAddr), gs.checkAddrBanned(remoteAddr))
	if allowance.isDeny() {
		gs.logger.Infof("refusing to accept inbound connection from addr: %v (%s)", remoteAddr, allowance)
		gs.logGate()
		return false
	}
	// If we are receiving a connection, and the remote address is private,
	// then we infer that we should be able to connect to that private address.
	gs.MarkPrivateAddrAsKnown(remoteAddr)
	return true
}

// InterceptSecured tests whether a given connection, now authenticated,
// is allowed.
//
// This is called by the upgrader, after it has performed the security
// handshake, and before it negotiates the muxer, or by the directly by the
// transport, at the exact same checkpoint.
func (gs *CodaGatingState) InterceptSecured(_ network.Direction, id peer.ID, addrs network.ConnMultiaddrs) bool {
	// note: we don't care about the direction (inbound/outbound). all
	// connections in coda are symmetric: if i am allowed to connect to
	// you, you are allowed to connect to me.
	remoteAddr := addrs.RemoteMultiaddr()
	allowance := gs.checkAllowedPeerWithAddr(id, remoteAddr)
	if allowance.isDeny() {
		gs.logger.Infof("refusing to accept inbound connection from authenticated addr: %v (%s)", remoteAddr, allowance)
		gs.logGate()
		return false
	}
	return true
}

// InterceptUpgraded tests whether a fully capable connection is allowed.
//
// At this point, the connection a multiplexer has been selected.
// When rejecting a connection, the gater can return a DisconnectReason.
// Refer to the godoc on the ConnectionGating type for more information.
//
// NOTE: the go-libp2p implementation currently IGNORES the disconnect reason.
func (gs *CodaGatingState) InterceptUpgraded(network.Conn) (allow bool, reason control.DisconnectReason) {
	allow = true
	reason = control.DisconnectReason(0)
	return
}

type customValidator struct {
	Base record.Validator
}

func (cv customValidator) Validate(key string, value []byte) error {
	logger.Debugf("DHT Validating: %s = %s", key, value)
	return cv.Base.Validate(key, value)
}

func (cv customValidator) Select(key string, values [][]byte) (int, error) {
	logger.Debugf("DHT Selecting Among: %s = %s", key, bytes.Join(values, []byte("; ")))
	return cv.Base.Select(key, values)
}

func (h *Helper) handleNodeStatusStreams(s network.Stream) {
	defer func() {
		err := s.Close()
		if err != nil {
			logger.Error("failed to close write side of stream", err)
			return
		}

		<-time.After(NodeStatusTimeout)

		err = s.Reset()
		if err != nil {
			logger.Error("failed to reset stream", err)
		}
	}()

	n, err := s.Write(h.NodeStatus)
	if err != nil {
		logger.Error("failed to write to stream", err)
		return
	} else if n != len(h.NodeStatus) {
		// TODO repeat writing, not log error
		logger.Error("failed to write all data to stream")
		return
	}

	logger.Debugf("wrote node status to stream %s", s.Protocol())
}

func (h *Helper) TrimOpenConns(ctx context.Context) {
	h.ConnectionManager.TrimOpenConns(ctx)
}

// MakeHelper does all the initialization to run one host
func MakeHelper(ctx context.Context, listenOn []ma.Multiaddr, externalAddr ma.Multiaddr, statedir string, pk crypto.PrivKey, networkID string, seeds []peer.AddrInfo, gatingConfig *CodaGatingConfig, minConnections, maxConnections int, peerProtectionRatio float32, grace time.Duration, knownPrivateIpNets []gonet.IPNet) (*Helper, error) {
	me, err := peer.IDFromPrivateKey(pk)
	if err != nil {
		return nil, err
	}

	initPrivateIpFilter()

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

	// custom validator to omit the ipns validation.
	rv := customValidator{Base: record.NamespacedValidator{"pk": record.PublicKeyValidator{}}}

	lanPatcher := patcher.NewPatcher()
	wanPatcher := patcher.NewPatcher()
	lanPatcher.MaxProtected = minConnections
	wanPatcher.MaxProtected = minConnections
	lanPatcher.ProtectionRate = peerProtectionRatio
	wanPatcher.ProtectionRate = peerProtectionRatio

	var kad *dual.DHT

	connManager, err := newCodaConnectionManager(minConnections, maxConnections, grace)
	if err != nil {
		return nil, err
	}
	bandwidthCounter := metrics.NewBandwidthCounter()

	// we initialize the known private addr filters to reject all ip addresses initially
	knownPrivateAddrFilters := ma.NewFilters()
	knownPrivateAddrFilters.AddFilter(parseCIDR("0.0.0.0/0"), ma.ActionDeny)
	for _, net := range knownPrivateIpNets {
		knownPrivateAddrFilters.AddFilter(net, ma.ActionAccept)
	}

	gs := NewCodaGatingState(gatingConfig, knownPrivateAddrFilters)
	host, err := p2p.New(
		p2p.Transport(tcp.NewTCPTransport),
		p2p.Muxer("/coda/yamux/1.0.0", libp2pyamux.DefaultTransport),
		p2p.Identity(pk),
		p2p.Peerstore(ps),
		p2p.DisableRelay(),
		p2p.ConnectionGater(gs),
		p2p.ConnectionManager(connManager),
		p2p.ListenAddrs(listenOn...),
		p2p.AddrsFactory(func(as []ma.Multiaddr) []ma.Multiaddr {
			if externalAddr != nil {
				as = append(as, externalAddr)
			}

			return as
		}),
		p2p.NATPortMap(),
		p2p.Routing(
			p2pconfig.RoutingC(func(host host.Host) (routing.PeerRouting, error) {
				if NoDHT {
					return nil, nil
				}

				kad, err = dual.New(ctx, host,
					dual.WanDHTOption(dht.Datastore(dsDht)),
					dual.DHTOption(dht.Validator(rv)),
					dual.DHTOption(dht.BootstrapPeers(seeds...)),
					dual.DHTOption(dht.ProtocolPrefix("/coda")),
				)
				lanPatcher.Patch(kad.LAN)
				wanPatcher.Patch(kad.WAN)
				return kad, err
			})),
		p2p.UserAgent("github.com/codaprotocol/coda/tree/master/src/app/libp2p_helper"),
		p2p.PrivateNetwork(pnetKey[:]),
		p2p.BandwidthReporter(bandwidthCounter),
	)

	if err != nil {
		return nil, err
	}
	bstore, err := OpenBitswapStorageLmdb(path.Join(statedir, "block-db"))
	if err != nil {
		return nil, err
	}
	bitswapNetwork := bitnet.NewFromIpfsHost(host, kad, bitnet.Prefix(BitSwapExchange))
	// Block store is provided, but only read-only methods are used
	// TODO update Bitswap libraries to require only read-only methods
	bs := bitswap.New(context.Background(), bitswapNetwork, bstore.Blockstore())

	// nil fields are initialized by beginAdvertising
	h := &Helper{
		Host:              host,
		Bitswap:           bs,
		BitswapStorage:    bstore,
		Ctx:               ctx,
		Mdns:              nil,
		Dht:               kad,
		Pubsub:            nil,
		Logger:            logger,
		Rendezvous:        rendezvousString,
		Discovery:         nil,
		Me:                me,
		gatingState:       gs,
		ConnectionManager: connManager,
		BandwidthCounter:  bandwidthCounter,
		MsgStats:          &MessageStats{min: math.MaxUint64},
		HeartbeatPeer: func(p peer.ID) {
			lanPatcher.Heartbeat(p)
			wanPatcher.Heartbeat(p)
		},
	}

	h.Host.SetStreamHandler(NodeStatusProtocolID, h.handleNodeStatusStreams)
	return h, nil
}
