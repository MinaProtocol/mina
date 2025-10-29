package hardfork

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// StopNodes stops the nodes running on the specified ports
func (t *HardforkTest) StopNodes(execPath string) error {
	t.Logger.Info("Stopping nodes...")

	// Stop node on port 10301
	cmd1 := exec.Command(execPath, "client", "stop-daemon", "--daemon-port", "10301")
	cmd1.Stdout = os.Stdout
	cmd1.Stderr = os.Stderr
	if err := cmd1.Run(); err != nil {
		return fmt.Errorf("failed to stop daemon on port 10301: %w", err)
	}

	// Stop node on port 10311
	cmd2 := exec.Command(execPath, "client", "stop-daemon", "--daemon-port", "10311")
	cmd2.Stdout = os.Stdout
	cmd2.Stderr = os.Stderr
	if err := cmd2.Run(); err != nil {
		return fmt.Errorf("failed to stop daemon on port 10311: %w", err)
	}

	t.Logger.Info("Nodes stopped successfully")
	return nil
}

// RunMainNetwork starts the main network
func (t *HardforkTest) RunMainNetwork(mainGenesisTs int64) (*exec.Cmd, error) {
	t.Logger.Info("Starting main network...")

	// Set environment variables
	mainGenesisTimestamp := config.FormatTimestamp(mainGenesisTs)

	// Prepare mina-local-network.sh command
	cmd := exec.Command(
		filepath.Join(t.ScriptDir, "../mina-local-network/mina-local-network.sh"),
		"--whales", "2",
		"--fish", "1",
		"--nodes", "1",
		"--update-genesis-timestamp", fmt.Sprintf("fixed:%s", mainGenesisTimestamp),
		"--log-level", "Error",
		"--file-log-level", "Trace",
		"--config", "reset",
		"--value-transfer-txns",
		"--transactions-frequency", strconv.Itoa(t.Config.MainSlot),
		"--override-slot-time", strconv.Itoa(t.Config.MainSlot*1000),
		"--slot-transaction-end", strconv.Itoa(t.Config.SlotTxEnd),
		"--slot-chain-end", strconv.Itoa(t.Config.SlotChainEnd),
	)
	cmd.Env = append(os.Environ(), "MINA_EXE="+t.Config.MainMinaExe)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Start command
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start main network: %w", err)
	}

	// Register command for cleanup on interrupt
	t.registerCmd(cmd)

	t.Logger.Info("Main network started successfully")
	return cmd, nil
}

// RunForkNetwork starts the fork network with hardfork configuration
func (t *HardforkTest) RunForkNetwork(configFile, forkLedgersDir string) (*exec.Cmd, error) {
	t.Logger.Info("Starting fork network...")

	// Prepare mina-local-network.sh command
	cmd := exec.Command(
		filepath.Join(t.ScriptDir, "../mina-local-network/mina-local-network.sh"),
		"--whales", "2",
		"--fish", "1",
		"--nodes", "1",
		"--update-genesis-timestamp", fmt.Sprintf("delay_sec:%d", t.Config.ForkDelay*60),
		"--log-level", "Error",
		"--file-log-level", "Trace",
		"--config", fmt.Sprintf("inherit_with:%s,%s", configFile, forkLedgersDir),
		"--value-transfer-txns",
		"--transactions-frequency", strconv.Itoa(t.Config.ForkSlot),
		"--override-slot-time", strconv.Itoa(t.Config.ForkSlot*1000),
	)
	cmd.Env = append(os.Environ(), "MINA_EXE="+t.Config.ForkMinaExe)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start fork network: %w", err)
	}

	// Register command for cleanup on interrupt
	t.registerCmd(cmd)

	t.Logger.Info("Fork network started successfully")
	return cmd, nil
}

// WaitForBlockHeight waits until the specified block height is reached
func (t *HardforkTest) WaitForBlockHeight(port int, minHeight int, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		height, err := t.Client.GetHeight(port)
		if err != nil {
			t.Logger.Debug("Failed to get block height: %v", err)
			time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
			continue
		}

		if height >= minHeight {
			return nil
		}

		time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
	}

	return fmt.Errorf("timed out waiting for block height >= %d", minHeight)
}

// WaitUntilBestChainQuery calculates and waits until it's time to query the best chain
func (t *HardforkTest) WaitUntilBestChainQuery(slotDurationSec int, chainStartDelaySec int) {
	sleepDuration := time.Duration(slotDurationSec*t.Config.BestChainQueryFrom)*time.Second +
		time.Duration(chainStartDelaySec*60)*time.Second

	t.Logger.Info("Sleeping for %v until best chain query...", sleepDuration)
	time.Sleep(sleepDuration)
}
