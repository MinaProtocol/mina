package hardfork

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
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

// SetupVestingAccount generates a fresh keypair and writes a one-element genesis
// account array (a timed/vesting account) to a temporary file, recording the
// public key and file path on the config so they can be used when launching the
// main network and when validating after the fork.
func (t *HardforkTest) SetupVestingAccount() error {
	if !t.Config.VestingTestEnabled {
		return nil
	}

	tmpDir, err := os.MkdirTemp("", "hf-vesting-account")
	if err != nil {
		return fmt.Errorf("failed to create temp dir for vesting account: %w", err)
	}

	// Generate a keypair using the main mina executable, mirroring the
	// generate-keypair helper in mina-local-network.sh.
	privPath := filepath.Join(tmpDir, "vesting_account")
	cmd := exec.Command(t.Config.MainMinaExe, "advanced", "generate-keypair", "-privkey-path", privPath)
	cmd.Env = append(os.Environ(), "MINA_PRIVKEY_PASS=")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to generate vesting account keypair: %w", err)
	}

	pubBytes, err := os.ReadFile(privPath + ".pub")
	if err != nil {
		return fmt.Errorf("failed to read generated vesting account public key: %w", err)
	}
	pubKey := strings.TrimSpace(string(pubBytes))
	if pubKey == "" {
		return fmt.Errorf("generated vesting account public key is empty")
	}
	t.Config.VestingAccountPubKey = pubKey

	balance := formatMina(config.VestingBalanceNanomina)
	account := map[string]any{
		"pk":       pubKey,
		"balance":  balance,
		"delegate": nil,
		"timing": map[string]any{
			// Fully locked at genesis, fully unlocking at the cliff.
			"initial_minimum_balance": balance,
			"cliff_time":              strconv.Itoa(t.Config.VestingPreForkCliffTime()),
			"cliff_amount":            balance,
			"vesting_period":          strconv.Itoa(config.VestingPreForkPeriod),
			"vesting_increment":       balance,
		},
	}

	data, err := json.MarshalIndent([]any{account}, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal vesting account: %w", err)
	}

	accFile := filepath.Join(tmpDir, "extra_account.json")
	if err := os.WriteFile(accFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write vesting account file: %w", err)
	}
	t.Config.VestingExtraAccountFile = accFile

	t.Logger.Info(
		"Vesting test: injecting timed account %s (pre-fork cliff_time=%d, hardfork_slot=%d, expected migrated cliff_time=%d)",
		pubKey, t.Config.VestingPreForkCliffTime(), t.Config.HardforkSlot(),
		t.Config.HardforkSlot()+2*config.VestingCliffOffsetSlots,
	)

	return nil
}

// CleanupVestingAccount removes the temporary files created by SetupVestingAccount.
func (t *HardforkTest) CleanupVestingAccount() {
	if t.Config.VestingExtraAccountFile == "" {
		return
	}
	if err := os.RemoveAll(filepath.Dir(t.Config.VestingExtraAccountFile)); err != nil {
		t.Logger.Error("Failed to remove vesting account temp dir: %v", err)
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

// ExpectedMigratedTiming computes the timing parameters the injected account
// should have *after* the Mesa slot-reduction update. It is a direct port of the
// "not yet vesting" branch of actively_vesting_hardfork_adjustment in
// src/lib/mina_base/account_timing.ml: the cliff time is pushed out to
// hardfork_slot + 2*(cliff_time - hardfork_slot) and the vesting period is
// doubled, while the amounts are unchanged.
func ExpectedMigratedTiming(hardforkSlot int) ExpectedTiming {
	hf := int64(hardforkSlot)
	preCliff := hf + int64(config.VestingCliffOffsetSlots)
	return ExpectedTiming{
		InitialMinimumBalance: config.VestingBalanceNanomina,
		CliffTime:             hf + 2*(preCliff-hf),
		CliffAmount:           config.VestingBalanceNanomina,
		VestingPeriod:         2 * config.VestingPreForkPeriod,
		VestingIncrement:      config.VestingBalanceNanomina,
	}
}

// ValidateVestingAfterFork queries the injected account on the fork network and
// asserts that its timing parameters match the expected slot-reduction-updated
// values. A mismatch (in particular an unchanged cliff time / vesting period) is
// the signature of the migrate_to_mesa bug.
func (t *HardforkTest) ValidateVestingAfterFork(port, hardforkSlot int) error {
	if !t.Config.VestingTestEnabled {
		return nil
	}

	expected := ExpectedMigratedTiming(hardforkSlot)

	actual, err := t.Client.AccountTiming(port, t.Config.VestingAccountPubKey)
	if err != nil {
		return fmt.Errorf("failed to query vesting account timing on fork network: %w", err)
	}
	if !actual.Timed {
		return fmt.Errorf("vesting account %s lost its timing after the fork (became untimed)", t.Config.VestingAccountPubKey)
	}

	var mismatches []string
	checkField := func(name string, exp, act int64) {
		if exp != act {
			mismatches = append(mismatches, fmt.Sprintf("%s: expected %d, got %d", name, exp, act))
		}
	}
	checkField("initialMinimumBalance", expected.InitialMinimumBalance, actual.InitialMinimumBalance)
	checkField("cliffTime", expected.CliffTime, actual.CliffTime)
	checkField("cliffAmount", expected.CliffAmount, actual.CliffAmount)
	checkField("vestingPeriod", expected.VestingPeriod, actual.VestingPeriod)
	checkField("vestingIncrement", expected.VestingIncrement, actual.VestingIncrement)

	if len(mismatches) > 0 {
		return fmt.Errorf(
			"vesting account timing was not correctly slot-reduction-updated during Mesa migration "+
				"(hardfork_slot=%d); this is the migrate_to_mesa bug. Mismatches: %s",
			hardforkSlot, strings.Join(mismatches, "; "),
		)
	}

	t.Logger.Info(
		"Vesting test: account %s timing correctly migrated (cliff_time=%d, vesting_period=%d)",
		t.Config.VestingAccountPubKey, actual.CliffTime, actual.VestingPeriod,
	)
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
func (t *HardforkTest) ValidateVestingLiquidUnlock(port, hardforkSlot int) error {
	if !t.Config.VestingTestEnabled {
		return nil
	}

	expectedCliff := int(ExpectedMigratedTiming(hardforkSlot).CliffTime)

	// Poll for a generous number of slots past the expected cliff.
	maxWait := time.Duration((expectedCliff-hardforkSlot+10)*t.Config.ForkSlot) * time.Second
	deadline := time.Now().Add(maxWait)

	t.Logger.Info(
		"Vesting test: watching liquid balance of %s; it must stay locked until slot %d",
		t.Config.VestingAccountPubKey, expectedCliff,
	)

	for time.Now().Before(deadline) {
		// Query the account first, then the best tip, so the slot we compare
		// against is never *earlier* than the slot the liquid balance was
		// computed at. This makes an "unlocked too early" verdict reliable.
		acct, err := t.Client.AccountTiming(port, t.Config.VestingAccountPubKey)
		if err != nil {
			t.Logger.Debug("Vesting test: failed to query account liquid balance: %v", err)
			time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
			continue
		}
		tip, err := t.Client.BestTip(port)
		if err != nil {
			t.Logger.Debug("Vesting test: failed to query best tip: %v", err)
			time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
			continue
		}

		fullyLiquid := acct.TotalBalance > 0 && acct.LiquidBalance >= acct.TotalBalance

		if fullyLiquid && tip.Slot < expectedCliff {
			return fmt.Errorf(
				"vesting account %s unlocked too early: fully liquid (liquid=%d total=%d) at slot %d, "+
					"but the correct migrated cliff is slot %d. This is the migrate_to_mesa slot-reduction bug.",
				t.Config.VestingAccountPubKey, acct.LiquidBalance, acct.TotalBalance, tip.Slot, expectedCliff,
			)
		}

		if tip.Slot >= expectedCliff {
			if fullyLiquid {
				t.Logger.Info(
					"Vesting test: account %s became fully liquid at/after slot %d as expected",
					t.Config.VestingAccountPubKey, expectedCliff,
				)
				return nil
			}
			// Reached the cliff but funds not yet liquid; the unlock happens at
			// the cliff, so give it one more slot to settle.
		}

		time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
	}

	t.Logger.Info(
		"Vesting test: fork network did not reach the expected cliff slot %d within the polling window; "+
			"relying on the timing-parameter assertion for correctness",
		expectedCliff,
	)
	return nil
}
