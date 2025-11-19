package hardfork

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
	analysis, err := t.AnalyzeBlocks(t.AllPortOfType(PORT_REST))
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

// RunForkNetworkPhase runs the fork network and validates its operation
func (t *HardforkTest) RunForkNetworkPhase(latestPreForkHeight int, configFile, forkLedgersDir string, forkGenesisTs, mainGenesisTs int64) error {
	// Start fork network
	forkCmd, err := t.RunForkNetwork(configFile, forkLedgersDir)
	if err != nil {
		return err
	}

	defer t.gracefulShutdown(forkCmd, "Fork network")

	// Calculate expected genesis slot
	expectedGenesisSlot := (forkGenesisTs - mainGenesisTs) / int64(t.Config.MainSlot)

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
