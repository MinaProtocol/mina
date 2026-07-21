package hardfork

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// Slot fill rate f hardcoded in the daemon (src/lib/consensus/vrf/consensus_vrf.ml),
// independent of build profile. A producer holding fraction s of the VRF
// denominator wins a slot with probability 1 - (1-f)^s; VRF evaluations are
// independent across producers, so P(slot filled) = 1 - (1-f)^(sum of s_i).
const vrfFillFraction = 0.75

// Slack added on top of the modeled pre-fork fill rate to absorb VRF variance
// over the ~30-slot measurement window (~1.7 sigma) and the stake the model
// ignores (online balances, service accounts)
const preForkFillMargin = 0.15

// Lower bar for the pre-fork occupancy: below this the network is considered
// broken rather than diluted, and the comparison against the post-fork
// occupancy would be meaningless
const preForkMinOccupancy = 0.05

// Relative tolerance when cross-checking the file-derived total currency
// against the staking epoch ledger's total currency reported by the daemon.
// The two may differ by accounts the daemon injects on top of the configured
// genesis (e.g. the genesis winner, ~1000 MINA against ~80M total); a mismatch
// beyond this tolerance means the genesis ledger file no longer describes the
// ledger the VRF samples.
const totalCurrencyTolerance = 0.001

// StakeStats summarizes the genesis ledger from the VRF's point of view, in
// nanomina
type StakeStats struct {
	// Sum of all account balances: the pre-fork VRF denominator
	TotalCurrency uint64
	// Sum of balances delegated to a producer key with a running daemon
	ActiveProducerStake uint64
	// Sum of the lazy whale account balances
	LazyStake uint64
}

// LazyWhalePks returns the public keys of the lazy whale offline accounts:
// the accounts in the generated genesis ledger whose stake is delegated to a
// whale producer key that has no running daemon. The classification is done
// against the ledger rather than by key-file index because the ledger
// generator pairs offline and online whale keys in glob order, which is not
// guaranteed to follow the filename indices.
func (t *HardforkTest) LazyWhalePks() ([]string, error) {
	running, err := t.RunningProducerPks()
	if err != nil {
		return nil, err
	}

	allOnlineWhalePks := make(map[string]bool)
	for i := 0; i < t.Config.NumWhales+t.Config.NumLazyWhales; i++ {
		path := filepath.Join(t.Config.Root, "online_whale_keys", fmt.Sprintf("online_whale_account_%d.pub", i))
		pk, err := readPubkeyFile(path)
		if err != nil {
			return nil, fmt.Errorf("failed to read online whale %d public key: %w", i, err)
		}
		allOnlineWhalePks[pk] = true
	}

	ledger, err := readGenesisLedger(filepath.Join(t.Config.Root, "genesis_ledger.json"))
	if err != nil {
		return nil, err
	}

	var pks []string
	for _, account := range ledger.Accounts {
		if account.Delegate == nil {
			continue
		}
		if allOnlineWhalePks[*account.Delegate] && !running[*account.Delegate] {
			pks = append(pks, account.Pk)
		}
	}
	if len(pks) != t.Config.NumLazyWhales {
		return nil, fmt.Errorf("expected %d lazy whale accounts in the genesis ledger, found %d", t.Config.NumLazyWhales, len(pks))
	}
	return pks, nil
}

// RunningProducerPks returns the public keys of the block producer accounts
// that actually have a daemon running: online whales 0..NumWhales-1 and online
// fish 0..NumFish-1
func (t *HardforkTest) RunningProducerPks() (map[string]bool, error) {
	pks := make(map[string]bool)
	for i := 0; i < t.Config.NumWhales; i++ {
		path := filepath.Join(t.Config.Root, "online_whale_keys", fmt.Sprintf("online_whale_account_%d.pub", i))
		pk, err := readPubkeyFile(path)
		if err != nil {
			return nil, fmt.Errorf("failed to read online whale %d public key: %w", i, err)
		}
		pks[pk] = true
	}
	for i := 0; i < t.Config.NumFish; i++ {
		path := filepath.Join(t.Config.Root, "online_fish_keys", fmt.Sprintf("online_fish_account_%d.pub", i))
		pk, err := readPubkeyFile(path)
		if err != nil {
			return nil, fmt.Errorf("failed to read online fish %d public key: %w", i, err)
		}
		pks[pk] = true
	}
	return pks, nil
}

func readPubkeyFile(path string) (string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	pk := strings.TrimSpace(string(data))
	if pk == "" {
		return "", fmt.Errorf("public key file %s is empty", path)
	}
	return pk, nil
}

type genesisLedgerAccount struct {
	Pk       string  `json:"pk"`
	Balance  string  `json:"balance"`
	Delegate *string `json:"delegate"`
}

type genesisLedgerFile struct {
	Accounts []genesisLedgerAccount `json:"accounts"`
}

func readGenesisLedger(path string) (*genesisLedgerFile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read genesis ledger: %w", err)
	}
	var ledger genesisLedgerFile
	if err := json.Unmarshal(data, &ledger); err != nil {
		return nil, fmt.Errorf("failed to parse genesis ledger %s: %w", path, err)
	}
	if len(ledger.Accounts) == 0 {
		return nil, fmt.Errorf("genesis ledger %s contains no accounts", path)
	}
	return &ledger, nil
}

// ComputeStakeStats reads the generated genesis ledger and classifies every
// account balance. An account's stake counts as active iff its delegate is a
// running producer key; a null delegate means self-delegation on the pre-fork
// (mesa) build, so such an account is active iff its own key is a running
// producer.
func ComputeStakeStats(genesisLedgerPath string, runningProducerPks, lazyPks map[string]bool) (StakeStats, error) {
	var stats StakeStats

	ledger, err := readGenesisLedger(genesisLedgerPath)
	if err != nil {
		return stats, err
	}

	for _, account := range ledger.Accounts {
		balance, err := parseNanominas(account.Balance)
		if err != nil {
			return stats, fmt.Errorf("account %s: %w", account.Pk, err)
		}
		stats.TotalCurrency += balance

		delegate := account.Pk
		if account.Delegate != nil {
			delegate = *account.Delegate
		}
		if runningProducerPks[delegate] {
			stats.ActiveProducerStake += balance
		}
		if lazyPks[account.Pk] {
			stats.LazyStake += balance
		}
	}

	return stats, nil
}

// parseNanominas parses a decimal mina amount as emitted by
// generate-mina-local-network-ledger.py (e.g. "11550000.000000000") into
// nanomina
func parseNanominas(balance string) (uint64, error) {
	whole, frac, found := strings.Cut(balance, ".")
	if !found {
		frac = "0"
	}
	wholeN, err := strconv.ParseUint(whole, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid balance %q: %w", balance, err)
	}
	if len(frac) > 9 {
		return 0, fmt.Errorf("invalid balance %q: more than 9 fractional digits", balance)
	}
	frac = frac + strings.Repeat("0", 9-len(frac))
	fracN, err := strconv.ParseUint(frac, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid balance %q: %w", balance, err)
	}
	return wholeN*1_000_000_000 + fracN, nil
}

// validatePreForkOccupancyDiluted asserts that the pre-fork slot occupancy is
// low because the lazy whales dilute the VRF denominator, while the network is
// still alive. The measured occupancy is recorded on the analysis result for
// the post-fork comparison.
func (t *HardforkTest) validatePreForkOccupancyDiluted(analysis *BlockAnalysisResult) error {
	occ, err := t.ComputeSlotOccupancy(analysis.GenesisBlock, analysis.Consensus.LastBlockBeforeTxEnd)
	if err != nil {
		return fmt.Errorf("failed to compute pre-fork slot occupancy: %w", err)
	}
	analysis.PreForkOccupancy = occ

	producerPks, err := t.RunningProducerPks()
	if err != nil {
		return err
	}
	lazyList, err := t.LazyWhalePks()
	if err != nil {
		return err
	}
	lazyPks := make(map[string]bool, len(lazyList))
	for _, pk := range lazyList {
		lazyPks[pk] = true
	}

	stats, err := ComputeStakeStats(filepath.Join(t.Config.Root, "genesis_ledger.json"), producerPks, lazyPks)
	if err != nil {
		return err
	}
	upperBound, err := ExpectedPreForkFillUpperBound(stats)
	if err != nil {
		return err
	}

	// The fill bound is modeled on the genesis ledger file under the
	// assumption that it is the staking epoch ledger the VRF samples during
	// the whole measurement window (epoch 0). Cross-check the file-derived
	// total against what consensus actually reports.
	consensusTotal, err := t.Client.StakingEpochLedgerTotalCurrency(t.Config.AnyDaemon().Port(config.PORT_REST))
	if err != nil {
		return fmt.Errorf("failed to query staking epoch ledger total currency: %w", err)
	}
	t.Logger.Info("Staking epoch ledger total currency per consensus: %d nanomina (genesis ledger file: %d nanomina)", consensusTotal, stats.TotalCurrency)
	if math.Abs(float64(consensusTotal)-float64(stats.TotalCurrency)) > totalCurrencyTolerance*float64(consensusTotal) {
		return fmt.Errorf("genesis ledger file total currency (%d nanomina) disagrees with the staking epoch ledger total currency (%d nanomina) by more than %.2f%%; the fill-rate bound would be computed against the wrong ledger", stats.TotalCurrency, consensusTotal, totalCurrencyTolerance*100)
	}

	t.Logger.Info("Genesis stake: total currency %d, active producer stake %d, lazy stake %d (lazy portion %f)",
		stats.TotalCurrency, stats.ActiveProducerStake, stats.LazyStake,
		float64(stats.LazyStake)/float64(stats.TotalCurrency))
	t.Logger.Info("Pre-fork slot occupancy: %f (expected below %f due to lazy whales)", occ, upperBound)

	if occ < preForkMinOccupancy {
		return fmt.Errorf("pre-fork slot occupancy (%f) is below %f, network appears broken rather than diluted", occ, preForkMinOccupancy)
	}
	if occ >= upperBound {
		return fmt.Errorf("pre-fork slot occupancy (%f) is not below the expected upper bound (%f), lazy whales are not diluting the VRF denominator", occ, upperBound)
	}
	return nil
}

// validatePostForkOccupancyRecovered asserts that unstaking the lazy whales at
// the fork restored the slot occupancy: it must beat the pre-fork occupancy
// and clear the standard 50% health bar.
func (t *HardforkTest) validatePostForkOccupancyRecovered(analysis *BlockAnalysisResult, commonGenesisBlock, bestTip client.BlockData) error {
	postOcc, err := t.ComputeSlotOccupancy(commonGenesisBlock, bestTip)
	if err != nil {
		return fmt.Errorf("failed to compute post-fork slot occupancy: %w", err)
	}

	t.Logger.Info("Post-fork slot occupancy: %f (pre-fork was %f)", postOcc, analysis.PreForkOccupancy)

	if postOcc <= analysis.PreForkOccupancy {
		return fmt.Errorf("post-fork slot occupancy (%f) did not improve on pre-fork occupancy (%f), unstaking the lazy whales had no effect", postOcc, analysis.PreForkOccupancy)
	}
	return t.ValidateSlotOccupancy(commonGenesisBlock, bestTip)
}

// ExpectedPreForkFillUpperBound bounds the pre-fork slot occupancy expected
// while the lazy whales dilute the VRF denominator: the modeled fill rate for
// the active stake share plus a slack margin. Pre-fork occupancy at or above
// this bound means the dilution did not happen.
func ExpectedPreForkFillUpperBound(s StakeStats) (float64, error) {
	if s.TotalCurrency == 0 {
		return 0, fmt.Errorf("total currency is zero, cannot compute expected fill rate")
	}
	sActive := float64(s.ActiveProducerStake) / float64(s.TotalCurrency)
	bound := 1 - math.Pow(1-vrfFillFraction, sActive) + preForkFillMargin
	if bound > 1 {
		bound = 1
	}
	return bound, nil
}
