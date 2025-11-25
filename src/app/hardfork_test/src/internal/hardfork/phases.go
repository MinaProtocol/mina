package hardfork

import (
	"fmt"
	"os"
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

	// Define all localnet file paths
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
		if err := t.GenerateForkConfigAndLedgers(analysis, preforkConfig, forkLedgersDir, forkHashesFile, postforkConfig, preforkGenesisConfigFile, forkGenesisTs, mainGenesisTs); err != nil {
			return nil, err
		}
	}

	return &ForkData{config: postforkConfig, ledgersDir: forkLedgersDir, genesis: forkGenesisTs}, nil

}
