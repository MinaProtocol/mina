package codanet

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"

	logging "github.com/ipfs/go-log/v2"
	peer "github.com/libp2p/go-libp2p/core/peer"
)

// BanManager is the single owner of all ban semantics in the helper. It keeps
// two uniform peer lists (banned and trusted), each split into peer_id-keyed
// and IP-keyed maps:
//
//   - banned entries with a non-nil `until` are auto bans (in-memory only,
//     expiring, subject to escalation and eviction); nil `until` means a
//     manual/indefinite ban (persisted to the banlist JSON).
//   - trusted entries always have nil `until` (operator-authored, indefinite,
//     persisted). Trusted wins over banned at gating time.
//
// All methods are safe for concurrent use: IPC dispatch runs in one goroutine,
// but gating checks happen on libp2p goroutines, so state is protected by a
// mutex.
type BanManager struct {
	mu   sync.RWMutex
	log  logging.EventLogger
	path string

	// now is injectable for tests.
	now func() time.Time

	banned  peerList
	trusted peerList
	strikes map[peer.ID]strike
}

type peerList struct {
	byPeerID map[peer.ID]banEntry
	byIP     map[string]banEntry
}

type banEntry struct {
	until *time.Time // nil = manual/indefinite
}

type strike struct {
	count       int
	lastOffense time.Time
}

// PeerEntryKind identifies which kind of identity a PeerEntry refers to.
type PeerEntryKind int

const (
	// PeerEntryPeerID identifies a peer by its peer ID.
	PeerEntryPeerID PeerEntryKind = iota
	// PeerEntryIP identifies a peer by its IP address.
	PeerEntryIP
)

// PeerEntry is a uniform entry of a peer list (banned or trusted), mirroring
// the capnp PeerEntry type. Until == nil means manual/indefinite (trusted
// entries always have nil Until).
type PeerEntry struct {
	Kind     PeerEntryKind
	Identity string
	Until    *time.Time
}

const (
	// maxPeerListSize bounds each of the keyed maps (per kind per list).
	maxPeerListSize = 7000
	// maxStrikeCount bounds the strike map.
	maxStrikeCount = 7000
	// banDurationBase is D(1): the first-offense ban duration.
	banDurationBase = 24 * time.Hour
	// banDurationMax caps the exponential escalation at 30 days.
	banDurationMax = 30 * 24 * time.Hour
	// strikeWindow is the sliding reset window for strikes.
	strikeWindow = 30 * 24 * time.Hour
)

// banDuration returns D(k) = min(24h * 2^(k-1), 30d) for k >= 1.
func banDuration(k int) time.Duration {
	if k < 1 {
		k = 1
	}
	d := banDurationBase
	for i := 1; i < k; i++ {
		if d >= banDurationMax {
			break
		}
		d *= 2
	}
	if d > banDurationMax {
		return banDurationMax
	}
	return d
}

// banlistDoc is the JSON persistence format (symmetric layout for the banned
// and trusted collections):
//
//	{ "version": 1, "banned": { "peerIds": [...], "ips": [...] },
//	  "trusted": { "peerIds": [...], "ips": [...] } }
//
// Only manual (indefinite) banned entries and the trusted list are persisted.
type banlistDoc struct {
	Version int               `json:"version"`
	Banned  banlistCollection `json:"banned"`
	Trusted banlistCollection `json:"trusted"`
}

type banlistCollection struct {
	PeerIDs []string `json:"peerIds"`
	IPs     []string `json:"ips"`
}

func newPeerList() peerList {
	return peerList{
		byPeerID: make(map[peer.ID]banEntry),
		byIP:     make(map[string]banEntry),
	}
}

// NewBanManager loads the banlist JSON at path and returns a manager ready for
// use. A missing file starts the manager empty. A corrupt/unparseable file or
// an unknown version is renamed to path.bak, logged, and the manager starts
// empty (failure-soft: never crashes, never silently overwrites the corrupt
// file). A single malformed identity is skipped with a log instead of failing
// the whole file.
func NewBanManager(path string, log logging.EventLogger) (*BanManager, error) {
	bm := &BanManager{
		log:     log,
		path:    path,
		now:     time.Now,
		banned:  newPeerList(),
		trusted: newPeerList(),
		strikes: make(map[peer.ID]strike),
	}
	if path == "" {
		return bm, nil
	}
	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			// Missing file: start empty.
			return bm, nil
		}
		// Unreadable (e.g. permissions): treat like corrupt.
		bm.failSoftLoad(err)
		return bm, nil
	}
	var doc banlistDoc
	if err := json.Unmarshal(data, &doc); err != nil {
		bm.failSoftLoad(err)
		return bm, nil
	}
	if doc.Version != 1 {
		bm.failSoftLoad(fmt.Errorf("unknown banlist version %d", doc.Version))
		return bm, nil
	}
	// Banned entries in the JSON are manual (indefinite) by construction.
	for _, pidStr := range doc.Banned.PeerIDs {
		pid, err := peer.Decode(pidStr)
		if err != nil {
			log.Errorf("banlist: skipping unparsable banned peer id %q: %s", pidStr, err)
			continue
		}
		bm.banned.byPeerID[pid] = banEntry{}
	}
	for _, ip := range doc.Banned.IPs {
		bm.banned.byIP[ip] = banEntry{}
	}
	for _, pidStr := range doc.Trusted.PeerIDs {
		pid, err := peer.Decode(pidStr)
		if err != nil {
			log.Errorf("banlist: skipping unparsable trusted peer id %q: %s", pidStr, err)
			continue
		}
		bm.trusted.byPeerID[pid] = banEntry{}
	}
	for _, ip := range doc.Trusted.IPs {
		bm.trusted.byIP[ip] = banEntry{}
	}
	return bm, nil
}

// failSoftLoad renames a corrupt/unreadable banlist file to path.bak and logs
// the error, leaving the manager empty. It never returns an error to the
// caller: the helper must start up regardless.
func (m *BanManager) failSoftLoad(err error) {
	m.log.Errorf("banlist: corrupt banlist file %s, starting empty: %s", m.path, err)
	if rerr := os.Rename(m.path, m.path+".bak"); rerr != nil {
		m.log.Errorf("banlist: failed to rename corrupt banlist file %s to .bak: %s", m.path, rerr)
	}
}

// BanPeer bans a peer, identified by peer ID and optionally IP.
//   - manual == true: manual/indefinite ban, persisted to disk.
//   - manual == false: auto ban; the helper computes its own expiring
//     duration D(k) from the strike map and the current time. Auto bans are
//     in-memory only.
//
// Trusted peers (by peer ID or IP) cannot be banned. The IP may be empty,
// resulting in a peer_id entry only. An already-manually-banned identity is a
// no-op success.
func (m *BanManager) BanPeer(pid peer.ID, ip string, manual bool) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	if m.isTrustedLocked(pid, ip) {
		return fmt.Errorf("trusted peers cannot be banned")
	}

	if manual {
		// Manual ban: upgrade existing entries to manual and persist.
		if err := setEntry(m.banned.byPeerID, pid, banEntry{}, true, m.log); err != nil {
			return err
		}
		if ip != "" {
			if err := setEntry(m.banned.byIP, ip, banEntry{}, true, m.log); err != nil {
				return err
			}
		}
		return m.saveLocked()
	}

	now := m.now()

	// Already manually banned: no-op success.
	if e, has := m.banned.byPeerID[pid]; has && e.until == nil {
		return nil
	}
	if ip != "" {
		if e, has := m.banned.byIP[ip]; has && e.until == nil {
			return nil
		}
	}

	// Strike count for this offense, sliding 30-day window. Re-banning an
	// auto-banned peer increments the strike (the count below already
	// includes this offense) and extends both maps' entries to now + D(k).
	k := m.strikeCountLocked(pid, now)
	untilT := now.Add(banDuration(k))
	e := banEntry{until: &untilT}
	if err := setEntry(m.banned.byPeerID, pid, e, true, m.log); err != nil {
		return err
	}
	if ip != "" {
		if err := setEntry(m.banned.byIP, ip, e, true, m.log); err != nil {
			return err
		}
	}
	// Strike map is bounded; evict the oldest offense when full.
	if _, has := m.strikes[pid]; !has && len(m.strikes) >= maxStrikeCount {
		evictOldestStrike(m.strikes)
	}
	m.strikes[pid] = strike{count: k, lastOffense: now}
	return nil
}

// strikeCountLocked returns the strike count for the peer's current offense:
// the recorded count plus one, or 1 if there is no record or the last offense
// is outside the sliding 30-day window. Old strike entries self-evict when the
// window passes.
func (m *BanManager) strikeCountLocked(pid peer.ID, now time.Time) int {
	s, has := m.strikes[pid]
	if !has || now.Sub(s.lastOffense) > strikeWindow {
		delete(m.strikes, pid)
		return 1
	}
	return s.count + 1
}

// UnbanPeer clears matching entries from both banned maps (peer_id match and,
// when given, IP match) and resets the peer's strike count. Gating lifts
// immediately. Persists the JSON (cheap; unban is a rare operation).
func (m *BanManager) UnbanPeer(pid peer.ID, ip string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.banned.byPeerID, pid)
	delete(m.strikes, pid)
	if ip != "" {
		delete(m.banned.byIP, ip)
	}
	if m.path != "" {
		_ = m.saveLocked()
	}
}

// GetBans returns the merged banned entries from both maps as uniform
// PeerEntry values. Expired auto entries are lazily dropped. Manual entries
// have nil Until.
func (m *BanManager) GetBans() []PeerEntry {
	m.mu.Lock()
	defer m.mu.Unlock()
	return m.peerListToEntriesLocked(&m.banned)
}

func (m *BanManager) peerListToEntriesLocked(pl *peerList) []PeerEntry {
	now := m.now()
	entries := make([]PeerEntry, 0, len(pl.byPeerID)+len(pl.byIP))
	for pid, e := range pl.byPeerID {
		if e.until != nil && !e.until.After(now) {
			delete(pl.byPeerID, pid) // expired auto entry
			continue
		}
		entries = append(entries, PeerEntry{Kind: PeerEntryPeerID, Identity: peer.Encode(pid), Until: e.until})
	}
	for ip, e := range pl.byIP {
		if e.until != nil && !e.until.After(now) {
			delete(pl.byIP, ip)
			continue
		}
		entries = append(entries, PeerEntry{Kind: PeerEntryIP, Identity: ip, Until: e.until})
	}
	return entries
}

// AddTrustedPeer adds the peer (peer ID and optionally IP) to the trusted
// list. Trusted entries are always indefinite and persisted. Trusted maps are
// operator-bounded with no eviction.
func (m *BanManager) AddTrustedPeer(pid peer.ID, ip string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if err := setEntry(m.trusted.byPeerID, pid, banEntry{}, false, m.log); err != nil {
		return err
	}
	if ip != "" {
		if err := setEntry(m.trusted.byIP, ip, banEntry{}, false, m.log); err != nil {
			return err
		}
	}
	return m.saveLocked()
}

// RemoveTrustedPeer removes the peer (peer ID and optionally IP) from the
// trusted list, persisting the change.
func (m *BanManager) RemoveTrustedPeer(pid peer.ID, ip string) {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.trusted.byPeerID, pid)
	if ip != "" {
		delete(m.trusted.byIP, ip)
	}
	if m.path != "" {
		_ = m.saveLocked()
	}
}

// GetTrustedPeers returns the trusted entries as uniform PeerEntry values
// (Until always nil).
func (m *BanManager) GetTrustedPeers() []PeerEntry {
	m.mu.RLock()
	defer m.mu.RUnlock()
	entries := make([]PeerEntry, 0, len(m.trusted.byPeerID)+len(m.trusted.byIP))
	for pid := range m.trusted.byPeerID {
		entries = append(entries, PeerEntry{Kind: PeerEntryPeerID, Identity: peer.Encode(pid)})
	}
	for ip := range m.trusted.byIP {
		entries = append(entries, PeerEntry{Kind: PeerEntryIP, Identity: ip})
	}
	return entries
}

// IsTrusted reports whether the peer ID or IP is in the trusted list.
func (m *BanManager) IsTrusted(pid peer.ID, ip string) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.isTrustedLocked(pid, ip)
}

func (m *BanManager) isTrustedLocked(pid peer.ID, ip string) bool {
	if _, has := m.trusted.byPeerID[pid]; has {
		return true
	}
	if ip != "" {
		if _, has := m.trusted.byIP[ip]; has {
			return true
		}
	}
	return false
}

// IsBanned reports whether the peer is banned (its IP is banned OR its peer
// ID is banned), expiry-aware: an expired auto entry is not banned and is
// lazily dropped.
func (m *BanManager) IsBanned(pid peer.ID, ip string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	now := m.now()
	if e, has := m.banned.byPeerID[pid]; has {
		if e.until == nil || e.until.After(now) {
			return true
		}
		delete(m.banned.byPeerID, pid) // expired auto entry
	}
	if ip != "" {
		if e, has := m.banned.byIP[ip]; has {
			if e.until == nil || e.until.After(now) {
				return true
			}
			delete(m.banned.byIP, ip)
		}
	}
	return false
}

// setEntry writes an entry into a keyed map, enforcing the size cap. When the
// map is full, evicts the soonest-expiring auto entry; if there is none (all
// manual), returns an error. With evict=false (trusted lists) a full map
// always errors. Updating an existing key never evicts.
func setEntry[K comparable](m map[K]banEntry, key K, e banEntry, evict bool, log logging.EventLogger) error {
	if _, has := m[key]; has {
		m[key] = e
		return nil
	}
	if len(m) >= maxPeerListSize {
		if !evict || !evictSoonestExpiring(m, log) {
			return fmt.Errorf("peer list is full (%d entries)", maxPeerListSize)
		}
	}
	m[key] = e
	return nil
}

// evictSoonestExpiring removes the auto entry (non-nil until) with the
// earliest expiry from the map. Returns false when there is no auto entry.
func evictSoonestExpiring[K comparable](m map[K]banEntry, log logging.EventLogger) bool {
	var (
		victim    K
		victimSet bool
		minUntil  time.Time
	)
	for k, e := range m {
		if e.until == nil {
			continue
		}
		if !victimSet || e.until.Before(minUntil) {
			victim = k
			minUntil = *e.until
			victimSet = true
		}
	}
	if !victimSet {
		return false
	}
	delete(m, victim)
	log.Infof("banlist: peer list full; evicted expiring ban (until %s)", minUntil)
	return true
}

// evictOldestStrike removes the strike entry with the oldest last offense,
// enforcing the strike-map cap.
func evictOldestStrike(m map[peer.ID]strike) {
	var (
		victim peer.ID
		oldest time.Time
		found  bool
	)
	for pid, s := range m {
		if !found || s.lastOffense.Before(oldest) {
			victim = pid
			oldest = s.lastOffense
			found = true
		}
	}
	if found {
		delete(m, victim)
	}
}

// saveLocked atomically writes the persisted state (manual bans + trusted
// list) to the banlist path via a temp file in the same directory and rename.
func (m *BanManager) saveLocked() error {
	if m.path == "" {
		return nil
	}
	doc := banlistDoc{Version: 1, Banned: banlistCollection{}, Trusted: banlistCollection{}}
	for pid, e := range m.banned.byPeerID {
		if e.until == nil {
			doc.Banned.PeerIDs = append(doc.Banned.PeerIDs, peer.Encode(pid))
		}
	}
	for ip, e := range m.banned.byIP {
		if e.until == nil {
			doc.Banned.IPs = append(doc.Banned.IPs, ip)
		}
	}
	for pid := range m.trusted.byPeerID {
		doc.Trusted.PeerIDs = append(doc.Trusted.PeerIDs, peer.Encode(pid))
	}
	for ip := range m.trusted.byIP {
		doc.Trusted.IPs = append(doc.Trusted.IPs, ip)
	}
	// Deterministic output.
	sort.Strings(doc.Banned.PeerIDs)
	sort.Strings(doc.Banned.IPs)
	sort.Strings(doc.Trusted.PeerIDs)
	sort.Strings(doc.Trusted.IPs)

	tmp, err := os.CreateTemp(filepath.Dir(m.path), "libp2p_banlist-*.json")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer func() {
		_ = os.Remove(tmpName)
	}()
	enc := json.NewEncoder(tmp)
	enc.SetIndent("", "  ")
	if err := enc.Encode(doc); err != nil {
		_ = tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, m.path)
}
