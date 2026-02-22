package hardfork

import (
	"context"
	"os"
	"os/exec"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/utils"
)

// HardforkTest represents the main hardfork test logic
type HardforkTest struct {
	Config         *config.Config
	Client         *client.Client
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
		Client:      client.NewClient(cfg.HTTPClientTimeoutSeconds, cfg.ClientMaxRetries),
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

	cmd.Process.Signal(syscall.SIGTERM)

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
			cmd.Process.Signal(syscall.SIGTERM)
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
	mainGenesisTs := time.Now().Unix() + int64(t.Config.MainDelayMin*60)

	// Phase 1: Run and validate main network
	t.Logger.Info("Phase 1: Running main network...")
	forkDataChan := make(chan ForkData, 1)

	beforeShutdown := func(t *HardforkTest, analysis *BlockAnalysisResult) error {
		t.Logger.Info("Phase 2: Forking with fork method `%s`...", t.Config.ForkMethod.String())

		var forkData *ForkData
		var err error
		switch t.Config.ForkMethod {
		case config.Legacy:
			forkData, err = t.LegacyForkPhase(analysis, mainGenesisTs)
		case config.Advanced:
			forkData, err = t.AdvancedForkPhase(analysis, mainGenesisTs)
		}

		if err != nil {
			return err
		}
		forkDataChan <- *forkData
		return nil
	}

	analysis, err := t.RunMainNetworkPhase(mainGenesisTs, beforeShutdown)
	if err != nil {
		return err
	}

	t.Logger.Info("Phase 3: Running fork network...")
	if err := t.RunForkNetworkPhase(analysis.Consensus.LastBlockBeforeTxEnd.BlockHeight, <-forkDataChan, mainGenesisTs); err != nil {
		return err
	}

	t.Logger.Info("===== Hardfork test completed successfully! =====")
	return nil
}
