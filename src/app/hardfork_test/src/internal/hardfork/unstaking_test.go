package hardfork

import (
	"encoding/json"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/currency"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/utils"
)

func testHarness(cfg *config.Config) *HardforkTest {
	return &HardforkTest{Config: cfg, Logger: utils.NewLogger()}
}

func TestComputeSlotOccupancy(t *testing.T) {
	t.Parallel()
	ht := testHarness(config.DefaultConfig())

	// Genesis anchor at height 1 / slot 0 excluded from the denominator; 15
	// blocks over the (0, 30] window = 0.5.
	occ, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 1, Slot: 0},
		client.BlockData{BlockHeight: 16, Slot: 30},
		30,
	)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if occ != 0.5 {
		t.Errorf("occupancy = %f, want 0.5", occ)
	}

	// The boundary, not the last block, sets the denominator. The last block
	// sits at slot 28 but the window runs to slot 30, so the two empty trailing
	// slots must lower occupancy (15/30 = 0.5), not be dropped (15/28 ≈ 0.536).
	occ, err = ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 1, Slot: 0},
		client.BlockData{BlockHeight: 16, Slot: 28},
		30,
	)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if occ != 0.5 {
		t.Errorf("occupancy with trailing empty slots = %f, want 0.5 (empty slots must not be dropped)", occ)
	}

	// A fully filled window is 1.0: every slot after the genesis anchor produced
	// a block, and the last block coincides with the boundary.
	occ, err = ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 1, Slot: 0},
		client.BlockData{BlockHeight: 31, Slot: 30},
		30,
	)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if occ != 1.0 {
		t.Errorf("fully filled window occupancy = %f, want 1.0", occ)
	}

	if _, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 5, Slot: 0},
		client.BlockData{BlockHeight: 5, Slot: 30},
		30,
	); err == nil {
		t.Error("expected error when start and last block have the same height")
	}

	// Swapped arguments must error, not return a negative or infinite value
	if _, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 16, Slot: 30},
		client.BlockData{BlockHeight: 1, Slot: 0},
		30,
	); err == nil {
		t.Error("expected error when last block is not after starting block")
	}
	if _, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 1, Slot: 10},
		client.BlockData{BlockHeight: 5, Slot: 10},
		30,
	); err == nil {
		t.Error("expected error when both blocks are at the same slot")
	}

	// A boundary before the last observed block is a caller error: blocks would
	// live past the window boundary and the numerator would over-count.
	if _, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 1, Slot: 0},
		client.BlockData{BlockHeight: 16, Slot: 30},
		28,
	); err == nil {
		t.Error("expected error when boundary slot is before the last block's slot")
	}
}

func TestActiveShares(t *testing.T) {
	t.Parallel()

	// CI-shaped config: 28.5% active pre-fork; after unstaking the 71.5% lazy
	// stake the active share is nearly the whole remaining denominator.
	stats := StakeStats{TotalCurrency: 1000, ActiveProducerStake: 285, LazyStake: 715}

	pre, err := preForkActiveShare(stats)
	if err != nil {
		t.Fatalf("preForkActiveShare: %v", err)
	}
	if math.Abs(pre-0.285) > 1e-9 {
		t.Errorf("preForkActiveShare = %f, want 0.285", pre)
	}

	post, err := postForkActiveShare(stats)
	if err != nil {
		t.Fatalf("postForkActiveShare: %v", err)
	}
	if want := 285.0 / (1000.0 - 715.0); math.Abs(post-want) > 1e-9 {
		t.Errorf("postForkActiveShare = %f, want %f", post, want)
	}
	// Post-fork share must exceed pre-fork share (denominator shrank).
	if post <= pre {
		t.Errorf("post-fork active share %f should exceed pre-fork %f", post, pre)
	}

	// Zero total currency must error, not divide by zero.
	if _, err := preForkActiveShare(StakeStats{}); err == nil {
		t.Error("expected error for zero total currency (pre)")
	}
	// Lazy stake >= total would make the post-fork denominator non-positive.
	if _, err := postForkActiveShare(StakeStats{TotalCurrency: 100, LazyStake: 100}); err == nil {
		t.Error("expected error when lazy stake is not below total currency")
	}
}

func TestValidateActiveProducerLiveness(t *testing.T) {
	t.Parallel()

	// CI-shaped partition: active + lazy = total.
	stats := StakeStats{TotalCurrency: 1000, ActiveProducerStake: 285, LazyStake: 715}
	running := map[string]bool{"A": true, "B": true}

	// Both running producers produced blocks (plus an empty-slot signature is
	// irrelevant): passes.
	if err := validateActiveProducerLiveness(running, map[string]bool{"A": true, "B": true}, stats); err != nil {
		t.Errorf("expected pass when every running producer authored a block, got %v", err)
	}

	// A running producer that never produced a block (B died): must fail.
	if err := validateActiveProducerLiveness(running, map[string]bool{"A": true}, stats); err == nil {
		t.Error("expected failure when a running producer authored no blocks (dead producer)")
	}

	// A block creator that is not a known running producer: must fail.
	if err := validateActiveProducerLiveness(running, map[string]bool{"A": true, "B": true, "C": true}, stats); err == nil {
		t.Error("expected failure when an unexpected key produced a block (rogue producer)")
	}

	// Partition overcount: active + lazy exceeds total, even with liveness OK.
	overcount := StakeStats{TotalCurrency: 1000, ActiveProducerStake: 600, LazyStake: 500}
	if err := validateActiveProducerLiveness(running, map[string]bool{"A": true, "B": true}, overcount); err == nil {
		t.Error("expected failure when active + lazy stake exceeds total currency")
	}

	// Exact partition (active + lazy == total) is allowed.
	exact := StakeStats{TotalCurrency: 1000, ActiveProducerStake: 300, LazyStake: 700}
	if err := validateActiveProducerLiveness(running, map[string]bool{"A": true, "B": true}, exact); err != nil {
		t.Errorf("expected pass when active + lazy == total, got %v", err)
	}
}

func TestNewOccupancyBand(t *testing.T) {
	t.Parallel()

	// Band is centered on Expected with half-width windowMargin, clamped to [0,1].
	band, err := newOccupancyBand(0.324, 30)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	wantMargin, _ := windowMargin(0.324, 30, occupancyBandZ)
	if math.Abs(band.Margin-wantMargin) > 1e-9 {
		t.Errorf("Margin = %f, want %f", band.Margin, wantMargin)
	}
	if math.Abs(band.Lower-(0.324-wantMargin)) > 1e-9 || math.Abs(band.Upper-(0.324+wantMargin)) > 1e-9 {
		t.Errorf("band = [%f, %f], want [%f, %f]", band.Lower, band.Upper, 0.324-wantMargin, 0.324+wantMargin)
	}

	// Edges clamp to [0,1]: a huge margin cannot push Lower below 0 or Upper above 1.
	wide, err := newOccupancyBand(0.75, 1) // margin = 3*sqrt(0.1875) ~= 1.3 > 0.75
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if wide.Lower < 0 || wide.Upper > 1 {
		t.Errorf("band edges not clamped: [%f, %f]", wide.Lower, wide.Upper)
	}

	// Non-positive window propagates the windowMargin error.
	if _, err := newOccupancyBand(0.324, 0); err == nil {
		t.Error("expected error for a zero-slot window")
	}
}

// TestOccupancyBandDecisions exercises the assembled pre/post-fork bounds
// against representative occupancy values: in-band pass, too-high / too-low
// fail, and the partial-recovery case whose detection depends on window length.
func TestOccupancyBandDecisions(t *testing.T) {
	t.Parallel()

	stats := StakeStats{TotalCurrency: 1000, ActiveProducerStake: 285, LazyStake: 715}

	// Pre-fork band (~0.324 expected) over a 30-slot window.
	sPre, _ := preForkActiveShare(stats)
	pre, err := newOccupancyBand(expectedFillRate(sPre), 30)
	if err != nil {
		t.Fatalf("pre band: %v", err)
	}
	if !(pre.Lower < 0.33 && 0.33 < pre.Upper) {
		t.Errorf("expected 0.33 in pre band [%f, %f]", pre.Lower, pre.Upper)
	}
	if 0.62 <= pre.Upper {
		t.Errorf("expected 0.62 above pre band upper %f (dilution-didn't-take)", pre.Upper)
	}
	if 0.05 >= pre.Lower {
		t.Errorf("expected 0.05 below pre band lower %f (over-suppressed)", pre.Lower)
	}

	// Post-fork lower bound (~0.75 expected). At n=30 the bound is ~0.51, so a
	// 0.55 partial recovery still passes; a longer n=60 window tightens the
	// bound above 0.55 and catches it.
	sPost, _ := postForkActiveShare(stats)
	post30, err := newOccupancyBand(expectedFillRate(sPost), 30)
	if err != nil {
		t.Fatalf("post band n=30: %v", err)
	}
	if !(0.55 >= post30.Lower) {
		t.Errorf("at n=30 the 0.55 partial recovery should pass (lower %f)", post30.Lower)
	}
	post60, err := newOccupancyBand(expectedFillRate(sPost), 60)
	if err != nil {
		t.Fatalf("post band n=60: %v", err)
	}
	if !(0.55 < post60.Lower) {
		t.Errorf("at n=60 the 0.55 partial recovery should fail (lower %f)", post60.Lower)
	}
	if post60.Lower >= post60.Expected {
		t.Errorf("post lower bound %f should be below expected %f", post60.Lower, post60.Expected)
	}
}

func TestExpectedFillRate(t *testing.T) {
	t.Parallel()

	cases := []struct {
		sActive float64
		want    float64
	}{
		{0.0, 0.0},                         // no active stake: no slot can be won
		{1.0, vrfFillFraction},             // full stake active: saturates at f = 0.75
		{0.285, 1 - math.Pow(0.25, 0.285)}, // CI config (2 active + 5 lazy whales)
	}
	for _, tc := range cases {
		if got := expectedFillRate(tc.sActive); math.Abs(got-tc.want) > 1e-9 {
			t.Errorf("expectedFillRate(%f) = %f, want %f", tc.sActive, got, tc.want)
		}
	}

	// Monotonic increasing in the active share
	prev := expectedFillRate(0)
	for _, s := range []float64{0.1, 0.3, 0.5, 0.9, 1.0} {
		cur := expectedFillRate(s)
		if cur <= prev {
			t.Errorf("expectedFillRate not increasing: f(%f)=%f <= previous %f", s, cur, prev)
		}
		prev = cur
	}
}

func TestWindowMargin(t *testing.T) {
	t.Parallel()

	// CI config sanity check: sActive ~= 0.285, n = 30, z = 3.
	// p ~= 0.324, sigma = sqrt(p(1-p)/30) ~= 0.0855, margin ~= 0.256.
	p := expectedFillRate(0.285)
	margin, err := windowMargin(p, 30, occupancyBandZ)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := occupancyBandZ * math.Sqrt(p*(1-p)/30)
	if math.Abs(margin-want) > 1e-9 {
		t.Errorf("windowMargin(%f, 30, %f) = %f, want %f", p, occupancyBandZ, margin, want)
	}
	if margin < 0.24 || margin > 0.27 {
		t.Errorf("CI-config margin = %f, expected ~0.256", margin)
	}

	// Monotonic decreasing in n: a longer window gives a tighter band.
	var last float64 = math.Inf(1)
	for _, n := range []int{5, 10, 30, 90, 200} {
		m, err := windowMargin(p, n, occupancyBandZ)
		if err != nil {
			t.Fatalf("unexpected error at n=%d: %v", n, err)
		}
		if m >= last {
			t.Errorf("margin not decreasing in n: margin(n=%d)=%f >= previous %f", n, m, last)
		}
		last = m
	}

	// Edge: p = 0 (sActive = 0) and p = 1 both give zero variance, zero margin.
	for _, edge := range []float64{0.0, 1.0} {
		m, err := windowMargin(edge, 30, occupancyBandZ)
		if err != nil {
			t.Fatalf("unexpected error for p=%f: %v", edge, err)
		}
		if math.Abs(m) > 1e-9 {
			t.Errorf("windowMargin(%f, 30, z) = %f, want 0", edge, m)
		}
	}

	// Non-positive window must error, not divide by zero or return NaN.
	for _, n := range []int{0, -1} {
		if _, err := windowMargin(p, n, occupancyBandZ); err == nil {
			t.Errorf("windowMargin(p, %d, z) should have errored", n)
		}
	}
}

func TestUnstakedTotal(t *testing.T) {
	t.Parallel()

	// BlockData amounts are nanomina uint64s, parsed from the GraphQL string
	// scalars at construction. The minuend is the PRE-FORK genesis total (the
	// fork genesis block's own totalCurrency additionally contains pre-fork
	// coinbases and must not be used).
	preFork := client.BlockData{TotalCurrency: 80853498000000000}
	forkGenesis := client.BlockData{StakingLedgerTotalCurrency: 23103498000000000}
	got, err := UnstakedTotal(preFork, forkGenesis)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if want := currency.Nanomina(57_750_000_000_000_000); got != want {
		t.Errorf("UnstakedTotal = %d, want %d", got, want)
	}

	// Fork staking total above the pre-fork genesis total is nonsense
	if _, err := UnstakedTotal(
		client.BlockData{TotalCurrency: 100},
		client.BlockData{StakingLedgerTotalCurrency: 101},
	); err == nil {
		t.Error("expected error when staked exceeds total")
	}
}

func writePubkey(t *testing.T, dir, name, pk string) {
	t.Helper()
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, name), []byte(pk+"\n"), 0644); err != nil {
		t.Fatal(err)
	}
}

func TestLazyWhalePksAndComputeStakeStats(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	cfg := config.DefaultConfig()
	cfg.Root = root
	cfg.NumWhales = 1
	cfg.NumLazyWhales = 2
	cfg.NumFish = 0
	ht := testHarness(cfg)

	// Whale 0 is active, whales 1 and 2 are lazy
	for i, pk := range []string{"B62qoffline0", "B62qoffline1", "B62qoffline2"} {
		writePubkey(t, filepath.Join(root, "offline_whale_keys"), strings.Replace("offline_whale_account_X.pub", "X", string(rune('0'+i)), 1), pk)
	}
	for i, pk := range []string{"B62qonline0", "B62qonline1", "B62qonline2"} {
		writePubkey(t, filepath.Join(root, "online_whale_keys"), strings.Replace("online_whale_account_X.pub", "X", string(rune('0'+i)), 1), pk)
	}

	producerPks, err := ht.RunningProducerPks()
	if err != nil {
		t.Fatalf("RunningProducerPks: %v", err)
	}
	if len(producerPks) != 1 || !producerPks["B62qonline0"] {
		t.Fatalf("RunningProducerPks = %v, want {B62qonline0}", producerPks)
	}

	online := func(pk string) *string { return &pk }
	// Build the ledger file with its real on-disk shape: balances are decimal
	// *mina* strings (ComputeStakeStats parses them to nanomina on read).
	type rawAccount struct {
		Pk       string  `json:"pk"`
		Balance  string  `json:"balance"`
		Delegate *string `json:"delegate"`
	}
	ledger := struct {
		Accounts []rawAccount `json:"accounts"`
	}{Accounts: []rawAccount{
		// The generator pairs offline/online keys in glob order, so the
		// pairing may not follow the filename indices: here offline1 (not
		// offline0) happens to be the account delegated to the running
		// producer. Lazy classification must follow the ledger, not indices.
		{Pk: "B62qoffline1", Balance: "11550000.000000000", Delegate: online("B62qonline0")},
		{Pk: "B62qonline0", Balance: "499.000000000", Delegate: nil}, // self-delegates to a running producer
		// Lazy whale pairs: delegated to producers that never run
		{Pk: "B62qoffline0", Balance: "11550000.000000000", Delegate: online("B62qonline1")},
		{Pk: "B62qonline1", Balance: "499.000000000", Delegate: nil},
		{Pk: "B62qoffline2", Balance: "11550000.000000000", Delegate: online("B62qonline2")},
		{Pk: "B62qonline2", Balance: "499.000000000", Delegate: nil},
		// Service account, delegate to nobody relevant
		{Pk: "B62qfaucet", Balance: "100000.000000000", Delegate: nil},
	}}
	data, err := json.Marshal(ledger)
	if err != nil {
		t.Fatal(err)
	}
	ledgerPath := filepath.Join(root, "genesis_ledger.json")
	if err := os.WriteFile(ledgerPath, data, 0644); err != nil {
		t.Fatal(err)
	}

	lazyPks, err := ht.LazyWhalePks()
	if err != nil {
		t.Fatalf("LazyWhalePks: %v", err)
	}
	if len(lazyPks) != 2 || lazyPks[0] != "B62qoffline0" || lazyPks[1] != "B62qoffline2" {
		t.Fatalf("LazyWhalePks = %v, want [B62qoffline0 B62qoffline2]", lazyPks)
	}

	// A count mismatch (e.g. a missing lazy whale account) must error
	cfg.NumLazyWhales = 3
	if _, err := ht.LazyWhalePks(); err == nil {
		t.Error("expected error when the ledger contains fewer lazy whales than configured")
	}
	cfg.NumLazyWhales = 2

	lazySet := map[string]bool{"B62qoffline0": true, "B62qoffline2": true}
	stats, err := ComputeStakeStats(ledgerPath, producerPks, lazySet)
	if err != nil {
		t.Fatalf("ComputeStakeStats: %v", err)
	}

	wantTotal := (3*11_550_000 + 3*499 + 100_000) * currency.Mina
	wantActive := (11_550_000 + 499) * currency.Mina
	wantLazy := 2 * 11_550_000 * currency.Mina
	if stats.TotalCurrency != wantTotal {
		t.Errorf("TotalCurrency = %d, want %d", stats.TotalCurrency, wantTotal)
	}
	if stats.ActiveProducerStake != wantActive {
		t.Errorf("ActiveProducerStake = %d, want %d", stats.ActiveProducerStake, wantActive)
	}
	if stats.LazyStake != wantLazy {
		t.Errorf("LazyStake = %d, want %d", stats.LazyStake, wantLazy)
	}
}
