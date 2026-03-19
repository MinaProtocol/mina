package hardfork

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

type HFHandler func(*HardforkTest, *BlockAnalysisResult) error

// RunMainNetworkPhase runs the main network and validates its operation
// and returns the fork config bytes and block analysis result
func (t *HardforkTest) RunMainNetworkPhase(mainGenesisTs int64, beforeShutdown HFHandler) (*BlockAnalysisResult, error) {

	for _, info := range t.Config.DaemonInfos {
		t.Logger.Info("Planning to use fork method %s on node %s", info.ForkMethod, info.NodeDir)

		if info.ForkMethod == config.Auto {
			if err := os.MkdirAll(info.NodeDir, 0755); err != nil {
				return nil, fmt.Errorf("Failed to create node dir at %s: %v", info.NodeDir, err)
			}
			extra_args := []byte("--hardfork-handling migrate-exit")
			if err := os.WriteFile(path.Join(info.NodeDir, "extra_args.txt"), extra_args, 0644); err != nil {
				return nil, fmt.Errorf("Failed to write extra_args.txt: %v", info.NodeDir, err)
			}
		}
	}

	// Start the main network
	mainNetCmd, err := t.RunMainNetwork(mainGenesisTs)
	if err != nil {
		return nil, err
	}

	defer t.gracefulShutdown(mainNetCmd, "Main network")

	anyDaemon := t.Config.SampleDaemonInfo("any", func(di *config.DaemonInfo) bool { return true })
	t.WaitForBestTip(anyDaemon.Port(config.PORT_REST), func(block client.BlockData) bool {
		return block.Slot >= 1
	}, fmt.Sprintf("best tip reached slot 1"),
		time.Until(
			time.Unix(mainGenesisTs, 0).
				Add(time.Duration(2*t.Config.MainSlot)*time.Second)),
	)

	analysis, err := t.AnalyzeBlocks(mainGenesisTs)
	if err != nil {
		return nil, err
	}

	t.Logger.Info("Network analayze result: %v", analysis)

	if err := t.ValidateSlotOccupancy(analysis.GenesisBlock, analysis.Consensus.LastBlockBeforeTxEnd); err != nil {
		return nil, err
	}

	if err := t.ValidateLatestOccupiedSlot(analysis.Consensus.LastOccupiedSlot); err != nil {
		return nil, err
	}

	if err := t.ValidateLatestLastBlockBeforeTxEndSlot(analysis.Consensus.LastBlockBeforeTxEnd); err != nil {
		return nil, err
	}

	nonAutoDaemon := t.Config.SampleDaemonInfo("any", func(di *config.DaemonInfo) bool { return di.ForkMethod != config.Auto })
	if err := t.ValidateNoNewBlocks(nonAutoDaemon.Port(config.PORT_REST)); err != nil {
		return nil, err
	}

	if err := beforeShutdown(t, analysis); err != nil {
		return nil, err
	}

	return analysis, nil
}

type ForkData struct {
	config     string
	ledgersDir string
	genesis    int64
}

// RunForkNetworkPhase runs the fork network and validates its operation
func (t *HardforkTest) RunForkNetworkPhase(latestPreForkHeight int, mainGenesisTs int64) error {
	// Start fork network
	forkCmd, err := t.RunForkNetwork()
	if err != nil {
		return err
	}

	defer t.gracefulShutdown(forkCmd, "Fork network")

	// Calculate expected genesis slot
	forkGenesisTs := t.Config.ForkGenesisTsGivenMainGenesisTs(mainGenesisTs)
	expectedGenesisSlot := (forkGenesisTs - mainGenesisTs) / int64(t.Config.MainSlot)

	t.Logger.Info("Fork network genesis slot: %d", expectedGenesisSlot)

	// Validate fork network blocks
	if err := t.ValidateFirstBlockOfForkChain(t.Config.SampleDaemonInfo("any", func(di *config.DaemonInfo) bool { return true }).Port(config.PORT_REST), latestPreForkHeight, expectedGenesisSlot); err != nil {
		return err
	}

	// Wait until best chain query time
	t.WaitUntilBestChainQuery(t.Config.ForkSlot, int(expectedGenesisSlot))

	genesisBlock, err := t.Client.GenesisBlock(t.Config.SampleDaemonInfo("any", func(di *config.DaemonInfo) bool { return true }).Port(config.PORT_REST))
	if err != nil {
		return err
	}

	// Check block height at slot BestChainQueryFrom
	bestTip, err := t.Client.BestTip(t.Config.SampleDaemonInfo("any", func(di *config.DaemonInfo) bool { return true }).Port(config.PORT_REST))
	if err != nil {
		return err
	}

	t.Logger.Info("Block height is %d at slot %d.", bestTip.BlockHeight, bestTip.Slot)

	// Validate slot occupancy
	if err := t.ValidateSlotOccupancy(*genesisBlock, *bestTip); err != nil {
		return err
	}

	// Validate user commands in blocks
	if err := t.ValidateBlockWithUserCommandCreatedForkNetwork(t.Config.SampleDaemonInfo("any", func(di *config.DaemonInfo) bool { return true }).Port(config.PORT_REST)); err != nil {
		return err
	}

	return nil
}

// NOTE: all *Fork functions will generate a "fork_data/{daemon.json, genesis}"
// structure under node's directory, after shutdown we need to move those files
// in place before genesis of fork network
func (t *HardforkTest) legacyFork(daemon config.DaemonInfo, analysis BlockAnalysisResult, mainGenesisTs int64) error {

	forkConfigBytes, err := t.GetForkConfig(daemon.StartPort + int(config.PORT_REST))
	if err != nil {
		return err
	}

	forkDataPrepatchPath := filepath.Join(daemon.NodeDir, "fork_data_prepatch")

	if err := os.MkdirAll(forkDataPrepatchPath, 0755); err != nil {
		return err
	}

	prepatchConfigFile := filepath.Join(forkDataPrepatchPath, "config.json")

	var prepatchConfig LegacyPrepatchForkConfigView
	dec := json.NewDecoder(bytes.NewReader(forkConfigBytes))
	dec.DisallowUnknownFields()

	if err := dec.Decode(&prepatchConfig); err != nil {
		return fmt.Errorf("failed to unmarshal legacy prepatch fork config: %w, here's the config: '%s'", err, string(forkConfigBytes))
	}

	// Validate fork config data
	if err := t.ValidateLegacyPrepatchForkConfig(analysis.Consensus.LastBlockBeforeTxEnd, prepatchConfig); err != nil {
		return err
	}
	// Write fork config to file
	if err := os.WriteFile(prepatchConfigFile, forkConfigBytes, 0644); err != nil {
		return err
	}

	prepatchLedgersDir := filepath.Join(forkDataPrepatchPath, "ledgers")
	prepatchHashesFile := filepath.Join(forkDataPrepatchPath, "ledger_hashes.json")
	if err := t.GenerateAndValidateHashesAndLedgers(analysis, prepatchConfigFile, prepatchLedgersDir, prepatchHashesFile); err != nil {
		return err
	}

	forkDataPath := filepath.Join(daemon.NodeDir, "fork_data")
	patchedConfigFile := filepath.Join(forkDataPath, "daemon.json")
	patchedLedgersDir := filepath.Join(forkDataPath, "genesis")

	forkGenesisTs := t.Config.ForkGenesisTsGivenMainGenesisTs(mainGenesisTs)

	preforkGenesisConfigFile := filepath.Join(t.Config.Root, "daemon.json")
	forkHashesFile := filepath.Join(forkDataPath, "ledger_hashes.json")

	patchedConfigBytes, err := t.PatchForkConfigAndGenerateLedgersLegacy(&analysis, prepatchConfigFile, patchedLedgersDir, forkHashesFile, patchedConfigFile, preforkGenesisConfigFile, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return err
	}

	var patchedConfig FinalForkConfigView
	dec = json.NewDecoder(bytes.NewReader(patchedConfigBytes))
	dec.DisallowUnknownFields()

	if err := dec.Decode(&patchedConfig); err != nil {
		return fmt.Errorf("failed to unmarshal fork config: %w", err)
	}

	err = t.ValidateFinalForkConfig(analysis.Consensus.LastBlockBeforeTxEnd, patchedConfig, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return err
	}

	return nil
}

func (t *HardforkTest) validateAutoForkData(daemon config.DaemonInfo, forkDataPath string, analysis BlockAnalysisResult, mainGenesisTs int64) error {

	forkConfigFile := filepath.Join(forkDataPath, "daemon.json")

	forkConfigBytes, err := os.ReadFile(forkConfigFile)
	if err != nil {
		return err
	}

	forkGenesisTs := t.Config.ForkGenesisTsGivenMainGenesisTs(mainGenesisTs)

	var config FinalForkConfigView
	dec := json.NewDecoder(bytes.NewReader(forkConfigBytes))
	dec.DisallowUnknownFields()

	if err := dec.Decode(&config); err != nil {
		return fmt.Errorf("failed to unmarshal fork config: %w", err)
	}

	if err := t.ValidateFinalForkConfig(analysis.Consensus.LastBlockBeforeTxEnd, config, forkGenesisTs, mainGenesisTs); err != nil {
		return err
	}

	return nil
}

func (t *HardforkTest) advancedFork(daemon config.DaemonInfo, analysis BlockAnalysisResult, mainGenesisTs int64) error {

	forkDataPath := filepath.Join(daemon.NodeDir, "fork_data")
	if err := t.AdvancedGenerateHardForkConfig(forkDataPath, daemon.StartPort+int(config.PORT_CLIENT)); err != nil {
		return err
	}

	if _, err := os.Stat(filepath.Join(forkDataPath, "activated")); err != nil {
		return fmt.Errorf("failed to check on activated file for advanced generate fork config: %w", err)
	}

	return t.validateAutoForkData(daemon, forkDataPath, analysis, mainGenesisTs)
}

func (t *HardforkTest) autoFork(daemon config.DaemonInfo, analysis BlockAnalysisResult, mainGenesisTs int64) error {
	forkDataPath := filepath.Join(daemon.NodeDir, "auto-fork-mesa-devnet")
	activatedFile := filepath.Join(forkDataPath, "activated")

	timeOutInstant := time.Unix(mainGenesisTs+int64((t.Config.SlotChainEnd+2)*t.Config.MainSlot), 0)

	forkActivated := false

	for time.Now().Before(timeOutInstant) {

		_, err := os.Stat(activatedFile)

		if err == nil {
			forkActivated = true
			break
		}

		time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
	}

	if !forkActivated {
		return fmt.Errorf("Node %s haven't create activated file, meaning it's not completed auto config generation!")
	}

	if err := t.validateAutoForkData(daemon, forkDataPath, analysis, mainGenesisTs); err != nil {
		return err
	}

	if err := os.Rename(forkDataPath, filepath.Join(daemon.NodeDir, "fork_data")); err != nil {
		return err
	}

	return nil
}

func (t *HardforkTest) ForkPhase(analysis *BlockAnalysisResult, mainGenesisTs int64) error {
	numDaemons := len(t.Config.DaemonInfos)
	errors := make([]error, numDaemons)

	var wg sync.WaitGroup
	for idx, info := range t.Config.DaemonInfos {
		wg.Add(1)
		go func(idx int, info config.DaemonInfo) {
			defer wg.Done()
			t.Logger.Info("Forking node at port %d with method %s", info.StartPort, info.ForkMethod.String())
			switch info.ForkMethod {
			case config.Legacy:
				errors[idx] = t.legacyFork(info, *analysis, mainGenesisTs)
			case config.Advanced:
				errors[idx] = t.advancedFork(info, *analysis, mainGenesisTs)
			case config.Auto:
				errors[idx] = t.autoFork(info, *analysis, mainGenesisTs)
			}
		}(idx, info)
	}
	wg.Wait()

	for i, info := range t.Config.DaemonInfos {
		if errors[i] != nil {
			return fmt.Errorf("Fork on daemon %v failed: %v", info, errors[i])
		}
	}

	return nil
}

// ComputeChainId computes the chain_id for the given config files using the
// post-fork mina binary's `internal chain-id --from-config-hashes-only` command.
// Returns empty string if the chain_id cannot be computed (e.g. config lacks hashes).
func (t *HardforkTest) ComputeChainId(configFiles ...string) (string, error) {
	args := []string{"internal", "chain-id"}
	for _, f := range configFiles {
		args = append(args, "--config-file", f)
	}
	args = append(args, "--from-config-hashes-only")
	cmd := exec.Command(t.Config.ForkMinaExe, args...)
	output, err := cmd.Output()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return "", fmt.Errorf("mina internal chain-id failed (exit %d): %s",
				exitErr.ExitCode(), string(exitErr.Stderr))
		}
		return "", fmt.Errorf("failed to run mina internal chain-id: %w", err)
	}
	return strings.TrimSpace(string(output)), nil
}

type MoveFileSpec struct {
	from, to string
}

func (t *HardforkTest) CleanUpNetworkForForkPhase() error {
	t.Logger.Info("Cleaning up deamon.json generate by mina-local-network so we're not using prefork genesis info...")
	networkDaemonConfig := filepath.Join(t.Config.Root, "daemon.json")
	data, err := os.ReadFile(networkDaemonConfig)
	if err != nil {
		return fmt.Errorf("Error reading daemon.json: %v", err)
	}

	var config map[string]any
	if err := json.Unmarshal(data, &config); err != nil {
		return fmt.Errorf("Error parsing daemon.json: %v", err)
	}

	delete(config, "ledger")
	t.Logger.Info("Removed .ledger from daemon.json")

	delete(config, "daemon")
	t.Logger.Info("Removed .daemon from daemon.json")

	if genesis, ok := config["genesis"].(map[string]any); ok {
		delete(genesis, "genesis_state_timestamp")
		t.Logger.Info("Removed .genesis.genesis_state_timestamp from daemon.json")
	} else {
		t.Logger.Debug(".genesis section not found in daemon.json!")
	}

	updatedData, err := json.Marshal(config)
	if err != nil {
		return fmt.Errorf("Error encoding daemon.json: %v", err)
	}

	if err := os.WriteFile(networkDaemonConfig, updatedData, 0644); err != nil {
		return fmt.Errorf("Error writing daemon.json: %v", err)
	}

	t.Logger.Info("`daemon.json` successfully sanitized, now moving fork config & ledgers in place for fork network")

	for _, info := range t.Config.DaemonInfos {
		forkDataBase := filepath.Join(info.NodeDir, "fork_data")
		forkConfigFile := filepath.Join(forkDataBase, "daemon.json")
		forkConfigContent, err := os.ReadFile(forkConfigFile)
		if err != nil {
			return fmt.Errorf("Can't read fork config from node %s: %v", info.NodeDir, err)
		}
		t.Logger.Info("Node %s will be using fork config of content: %s", info.NodeDir, string(forkConfigContent))
		// NOTE: Compute chain_id from the merged config (fork + shared) to determine
		// the nested directory structure the post-fork daemon will use. The daemon
		// loads its config-directory daemon.json first, then overlays --config-file
		// args, so we pass both in the same order.
		chainId, err := t.ComputeChainId(forkConfigFile, networkDaemonConfig)
		if err != nil {
			return fmt.Errorf("failed to compute chain_id from fork config on node at %s: %v", info.NodeDir, err)
		}
		t.Logger.Info("Computed chain_id for fork config at %s: %s", info.NodeDir, chainId)

		extraArgsToRemove := filepath.Join(info.NodeDir, "extra_args.txt")
		// Remove extra_args.txt that's no longer needed post-fork
		_, err = os.Stat(extraArgsToRemove)
		if err != nil {
			err = os.Remove(extraArgsToRemove)
			if err != nil {
				return fmt.Errorf("Failed to remove extra_args.txt for node %s", info.NodeDir)
			}
		}

		chainStateDir := filepath.Join(info.NodeDir, chainId)
		err = os.MkdirAll(chainStateDir, 0755)
		if err != nil {
			return err
		}
		filesToMove := []MoveFileSpec{
			{from: forkConfigFile, to: filepath.Join(info.NodeDir, "daemon.json")},
			{from: filepath.Join(forkDataBase, "genesis"), to: filepath.Join(chainStateDir, "genesis")},
		}
		for _, spec := range filesToMove {
			// NOTE: all *Fork functions will generate a "fork_data/{daemon.json, genesis}"

			if _, err = os.Stat(spec.to); err == nil {
				t.Logger.Info("Target file/folder %s exists, removing it first", spec.to)
				err = os.RemoveAll(spec.to)
				if err != nil {
					return fmt.Errorf("Failed to remove existing file/folder %s: %v", spec.to, err)
				}
			}
			err := os.Rename(spec.from, spec.to)
			if err != nil {
				return fmt.Errorf("Error moving fork data %s -> %s on node %s: %v", spec.from, spec.to, info.NodeDir, err)
			}
		}
	}
	return nil
}
