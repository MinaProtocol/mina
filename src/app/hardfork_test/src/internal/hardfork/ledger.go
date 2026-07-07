package hardfork

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// LedgerHashes holds the expected ledger hashes for validation
type LedgerHashes struct {
	StakingHash string
	NextHash    string
	LedgerHash  string
}

// GenerateForkLedgers generates the hardfork ledgers using the specified
// executable. When preforkGenesisConfig is non-empty it is passed as
// --prefork-genesis-config, which makes runtime_genesis_ledger derive the
// hardfork slot (slot_chain_end + hard_fork_genesis_slot_delta) from it and
// apply the Mesa vesting slot-reduction update to timed accounts. The legacy
// path MUST supply it for the final fork ledgers: without it the generated
// ledger keeps un-migrated vesting timing, which both diverges from the
// auto/advanced (daemon-side) migration — splitting the network on chain id —
// and from the real release flow
// (scripts/hardfork/release/generate-fork-config-with-ledger-tarballs.sh). It is
// left empty when (re)generating the pre-fork ledgers, whose hashes must match
// the still-un-migrated live network state.
func (t *HardforkTest) GenerateForkLedgers(executablePath, forkConfigPath, ledgersDir, hashesFile, preforkGenesisConfig string) error {
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
	if preforkGenesisConfig != "" {
		args = append(args, "--prefork-genesis-config", preforkGenesisConfig)
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

func (t *HardforkTest) GenerateAndValidateHashesAndLedgers(analysis BlockAnalysisResult, forkConfigPath, preforkLedgersDir, prepatchForkConfig string) error {
	// Generate prefork ledgers using main network executable. No prefork genesis
	// config here: these hashes are validated against the still-un-migrated live
	// prefork network state, so the slot-reduction update must NOT be applied.
	if err := t.GenerateForkLedgers(t.Config.MainRuntimeGenesisLedger, forkConfigPath, preforkLedgersDir, prepatchForkConfig, ""); err != nil {
		return err
	}

	return t.ValidateRuntimeGenesisLedgerHashes(
		analysis,
		prepatchForkConfig,
	)
}

// PatchForkConfigAndGenerateLedgersLegacy does the following:
// 1. generate fork ledgers with runtime-genesis-ledger
// 2. patch the genesis time & slot for fork config with create_runtime_config.sh
// 3. perform some base sanity check on the fork config
func (t *HardforkTest) PatchForkConfigAndGenerateLedgersLegacy(analysis *BlockAnalysisResult, forkConfigPath, forkLedgersDir, forkHashesFile, configFile, preforkGenesisConfigFile string, forkGenesisTs, mainGenesisTs int64) ([]byte, error) {
	// Generate fork ledgers using fork network executable. Pass the prefork
	// genesis config so runtime_genesis_ledger applies the Mesa vesting
	// slot-reduction update (mirrors the release flow); otherwise the legacy
	// ledger would keep un-migrated timing and diverge from auto/advanced.
	if err := t.GenerateForkLedgers(t.Config.ForkRuntimeGenesisLedger, forkConfigPath, forkLedgersDir, forkHashesFile, preforkGenesisConfigFile); err != nil {
		return nil, err
	}

	// Create runtime config
	forkGenesisTimestamp := config.FormatTimestamp(forkGenesisTs)
	return t.PatchRuntimeConfigLegacy(forkGenesisTimestamp, forkConfigPath, configFile, preforkGenesisConfigFile, forkHashesFile)
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
