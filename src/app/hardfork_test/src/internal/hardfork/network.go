package hardfork

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/topology"
)

// startLocalNetwork spawns a network from a pre-built topology JSON blob using
// mina-local-network.py spawn topology. It writes the JSON to a temp file,
// starts the python process in the background, and registers it for cleanup.
func (t *HardforkTest) startLocalNetwork(topoJSON []byte, profile string) (*exec.Cmd, error) {
	t.Logger.Info("Starting network %s...", profile)

	topoFile := filepath.Join(os.TempDir(), fmt.Sprintf("mina-hf-test-%s-topology.json", profile))
	if err := os.WriteFile(topoFile, topoJSON, 0644); err != nil {
		return nil, fmt.Errorf("failed to write topology file for %s network: %w", profile, err)
	}

	pythonPath := filepath.Join(t.ScriptDir, "../mina-local-network/mina-local-network.py")
	cmd := exec.Command("python3", pythonPath, "spawn", "topology", topoFile)
	cmd.Env = os.Environ()
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start %s network: %w", profile, err)
	}

	t.registerCmd(cmd)

	t.Logger.Info("Network %s started successfully", profile)
	return cmd, nil
}

// RunMainNetwork starts the main (pre-fork) network using the topology generator.
func (t *HardforkTest) RunMainNetwork(extraFilesRoot string, mainGenesisTs int64) (*exec.Cmd, error) {
	extraAccountsFile := ""
	if t.Config.VestingTestEnabled && t.vestingAccount != nil {
		extraAccountsFile = t.vestingAccount.extraAccountFile
	}

	genesisTsRFC3339 := time.Unix(mainGenesisTs, 0).UTC().Format(time.RFC3339)
	topoJSON, err := topology.GenerateMainTopologyJSON(t.Config, extraFilesRoot, extraAccountsFile, genesisTsRFC3339)
	if err != nil {
		return nil, fmt.Errorf("failed to generate main topology JSON: %w", err)
	}

	return t.startLocalNetwork(topoJSON, "main")
}

// RunForkNetwork starts the fork (post-fork) network using the topology generator.
func (t *HardforkTest) RunForkNetwork() (*exec.Cmd, error) {
	topoJSON, err := topology.GenerateForkTopologyJSON(t.Config, "")
	if err != nil {
		return nil, fmt.Errorf("failed to generate fork topology JSON: %w", err)
	}

	return t.startLocalNetwork(topoJSON, "fork")
}

// WaitUntilBestChainQuery calculates and waits until it's time to query the best chain
func (t *HardforkTest) WaitUntilBestChainQuery(slotDurationSec int, genesisSlot int) {
	t.WaitForBestTip(t.Config.AnyDaemon().Port(config.PORT_REST), func(block client.BlockData) bool {
		return block.Slot >= t.Config.BestChainQueryFrom+genesisSlot
	}, fmt.Sprintf("best tip reached slot %d", t.Config.BestChainQueryFrom),
		time.Duration(2*t.Config.BestChainQueryFrom*slotDurationSec)*time.Second,
	)
}
