package hardfork

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

type HFHandler func(*HardforkTest, *BlockAnalysisResult) error

// RunMainNetworkPhase runs the main network and validates its operation
// and returns the fork config bytes and block analysis result
func (t *HardforkTest) RunMainNetworkPhase(mainGenesisTs int64) (*BlockAnalysisResult, *ForkData, error) {
	// Start the main network
	mainNetCmd, err := t.RunMainNetwork(mainGenesisTs, t.Config.ForkMethod == config.Auto)
	if err != nil {
		return nil, nil, err
	}

	defer t.gracefulShutdown(mainNetCmd, "Main network")

	// Wait until best chain query time
	t.WaitUntilBestChainQuery(t.Config.MainSlot, 0)

	// Check block height at slot BestChainQueryFrom
	bestTip, err := t.Client.BestTip(t.AnyPortOfType(PORT_REST))
	if err != nil {
		return nil, nil, err
	}

	t.Logger.Info("Block height is %d at slot %d.", bestTip.BlockHeight, bestTip.Slot)

	// Validate slot occupancy
	if err := t.ValidateSlotOccupancy(0, bestTip.BlockHeight); err != nil {
		return nil, nil, err
	}

	// Analyze blocks and get genesis epoch data
	analysis, err := t.AnalyzeBlocks()
	if err != nil {
		return nil, nil, err
	}

	t.Logger.Info("Network analayze result: %v", analysis)

	// Validate max slot
	if err := t.ValidateLatestOccupiedSlot(analysis.LastOccupiedSlot); err != nil {
		return nil, nil, err
	}

	// Validate latest block slot
	if err := t.ValidateLatestLastBlockBeforeTxEndSlot(analysis.LastBlockBeforeTxEnd); err != nil {
		return nil, nil, err
	}

	// On auto mode node shutdown itself at slot-chain-end as long as it heards
	// from block at slot-tx-end, so it's not guaranteed we can still connect to
	// nodes here.
	if t.Config.ForkMethod != config.Auto {
		// Validate no new blocks are created after chain end
		if err := t.ValidateNoNewBlocks(t.AnyPortOfType(PORT_REST)); err != nil {
			return nil, nil, err
		}
	}

	t.Logger.Info("Phase 2: Forking with fork method `%s`...", t.Config.ForkMethod.String())

	var forkData *ForkData
	switch t.Config.ForkMethod {
	case config.Legacy:
		forkData, err = t.LegacyForkPhase(analysis, mainGenesisTs)
	case config.Advanced:
		forkData, err = t.AdvancedForkPhase(analysis, mainGenesisTs)
	case config.Auto:
		// WARN: We're using the dummy ForkData here, expecting callee to call
		// `t.AutoForkPhase`, this is because auto fork config is guaranteed to be
		// produced before the network closed
	}
	if err != nil {
		return nil, nil, err
	}
	return analysis, forkData, nil
}

type ForkDataAndUsage interface {
	generateLocalNetworkParam() string
	// config     string
	// ledgersDir string
}

type ConfigWithLedgers struct {
	config     string
	ledgersDir string
}

func (c ConfigWithLedgers) generateLocalNetworkParam() string {
	return fmt.Sprintf("inherit_with:%s,%s", c.config, c.ledgersDir)
}

type ConfigOnly struct {
	config string
}

func (c ConfigOnly) generateLocalNetworkParam() string {
	return fmt.Sprintf("inherit:%s", c.config)
}

type ForkData struct {
	data    ForkDataAndUsage
	genesis int64
}

// RunForkNetworkPhase runs the fork network and validates its operation
func (t *HardforkTest) RunForkNetworkPhase(latestPreForkHeight int, forkData ForkData, mainGenesisTs int64) error {
	// Start fork network
	forkCmd, err := t.RunForkNetwork(forkData.data)
	if err != nil {
		return err
	}

	defer t.gracefulShutdown(forkCmd, "Fork network")

	// Calculate expected genesis slot
	expectedGenesisSlot := (forkData.genesis - mainGenesisTs) / int64(t.Config.MainSlot)

	t.Logger.Info("Fork network genesis slot: %d", expectedGenesisSlot)

	// Validate fork network blocks
	if err := t.ValidateFirstBlockOfForkChain(t.AnyPortOfType(PORT_REST), latestPreForkHeight, expectedGenesisSlot); err != nil {
		return err
	}

	// Wait until best chain query time
	t.WaitUntilBestChainQuery(t.Config.ForkSlot, int(expectedGenesisSlot))

	// Check block height at slot BestChainQueryFrom
	bestTip, err := t.Client.BestTip(t.AnyPortOfType(PORT_REST))
	if err != nil {
		return err
	}

	t.Logger.Info("Block height is %d at slot %d.", bestTip.BlockHeight, bestTip.Slot)

	// Validate slot occupancy
	if err := t.ValidateSlotOccupancy(latestPreForkHeight+1, bestTip.BlockHeight); err != nil {
		return err
	}

	// Validate user commands in blocks
	if err := t.ValidateBlockWithUserCommandCreatedForkNetwork(t.AnyPortOfType(PORT_REST)); err != nil {
		return err
	}

	return nil
}

func (t *HardforkTest) LegacyForkPhase(analysis *BlockAnalysisResult, mainGenesisTs int64) (*ForkData, error) {

	idx := rand.Intn(len(analysis.CandidatePortBasesForFork))
	forkConfigBytes, err := t.GetForkConfig(analysis.CandidatePortBasesForFork[idx] + int(PORT_REST))
	if err != nil {
		return nil, err
	}

	if err := os.MkdirAll("fork_data/prepatch", 0755); err != nil {
		return nil, err
	}

	// Define all fork_data file paths
	prepatchConfigFile := "fork_data/prepatch/config.json"

	var prepatchConfig LegacyPrepatchForkConfigView
	dec := json.NewDecoder(bytes.NewReader(forkConfigBytes))
	dec.DisallowUnknownFields()

	if err := dec.Decode(&prepatchConfig); err != nil {
		return nil, fmt.Errorf("failed to unmarshal legacy prepatch fork config: %w", err)
	}

	// Validate fork config data
	if err := t.ValidateLegacyPrepatchForkConfig(analysis.LastBlockBeforeTxEnd, prepatchConfig); err != nil {
		return nil, err
	}
	// Write fork config to file
	if err := os.WriteFile(prepatchConfigFile, forkConfigBytes, 0644); err != nil {
		return nil, err
	}

	prepatchLedgersDir := "fork_data/prepatch/hf_ledgers"
	prepatchHashesFile := "fork_data/prepatch/hf_ledger_hashes.json"
	if err := t.GenerateAndValidateHashesAndLedgers(analysis, prepatchConfigFile, prepatchLedgersDir, prepatchHashesFile); err != nil {
		return nil, err
	}

	if err := os.MkdirAll("fork_data/postpatch", 0755); err != nil {
		return nil, err
	}

	patchedConfigFile := "fork_data/postpatch/config.json"
	patchedLedgersDir := "fork_data/postpatch/hf_ledgers"

	forkGenesisTs := t.Config.ForkGenesisTsGivenMainGenesisTs(mainGenesisTs)

	preforkGenesisConfigFile := fmt.Sprintf("%s/daemon.json", t.Config.Root)
	forkHashesFile := "fork_data/hf_ledger_hashes.json"

	patchedConfigBytes, err := t.PatchForkConfigAndGenerateLedgersLegacy(analysis, prepatchConfigFile, patchedLedgersDir, forkHashesFile, patchedConfigFile, preforkGenesisConfigFile, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return nil, err
	}

	var patchedConfig FinalForkConfigView
	dec = json.NewDecoder(bytes.NewReader(patchedConfigBytes))
	dec.DisallowUnknownFields()

	if err := dec.Decode(&patchedConfig); err != nil {
		return nil, fmt.Errorf("failed to unmarshal fork config: %w", err)
	}

	err = t.ValidateFinalForkConfig(analysis.LastBlockBeforeTxEnd, patchedConfig, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return nil, err
	}

	return &ForkData{
			data:    ConfigWithLedgers{config: patchedConfigFile, ledgersDir: patchedLedgersDir},
			genesis: forkGenesisTs},
		nil

}

// Uses `mina advanced generate-hardfork-config CLI`
func (t *HardforkTest) AdvancedForkPhase(analysis *BlockAnalysisResult, mainGenesisTs int64) (*ForkData, error) {

	cwd := ""
	var err error = nil
	if cwd, err = os.Getwd(); err != nil {
		return nil, err
	}

	forkDataPath := fmt.Sprintf("%s/fork_data", cwd)

	idx := rand.Intn(len(analysis.CandidatePortBasesForFork))
	if err := t.AdvancedGenerateHardForkConfig(forkDataPath, analysis.CandidatePortBasesForFork[idx]+int(PORT_CLIENT)); err != nil {
		return nil, err
	}

	forkConfig := fmt.Sprintf("%s/daemon.json", forkDataPath)

	forkConfigBytes, err := os.ReadFile(forkConfig)
	if err != nil {
		return nil, err
	}

	forkGenesisTs := t.Config.ForkGenesisTsGivenMainGenesisTs(mainGenesisTs)

	var config FinalForkConfigView
	dec := json.NewDecoder(bytes.NewReader(forkConfigBytes))
	dec.DisallowUnknownFields()

	if err := dec.Decode(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal fork config: %w", err)
	}

	err = t.ValidateFinalForkConfig(analysis.LastBlockBeforeTxEnd, config, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return nil, err
	}

	forkLedgersDir := fmt.Sprintf("%s/genesis", forkDataPath)
	return &ForkData{
		data:    ConfigWithLedgers{config: forkConfig, ledgersDir: forkLedgersDir},
		genesis: forkGenesisTs,
	}, nil
}

func (t *HardforkTest) AutoForkPhase(analysis *BlockAnalysisResult, mainGenesisTs int64) (*ForkData, error) {

	// NOTE: Auto mode differs from either Legacy/Advanced fork mode in that each
	// node tries to generate their own fork config, and we try to boot each node
	// with the data they generated on their own. This is more decentralized
	// compared to the other methods

	nodesDir := "~/.mina-network/nodes"

	var err error = nil

	seenForkConfig := false
	forkConfig := ""

	err = filepath.WalkDir(nodesDir, func(path string, d os.DirEntry, err error) error {
		forkConfigBase := path + "/auto-fork-mesa-devnet"
		if err != nil {
			return err
		}
		if !d.IsDir() {
			return fmt.Errorf("Unexpected file %s in node directory %s", path, nodesDir)
		}
		if d.Name() == "snark_workers" {
			// SNARK workers doesn't participate in fork
			return nil
		}

		_, err = os.Stat(forkConfigBase + "/activated")
		if err != nil {
			return err
		}

		currentForkConfig, err := os.ReadFile(forkConfigBase + "/daemon.json")
		if err != nil {
			return err
		}

		if !seenForkConfig {
			seenForkConfig = true
			forkConfig = string(currentForkConfig)
		} else if string(currentForkConfig) != forkConfig {
			return fmt.Errorf("Node at %s generated fork config '%s' not same as the commonly agreed one '%s'",
				path, currentForkConfig, forkConfig)
		}

		err = os.Rename(forkConfigBase+"/genesis", path+"/override_genesis_ledger")
		if err != nil {
			return err
		}

		return nil
	})

	if err != nil {
		return nil, err
	}

	if !seenForkConfig {
		return nil, fmt.Errorf("No fork config has been found after auto mode has been used!")
	}

	forkGenesisTs := t.Config.ForkGenesisTsGivenMainGenesisTs(mainGenesisTs)

	var configUnmarshalled FinalForkConfigView
	dec := json.NewDecoder(bytes.NewReader([]byte(forkConfig)))
	dec.DisallowUnknownFields()

	if err := dec.Decode(&configUnmarshalled); err != nil {
		return nil, fmt.Errorf("failed to unmarshal fork config: %w", err)
	}

	err = t.ValidateFinalForkConfig(analysis.LastBlockBeforeTxEnd, configUnmarshalled, forkGenesisTs, mainGenesisTs)

	forkConfigFile := "/tmp/fork_config.json"
	os.WriteFile(forkConfigFile, []byte(forkConfig), 0644)

	if err != nil {
		return nil, err
	}

	// genesis ledgers has been overriden and each node will use a different one generated during auto fork phase
	return &ForkData{
			data: ConfigOnly{
				config: forkConfigFile,
			},
			genesis: forkGenesisTs,
		},
		nil
}
