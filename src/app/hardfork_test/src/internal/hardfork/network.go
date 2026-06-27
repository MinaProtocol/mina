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
		"--log-level", "Info",
		"--file-log-level", "Trace",
		"--transaction-interval", strconv.Itoa(t.Config.PaymentInterval),
		"--root", t.Config.Root,
	)

	// Built-in value-transfer load (mina-local-network's per-payment `mina client
	// send-payment` loop), selected per phase. Both networks default to OFF: the
	// transaction load is instead driven in-process over ITN (custom-token payments
	// on the pre-fork network, max-cost zkApps on the post-fork network), which the
	// daemon schedules internally and so avoids spawning a client subprocess per
	// payment (which otherwise churns PIDs against the cgroup limit). The old
	// subprocess loop can still be re-enabled per phase with
	// HARDFORK_VALUE_TRANSFERS_MAIN / HARDFORK_VALUE_TRANSFERS_FORK ("0"/"1").
	valueTransfers := false
	vtVar := "HARDFORK_VALUE_TRANSFERS_MAIN"
	if profile == "fork" {
		vtVar = "HARDFORK_VALUE_TRANSFERS_FORK"
	}
	if v := os.Getenv(vtVar); v != "" {
		valueTransfers = v != "0"
	}
	if valueTransfers {
		cmd.Args = append(cmd.Args, "--value-transfer-txns")
	}

	// Combine block-producer roles onto the seed and snark coordinator so the
	// network runs as 2 daemons instead of 4. These flags apply to both the main
	// and fork networks (both must keep producing blocks).
	if t.Config.SeedIsWhale {
		cmd.Args = append(cmd.Args, "--seed-is-whale")
	}
	if t.Config.SnarkCoordinatorIsWhale {
		cmd.Args = append(cmd.Args, "--snark-coordinator-is-whale")
	}

	cmd.Args = append(cmd.Args, extraArgs...)
	cmd.Env = append(os.Environ(), "MINA_EXE="+minaExecutable)

	// Optional archive node: when HARDFORK_ARCHIVE_PORT is set, enable the archive
	// node in the local network and select the protocol-appropriate archive binary
	// (Berkeley for the main/pre-fork network, Mesa for the fork/post-fork network)
	// so the archive binary stays compatible with the (migrated) schema across the
	// hardfork. The Postgres connection and the pre-fork schema file are taken from
	// the PG_* / CREATE_SCHEMA_FILE environment, which mina-local-network.sh reads.
	if archivePort := os.Getenv("HARDFORK_ARCHIVE_PORT"); archivePort != "" {
		cmd.Args = append(cmd.Args, "--archive-server-port", archivePort)
		archiveExe := os.Getenv("MAIN_ARCHIVE_EXE")
		if profile == "fork" {
			archiveExe = os.Getenv("FORK_ARCHIVE_EXE")
		}
		if archiveExe != "" {
			cmd.Env = append(cmd.Env, "ARCHIVE_EXE="+archiveExe)
		}
	}

	// Optional ITN GraphQL endpoint (each daemon's base port + 5), used to drive
	// transaction load externally after a quiet, archive-verified warm-up: payments
	// on the pre-fork (main) network and max-cost zkApp commands on the post-fork
	// (Mesa) network. Selected per phase so ITN can be enabled only where the binary
	// supports it (the Berkeley pre-fork binary may differ from the Mesa one). The
	// daemons additionally need ITN_FEATURES=1 in their environment (caller-provided).
	itnEnv := "HARDFORK_ITN_KEYS_MAIN"
	if profile == "fork" {
		itnEnv = "HARDFORK_ITN_KEYS_FORK"
	}
	if itnKeys := os.Getenv(itnEnv); itnKeys != "" {
		cmd.Args = append(cmd.Args, "--itn-keys", itnKeys)
		// mina-local-network.sh only wires up the ITN GraphQL endpoint when the
		// daemons see ITN_FEATURES=1 in their environment, so propagate it here.
		cmd.Env = append(cmd.Env, "ITN_FEATURES=1")
	}

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

	// Seed the timed/vesting account into the freshly generated genesis ledger so
	// it flows through fork-config extraction and migration (see vesting.go).
	if t.Config.VestingTestEnabled && t.Config.VestingExtraAccountFile != "" {
		args = append(args, "--extra-genesis-account-file", t.Config.VestingExtraAccountFile)
	}

	return t.startLocalNetwork(t.Config.MainMinaExe, "main", args)
}

// RunForkNetwork starts the fork network with hardfork configuration
func (t *HardforkTest) RunForkNetwork() (*exec.Cmd, error) {
	return t.startLocalNetwork(t.Config.ForkMinaExe, "fork", []string{
		"--config", "inherit",
		"--override-slot-time", strconv.Itoa(t.Config.ForkSlot * 1000)},
	)
}

// WaitUntilBestChainQuery calculates and waits until it's time to query the best chain
func (t *HardforkTest) WaitUntilBestChainQuery(slotDurationSec int, genesisSlot int) {
	t.WaitForBestTip(t.Config.AnyDaemon().Port(config.PORT_REST), func(block client.BlockData) bool {
		return block.Slot >= t.Config.BestChainQueryFrom+genesisSlot
	}, fmt.Sprintf("best tip reached slot %d", t.Config.BestChainQueryFrom),
		time.Duration(2*t.Config.BestChainQueryFrom*slotDurationSec)*time.Second,
	)
}
