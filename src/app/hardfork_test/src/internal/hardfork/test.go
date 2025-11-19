package hardfork

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/graphql"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/utils"
)

// HardforkTest represents the main hardfork test logic
type HardforkTest struct {
	Config         *config.Config
	Client         *graphql.Client
	Logger         *utils.Logger
	ScriptDir      string
	runningCmds    []*exec.Cmd
	runningCmdsMux sync.Mutex
	ctx            context.Context
	cancel         context.CancelFunc
}

// NewHardforkTest creates a new instance of the hardfork test
func NewHardforkTest(cfg *config.Config) *HardforkTest {
	ctx, cancel := context.WithCancel(context.Background())
	return &HardforkTest{
		Config:      cfg,
		Client:      graphql.NewClient(cfg.HTTPClientTimeoutSeconds, cfg.GraphQLMaxRetries),
		Logger:      utils.NewLogger(),
		ScriptDir:   cfg.ScriptDir,
		runningCmds: make([]*exec.Cmd, 0),
		ctx:         ctx,
		cancel:      cancel,
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

// registerCmd adds a command to the list of running commands
func (t *HardforkTest) registerCmd(cmd *exec.Cmd) {
	t.runningCmdsMux.Lock()
	defer t.runningCmdsMux.Unlock()
	t.runningCmds = append(t.runningCmds, cmd)
}

// cleanupAllProcesses kills all running processes
func (t *HardforkTest) cleanupAllProcesses() {
	t.runningCmdsMux.Lock()
	defer t.runningCmdsMux.Unlock()

	if len(t.runningCmds) == 0 {
		return
	}

	// Kill all script processes
	for _, cmd := range t.runningCmds {
		if cmd != nil && cmd.Process != nil {
			t.Logger.Info("Killing process PID %d", cmd.Process.Pid)
			cmd.Process.Kill()
		}
	}
}

// setupSignalHandler sets up signal handling for graceful shutdown
func (t *HardforkTest) setupSignalHandler() {
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		<-sigChan
		t.Logger.Info("\nReceived interrupt signal, cleaning up...")
		t.cancel()
		t.cleanupAllProcesses()
		os.Exit(130) // Standard exit code for SIGINT
	}()
}

// Run executes the hardfork test process with well-defined phases
func (t *HardforkTest) Run() error {
	// Set up signal handler for Ctrl+C
	t.setupSignalHandler()
	defer t.cleanupAllProcesses()

	t.Logger.Info("===== Starting Hardfork Test =====")

	// Calculate main network genesis timestamp
	mainGenesisTs := time.Now().Unix() + int64(t.Config.MainDelay*60)

	// Define all localnet file paths
	if err := os.MkdirAll("fork_data/prefork", 0755); err != nil {
		return err
	}

	// Define all fork_data file paths
	preforkConfig := "fork_data/prefork/config.json"

	// Phase 1: Run and validate main network
	t.Logger.Info("Phase 1: Running main network...")
	forkConfigBytes, analysis, err := t.RunMainNetworkPhase(mainGenesisTs)
	if err != nil {
		return err
	}

	t.Logger.Info("Phase 2: Validating extracted fork configuration...")
	// Validate fork config data
	if err := t.ValidateForkConfigData(analysis.LatestNonEmptyBlock, forkConfigBytes); err != nil {
		return err
	}
	// Write fork config to file
	if err := os.WriteFile(preforkConfig, forkConfigBytes, 0644); err != nil {
		return err
	}
	{
		preforkLedgersDir := "fork_data/prefork/hf_ledgers"
		preforkHashesFile := "fork_data/prefork/hf_ledger_hashes.json"
		if err := t.GenerateAndValidatePreforkLedgers(analysis, preforkConfig, preforkLedgersDir, preforkHashesFile); err != nil {
			return err
		}
	}

	if err = os.MkdirAll("fork_data/postfork", 0755); err != nil {
		return err
	}

	postforkConfig := "fork_data/postfork/config.json"
	forkLedgersDir := "fork_data/postfork/hf_ledgers"

	// Calculate fork genesis timestamp relative to now (before starting fork network)
	forkGenesisTs := time.Now().Unix() + int64(t.Config.ForkDelay*60)

	t.Logger.Info("Phase 3: Generating fork configuration and ledgers...")
	{
		preforkGenesisConfigFile := fmt.Sprintf("%s/daemon.json", t.Config.Root)
		forkHashesFile := "fork_data/hf_ledger_hashes.json"
		if err := t.GenerateForkConfigAndLedgers(analysis, preforkConfig, forkLedgersDir, forkHashesFile, postforkConfig, preforkGenesisConfigFile, forkGenesisTs, mainGenesisTs); err != nil {
			return err
		}
	}

	t.Logger.Info("Phase 4: Running fork network...")
	if err := t.RunForkNetworkPhase(analysis.LatestNonEmptyBlock.BlockHeight, postforkConfig, forkLedgersDir, forkGenesisTs, mainGenesisTs); err != nil {
		return err
	}

	t.Logger.Info("===== Hardfork test completed successfully! =====")
	return nil
}
