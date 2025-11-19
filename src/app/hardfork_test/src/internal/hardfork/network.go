package hardfork

import (
	"errors"
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"sync"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// TODO: ensure integrity of ports in hf-test-go and mina-local-network

type PortType int

const (
	PORT_CLIENT PortType = iota
	PORT_REST
	PORT_EXTERNAL
	PORT_DAEMON_METRICS
	PORT_LIBP2P_METRICS
)

func (t *HardforkTest) AllPortOfType(ty PortType) []int {
	all_ports := []int{t.Config.SeedStartPort, t.Config.SnarkCoordinatorPort}

	for i := 0; i < t.Config.NumWhales; i++ {
		all_ports = append(all_ports, t.Config.WhaleStartPort+i*5)
	}
	for i := 0; i < t.Config.NumFish; i++ {
		all_ports = append(all_ports, t.Config.FishStartPort+i*5)
	}

	for i := 0; i < t.Config.NumNodes; i++ {
		all_ports = append(all_ports, t.Config.NodeStartPort+i*5)
	}
	for i := range all_ports {
		all_ports[i] += int(ty)
	}
	return all_ports
}

func (t *HardforkTest) AnyPortOfType(ty PortType) int {
	candidates_ports := t.AllPortOfType(ty)

	idx := rand.Intn(len(candidates_ports))
	return candidates_ports[idx]
}

func (t *HardforkTest) stopNode(execPath string, port int, tag string) error {
	t.Logger.Info("Stopping %s at %d", tag, port)
	cmd1 := exec.Command(execPath, "client", "stop-daemon", "--daemon-port", strconv.Itoa(port))
	cmd1.Stdout = os.Stdout
	cmd1.Stderr = os.Stderr
	if err := cmd1.Run(); err != nil {
		return fmt.Errorf("failed to stop %s on port %d: %w", tag, port, err)
	}
	return nil
}

func (t *HardforkTest) StopNodes(execPath string) error {
	t.Logger.Info("Stopping nodes...")

	var wg sync.WaitGroup
	var mu sync.Mutex
	var errs []error

	stop := func(port int, name string) {
		defer wg.Done()
		if err := t.stopNode(execPath, port, name); err != nil {
			mu.Lock()
			errs = append(errs, err)
			mu.Unlock()
		}
	}

	// Step 1: stop all non-seed nodes
	wg.Add(1)
	go stop(SNARK_COORDINATOR_PORT, "snark-coordinator")

	for i := 0; i < t.Config.NumWhales; i++ {
		wg.Add(1)
		go stop(WHALE_START_PORT+i*5, "whale")
	}

	for i := 0; i < t.Config.NumFish; i++ {
		wg.Add(1)
		go stop(FISH_START_PORT+i*5, "fish")
	}

	for i := 0; i < t.Config.NumNodes; i++ {
		wg.Add(1)
		go stop(NODE_START_PORT+i*5, "plain-node")
	}

	wg.Wait()

	// Step 2: stop the seed node
	if err := t.stopNode(execPath, SEED_START_PORT, "seed"); err != nil {
		errs = append(errs, err)
	}

	if len(errs) > 0 {
		return fmt.Errorf("multiple stopNode errors: %w", errors.Join(errs...))
	} else {
		t.Logger.Info("Nodes stopped successfully")
		return nil
	}
}

func (t *HardforkTest) startLocalNetwork(minaExecutable string, profile string, extraArgs []string) (*exec.Cmd, error) {

	t.Logger.Info("Starting network %s...", profile)
	cmd := exec.Command(
		filepath.Join(t.ScriptDir, "../mina-local-network/mina-local-network.sh"),
		"--seed-start-port", strconv.Itoa(t.Config.SeedStartPort),
		"--snark-coordinator-start-port", strconv.Itoa(t.Config.SnarkCoordinatorPort),

		"--whale-start-port", strconv.Itoa(t.Config.WhaleStartPort),
		"--fish-start-port", strconv.Itoa(t.Config.FishStartPort),
		"--node-start-port", strconv.Itoa(t.Config.NodeStartPort),
		"--whales", strconv.Itoa(t.Config.NumWhales),
		"--fish", strconv.Itoa(t.Config.NumFish),
		"--nodes", strconv.Itoa(t.Config.NumNodes),
		"--log-level", "Error",
		"--file-log-level", "Trace",
		"--value-transfer-txns",
		"--transaction-interval", strconv.Itoa(t.Config.PaymentInterval),
		"--root", t.Config.Root,
	)

	cmd.Args = append(cmd.Args, extraArgs...)
	cmd.Env = append(os.Environ(), "MINA_EXE="+minaExecutable)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Start command
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start main network: %w", err)
	}

	// Register command for cleanup on interrupt
	t.registerCmd(cmd)

	t.Logger.Info("Network %s started successfully", profile)
	return cmd, nil
}

// RunMainNetwork starts the main network
func (t *HardforkTest) RunMainNetwork(mainGenesisTs int64) (*exec.Cmd, error) {

	// Set environment variables
	mainGenesisTimestamp := config.FormatTimestamp(mainGenesisTs)

	return t.startLocalNetwork(t.Config.MainMinaExe, "main", []string{
		"--update-genesis-timestamp", fmt.Sprintf("fixed:%s", mainGenesisTimestamp),
		"--config", "reset",
		"--override-slot-time", strconv.Itoa(t.Config.MainSlot * 1000),
		"--slot-transaction-end", strconv.Itoa(t.Config.SlotTxEnd),
		"--slot-chain-end", strconv.Itoa(t.Config.SlotChainEnd),
	})
}

// RunForkNetwork starts the fork network with hardfork configuration
func (t *HardforkTest) RunForkNetwork(configFile, forkLedgersDir string) (*exec.Cmd, error) {
	return t.startLocalNetwork(t.Config.ForkMinaExe, "fork", []string{
		"--update-genesis-timestamp", fmt.Sprintf("delay_sec:%d", t.Config.ForkDelay*60),
		"--config", fmt.Sprintf("inherit_with:%s,%s", configFile, forkLedgersDir),
		"--override-slot-time", strconv.Itoa(t.Config.ForkSlot * 1000)},
	)
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
