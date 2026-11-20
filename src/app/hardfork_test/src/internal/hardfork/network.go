package hardfork

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

func (t *HardforkTest) startLocalNetwork(minaExecutable string, profile string, extraArgs []string, extraEnv []string) (*exec.Cmd, error) {

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
		"--log-level", "Info",
		"--file-log-level", "Trace",
		"--value-transfer-txns",
		"--transaction-interval", strconv.Itoa(t.Config.PaymentInterval),
		"--root", t.Config.Root,
	)

	cmd.Args = append(cmd.Args, extraArgs...)
	cmd.Env = append(
		os.Environ(),
		"MINA_EXE="+minaExecutable,
		"MINA_GRAPHQL_CLIENT_EXE="+t.Config.MinaGraphqlClientExe,
	)
	cmd.Env = append(cmd.Env, extraEnv...)

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
func (t *HardforkTest) RunMainNetwork(extraFilesRoot string, mainGenesisTs int64) (*exec.Cmd, error) {

	mainGenesisTimestamp := config.FormatTimestamp(mainGenesisTs)

	args := []string{
		"--update-genesis-timestamp", fmt.Sprintf("fixed:%s", mainGenesisTimestamp),
		"--config", "reset",
		"--override-slot-time", strconv.Itoa(t.Config.MainSlot * 1000),
		"--slot-transaction-end", strconv.Itoa(t.Config.SlotTxEnd),
		"--slot-chain-end", strconv.Itoa(t.Config.SlotChainEnd),
		"--hardfork-genesis-slot-delta", strconv.Itoa(t.Config.HfSlotDelta),
		"--extra-files-root", extraFilesRoot,
	}

	var env []string
	if t.Config.ArchiveEnabled() {
		archiveArgs, err := t.archiveNetworkArgs()
		if err != nil {
			return nil, err
		}
		args = append(args, archiveArgs...)
		args = append(args, "--pg-schema-file", t.Config.MainArchiveSchema)
		env = append(env, "ARCHIVE_EXE="+t.Config.MainArchiveExe)
	}

	return t.startLocalNetwork(t.Config.MainMinaExe, "main", args, env)
}

// RunForkNetwork starts the fork network with hardfork configuration
func (t *HardforkTest) RunForkNetwork() (*exec.Cmd, error) {
	args := []string{
		"--config", "inherit",
		"--override-slot-time", strconv.Itoa(t.Config.ForkSlot * 1000),
	}

	var env []string
	if t.Config.ArchiveEnabled() {
		archiveArgs, err := t.archiveNetworkArgs()
		if err != nil {
			return nil, err
		}
		args = append(args, archiveArgs...)
		// In inherit mode mina-local-network.sh keeps the database, so the
		// fork archive continues in the database of the main network.
		args = append(args,
			"--archive-config-file", t.archiveForkConfigFile(),
			"--rosetta-port", strconv.Itoa(t.Config.RosettaPort),
		)
		env = append(env,
			"ARCHIVE_EXE="+t.Config.ForkArchiveExe,
			"ROSETTA_EXE="+t.Config.ForkRosettaExe,
			// The archive loads the fork genesis ledger from this directory.
			"MINA_KEYS_PATH="+t.forkGenesisDir,
		)
	}

	return t.startLocalNetwork(t.Config.ForkMinaExe, "fork", args, env)
}

// WaitUntilBestChainQuery calculates and waits until it's time to query the best chain
func (t *HardforkTest) WaitUntilBestChainQuery(slotDurationSec int, genesisSlot int) {
	t.WaitForBestTip(t.Config.AnyDaemon().Port(config.PORT_REST), func(block client.BlockData) bool {
		return block.Slot >= t.Config.BestChainQueryFrom+genesisSlot
	}, fmt.Sprintf("best tip reached slot %d", t.Config.BestChainQueryFrom),
		time.Duration(2*t.Config.BestChainQueryFrom*slotDurationSec)*time.Second,
	)
}
