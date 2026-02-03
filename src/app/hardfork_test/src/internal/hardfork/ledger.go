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

func (t *HardforkTest) GenerateAndValidateHashesAndLedgers(analysis *BlockAnalysisResult, forkConfigPath, preforkLedgersDir, prepatchForkConfig string) error {
	// Generate prefork ledgers using main network executable
	if err := t.GenerateForkLedgers(t.Config.MainRuntimeGenesisLedger, forkConfigPath, preforkLedgersDir, prepatchForkConfig); err != nil {
		return err
	}

	return t.ValidateRuntimeGenesisLedgerHashes(
		analysis.LastBlockBeforeTxEnd,
		analysis.GenesisBlock.CurEpochHash,
		analysis.GenesisBlock.NextEpochHash,
		analysis.RecentSnarkedHashPerEpoch,
		prepatchForkConfig,
	)
}

// PatchForkConfigAndGenerateLedgersLegacy does the following:
// 1. generate fork ledgers with runtime-genesis-ledger
// 2. patch the genesis time & slot for fork config with create_runtime_config.sh
// 3. perform some base sanity check on the fork config
func (t *HardforkTest) PatchForkConfigAndGenerateLedgersLegacy(analysis *BlockAnalysisResult, forkConfigPath, forkLedgersDir, forkHashesFile, configFile, preforkGenesisConfigFile string, forkGenesisTs, mainGenesisTs int64) ([]byte, error) {
	// Generate fork ledgers using fork network executable
	if err := t.GenerateForkLedgers(t.Config.ForkRuntimeGenesisLedger, forkConfigPath, forkLedgersDir, forkHashesFile); err != nil {
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
