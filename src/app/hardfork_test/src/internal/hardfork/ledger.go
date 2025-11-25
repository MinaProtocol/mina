package hardfork

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// LedgerHashes holds the expected ledger hashes for validation
type LedgerHashes struct {
	StakingHash string
	NextHash    string
	LedgerHash  string
}

// GenerateForkLedgers generates the hardfork ledgers using the specified executable
func (t *HardforkTest) GenerateForkLedgers(executablePath, forkConfigPath, ledgersDir, hashesFile string) error {
	t.Logger.Info("Generating hardfork ledgers...")

	// Create hardfork ledgers directory
	os.RemoveAll(ledgersDir)
	os.MkdirAll(ledgersDir, 0755)

	// Generate hardfork ledgers with specified executable
	cmd := exec.Command(
		executablePath,
		"--config-file", forkConfigPath,
		"--genesis-dir", ledgersDir,
		"--hash-output-file", hashesFile,
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run fork runtime genesis ledger: %w", err)
	}

	t.Logger.Info("Fork ledgers generated successfully")
	return nil
}

// GenerateAndValidatePreforkLedgers validates fork config and ledgers
// Note: Fork config extraction happens in RunMainNetworkPhase before nodes shutdown
func (t *HardforkTest) GenerateAndValidatePreforkLedgers(analysis *BlockAnalysisResult, forkConfigPath, preforkLedgersDir, preforkHashesFile string) error {
	// Generate prefork ledgers using main network executable
	if err := t.GenerateForkLedgers(t.Config.MainRuntimeGenesisLedger, forkConfigPath, preforkLedgersDir, preforkHashesFile); err != nil {
		return err
	}

	// Validate prefork ledger hashes
	if err := t.ValidatePreforkLedgerHashes(
		analysis.LatestNonEmptyBlock,
		analysis.GenesisEpochStaking,
		analysis.GenesisEpochNext,
		analysis.LatestSnarkedHashPerEpoch,
		preforkHashesFile,
	); err != nil {
		return err
	}

	return nil
}

// PatchForkConfigAndGenerateLedgersLegacy does the following:
// 1. generate fork ledgers with runtime-genesis-ledger
// 2. patch the genesis time & slot for fork config with create_runtime_config.sh
// 3. perform some base sanity check on the fork config
func (t *HardforkTest) PatchForkConfigAndGenerateLedgersLegacy(analysis *BlockAnalysisResult, forkConfigPath, forkLedgersDir, forkHashesFile, configFile, preforkGenesisConfigFile string, forkGenesisTs, mainGenesisTs int64) error {
	// Generate fork ledgers using fork network executable
	if err := t.GenerateForkLedgers(t.Config.ForkRuntimeGenesisLedger, forkConfigPath, forkLedgersDir, forkHashesFile); err != nil {
		return err
	}

	// Create runtime config
	forkGenesisTimestamp := config.FormatTimestamp(forkGenesisTs)
	runtimeConfigBytes, err := t.PatchRuntimeConfigLegacy(forkGenesisTimestamp, forkConfigPath, configFile, preforkGenesisConfigFile, forkHashesFile)
	if err != nil {
		return err
	}

	// Validate modified fork data
	return t.ValidateForkRuntimeConfig(analysis.LatestNonEmptyBlock, runtimeConfigBytes, forkGenesisTs, mainGenesisTs)
}

func (t *HardforkTest) AdvancedGenerateHardForkConfig(configDir string) error {
	cmd := exec.Command(t.Config.MainMinaExe,
		"advanced", "generate-hardfork-config",
		"--hardfork-config-dir", configDir,
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to call mina CLI: %w", err)
	}

	cmd.Wait()

	_, err := os.Stat(fmt.Sprintf("%s/activated", configDir))
	if err != nil {
		return fmt.Errorf("failed to check on activated file for advanced generate fork config: %w", err)
	}

	return nil
}
