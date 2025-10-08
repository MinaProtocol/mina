package hardfork

import (
	"os"
	"os/exec"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/graphql"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/utils"
)

// HardforkTest represents the main hardfork test logic
type HardforkTest struct {
	Config    *config.Config
	Client    *graphql.Client
	Logger    *utils.Logger
	ScriptDir string
}

// NewHardforkTest creates a new instance of the hardfork test
func NewHardforkTest(cfg *config.Config) *HardforkTest {
	return &HardforkTest{
		Config:    cfg,
		Client:    graphql.NewClient(cfg.HTTPClientTimeoutSeconds),
		Logger:    utils.NewLogger(),
		ScriptDir: cfg.ScriptDir,
	}
}

// gracefulShutdown attempts to gracefully shutdown a process with timeout
// It waits for the configured shutdown timeout before forcefully killing the process
func (t *HardforkTest) gracefulShutdown(cmd *exec.Cmd, processName string) {
	if cmd == nil || cmd.Process == nil {
		return
	}

	shutdownTimeout := time.NewTimer(time.Duration(t.Config.ShutdownTimeoutMinutes) * time.Minute)
	processDone := make(chan error, 1)

	go func() {
		processDone <- cmd.Wait()
	}()

	select {
	case <-shutdownTimeout.C:
		t.Logger.Info("%s process did not stop gracefully after %d minutes, forcing kill", processName, t.Config.ShutdownTimeoutMinutes)
		cmd.Process.Kill()
	case <-processDone:
		t.Logger.Info("%s process stopped gracefully", processName)
		shutdownTimeout.Stop()
	}
}

// Run executes the hardfork test process with well-defined phases
func (t *HardforkTest) Run() error {
	t.Logger.Info("===== Starting Hardfork Test =====")

	// Calculate main network genesis timestamp
	mainGenesisTs := time.Now().Unix() + int64(t.Config.MainDelay*60)

	// Define all localnet file paths
	forkConfigPath := "localnet/fork_config.json"

	// Phase 1: Run and validate main network
	t.Logger.Info("Phase 1: Running main network...")
	forkConfigBytes, analysis, err := t.RunMainNetworkPhase(forkConfigPath, mainGenesisTs)
	if err != nil {
		return err
	}

	t.Logger.Info("Phase 2: Validating extracted fork configuration...")
	// Validate fork config data
	if err := t.ValidateForkConfigData(analysis.LatestNonEmptyBlock, forkConfigBytes); err != nil {
		return err
	}
	{
		preforkLedgersDir := "localnet/prefork_hf_ledgers"
		preforkHashesFile := "localnet/prefork_hf_ledger_hashes.json"
		if err := t.GenerateAndValidatePreforkLedgers(analysis, forkConfigPath, preforkLedgersDir, preforkHashesFile); err != nil {
			return err
		}
	}

	configFile := "localnet/config.json"
	forkLedgersDir := "localnet/hf_ledgers"

	// Calculate fork genesis timestamp relative to now (before starting fork network)
	forkGenesisTs := time.Now().Unix() + int64(t.Config.ForkDelay*60)

	t.Logger.Info("Phase 3: Generating fork configuration and ledgers...")
	{
		os.MkdirAll("localnet/config", 0755)
		baseConfigFile := "localnet/config/base.json"
		forkHashesFile := "localnet/hf_ledger_hashes.json"
		if err := t.GenerateForkConfigAndLedgers(analysis, forkConfigPath, forkLedgersDir, forkHashesFile, configFile, baseConfigFile, forkGenesisTs, mainGenesisTs); err != nil {
			return err
		}
	}

	t.Logger.Info("Phase 4: Running fork network...")
	if err := t.RunForkNetworkPhase(analysis.LatestNonEmptyBlock.BlockHeight, configFile, forkLedgersDir, forkGenesisTs, mainGenesisTs); err != nil {
		return err
	}

	t.Logger.Info("===== Hardfork test completed successfully! =====")
	return nil
}
