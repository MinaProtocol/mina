package hardfork

import (
	"bytes"
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
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

	t.WaitUntilBestChainQuery(t.Config.MainSlot, 0)

	bestTip, err := t.Client.BestTip(t.AnyPortOfType(PORT_REST))
	if err != nil {
		return nil, err
	}
	t.Logger.Info("Block height is %d at slot %d.", bestTip.BlockHeight, bestTip.Slot)

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

	if err := t.ValidateNoNewBlocks(t.AnyPortOfType(PORT_REST)); err != nil {
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
func (t *HardforkTest) RunForkNetworkPhase(latestPreForkHeight int, forkData ForkData, mainGenesisTs int64) error {
	// Start fork network
	forkCmd, err := t.RunForkNetwork(forkData.config, forkData.ledgersDir)
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

	genesisBlock, err := t.Client.GenesisBlock(t.AnyPortOfType(PORT_REST))
	if err != nil {
		return err
	}

	// Check block height at slot BestChainQueryFrom
	bestTip, err := t.Client.BestTip(t.AnyPortOfType(PORT_REST))
	if err != nil {
		return err
	}

	t.Logger.Info("Block height is %d at slot %d.", bestTip.BlockHeight, bestTip.Slot)

	// Validate slot occupancy
	if err := t.ValidateSlotOccupancy(*genesisBlock, *bestTip); err != nil {
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
	if err := t.ValidateLegacyPrepatchForkConfig(analysis.Consensus.LastBlockBeforeTxEnd, prepatchConfig); err != nil {
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

	err = t.ValidateFinalForkConfig(analysis.Consensus.LastBlockBeforeTxEnd, patchedConfig, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return nil, err
	}

	return &ForkData{config: patchedConfigFile, ledgersDir: patchedLedgersDir, genesis: forkGenesisTs}, nil

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

	err = t.ValidateFinalForkConfig(analysis.Consensus.LastBlockBeforeTxEnd, config, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return nil, err
	}

	forkLedgersDir := fmt.Sprintf("%s/genesis", forkDataPath)
	return &ForkData{config: forkConfig, ledgersDir: forkLedgersDir, genesis: forkGenesisTs}, nil
}
