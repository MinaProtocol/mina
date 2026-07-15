package hardfork

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
)

// LedgerHashes holds the expected ledger hashes for validation
type LedgerHashes struct {
	StakingHash string
	NextHash    string
	LedgerHash  string
}

// GenerateGenesisLedgersFromRuntimeConfig generates the hardfork ledgers using the specified
// executable. When hardforkSlot is non-zero it is passed as
// --hardfork-slot, which makes runtime_genesis_ledger apply the vesting
// slot-reduction update (slot re-basing) to timed accounts. A zero hardforkSlot
// means accounts are loaded verbatim without conversion.
func (t *HardforkTest) GenerateGenesisLedgersFromRuntimeConfig(executablePath, forkConfigPath, ledgersDir, hashesFile string, hardforkSlot int) error {
	t.Logger.Info("Generating hardfork ledgers with %s...", executablePath)

	// Create hardfork ledgers directory
	os.RemoveAll(ledgersDir)
	os.MkdirAll(ledgersDir, 0755)

	// Generate hardfork ledgers with specified executable
	args := []string{
		"--config-file", forkConfigPath,
		"--genesis-dir", ledgersDir,
		"--hash-output-file", hashesFile,
		// Forking to mesa need App State size to be expanded to 32
		// TODO: Consider design the test so this pad app state size is only applied when forking into Mesa
		"--pad-app-state",
	}
	if hardforkSlot != 0 {
		args = append(args, "--hardfork-slot", strconv.Itoa(hardforkSlot))
	}

	cmd := exec.Command(executablePath, args...)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run fork runtime genesis ledger: %w", err)
	}

	t.Logger.Info("Fork ledgers generated successfully")
	return nil
}

func (t *HardforkTest) RegenerateAndValidatePrepatchLedgerHashes(analysis BlockAnalysisResult, forkConfigPath, preforkLedgersDir, prepatchForkConfig string) error {
	// Generate prefork ledgers using main network executable. No prefork genesis
	// config here: these hashes are validated against the still-un-migrated live
	// prefork network state, so the slot-reduction update must NOT be applied.
	if err := t.GenerateGenesisLedgersFromRuntimeConfig(t.Config.MainRuntimeGenesisLedger, forkConfigPath, preforkLedgersDir, prepatchForkConfig, 0); err != nil {
		return err
	}

	return t.ValidateRuntimeGenesisLedgerHashes(
		analysis,
		prepatchForkConfig,
	)
}

// GenerateLegacyPostforkGenesisLedgers generates postfork genesis ledgers
// from the prepatch fork config using the fork-network runtime_genesis_ledger binary.
func (t *HardforkTest) GenerateLegacyPostforkGenesisLedgers(
	forkConfigPath, forkLedgersDir, forkHashesFile string, hardforkSlot int,
) error {
	return t.GenerateGenesisLedgersFromRuntimeConfig(
		t.Config.ForkRuntimeGenesisLedger,
		forkConfigPath, forkLedgersDir, forkHashesFile, hardforkSlot,
	)
}

func (t *HardforkTest) AdvancedGenerateHardForkConfig(configDir string, clientPort int) error {
	cmd := exec.Command(t.Config.MainMinaExe,
		"advanced", "generate-hardfork-config",
		"--hardfork-config-dir", configDir,
		"--daemon-port", strconv.Itoa(clientPort),
		"--generate-fork-validation", "false",
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to call mina CLI: %w", err)
	}

	err := cmd.Wait()

	if err != nil {
		return fmt.Errorf("failed to wait for mina CLI to terminate: %w", err)
	}

	_, err = os.Stat(fmt.Sprintf("%s/activated", configDir))
	if err != nil {
		return fmt.Errorf("failed to check on activated file for advanced generate fork config: %w", err)
	}

	return nil
}
