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
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/utils"
)

func testHarness(cfg *config.Config) *HardforkTest {
	return &HardforkTest{Config: cfg, Logger: utils.NewLogger()}
}

func TestParseNanominas(t *testing.T) {
	t.Parallel()

	valid := []struct {
		in   string
		want uint64
	}{
		{"0.000000000", 0},
		{"11550000.000000000", 11_550_000_000_000_000},
		{"499.000000000", 499_000_000_000},
		{"0.000000001", 1},
		{"1", 1_000_000_000},
		{"65500.5", 65_500_500_000_000},
	}
	for _, tc := range valid {
		got, err := parseNanominas(tc.in)
		if err != nil {
			t.Errorf("parseNanominas(%q) errored: %v", tc.in, err)
		} else if got != tc.want {
			t.Errorf("parseNanominas(%q) = %d, want %d", tc.in, got, tc.want)
		}
	}

	invalid := []string{"", "abc", "1.0000000001", "-1.0", "1.2.3"}
	for _, in := range invalid {
		if _, err := parseNanominas(in); err == nil {
			t.Errorf("parseNanominas(%q) should have errored", in)
		}
	}
}

func TestComputeSlotOccupancy(t *testing.T) {
	t.Parallel()
	ht := testHarness(config.DefaultConfig())

	occ, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 1, Slot: 0},
		client.BlockData{BlockHeight: 16, Slot: 30},
	)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if occ != 0.5 {
		t.Errorf("occupancy = %f, want 0.5", occ)
	}

	if _, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 5, Slot: 0},
		client.BlockData{BlockHeight: 5, Slot: 30},
	); err == nil {
		t.Error("expected error when start and last block have the same height")
	}

	// Swapped arguments must error, not return a negative or infinite value
	if _, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 16, Slot: 30},
		client.BlockData{BlockHeight: 1, Slot: 0},
	); err == nil {
		t.Error("expected error when last block is not after starting block")
	}
	if _, err := ht.ComputeSlotOccupancy(
		client.BlockData{BlockHeight: 1, Slot: 10},
		client.BlockData{BlockHeight: 5, Slot: 10},
	); err == nil {
		t.Error("expected error when both blocks are at the same slot")
	}
}

func TestExpectedPreForkFillUpperBound(t *testing.T) {
	t.Parallel()

	// Full stake active: bound saturates at 1 - 0.25^1 + margin = 0.9
	bound, err := ExpectedPreForkFillUpperBound(StakeStats{TotalCurrency: 100, ActiveProducerStake: 100})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(bound-0.9) > 1e-9 {
		t.Errorf("bound = %f, want 0.9", bound)
	}

	// ~28.5% active (the CI configuration: 2 active + 5 lazy whales):
	// 1 - 0.25^0.285 + 0.15
	stats := StakeStats{TotalCurrency: 1000, ActiveProducerStake: 285, LazyStake: 715}
	bound, err = ExpectedPreForkFillUpperBound(stats)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := 1 - math.Pow(0.25, 0.285) + 0.15
	if math.Abs(bound-want) > 1e-9 {
		t.Errorf("bound = %f, want %f", bound, want)
	}
	if bound < 0 || bound > 1 || math.IsNaN(bound) {
		t.Errorf("bound = %f, want a non-NaN value in [0,1]", bound)
	}

	// No active stake: bound = margin
	bound, err = ExpectedPreForkFillUpperBound(StakeStats{TotalCurrency: 100})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(bound-preForkFillMargin) > 1e-9 {
		t.Errorf("bound = %f, want %f", bound, preForkFillMargin)
	}

	// Zero total currency must error, not return NaN
	if _, err := ExpectedPreForkFillUpperBound(StakeStats{}); err == nil {
		t.Error("expected error for zero total currency")
	}
}

func TestUnstakedTotal(t *testing.T) {
	t.Parallel()

	// GraphQL Amounts are raw nanomina integer strings. The minuend is the
	// PRE-FORK genesis total (the fork genesis block's own totalCurrency
	// additionally contains pre-fork coinbases and must not be used).
	preFork := client.BlockData{TotalCurrency: "80853498000000000"}
	forkGenesis := client.BlockData{StakingLedgerTotalCurrency: "23103498000000000"}
	got, err := UnstakedTotal(preFork, forkGenesis)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if want := uint64(57_750_000_000_000_000); got != want {
		t.Errorf("UnstakedTotal = %d, want %d", got, want)
	}

	// Missing fields (e.g. build that doesn't serve them) must error
	if _, err := UnstakedTotal(client.BlockData{}, client.BlockData{}); err == nil {
		t.Error("expected error for empty amounts")
	}
	// Fork staking total above the pre-fork genesis total is nonsense
	if _, err := UnstakedTotal(
		client.BlockData{TotalCurrency: "100"},
		client.BlockData{StakingLedgerTotalCurrency: "101"},
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
	ledger := genesisLedgerFile{Accounts: []genesisLedgerAccount{
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

	const mina = uint64(1_000_000_000)
	wantTotal := (3*11_550_000 + 3*499 + 100_000) * mina
	wantActive := (11_550_000 + 499) * mina
	wantLazy := 2 * 11_550_000 * mina
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
