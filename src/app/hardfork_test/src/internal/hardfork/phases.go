package hardfork

import (
	"fmt"
	"math/rand"
	"os"

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

	// Validate no new blocks are created after chain end
	if err := t.ValidateNoNewBlocks(t.AnyPortOfType(PORT_REST)); err != nil {
		return nil, nil, err
	}

	t.Logger.Info("Phase 2: Forking with fork method `%s`...", t.Config.ForkMethod.String())

	var forkData *ForkData
	switch t.Config.ForkMethod {
	case config.Legacy:
		forkData, err = t.LegacyForkPhase(analysis, mainGenesisTs)
	case config.Advanced:
		forkData, err = t.AdvancedForkPhase(analysis, mainGenesisTs)
	case config.Auto:
		panic("TODO: implement auto mode fork config generation")
	}
	if err != nil {
		return nil, nil, err
	}
	return analysis, forkData, nil
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
	prepatchConfig := "fork_data/prepatch/config.json"

	// Validate fork config data
	if err := t.ValidateLegacyPrepatchForkConfig(analysis.LastBlockBeforeTxEnd, forkConfigBytes); err != nil {
		return nil, err
	}
	// Write fork config to file
	if err := os.WriteFile(prepatchConfig, forkConfigBytes, 0644); err != nil {
		return nil, err
	}

	prepatchLedgersDir := "fork_data/prepatch/hf_ledgers"
	prepatchHashesFile := "fork_data/prepatch/hf_ledger_hashes.json"
	if err := t.GenerateAndValidateHashesAndLedgers(analysis, prepatchConfig, prepatchLedgersDir, prepatchHashesFile); err != nil {
		return nil, err
	}

	if err := os.MkdirAll("fork_data/postpatch", 0755); err != nil {
		return nil, err
	}

	postpatchConfig := "fork_data/postpatch/config.json"
	postpatchLedgersDir := "fork_data/postpatch/hf_ledgers"

	forkGenesisTs := t.Config.ForkGenesisTsGivenMainGenesisTs(mainGenesisTs)

	preforkGenesisConfigFile := fmt.Sprintf("%s/daemon.json", t.Config.Root)
	forkHashesFile := "fork_data/hf_ledger_hashes.json"

	patchedConfigBytes, err := t.PatchForkConfigAndGenerateLedgersLegacy(analysis, prepatchConfig, postpatchLedgersDir, forkHashesFile, postpatchConfig, preforkGenesisConfigFile, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return nil, err
	}
	err = t.ValidateFinalForkConfig(analysis.LastBlockBeforeTxEnd, patchedConfigBytes, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return nil, err
	}

	return &ForkData{config: postpatchConfig, ledgersDir: postpatchLedgersDir, genesis: forkGenesisTs}, nil

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

	err = t.ValidateFinalForkConfig(analysis.LastBlockBeforeTxEnd, forkConfigBytes, forkGenesisTs, mainGenesisTs)
	if err != nil {
		return nil, err
	}

	forkLedgersDir := fmt.Sprintf("%s/genesis", forkDataPath)
	return &ForkData{config: forkConfig, ledgersDir: forkLedgersDir, genesis: forkGenesisTs}, nil
}
