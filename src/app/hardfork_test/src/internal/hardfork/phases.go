package hardfork

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
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
	// Start the main network
	mainNetCmd, err := t.RunMainNetwork(mainGenesisTs)
	if err != nil {
		return nil, err
	}

	defer t.gracefulShutdown(mainNetCmd, "Main network")

	t.WaitForBestTip(t.Config.AnyPortOfType(config.PORT_REST), func(block client.BlockData) bool {
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

	if err := t.ValidateNoNewBlocks(t.Config.AnyPortOfType(config.PORT_REST)); err != nil {
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
	if err := t.ValidateFirstBlockOfForkChain(t.Config.AnyPortOfType(config.PORT_REST), latestPreForkHeight, expectedGenesisSlot); err != nil {
		return err
	}

	// Wait until best chain query time
	t.WaitUntilBestChainQuery(t.Config.ForkSlot, int(expectedGenesisSlot))

	genesisBlock, err := t.Client.GenesisBlock(t.Config.AnyPortOfType(config.PORT_REST))
	if err != nil {
		return err
	}

	// Check block height at slot BestChainQueryFrom
	bestTip, err := t.Client.BestTip(t.Config.AnyPortOfType(config.PORT_REST))
	if err != nil {
		return err
	}

	t.Logger.Info("Block height is %d at slot %d.", bestTip.BlockHeight, bestTip.Slot)

	// Validate slot occupancy
	if err := t.ValidateSlotOccupancy(*genesisBlock, *bestTip); err != nil {
		return err
	}

	// Validate user commands in blocks
	if err := t.ValidateBlockWithUserCommandCreatedForkNetwork(t.Config.AnyPortOfType(config.PORT_REST)); err != nil {
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
		return fmt.Errorf("failed to unmarshal legacy prepatch fork config: %w", err)
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
	if err := t.GenerateAndValidateHashesAndLedgers(&analysis, prepatchConfigFile, prepatchLedgersDir, prepatchHashesFile); err != nil {
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

func (t *HardforkTest) LegacyForkPhase(analysis *BlockAnalysisResult, mainGenesisTs int64) error {
	daemonInfos := t.Config.AllDaemonInfos()
	errors := make([]error, len(daemonInfos))

	var wg sync.WaitGroup
	for idx, info := range daemonInfos {
		wg.Add(1)
		go func(idx int, info config.DaemonInfo) {
			defer wg.Done()
			errors[idx] = t.legacyFork(info, *analysis, mainGenesisTs)
		}(idx, info)
	}
	wg.Wait()

	for i, info := range daemonInfos {
		if errors[i] != nil {
			return fmt.Errorf("Legacy fork on daemon %v failed: %v", info, errors[i])
		}
	}

	return nil
}

func (t *HardforkTest) advancedFork(daemon config.DaemonInfo, analysis BlockAnalysisResult, mainGenesisTs int64) error {

	forkDataPath := filepath.Join(daemon.NodeDir, "fork_data")
	if err := t.AdvancedGenerateHardForkConfig(forkDataPath, daemon.StartPort+int(config.PORT_CLIENT)); err != nil {
		return err
	}

	forkConfigFile := filepath.Join(forkDataPath, "daemon.json")

	if _, err := os.Stat(filepath.Join(forkDataPath, "activated")); err != nil {
		return fmt.Errorf("failed to check on activated file for advanced generate fork config: %w", err)
	}

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

	err = t.ValidateFinalForkConfig(analysis.Consensus.LastBlockBeforeTxEnd, config, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return err
	}

	return nil
}

// Uses `mina advanced generate-hardfork-config CLI`
func (t *HardforkTest) AdvancedForkPhase(analysis *BlockAnalysisResult, mainGenesisTs int64) error {
	daemonInfos := t.Config.AllDaemonInfos()
	errors := make([]error, len(daemonInfos))

	var wg sync.WaitGroup
	for idx, info := range daemonInfos {
		wg.Add(1)
		go func(idx int, info config.DaemonInfo) {
			defer wg.Done()
			errors[idx] = t.advancedFork(info, *analysis, mainGenesisTs)
		}(idx, info)
	}
	wg.Wait()

	for i, info := range daemonInfos {
		if errors[i] != nil {
			return fmt.Errorf("Advanced fork on daemon %v failed: %v", info, errors[i])
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

	for _, info := range t.Config.AllDaemonInfos() {
		forkDataBase := filepath.Join(info.NodeDir, "fork_data")
		// NOTE: Compute chain_id from the merged config (fork + shared) to determine
		// the nested directory structure the post-fork daemon will use. The daemon
		// loads its config-directory daemon.json first, then overlays --config-file
		// args, so we pass both in the same order.
		forkConfigFile := filepath.Join(forkDataBase, "daemon.json")
		chainId, err := t.ComputeChainId(forkConfigFile, networkDaemonConfig)
		if err != nil {
			return fmt.Errorf("failed to compute chain_id from fork config on node at %s: %v", info.NodeDir, err)
		}
		t.Logger.Info("Computed chain_id for fork config at %s: %s", info.NodeDir, chainId)
		chainStateDir := filepath.Join(info.NodeDir, chainId)
		os.Mkdir(chainStateDir, 0755)
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
