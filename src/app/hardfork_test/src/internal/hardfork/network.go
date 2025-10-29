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

// TODO: ensure integrity of ports in hf-test-go and mina-local-network

const SEED_START_PORT = 3000
const ARCHIVE_SERVER_PORT = 3086
const SNARK_COORDINATOR_PORT = 7000
const WHALE_START_PORT = 4000
const FISH_START_PORT = 5000
const NODE_START_PORT = 6000

func (t *HardforkTest) stopNode(execPath string, port int, tag string) error {
	t.Logger.Info("Stopping %s at %d", tag, port)
	cmd1 := exec.Command(execPath, "client", "stop-daemon", "--daemon-port", strconv.Itoa(port))
	cmd1.Stdout = os.Stdout
	cmd1.Stderr = os.Stderr
	if err := cmd1.Run(); err != nil {
		return fmt.Errorf("failed to stop %s on port 10301: %w", tag, err)
	}
	return nil
}

// StopNodes stops the nodes running on the specified ports
func (t *HardforkTest) StopNodes(execPath string) error {
	t.Logger.Info("Stopping nodes...")

	if err := t.stopNode(execPath, SEED_START_PORT, "seed"); err != nil {
		return err
	}

	if err := t.stopNode(execPath, SNARK_COORDINATOR_PORT, "snark-cooridinator"); err != nil {
		return err
	}

	for i := 0; i < t.Config.NumWhales; i++ {
		if err := t.stopNode(execPath, WHALE_START_PORT+i*5, "whale"); err != nil {
			return err
		}
	}

	for i := 0; i < t.Config.NumFish; i++ {
		if err := t.stopNode(execPath, FISH_START_PORT+i*5, "fish"); err != nil {
			return err
		}
	}

	for i := 0; i < t.Config.NumNodes; i++ {
		if err := t.stopNode(execPath, NODE_START_PORT+i*5, "plain-node"); err != nil {
			return err
		}
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
		"--whales", strconv.Itoa(t.Config.NumWhales),
		"--fish", strconv.Itoa(t.Config.NumFish),
		"--nodes", strconv.Itoa(t.Config.NumNodes),
		"--update-genesis-timestamp", fmt.Sprintf("fixed:%s", mainGenesisTimestamp),
		"--log-level", "Error",
		"--file-log-level", "Trace",
		"--config", "reset",
		"--value-transfer-txns",
		"--transactions-frequency", strconv.Itoa(t.Config.PaymentInterval),
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
		"--whales", strconv.Itoa(t.Config.NumWhales),
		"--fish", strconv.Itoa(t.Config.NumFish),
		"--nodes", strconv.Itoa(t.Config.NumNodes),
		"--update-genesis-timestamp", fmt.Sprintf("delay_sec:%d", t.Config.ForkDelay*60),
		"--log-level", "Error",
		"--file-log-level", "Trace",
		"--config", fmt.Sprintf("inherit_with:%s,%s", configFile, forkLedgersDir),
		"--value-transfer-txns",
		"--transactions-frequency", strconv.Itoa(t.Config.PaymentInterval),
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
