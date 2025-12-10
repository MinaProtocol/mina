package hardfork

import (
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
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
		all_ports = append(all_ports, t.Config.WhaleStartPort+i*6)
	}
	for i := 0; i < t.Config.NumFish; i++ {
		all_ports = append(all_ports, t.Config.FishStartPort+i*6)
	}

	for i := 0; i < t.Config.NumNodes; i++ {
		all_ports = append(all_ports, t.Config.NodeStartPort+i*6)
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

func (t *HardforkTest) startLocalNetwork(minaExecutable string, profile string, extraArgs []string) (*exec.Cmd, error) {

	t.Logger.Info("Starting network %s...", profile)
	cmd := exec.Command(
		filepath.Join(t.ScriptDir, "../mina-local-network/mina-local-network.sh"),
		"--seed", fmt.Sprintf("spawn:%d", t.Config.SeedStartPort),
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

	mainGenesisTimestamp := config.FormatTimestamp(mainGenesisTs)

	args := []string{
		"--update-genesis-timestamp", fmt.Sprintf("fixed:%s", mainGenesisTimestamp),
		"--config", "reset",
		"--override-slot-time", strconv.Itoa(t.Config.MainSlot * 1000),
		"--slot-transaction-end", strconv.Itoa(t.Config.SlotTxEnd),
		"--slot-chain-end", strconv.Itoa(t.Config.SlotChainEnd),
		"--hardfork-genesis-slot-delta", strconv.Itoa(t.Config.HfSlotDelta),
	}

	return t.startLocalNetwork(t.Config.MainMinaExe, "main", args)
}

// RunForkNetwork starts the fork network with hardfork configuration
func (t *HardforkTest) RunForkNetwork(configFile, forkLedgersDir string) (*exec.Cmd, error) {
	return t.startLocalNetwork(t.Config.ForkMinaExe, "fork", []string{
		"--config", fmt.Sprintf("inherit_with:%s,%s", configFile, forkLedgersDir),
		"--override-slot-time", strconv.Itoa(t.Config.ForkSlot * 1000)},
	)
}

// WaitUntilBestChainQuery calculates and waits until it's time to query the best chain
// TODO: refactor away chainStartDelayMin as it's not used at all, unify behavior of legacy/advanced mode
// to use HfSlotDelta
func (t *HardforkTest) WaitUntilBestChainQuery(slotDurationSec int, genesisSlot int) {
	t.WaitForBestTip(t.AnyPortOfType(PORT_REST), func(block client.BlockData) bool {
		return block.Slot >= t.Config.BestChainQueryFrom+genesisSlot
	}, fmt.Sprintf("best tip reached slot %d", t.Config.BestChainQueryFrom),
		time.Duration(2*t.Config.BestChainQueryFrom*slotDurationSec)*time.Second,
	)
}
