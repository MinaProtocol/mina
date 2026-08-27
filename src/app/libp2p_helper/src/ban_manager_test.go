package codanet

import (
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	logging "github.com/ipfs/go-log/v2"
	peer "github.com/libp2p/go-libp2p/core/peer"
	mh "github.com/multiformats/go-multihash"
	"github.com/stretchr/testify/require"
)

// fakeClock is an injectable clock for deterministic ban expiry tests.
type fakeClock struct {
	mu sync.Mutex
	t  time.Time
}

func newFakeClock(t0 time.Time) *fakeClock { return &fakeClock{t: t0} }

func (c *fakeClock) Now() time.Time {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.t
}

func (c *fakeClock) Advance(d time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.t = c.t.Add(d)
}

// testPeerID returns a distinct, valid (Encode/Decode round-trippable) peer
// ID for index i.
func testPeerID(i int) peer.ID {
	h := sha256.Sum256([]byte(fmt.Sprintf("test-peer-%d", i)))
	b, err := mh.Sum(h[:], mh.SHA2_256, -1)
	if err != nil {
		panic(err)
	}
	return peer.ID(b)
}

// newTestBanManager creates a manager with an empty (or disposable) banlist
// path and a controllable clock.
func newTestBanManager(t *testing.T) (*BanManager, *fakeClock) {
	t.Helper()
	bm, err := NewBanManager(filepath.Join(t.TempDir(), "libp2p_banlist.json"), logging.Logger("test"))
	require.NoError(t, err)
	clock := newFakeClock(time.Date(2026, 8, 18, 0, 0, 0, 0, time.UTC))
	bm.now = clock.Now
	return bm, clock
}

func newPathTestBanManager(t *testing.T, path string) *BanManager {
	t.Helper()
	bm, err := NewBanManager(path, logging.Logger("test"))
	require.NoError(t, err)
	bm.now = time.Now
	return bm
}

// untilOf returns the non-nil expiry shared by all GetBans entries (a ban
// writes both a peer_id and an IP entry with the same expiry).
func untilOf(t *testing.T, bm *BanManager) time.Time {
	t.Helper()
	entries := bm.GetBans()
	require.NotEmpty(t, entries)
	var until *time.Time
	for _, e := range entries {
		require.NotNil(t, e.Until, "expected auto entries with an expiry")
		if until == nil {
			until = e.Until
		} else {
			require.Equal(t, *until, *e.Until)
		}
	}
	return *until
}

func TestBanDuration(t *testing.T) {
	require.Equal(t, 24*time.Hour, banDuration(1))
	require.Equal(t, 48*time.Hour, banDuration(2))
	require.Equal(t, 96*time.Hour, banDuration(3))
	require.Equal(t, 192*time.Hour, banDuration(4))
	require.Equal(t, 384*time.Hour, banDuration(5))
	// 24h * 2^5 = 768h = 32d > 30d cap.
	require.Equal(t, 30*24*time.Hour, banDuration(6))
	require.Equal(t, 30*24*time.Hour, banDuration(100))
	// Defensive: k < 1 behaves like the first offense.
	require.Equal(t, 24*time.Hour, banDuration(0))
}

func TestBanManagerEscalationAndExtendOnReban(t *testing.T) {
	bm, clock := newTestBanManager(t)
	t0 := clock.Now()
	pid := testPeerID(1)

	require.NoError(t, bm.BanPeer(pid, "1.2.3.4", false)) // manual=false => auto ban
	require.Equal(t, t0.Add(24*time.Hour), untilOf(t, bm))

	// Re-ban while already auto-banned: extend + escalate 24h -> 48h.
	require.NoError(t, bm.BanPeer(pid, "1.2.3.4", false))
	require.Equal(t, t0.Add(48*time.Hour), untilOf(t, bm))

	// And 48h -> 96h.
	require.NoError(t, bm.BanPeer(pid, "1.2.3.4", false))
	require.Equal(t, t0.Add(96*time.Hour), untilOf(t, bm))

	// The expiry was extended into the future beyond the current time.
	clock.Advance(50 * time.Hour)
	require.True(t, untilOf(t, bm).After(clock.Now()))
}

func TestBanManagerEscalationCap(t *testing.T) {
	bm, clock := newTestBanManager(t)
	pid := testPeerID(2)

	for i := 0; i < 20; i++ {
		require.NoError(t, bm.BanPeer(pid, "5.6.7.8", false))
	}
	until := untilOf(t, bm)
	require.LessOrEqual(t, until.Sub(clock.Now()), 30*24*time.Hour)
}

func TestBanManagerStrikeWindowReset(t *testing.T) {
	bm, clock := newTestBanManager(t)
	t0 := clock.Now()
	pid := testPeerID(3)

	require.NoError(t, bm.BanPeer(pid, "", false))
	require.Equal(t, t0.Add(24*time.Hour), untilOf(t, bm))

	// A second offense within the 30-day window escalates to 48h.
	clock.Advance(10 * 24 * time.Hour)
	t1 := clock.Now()
	require.NoError(t, bm.BanPeer(pid, "", false))
	require.Equal(t, t1.Add(48*time.Hour), untilOf(t, bm))

	// An offense more than 30 days after the last resets the count to 1.
	clock.Advance(40 * 24 * time.Hour)
	t2 := clock.Now()
	require.NoError(t, bm.BanPeer(pid, "", false))
	require.Equal(t, t2.Add(24*time.Hour), untilOf(t, bm))
}

func TestBanManagerUnbanResetsStrikesAndLiftsGating(t *testing.T) {
	bm, clock := newTestBanManager(t)
	pid := testPeerID(4)

	require.NoError(t, bm.BanPeer(pid, "9.9.9.9", false))
	require.True(t, bm.IsBanned(pid, "9.9.9.9"))
	require.True(t, bm.IsBanned(pid, "")) // pid entry too

	bm.UnbanPeer(pid, "9.9.9.9")
	require.False(t, bm.IsBanned(pid, "9.9.9.9"))
	require.False(t, bm.IsBanned(pid, ""))
	require.Empty(t, bm.GetBans())

	// Unban resets the strike count: the next ban is a first offense (24h).
	clock.Advance(time.Hour)
	t1 := clock.Now()
	require.NoError(t, bm.BanPeer(pid, "9.9.9.9", false))
	require.Equal(t, t1.Add(24*time.Hour), untilOf(t, bm))
}

func TestBanManagerUnbanByPeerIDOnly(t *testing.T) {
	bm, _ := newTestBanManager(t)
	pid := testPeerID(5)

	require.NoError(t, bm.BanPeer(pid, "1.1.1.1", false))
	// Unbanning without the IP clears the peer_id entry but leaves the IP ban.
	bm.UnbanPeer(pid, "")
	require.False(t, bm.IsBanned(pid, ""))
	require.True(t, bm.IsBanned(pid, "1.1.1.1"))
}

func TestBanManagerManualBan(t *testing.T) {
	bm, _ := newTestBanManager(t)
	pid := testPeerID(6)

	require.NoError(t, bm.BanPeer(pid, "2.2.2.2", true)) // manual
	entries := bm.GetBans()
	require.Len(t, entries, 2)
	for _, e := range entries {
		require.Nil(t, e.Until, "manual bans have nil Until")
	}
	require.True(t, bm.IsBanned(pid, "2.2.2.2"))

	// Auto-ban of an already-manually-banned identity is a no-op success.
	require.NoError(t, bm.BanPeer(pid, "2.2.2.2", false))
	for _, e := range bm.GetBans() {
		require.Nil(t, e.Until, "manual ban must not be downgraded to auto")
	}
}

func TestBanManagerManualUpgradesAuto(t *testing.T) {
	bm, _ := newTestBanManager(t)
	pid := testPeerID(7)

	require.NoError(t, bm.BanPeer(pid, "3.3.3.3", false))
	require.NotNil(t, untilOf(t, bm))

	// A manual ban of an auto-banned identity upgrades it to indefinite.
	require.NoError(t, bm.BanPeer(pid, "3.3.3.3", true))
	for _, e := range bm.GetBans() {
		require.Nil(t, e.Until)
	}
}

func TestBanManagerORCombinedGating(t *testing.T) {
	bm, _ := newTestBanManager(t)

	// Banned by IP only.
	pidA := testPeerID(8)
	require.NoError(t, bm.BanPeer(pidA, "10.0.0.1", false))
	require.True(t, bm.IsBanned(pidA, "10.0.0.1"))
	require.True(t, bm.IsBanned(testPeerID(8001), "10.0.0.1"), "IP ban catches other peer IDs behind it")

	// Banned by peer ID only.
	pidB := testPeerID(9)
	require.NoError(t, bm.BanPeer(pidB, "10.0.0.2", false))
	require.True(t, bm.IsBanned(pidB, ""))
	require.True(t, bm.IsBanned(pidB, "10.0.0.2"))
	require.False(t, bm.IsBanned(testPeerID(9001), "10.0.0.99"), "peer_id ban does not catch a different IP")
	require.True(t, bm.IsBanned(testPeerID(9001), "10.0.0.2"), "peer on a banned IP is banned")
}

func TestBanManagerExpiredAutoNotBanned(t *testing.T) {
	bm, clock := newTestBanManager(t)
	pid := testPeerID(10)

	require.NoError(t, bm.BanPeer(pid, "4.4.4.4", false))
	require.True(t, bm.IsBanned(pid, "4.4.4.4"))

	clock.Advance(25 * time.Hour)
	require.False(t, bm.IsBanned(pid, "4.4.4.4"), "expired auto ban is not banned")
	require.Empty(t, bm.GetBans(), "expired auto entries are lazily dropped")
}

func TestBanManagerTrustedRejection(t *testing.T) {
	bm, _ := newTestBanManager(t)
	pid := testPeerID(11)

	require.NoError(t, bm.AddTrustedPeer(pid, "8.8.8.8"))
	require.Error(t, bm.BanPeer(pid, "8.8.8.8", false), "trusted peer cannot be banned")
	require.Error(t, bm.BanPeer(pid, "", true), "trusted peer cannot be banned")

	// Trusted by IP alone also protects.
	pid2 := testPeerID(12)
	require.NoError(t, bm.AddTrustedPeer(pid2, "8.8.8.8"))
	require.Error(t, bm.BanPeer(pid2, "8.8.8.8", false))
}

func TestBanManagerTrustedWinsAtGating(t *testing.T) {
	bm, _ := newTestBanManager(t)
	pid := testPeerID(13)

	require.NoError(t, bm.BanPeer(pid, "7.7.7.7", false))
	require.True(t, bm.IsBanned(pid, "7.7.7.7"))

	// Trusting an already-banned peer lifts gating immediately.
	require.NoError(t, bm.AddTrustedPeer(pid, "7.7.7.7"))
	require.True(t, bm.IsTrusted(pid, "7.7.7.7"))
	// The ban stays recorded, but gating is trusted-first, so it is allowed.
	require.True(t, bm.IsBanned(pid, "7.7.7.7"))
}

func TestBanManagerBoundedEviction(t *testing.T) {
	bm, clock := newTestBanManager(t)

	// Fill the peer_id map with auto bans at increasing times. The first ban
	// is the soonest-expiring.
	for i := 0; i < maxPeerListSize; i++ {
		require.NoError(t, bm.BanPeer(testPeerID(i), "", false))
		clock.Advance(time.Millisecond)
	}
	require.Len(t, bm.GetBans(), maxPeerListSize)

	// One more ban evicts the soonest-expiring auto entry (the first ban).
	require.NoError(t, bm.BanPeer(testPeerID(maxPeerListSize), "", false))
	entries := bm.GetBans()
	require.Len(t, entries, maxPeerListSize)
	require.False(t, bm.IsBanned(testPeerID(0), ""), "first (soonest-expiring) ban was evicted")
	require.True(t, bm.IsBanned(testPeerID(maxPeerListSize), ""))
}

func TestBanManagerFullManualRejects(t *testing.T) {
	bm, _ := newTestBanManager(t)
	// Fill the peer_id map with manual entries (no eviction allowed).
	for i := 0; i < maxPeerListSize; i++ {
		bm.banned.byPeerID[testPeerID(i)] = banEntry{}
	}
	require.Error(t, bm.BanPeer(testPeerID(maxPeerListSize), "", true))
}

func TestBanManagerFullManualRejectsAuto(t *testing.T) {
	bm, _ := newTestBanManager(t)
	for i := 0; i < maxPeerListSize; i++ {
		bm.banned.byPeerID[testPeerID(i)] = banEntry{}
	}
	require.Error(t, bm.BanPeer(testPeerID(maxPeerListSize), "", false))
}

func TestBanManagerTrustedCapNoEviction(t *testing.T) {
	bm, _ := newTestBanManager(t)
	for i := 0; i < maxPeerListSize; i++ {
		bm.trusted.byPeerID[testPeerID(i)] = banEntry{}
	}
	require.Error(t, bm.AddTrustedPeer(testPeerID(maxPeerListSize), ""))
	require.Len(t, bm.GetTrustedPeers(), maxPeerListSize)
}

func TestBanManagerStrikeCap(t *testing.T) {
	bm, clock := newTestBanManager(t)
	now := clock.Now()
	// One strike per distinct peer: the oldest offense is evicted when full.
	for i := 0; i < maxStrikeCount; i++ {
		require.NoError(t, bm.BanPeer(testPeerID(100000+i), "", false))
		clock.Advance(time.Millisecond)
	}
	require.Len(t, bm.strikes, maxStrikeCount)
	now = clock.Now()
	require.NoError(t, bm.BanPeer(testPeerID(999999), "", false))
	require.Len(t, bm.strikes, maxStrikeCount)
	// The evicted strike belonged to the oldest offense.
	_, has := bm.strikes[testPeerID(100000)]
	require.False(t, has, "oldest strike evicted")
	// The fresh offense counts as strike 1 and gets a 24h ban.
	s, has := bm.strikes[testPeerID(999999)]
	require.True(t, has)
	require.Equal(t, 1, s.count)
	// The eviction also removed the oldest ban from the banned map.
	require.False(t, bm.IsBanned(testPeerID(100000), ""))
	for _, e := range bm.GetBans() {
		if e.Kind == PeerEntryPeerID && e.Identity == peer.Encode(testPeerID(999999)) {
			require.Equal(t, now.Add(24*time.Hour), *e.Until)
			return
		}
	}
	t.Fatal("newest ban not found in GetBans")
}

func TestBanManagerJSONRoundTrip(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "libp2p_banlist.json")

	bm := newPathTestBanManager(t, path)
	pid := testPeerID(20)
	require.NoError(t, bm.BanPeer(pid, "1.1.1.1", true)) // manual ban
	require.NoError(t, bm.AddTrustedPeer(testPeerID(21), "2.2.2.2"))
	require.FileExists(t, path)

	// Symmetric layout with manual bans + trusted list.
	data, err := os.ReadFile(path)
	require.NoError(t, err)
	var doc banlistDoc
	require.NoError(t, json.Unmarshal(data, &doc))
	require.Equal(t, 1, doc.Version)
	require.ElementsMatch(t, []string{peer.Encode(pid)}, doc.Banned.PeerIDs)
	require.ElementsMatch(t, []string{"1.1.1.1"}, doc.Banned.IPs)
	require.ElementsMatch(t, []string{peer.Encode(testPeerID(21))}, doc.Trusted.PeerIDs)
	require.ElementsMatch(t, []string{"2.2.2.2"}, doc.Trusted.IPs)

	// Auto bans are never persisted.
	require.NoError(t, bm.BanPeer(testPeerID(22), "3.3.3.3", false))
	data, err = os.ReadFile(path)
	require.NoError(t, err)
	require.NoError(t, json.Unmarshal(data, &doc))
	require.NotContains(t, doc.Banned.PeerIDs, peer.Encode(testPeerID(22)))

	// Load at startup reconstructs manual bans and the trusted list.
	bm2 := newPathTestBanManager(t, path)
	require.True(t, bm2.IsBanned(pid, "1.1.1.1"))
	require.True(t, bm2.IsTrusted(testPeerID(21), "2.2.2.2"))
	require.False(t, bm2.IsTrusted(testPeerID(22), "3.3.3.3"))

	// Unban + remove trusted persist.
	bm2.UnbanPeer(pid, "1.1.1.1")
	bm2.RemoveTrustedPeer(testPeerID(21), "2.2.2.2")
	bm3 := newPathTestBanManager(t, path)
	require.False(t, bm3.IsBanned(pid, "1.1.1.1"))
	require.False(t, bm3.IsTrusted(testPeerID(21), "2.2.2.2"))
}

func TestBanManagerMissingFileStartsEmpty(t *testing.T) {
	bm := newPathTestBanManager(t, filepath.Join(t.TempDir(), "does-not-exist.json"))
	require.Empty(t, bm.GetBans())
	require.Empty(t, bm.GetTrustedPeers())
}

func TestBanManagerCorruptFileRenamedAndEmpty(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "libp2p_banlist.json")
	require.NoError(t, os.WriteFile(path, []byte("{ not valid json "), 0644))

	bm := newPathTestBanManager(t, path)
	require.Empty(t, bm.GetBans())
	require.FileExists(t, path+".bak", "corrupt file renamed to .bak, never silently overwritten")
	require.False(t, fileExists(path))
}

func TestBanManagerUnknownVersionRenamedAndEmpty(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "libp2p_banlist.json")
	require.NoError(t, os.WriteFile(path, []byte(`{"version": 99, "banned": {"peerIds": [], "ips": []}, "trusted": {"peerIds": [], "ips": []}}`), 0644))

	bm := newPathTestBanManager(t, path)
	require.Empty(t, bm.GetBans())
	require.FileExists(t, path+".bak")
}

func TestBanManagerMalformedIdentitySkipped(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "libp2p_banlist.json")
	// One valid and one unparsable peer id in the banned list.
	require.NoError(t, os.WriteFile(path, []byte(`{"version": 1, "banned": {"peerIds": ["12D3KooWJDGPa2hiYCJ2o7XPqEq2tjrWpFJzqa4dy538Gfs7Vn2r", "%%%not-a-peer-id%%%"], "ips": ["1.1.1.1"]}, "trusted": {"peerIds": [], "ips": []}}`), 0644))

	bm := newPathTestBanManager(t, path)
	require.True(t, bm.IsBanned(testPeerID(0), "1.1.1.1"), "IP ban loaded")
	// The valid peer id should be loaded.
	validPID, err := peer.Decode("12D3KooWJDGPa2hiYCJ2o7XPqEq2tjrWpFJzqa4dy538Gfs7Vn2r")
	require.NoError(t, err)
	require.True(t, bm.IsBanned(validPID, ""))
	// Only two banned entries: the valid peer id and the IP.
	require.Len(t, bm.GetBans(), 2)
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}
