package hardfork

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/topology"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/utils"
)

// HardforkTest represents the main hardfork test logic
type HardforkTest struct {
	Config *config.Config
	// Topology is the network shape both the main and fork networks run on.
	Topology *topology.Topology
	// ConsensusParams are read from the topology, which is what the daemons are
	// configured from, so the test cannot disagree with the network it runs.
	ConsensusParams topology.ConsensusParams
	Client          *client.Client
	Logger          *utils.Logger
	ScriptDir       string
	vestingAccount  *vestingAccount
	topologyFiles   []string
	runningCmds     []*exec.Cmd
	runningCmdsMux  sync.Mutex
	ctx             context.Context
	cancel          context.CancelFunc
}

// lowerTopologyFile lowers a topology preset to its explicit-nodes (v1) form via
// the mln sampler, writing the result to a temp file and returning its path. A v2
// (constraint) preset is sampled into concrete nodes; a v1 preset passes through
// unchanged. The caller owns the returned temp file.
func lowerTopologyFile(scriptDir, topologyFile string) (string, error) {
	mln := filepath.Join(scriptDir, "../mina-local-network/mina-local-network.py")
	cmd := exec.Command("python3", mln, "plan", "lower", topologyFile)
	cmd.Env = os.Environ()
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to lower topology %q: %w", topologyFile, err)
	}
	f, err := os.CreateTemp("", "hardfork-lowered-*.json")
	if err != nil {
		return "", err
	}
	if _, err := f.Write(out); err != nil {
		f.Close()
		os.Remove(f.Name())
		return "", fmt.Errorf("failed to write lowered topology: %w", err)
	}
	if err := f.Close(); err != nil {
		os.Remove(f.Name())
		return "", err
	}
	return f.Name(), nil
}

// NewHardforkTest creates a new instance of the hardfork test
func NewHardforkTest(cfg *config.Config) (*HardforkTest, error) {
	ctx, cancel := context.WithCancel(context.Background())

	// Lower the preset to its explicit-nodes (v1) form first. A constraint (v2)
	// topology names no nodes directly — the sampler places them — so the harness
	// asks mln for the lowered form and builds its daemon list from those sampled
	// nodes. A v1 preset lowers to itself, so this path is uniform.
	//
	// Sampling is random per run (an unpinned v2 topology draws a fresh layout), so
	// this lowering happens exactly once: its concrete nodes are what both the main
	// and fork networks render from (`plan topology`/`patch topology` receive nodes,
	// not requirements, and so never re-sample). Main and fork therefore always
	// agree on the layout without pinning a seed.
	loweredFile, err := lowerTopologyFile(cfg.ScriptDir, cfg.TopologyFile)
	if err != nil {
		cancel()
		return nil, err
	}
	defer os.Remove(loweredFile) // topology.Load reads it fully into memory

	// The topology declares the daemons, so it must be loaded before the daemon
	// list can be built from it.
	topo, err := topology.Load(loweredFile)
	if err != nil {
		cancel()
		return nil, err
	}
	if err := cfg.InitDaemonInfos(topo.NodeNames(), topo.SeedName()); err != nil {
		cancel()
		return nil, err
	}

	slotEnds, err := cfg.ResolveSlotEnds()
	if err != nil {
		cancel()
		return nil, err
	}
	logger := utils.NewLogger()
	// Logged before anything can fail: slot-tx-end is randomized when not given,
	// so this line is what makes a failing run reproducible.
	logger.Info("Slot schedule: %s", slotEnds)

	return &HardforkTest{
		Config:          cfg,
		Topology:        topo,
		ConsensusParams: topo.Consensus(),
		Client:          client.NewClient(cfg.HTTPClientTimeoutSeconds, cfg.ClientMaxRetries),
		Logger:          logger,
		ScriptDir:       cfg.ScriptDir,
		runningCmds:     make([]*exec.Cmd, 0),
		ctx:             ctx,
		cancel:          cancel,
	}, nil
}

// sigtermExitCode is what a process that terminates on SIGTERM exits with, by
// the shell's 128+signal convention. Since gracefulShutdown asks for exactly
// that, it is the expected code for a *successful* shutdown, not a failure.
const sigtermExitCode = 128 + int(syscall.SIGTERM)

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
	case err := <-processDone:
		shutdownTimeout.Stop()
		// The process has been reaped, so its PID must not be signalled again.
		t.unregisterCmd(cmd)
		switch exitErr, ok := err.(*exec.ExitError); {
		case err == nil, ok && exitErr.ExitCode() == sigtermExitCode:
			t.Logger.Info("%s process stopped gracefully", processName)
		case ok:
			t.Logger.Error("%s shutdown was incomplete (exit code %d), some nodes may not have been stopped cleanly", processName, exitErr.ExitCode())
		default:
			t.Logger.Error("%s shutdown failed: %v", processName, err)
		}
	}
}

// registerCmd adds a command to the list of running commands
func (t *HardforkTest) registerCmd(cmd *exec.Cmd) {
	t.runningCmdsMux.Lock()
	defer t.runningCmdsMux.Unlock()
	t.runningCmds = append(t.runningCmds, cmd)
}

// unregisterCmd drops a command from the list of running commands, so that a
// process which has already been waited for is never signalled again — its PID
// is free for the OS to reuse the moment it is reaped.
func (t *HardforkTest) unregisterCmd(cmd *exec.Cmd) {
	t.runningCmdsMux.Lock()
	defer t.runningCmdsMux.Unlock()

	for i, c := range t.runningCmds {
		if c == cmd {
			t.runningCmds = append(t.runningCmds[:i], t.runningCmds[i+1:]...)
			return
		}
	}
}

// cleanupAllProcesses terminates every process still registered as running.
func (t *HardforkTest) cleanupAllProcesses() {
	t.runningCmdsMux.Lock()
	defer t.runningCmdsMux.Unlock()

	if len(t.runningCmds) == 0 {
		return
	}

	// Terminate all script processes
	for _, cmd := range t.runningCmds {
		if cmd != nil && cmd.Process != nil {
			t.Logger.Info("Terminating process PID %d", cmd.Process.Pid)
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
	defer t.cleanupTopologyFiles()

	t.Logger.Info("===== Starting Hardfork Test =====")

	// Seed a timed/vesting account into the pre-fork genesis ledger so we can
	// verify the Mesa slot-reduction vesting update after the fork (see vesting.go).
	if err := t.SetupVestingAccount(); err != nil {
		return err
	}
	defer t.CleanupVestingAccount()

	// Calculate main network genesis timestamp
	mainGenesisTs := time.Now().Unix() + int64(t.Config.MainDelayMin*60)

	// Phase 1: Run and validate main network
	t.Logger.Info("Phase 1: Running main network...")

	beforeShutdown := func(t *HardforkTest, analysis *BlockAnalysisResult) error {
		t.Logger.Info("Phase 2: Forking with fork method `%s`...", t.Config.ForkMethods)

		if err := t.ForkPhase(analysis, mainGenesisTs); err != nil {
			return err
		}
		return nil
	}

	analysis, err := t.RunMainNetworkPhase(mainGenesisTs, beforeShutdown)
	if err != nil {
		return err
	}

	t.Logger.Info("Phase 3: Cleaning up main config and moving fork config into correct location...")

	if err := t.CleanUpNetworkForForkPhase(); err != nil {
		return err
	}

	t.Logger.Info("Phase 4: Running fork network...")
	if err := t.RunForkNetworkPhase(
		analysis.Consensus.LastBlockBeforeTxEnd.BlockHeight,
		mainGenesisTs,
		analysis.PreForkPoolNonces,
	); err != nil {
		return err
	}

	t.Logger.Info("===== Hardfork test completed successfully! =====")
	return nil
}
