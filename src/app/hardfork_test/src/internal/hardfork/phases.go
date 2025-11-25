package hardfork

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"
)

// RunMainNetworkPhase runs the main network and validates its operation
// and returns the fork config bytes and block analysis result
func (t *HardforkTest) RunMainNetworkPhase(mainGenesisTs int64) ([]byte, *BlockAnalysisResult, error) {
	// Start the main network
	mainNetCmd, err := t.RunMainNetwork(mainGenesisTs)
	if err != nil {
		return nil, nil, err
	}

	defer t.gracefulShutdown(mainNetCmd, "Main network")

	// Wait until best chain query time
	t.WaitUntilBestChainQuery(t.Config.MainSlot, t.Config.MainDelay)

	// Check block height at slot BestChainQueryFrom
	blockHeight, err := t.Client.GetHeight(t.AnyPortOfType(PORT_REST))
	if err != nil {
		return nil, nil, err
	}

	t.Logger.Info("Block height is %d at slot %d.", blockHeight, t.Config.BestChainQueryFrom)

	// Validate slot occupancy
	if err := t.ValidateSlotOccupancy(0, blockHeight); err != nil {
		return nil, nil, err
	}

	// Analyze blocks and get genesis epoch data
	analysis, err := t.AnalyzeBlocks()
	if err != nil {
		return nil, nil, err
	}

	// Validate max slot
	if err := t.ValidateLatestOccupiedSlot(analysis.LatestOccupiedSlot); err != nil {
		return nil, nil, err
	}

	// Validate latest block slot
	if err := t.ValidateLatestNonEmptyBlockSlot(analysis.LatestNonEmptyBlock); err != nil {
		return nil, nil, err
	}

	// Validate no new blocks are created after chain end
	if err := t.ValidateNoNewBlocks(t.AnyPortOfType(PORT_REST)); err != nil {
		return nil, nil, err
	}

	// Extract fork config before nodes shutdown
	forkConfigBytes, err := t.GetForkConfig(t.AnyPortOfType(PORT_REST))
	if err != nil {
		return nil, nil, err
	}

	return forkConfigBytes, analysis, nil
}

type ForkData struct {
	config     string
	ledgersDir string
	genesis    int64
}

// RunForkNetworkPhase runs the fork network and validates its operation
func (t *HardforkTest) RunForkNetworkPhase(latestPreForkHeight int, forkData ForkData, mainGenesisTs int64) error {
	// Start fork network
	forkCmd, err := t.RunForkNetwork(forkData.config, forkData.ledgersDir)
	if err != nil {
		return err
	}

	defer t.gracefulShutdown(forkCmd, "Fork network")

	// Calculate expected genesis slot
	expectedGenesisSlot := (forkData.genesis - mainGenesisTs) / int64(t.Config.MainSlot)

	// Validate fork network blocks
	if err := t.ValidateFirstBlockOfForkChain(t.AnyPortOfType(PORT_REST), latestPreForkHeight, expectedGenesisSlot); err != nil {
		return err
	}

	// Wait until best chain query time
	t.WaitUntilBestChainQuery(t.Config.ForkSlot, t.Config.ForkDelay)

	// Check block height at slot BestChainQueryFrom
	blockHeight, err := t.Client.GetHeight(t.AnyPortOfType(PORT_REST))
	if err != nil {
		return err
	}

	t.Logger.Info("Block height is %d at estimated slot %d.", blockHeight, expectedGenesisSlot+int64(t.Config.BestChainQueryFrom))

	// Validate slot occupancy
	if err := t.ValidateSlotOccupancy(latestPreForkHeight+1, blockHeight); err != nil {
		return err
	}

	// Validate user commands in blocks
	if err := t.ValidateBlockWithUserCommandCreated(t.AnyPortOfType(PORT_REST)); err != nil {
		return err
	}

	return nil
}

func (t *HardforkTest) LegacyForkPhase(analysis *BlockAnalysisResult, forkConfigBytes []byte, mainGenesisTs int64) (*ForkData, error) {

	if err := os.MkdirAll("fork_data/prefork", 0755); err != nil {
		return nil, err
	}

	// Define all fork_data file paths
	preforkConfig := "fork_data/prefork/config.json"

	// Validate fork config data
	if err := t.ValidateForkConfigData(analysis.LatestNonEmptyBlock, forkConfigBytes); err != nil {
		return nil, err
	}
	// Write fork config to file
	if err := os.WriteFile(preforkConfig, forkConfigBytes, 0644); err != nil {
		return nil, err
	}
	{
		preforkLedgersDir := "fork_data/prefork/hf_ledgers"
		preforkHashesFile := "fork_data/prefork/hf_ledger_hashes.json"
		if err := t.GenerateAndValidatePreforkLedgers(analysis, preforkConfig, preforkLedgersDir, preforkHashesFile); err != nil {
			return nil, err
		}
	}

	if err := os.MkdirAll("fork_data/postfork", 0755); err != nil {
		return nil, err
	}

	postforkConfig := "fork_data/postfork/config.json"
	forkLedgersDir := "fork_data/postfork/hf_ledgers"

	// Calculate fork genesis timestamp relative to now (before starting fork network)
	forkGenesisTs := time.Now().Unix() + int64(t.Config.ForkDelay*60)

	{
		preforkGenesisConfigFile := fmt.Sprintf("%s/daemon.json", t.Config.Root)
		forkHashesFile := "fork_data/hf_ledger_hashes.json"
		if err := t.PatchForkConfigAndGenerateLedgersLegacy(analysis, preforkConfig, forkLedgersDir, forkHashesFile, postforkConfig, preforkGenesisConfigFile, forkGenesisTs, mainGenesisTs); err != nil {
			return nil, err
		}
	}

	return &ForkData{config: postforkConfig, ledgersDir: forkLedgersDir, genesis: forkGenesisTs}, nil

}

// Uses `mina advanced generate-hardfork-config CLI`
func (t *HardforkTest) AdvancedForkPhase(analysis *BlockAnalysisResult, forkConfigBytes []byte, mainGenesisTs int64) (*ForkData, error) {

	cwd := ""
	var err error = nil
	if cwd, err = os.Getwd(); err != nil {
		return nil, err
	}

	forkDataPath := fmt.Sprintf("%s/fork_data", cwd)
	if err := os.MkdirAll(forkDataPath, 0755); err != nil {
		return nil, err
	}

	if err := t.AdvancedGenerateHardForkConfig(forkDataPath); err != nil {
		return nil, err
	}

	configToPatch := fmt.Sprintf("%s/daemon.json", forkDataPath)

	configJsonString, err := os.ReadFile(configToPatch)
	if err != nil {
		return nil, err
	}

	var configRaw map[string]map[string]string
	json.Unmarshal(configJsonString, &configRaw)

	preforkChainEndTs, err := time.Parse(time.RFC3339Nano, configRaw["genesis"]["genesis_state_timestamp"])
	if err != nil {
		return nil, err
	}
	roughForkGenesisTs := time.Now().Add(time.Duration(t.Config.ForkDelay) * time.Minute)
	hardforkGenesisSecDelta := roughForkGenesisTs.Sub(preforkChainEndTs).Seconds()
	hardforkGenesisSlotDelta := int(math.Ceil(hardforkGenesisSecDelta / float64(t.Config.MainSlot)))
	forkSlotDuration := time.Duration(t.Config.MainSlot) * time.Second
	forkGenesisTs := preforkChainEndTs.Add(time.Duration(hardforkGenesisSlotDelta) * forkSlotDuration).Unix()

	cmd := exec.Command(filepath.Join(t.ScriptDir, "patch-runtime-config-advanced-gen-fork-config.sh"))

	cmd.Env = append(os.Environ(),
		"FORK_CONFIG_TO_PATCH="+configToPatch,
		"PREFORK_SLOT_TIME_SEC="+strconv.Itoa(t.Config.MainSlot),
		"HARDFORK_GENESIS_SLOT_DELTA="+strconv.Itoa(hardforkGenesisSlotDelta),
	)
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return nil, fmt.Errorf("failed to run patch-runtime-config-advanced-gen-fork-config.sh: %w", err)
	}

	patchedConfigString, err := cmd.Output()

	err = os.WriteFile(configToPatch, patchedConfigString, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed to patch fork config: %w", err)
	}

	forkLedgersDir := fmt.Sprintf("%s/genesis", forkDataPath)
	return &ForkData{config: configToPatch, ledgersDir: forkLedgersDir, genesis: forkGenesisTs}, nil
}
