package hardfork

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// This file implements an end-to-end test for the Mesa hardfork "slot reduction"
// vesting update (MIP-0006). A timed account that only *starts* vesting after the
// hardfork slot is injected into the pre-fork genesis ledger. After the fork, its
// timing must have been adjusted by Account.slot_reduction_update so that it still
// unlocks funds at the same wall-clock time despite slots becoming 2x faster:
// the vesting period is doubled and the cliff is pushed from
// hardfork_slot + offset to hardfork_slot + 2*offset.
//
// The bug described in 3_mesa-hardfork-vesting-schedule-not-adjusted.txt is that
// Account.Hardfork.migrate_to_mesa discards its hardfork_slot argument and never
// applies this update, so the account vests ~2x too fast. This test catches that
// both by asserting the migrated timing parameters and by observing that liquid
// funds do not unlock before the correct slot.

// formatMina renders a nanomina amount as the decimal-mina string used in genesis
// ledger JSON (mirrors encode_nanominas in
// scripts/mina-local-network/generate-mina-local-network-ledger.py).
func formatMina(nanomina int64) string {
	return fmt.Sprintf("%d.%09d", nanomina/1_000_000_000, nanomina%1_000_000_000)
}

type genesisMinaAmount int64

func (a genesisMinaAmount) MarshalJSON() ([]byte, error) {
	return json.Marshal(formatMina(int64(a)))
}

type genesisSlot int64

func (s genesisSlot) MarshalJSON() ([]byte, error) {
	return json.Marshal(strconv.FormatInt(int64(s), 10))
}

// generateKeypair generates a Mina keypair at privPath and returns its public
// key, mirroring the generate-keypair helper in mina-local-network.sh.
func generateKeypair(minaExe, privPath string) (string, error) {
	cmd := exec.Command(minaExe, "advanced", "generate-keypair", "-privkey-path", privPath)
	cmd.Env = append(os.Environ(), "MINA_PRIVKEY_PASS=")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("failed to generate keypair: %w", err)
	}

	pubBytes, err := os.ReadFile(privPath + ".pub")
	if err != nil {
		return "", fmt.Errorf("failed to read generated public key: %w", err)
	}
	pubKey := strings.TrimSpace(string(pubBytes))
	if pubKey == "" {
		return "", fmt.Errorf("generated public key is empty")
	}
	return pubKey, nil
}

// Vesting-account test parameters. All amounts are in nanomina.
//
// The account is "not yet vesting" at the hardfork slot (its cliff is
// vestingCliffOffsetSlots slots *after* the hardfork slot) and fully unlocks at
// its cliff (cliff_amount == initial_minimum_balance). The Mesa slot-reduction
// update therefore must double the vesting period and push the cliff out to
// hardfork_slot + 2*vestingCliffOffsetSlots. See
// src/lib/mina_base/account_timing.ml:actively_vesting_hardfork_adjustment.
//
// vestingCliffOffsetSlots is chosen so that the *buggy* (un-migrated) cliff
// (hardfork_slot + offset) falls before, and the *correct* migrated cliff
// (hardfork_slot + 2*offset) falls after, the slot at which the fork network
// becomes queryable (BestChainQueryFrom + genesisSlot, default 25 + 68 = 93).
// This lets the liquid-balance check observe the account still locked under
// correct migration while it would already be unlocked under the bug.
const (
	vestingBalanceNanomina  = 100 * 1_000_000_000
	vestingCliffOffsetSlots = 15
	vestingPreForkPeriod    = 1
)

type vestingAccount struct {
	PK       string               `json:"pk"`
	Balance  genesisMinaAmount    `json:"balance"`
	Delegate *string              `json:"delegate"`
	Timing   vestingAccountTiming `json:"timing"`

	extraAccountFile string
}

type vestingAccountTiming struct {
	InitialMinimumBalance genesisMinaAmount `json:"initial_minimum_balance"`
	CliffTime             genesisSlot       `json:"cliff_time"`
	CliffAmount           genesisMinaAmount `json:"cliff_amount"`
	VestingPeriod         genesisSlot       `json:"vesting_period"`
	VestingIncrement      genesisMinaAmount `json:"vesting_increment"`
}

func newFullyLockedVestingAccountTiming(balance genesisMinaAmount, cliffTime, vestingPeriod genesisSlot) vestingAccountTiming {
	// Fully locked at genesis, fully unlocking at the cliff.
	return vestingAccountTiming{
		InitialMinimumBalance: balance,
		CliffTime:             cliffTime,
		CliffAmount:           balance,
		VestingPeriod:         vestingPeriod,
		VestingIncrement:      balance,
	}
}

func newVestingAccount(pubKey, extraAccountFile string, hardforkSlot int) *vestingAccount {
	balance := genesisMinaAmount(vestingBalanceNanomina)
	cliffTime := genesisSlot(hardforkSlot + vestingCliffOffsetSlots)
	vestingPeriod := genesisSlot(vestingPreForkPeriod)

	return &vestingAccount{
		PK:               pubKey,
		Balance:          balance,
		Timing:           newFullyLockedVestingAccountTiming(balance, cliffTime, vestingPeriod),
		extraAccountFile: extraAccountFile,
	}
}

// ExpectedTiming holds the timing parameters expected after migration. Amounts
// are in nanomina; times are global-slot numbers.
type ExpectedTiming struct {
	InitialMinimumBalance int64
	CliffTime             int64
	CliffAmount           int64
	VestingPeriod         int64
	VestingIncrement      int64
}

// ExpectedMigratedTiming computes the timing parameters this account should
// have *after* the Mesa slot-reduction update. It is a direct port of the "not
// yet vesting" branch of actively_vesting_hardfork_adjustment in
// src/lib/mina_base/account_timing.ml: the cliff time is pushed out to
// hardfork_slot + 2*(cliff_time - hardfork_slot) and the vesting period is
// doubled, while the amounts are unchanged.
func (a *vestingAccount) ExpectedMigratedTiming(hardforkSlot int) ExpectedTiming {
	hf := int64(hardforkSlot)
	preCliff := int64(a.Timing.CliffTime)
	return ExpectedTiming{
		InitialMinimumBalance: int64(a.Timing.InitialMinimumBalance),
		CliffTime:             hf + 2*(preCliff-hf),
		CliffAmount:           int64(a.Timing.CliffAmount),
		VestingPeriod:         2 * int64(a.Timing.VestingPeriod),
		VestingIncrement:      int64(a.Timing.VestingIncrement),
	}
}

// SetupVestingAccount generates a fresh keypair and writes a one-element genesis
// account array (a timed/vesting account) to a temporary file, recording the
// public key and file path on the test so they can be used when launching the
// main network and when validating after the fork.
func (t *HardforkTest) SetupVestingAccount() error {
	if !t.Config.VestingTestEnabled {
		return nil
	}

	tmpDir, err := os.MkdirTemp("", "hf-vesting-account")
	if err != nil {
		return fmt.Errorf("failed to create temp dir for vesting account: %w", err)
	}

	privPath := filepath.Join(tmpDir, "vesting_account")
	pubKey, err := generateKeypair(t.Config.MainMinaExe, privPath)
	if err != nil {
		return fmt.Errorf("failed to generate vesting account keypair: %w", err)
	}

	account := newVestingAccount(pubKey, filepath.Join(tmpDir, "extra_account.json"), t.Config.HardforkSlot())
	data, err := json.MarshalIndent([]*vestingAccount{account}, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal vesting account: %w", err)
	}

	if err := os.WriteFile(account.extraAccountFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write vesting account file: %w", err)
	}
	t.vestingAccount = account
	expected := account.ExpectedMigratedTiming(t.Config.HardforkSlot())

	t.Logger.Info(
		"Vesting test: injecting timed account %s (pre-fork cliff_time=%d, hardfork_slot=%d, expected migrated cliff_time=%d)",
		account.PK, account.Timing.CliffTime, t.Config.HardforkSlot(), expected.CliffTime,
	)

	return nil
}

// CleanupVestingAccount removes the temporary files created by SetupVestingAccount.
func (t *HardforkTest) CleanupVestingAccount() {
	if t.vestingAccount == nil || t.vestingAccount.extraAccountFile == "" {
		return
	}
	if err := os.RemoveAll(filepath.Dir(t.vestingAccount.extraAccountFile)); err != nil {
		t.Logger.Error("Failed to remove vesting account temp dir: %v", err)
	}
}

// ValidateVestingAfterFork queries the injected account on the fork network and
// asserts that its timing parameters match the expected slot-reduction-updated
// values. A mismatch (in particular an unchanged cliff time / vesting period) is
// the signature of the migrate_to_mesa bug.
//
// It takes the whole daemon rather than just its port so its log lines can name
// which daemon (and therefore which fork method) they describe: every daemon
// validates the same account, so the account alone does not identify them.
func (t *HardforkTest) ValidateVestingAfterFork(daemon config.DaemonInfo, hardforkSlot int) error {
	if !t.Config.VestingTestEnabled {
		return nil
	}
	account := t.vestingAccount
	if account == nil {
		return fmt.Errorf("vesting test is enabled but no vesting account was set up")
	}

	expected := account.ExpectedMigratedTiming(hardforkSlot)

	actual, err := t.Client.AccountTiming(&daemon, account.PK)
	if err != nil {
		return fmt.Errorf("failed to query vesting account timing on fork network: %w", err)
	}
	if actual.Timing == nil {
		return fmt.Errorf("vesting account %s lost its timing after the fork (became untimed)", account.PK)
	}

	var mismatches []string
	checkField := func(name string, exp, act int64) {
		if exp != act {
			mismatches = append(mismatches, fmt.Sprintf("%s: expected %d, got %d", name, exp, act))
		}
	}
	checkField("initialMinimumBalance", expected.InitialMinimumBalance, actual.Timing.InitialMinimumBalance)
	checkField("cliffTime", expected.CliffTime, actual.Timing.CliffTime)
	checkField("cliffAmount", expected.CliffAmount, actual.Timing.CliffAmount)
	checkField("vestingPeriod", expected.VestingPeriod, actual.Timing.VestingPeriod)
	checkField("vestingIncrement", expected.VestingIncrement, actual.Timing.VestingIncrement)

	if len(mismatches) > 0 {
		return fmt.Errorf(
			"vesting account timing was not correctly slot-reduction-updated during Mesa migration "+
				"(hardfork_slot=%d); this is the migrate_to_mesa bug. Mismatches: %s",
			hardforkSlot, strings.Join(mismatches, "; "),
		)
	}

	t.Logger.Info(
		"Vesting test: daemon %s (fork method %s): account %s timing correctly migrated "+
			"(cliff_time=%d, vesting_period=%d)",
		daemon.Name, daemon.ForkMethod, account.PK,
		actual.Timing.CliffTime, actual.Timing.VestingPeriod,
	)
	return nil
}

func (t *HardforkTest) ValidateVestingOnForkNetwork(hardforkSlot int) error {
	if !t.Config.VestingTestEnabled {
		return nil
	}
	if t.vestingAccount == nil {
		return fmt.Errorf("vesting test is enabled but no vesting account was set up")
	}

	type validationResult struct {
		daemon config.DaemonInfo
		err    error
	}

	var timingErrors []string
	for _, daemon := range t.Config.DaemonInfos {
		t.Logger.Info(
			"Vesting test: validating migrated timing on daemon %s using fork method %s (REST port %d)",
			daemon.Name, daemon.ForkMethod, daemon.Port(config.PORT_REST),
		)
		if err := t.ValidateVestingAfterFork(daemon, hardforkSlot); err != nil {
			timingErrors = append(timingErrors, fmt.Sprintf(
				"%s using fork method %s: %v",
				daemon.Name, daemon.ForkMethod, err,
			))
		}
	}
	if len(timingErrors) > 0 {
		return fmt.Errorf("vesting timing validation failed: %s", strings.Join(timingErrors, "; "))
	}

	results := make(chan validationResult, len(t.Config.DaemonInfos))
	var wg sync.WaitGroup
	for _, daemon := range t.Config.DaemonInfos {
		daemon := daemon
		wg.Add(1)
		go func() {
			defer wg.Done()
			t.Logger.Info(
				"Vesting test: watching liquid balance on daemon %s using fork method %s (REST port %d)",
				daemon.Name, daemon.ForkMethod, daemon.Port(config.PORT_REST),
			)
			err := t.ValidateVestingLiquidUnlock(daemon, hardforkSlot)
			results <- validationResult{daemon: daemon, err: err}
		}()
	}
	wg.Wait()
	close(results)

	var errors []string
	for result := range results {
		if result.err != nil {
			errors = append(errors, fmt.Sprintf(
				"%s using fork method %s: %v",
				result.daemon.Name, result.daemon.ForkMethod, result.err,
			))
		}
	}
	if len(errors) > 0 {
		return fmt.Errorf("vesting liquid-balance validation failed: %s", strings.Join(errors, "; "))
	}

	return nil
}

// ValidateVestingLiquidUnlock polls the injected account's liquid balance and
// asserts it does not become fully liquid before the correct (migrated) cliff
// slot. Under the migrate_to_mesa bug the cliff is never advanced, so the funds
// unlock at hardfork_slot + offset instead of hardfork_slot + 2*offset, which
// this check observes as the account being fully liquid while the best tip slot
// is still below the expected cliff.
//
// The check only *fails* on a definitive early unlock; if the network does not
// reach the expected cliff within the polling window it logs a warning and
// returns nil, leaving ValidateVestingAfterFork as the authoritative gate.
// It takes the whole daemon rather than just its port for the same reason as
// ValidateVestingAfterFork: these run concurrently, one per daemon, and all
// watch the same account, so only the daemon name distinguishes their output.
func (t *HardforkTest) ValidateVestingLiquidUnlock(daemon config.DaemonInfo, hardforkSlot int) error {
	if !t.Config.VestingTestEnabled {
		return nil
	}
	account := t.vestingAccount
	if account == nil {
		return fmt.Errorf("vesting test is enabled but no vesting account was set up")
	}

	expected := account.ExpectedMigratedTiming(hardforkSlot)
	expectedCliff := int(expected.CliffTime)

	// Poll for a generous number of slots past the expected cliff.
	maxWait := time.Duration((expectedCliff-hardforkSlot+10)*t.Config.ForkSlot) * time.Second
	deadline := time.Now().Add(maxWait)

	t.Logger.Info(
		"Vesting test: daemon %s (fork method %s): watching liquid balance of %s; "+
			"it must stay locked until slot %d",
		daemon.Name, daemon.ForkMethod, account.PK, expectedCliff,
	)

	for time.Now().Before(deadline) {
		// Query the account first, then the best tip, so the slot we compare
		// against is never *earlier* than the slot the liquid balance was
		// computed at. This makes an "unlocked too early" verdict reliable.
		acct, err := t.Client.AccountTiming(&daemon, account.PK)
		if err != nil {
			t.Logger.Debug("Vesting test: failed to query account liquid balance: %v", err)
			time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
			continue
		}
		tip, err := t.Client.BestTip(&daemon)
		if err != nil {
			t.Logger.Debug("Vesting test: failed to query best tip: %v", err)
			time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
			continue
		}

		fullyLiquid := acct.Balance.Total > 0 && acct.Balance.Liquid >= acct.Balance.Total

		if fullyLiquid && tip.Slot < expectedCliff {
			return fmt.Errorf(
				"vesting account %s unlocked too early: fully liquid (liquid=%d total=%d) at slot %d, "+
					"but the correct migrated cliff is slot %d. This is the migrate_to_mesa slot-reduction bug.",
				account.PK, acct.Balance.Liquid, acct.Balance.Total, tip.Slot, expectedCliff,
			)
		}

		if tip.Slot >= expectedCliff {
			if fullyLiquid {
				t.Logger.Info(
					"Vesting test: daemon %s (fork method %s): account %s became fully liquid "+
						"at/after slot %d as expected",
					daemon.Name, daemon.ForkMethod, account.PK, expectedCliff,
				)
				return nil
			}
			// Reached the cliff but funds not yet liquid; the unlock happens at
			// the cliff, so give it one more slot to settle.
		}

		time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
	}

	t.Logger.Info(
		"Vesting test: daemon %s (fork method %s): fork network did not reach the expected cliff "+
			"slot %d within the polling window; relying on the timing-parameter assertion for correctness",
		daemon.Name, daemon.ForkMethod, expectedCliff,
	)
	return nil
}
