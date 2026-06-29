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

// GenerateForkLedgers generates the hardfork ledgers using the specified executable
func (t *HardforkTest) GenerateForkLedgers(executablePath, forkConfigPath, ledgersDir, hashesFile string, extraArgs ...string) error {
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
	args = append(args, extraArgs...)

	cmd := exec.Command(executablePath, args...)

	tmpDir, err := os.MkdirTemp("", "mina-hf-tmp-")
	if err != nil {
		return fmt.Errorf("failed to create temp dir: %w", err)
	}
	cmd.Env = append(os.Environ(), "TMPDIR="+tmpDir)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run fork runtime genesis ledger: %w", err)
	}

	t.Logger.Info("Fork ledgers generated successfully")
	return nil
}

func (t *HardforkTest) GenerateAndValidateHashesAndLedgers(analysis BlockAnalysisResult, forkConfigPath, preforkLedgersDir, prepatchForkConfig string) error {
	// Generate prefork ledgers using main network executable
	if err := t.GenerateForkLedgers(t.Config.MainRuntimeGenesisLedger, forkConfigPath, preforkLedgersDir, prepatchForkConfig); err != nil {
		return err
	}

	return t.ValidateRuntimeGenesisLedgerHashes(
		analysis,
		prepatchForkConfig,
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
