package hardfork

import (
	"fmt"
	"reflect"
	"sync"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

type ConsensusState struct {
	LastOccupiedSlot     int              `json:"last_occupied_slot"`
	LastBlockBeforeTxEnd client.BlockData `json:"last_block_before_tx_end"`
}

type BlockAnalysisResult struct {
	Consensus          ConsensusState
	GenesisBlock       client.BlockData
	SnarkedHashByEpoch SnarkedHashByEpoch
}

func (t *HardforkTest) WaitForBestTip(port int, pred func(client.BlockData) bool, predDescription string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)

	t.Logger.Info("Waiting for best tip at port %d to satisfy condition: %s", port, predDescription)

	for time.Now().Before(deadline) {
		bestTip, err := t.Client.BestTip(port)
		if err != nil {
			t.Logger.Debug("Failed to get best tip: %v", err)
			time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
			continue
		}

		if pred(*bestTip) {
			t.Logger.Info("Condition %s satisfied for daemon at port %d", predDescription, port)
			return nil
		}

		time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
	}
	return fmt.Errorf("timed out waiting for condition: %s at port %d", predDescription, port)
}

// ValidateSlotOccupancy checks if block occupancy is above 50%
func (t *HardforkTest) ValidateSlotOccupancy(startBlock, lastBlock client.BlockData) error {
	expectedOccupancy := 0.5

	t.Logger.Info("Calculating slot occupancy between block %v and %v", startBlock, lastBlock)

	if startBlock.BlockHeight == lastBlock.BlockHeight {
		return fmt.Errorf("starting block has same height as last block, can't calculate slot occupancy!")
	}

	actualOccupancy := float64(lastBlock.BlockHeight-startBlock.BlockHeight) / float64(lastBlock.Slot-startBlock.Slot)

	if actualOccupancy < expectedOccupancy {
		return fmt.Errorf("slot occupancy (%f) is below expected (%f)", actualOccupancy, expectedOccupancy)
	}
	return nil
}

// ValidateLatestOccupiedSlot checks that the max slot is not beyond the chain end
func (t *HardforkTest) ValidateLatestOccupiedSlot(latestOccupiedSlot int) error {
	t.Logger.Info("Last occupied slot of pre-fork chain: %d", latestOccupiedSlot)
	if latestOccupiedSlot >= t.Config.SlotChainEnd {
		t.Logger.Error("Assertion failed: block with slot %d created after slot chain end", latestOccupiedSlot)
		return fmt.Errorf("block with slot %d created after slot chain end", latestOccupiedSlot)
	}
	return nil
}

// Validate last block before slot tx end
func (t *HardforkTest) ValidateLatestLastBlockBeforeTxEndSlot(lastBlockBeforeTxEnd client.BlockData) error {
	t.Logger.Info("Last block before slot-tx-end: %s, height: %d, slot: %d",
		lastBlockBeforeTxEnd.StateHash, lastBlockBeforeTxEnd.BlockHeight, lastBlockBeforeTxEnd.Slot)

	if lastBlockBeforeTxEnd.Slot >= t.Config.SlotTxEnd {
		return fmt.Errorf("non-empty block with slot %d created after slot tx end", lastBlockBeforeTxEnd.Slot)
	}
	return nil
}

// ValidateNoNewBlocks verifies that no new blocks are created after chain end
func (t *HardforkTest) ValidateNoNewBlocks(port int) error {
	t.Logger.Info("Waiting to verify no new blocks are created after chain end...")

	bestTip1, err := t.Client.BestTip(port)
	if err != nil {
		return fmt.Errorf("failed to get bestTip at port %d: %w", port, err)
	}

	time.Sleep(time.Duration(t.Config.NoNewBlocksWaitSeconds) * time.Second)

	bestTip2, err := t.Client.BestTip(port)
	if err != nil {
		return fmt.Errorf("failed to get bestTip at port %d: %w", port, err)
	}

	if bestTip2.BlockHeight > bestTip1.BlockHeight {
		return fmt.Errorf("unexpected block height increase from %d to %d after chain end", bestTip2.BlockHeight, bestTip1.BlockHeight)
	}

	return nil
}

func (t *HardforkTest) ReportBlocksInfo(port int, blocks []client.BlockData) {
	t.Logger.Info("================================================")
	for _, block := range blocks {
		t.Logger.Info("node at %d has block %v", port, block)
	}
}

func (t *HardforkTest) ConsensusStateOnNode(port int) (*ConsensusState, error) {

	state := new(ConsensusState)

	recentBlocks, err := t.Client.RecentBlocks(port, config.ProtocolK)

	t.ReportBlocksInfo(port, recentBlocks)

	if err != nil {
		return nil, fmt.Errorf("failed to collect blocks at port %d: %w", port, err)
	}

	if len(recentBlocks) == 0 {
		return nil, fmt.Errorf("no blocks is tracked at port %d!", port)
	}

	// Process each block
	for _, block := range recentBlocks {
		// Update max slot
		if block.Slot > state.LastOccupiedSlot {
			state.LastOccupiedSlot = block.Slot
		}

		// Track latest non-empty block
		if block.Slot > state.LastBlockBeforeTxEnd.Slot && block.Slot < t.Config.SlotTxEnd {
			state.LastBlockBeforeTxEnd = block
		}
	}

	if state.LastBlockBeforeTxEnd.Slot == 0 {
		return nil, fmt.Errorf("no blocks with slot > 0 at port %d", port)
	}

	return state, nil
}

type SnarkedHashByEpoch map[int]string

func (t *HardforkTest) CollectEpochHashes(mainGenesisTs int64) (*SnarkedHashByEpoch, error) {
	// NOTE: we're only tracking epoch ledgers on a single node, we're relying that
	// epoch hashes having stronger consensus guarantee because it's updated much
	// slower than blocks
	slotPerCheck := config.ProtocolK / 2
	// Very unlikely to happen but we have it here for fail-safe
	if slotPerCheck < 1 {
		slotPerCheck = 1
	}

	slotChainEnd := t.Config.MainSlotChainEnd(mainGenesisTs)
	sleepDuration := time.Duration(t.Config.MainSlot*slotPerCheck) * time.Second

	snarkedHashByEpoch := make(SnarkedHashByEpoch)
	lastSlotPerEpoch := make(map[int]int)
	for time.Now().Before(slotChainEnd) {
		recentBlocks, err := t.Client.RecentBlocks(t.Config.SampleDaemonInfo("any", func(di *config.DaemonInfo) bool { return true }).Port(config.PORT_REST), config.ProtocolK)
		if err != nil {
			return nil, err
		}

		for _, block := range recentBlocks {
			// NOTE: If it's equal, we're likely to have a chain-reorg, so always accept
			// new data.
			if block.Slot >= lastSlotPerEpoch[block.Epoch] {
				snarkedHashByEpoch[block.Epoch] = block.SnarkedHash
				lastSlotPerEpoch[block.Epoch] = block.Slot
				t.Logger.Info("Updated last seen snarked ledger hash within epoch %d at slot %d: %s", block.Epoch, block.Slot, block.SnarkedHash)
			}
		}

		actualSleepDuration := time.Until(slotChainEnd)
		if sleepDuration < actualSleepDuration {
			actualSleepDuration = sleepDuration
		}
		time.Sleep(actualSleepDuration)
	}
	return &snarkedHashByEpoch, nil
}

func (t *HardforkTest) ConsensusAcrossNodes() (*ConsensusState, error) {
	allNonAutoDaemons := t.Config.AllDaemonInfos("non-auto", func(di *config.DaemonInfo) bool { return di.ForkMethod != config.Auto })

	var wg sync.WaitGroup

	states := make([]*ConsensusState, len(allNonAutoDaemons)) // store results
	errors := make([]error, len(allNonAutoDaemons))

	for i, daemon := range allNonAutoDaemons {
		wg.Add(1)
		go func(i, port int) {
			defer wg.Done()
			state, err := t.ConsensusStateOnNode(port)
			states[i] = state
			errors[i] = err
		}(i, daemon.Port(config.PORT_REST))
	}

	wg.Wait()

	for i, daemon := range allNonAutoDaemons {
		if errors[i] != nil {
			return nil, fmt.Errorf("Failed to query consensus state on node %s: %w", daemon.Name, errors[i])
		}
	}

	for i, daemon := range allNonAutoDaemons {
		if i == 0 {
			continue
		}

		state := states[i]
		last_state := states[i-1]

		if state.LastBlockBeforeTxEnd != last_state.LastBlockBeforeTxEnd {
			return nil, fmt.Errorf(
				"Daemon %s and %s doesn't agree on last block seen before tx end! The previous has %v while the later has %v",
				allNonAutoDaemons[i-1].Name, daemon.Name, last_state, state)
		}
	}

	if len(allNonAutoDaemons) == 0 {
		return nil, fmt.Errorf("No nodes are running after slot-chain-end!")
	}

	return states[0], nil
}

// AnalyzeBlocks performs comprehensive block analysis including finding genesis epoch hashes
func (t *HardforkTest) AnalyzeBlocksOnMainNetwork(mainGenesisTs int64) (*BlockAnalysisResult, error) {

	daemonForGenesisBlock := t.Config.SampleDaemonInfo("any", func(di *config.DaemonInfo) bool { return true })
	genesisBlock, err := t.Client.GenesisBlock(daemonForGenesisBlock.Port(config.PORT_REST))
	if err != nil {
		return nil, fmt.Errorf("failed to get genesis block on daemon %s: %w", daemonForGenesisBlock.Name, err)
	}
	t.Logger.Info("Genesis block: %v", genesisBlock)

	snarkedHashByEpoch, err := t.CollectEpochHashes(mainGenesisTs)
	if err != nil {
		return nil, err
	}

	// NOTE: We should already be at slot chain end given how `CollectEpochHashes`
	// is implemented
	t.Logger.Info("Sleeping till slot chain end before start querying block info on chain..")

	// NOTE: We sleep because the chain might not produce a block exactly at the
	// slot chain end; sleeping ensures we have definitely reached that instant.
	time.Sleep(time.Until(t.Config.MainSlotChainEnd(mainGenesisTs)))

	consensus, err := t.ConsensusAcrossNodes()
	if err != nil {
		return nil, err
	}

	return &BlockAnalysisResult{
		Consensus:          *consensus,
		GenesisBlock:       *genesisBlock,
		SnarkedHashByEpoch: *snarkedHashByEpoch,
	}, nil
}

// FindStakingHash finds the staking ledger hash for the given epoch
func (t *HardforkTest) FindStakingHash(
	epoch int,
	genesisBlock client.BlockData,
	epochs map[int]string,
) (string, error) {
	// Handle special cases for genesis epochs
	if epoch == 0 {
		return genesisBlock.CurEpochHash, nil
	}

	if epoch == 1 {
		return genesisBlock.NextEpochHash, nil
	}

	// For other epochs, look up in the map
	hash, exists := epochs[epoch-2]
	if !exists {
		return "", fmt.Errorf("last snarked ledger for epoch %d wasn't captured", epoch-2)
	}

	return hash, nil
}

// ValidateBlockWithUserCommandCreated checks that blocks contain user commands
func (t *HardforkTest) ValidateBlockWithUserCommandCreatedForkNetwork(port int) error {
	allBlocksEmpty := true
	for i := 0; i < t.Config.UserCommandCheckMaxIterations; i++ {
		time.Sleep(time.Duration(t.Config.ForkSlot) * time.Second)

		userCmds, err := t.Client.NumUserCommandsInBestChain(port)
		if err != nil {
			t.Logger.Debug("Failed to get blocks with user commands: %v", err)
			continue
		}

		if userCmds > 0 {
			allBlocksEmpty = false
			break
		}
	}

	if allBlocksEmpty {
		t.Logger.Error("Assertion failed: all blocks in fork chain are empty %s", "")
		return fmt.Errorf("all blocks in fork chain are empty")
	}

	return nil
}

func (t *HardforkTest) GenesisBlockAcrossNetwork() (*client.BlockData, error) {
	seenBlock := false
	var commonGenesisBlock *client.BlockData
	var daemonReturningCommonGenesisBlock config.DaemonInfo

	for _, info := range t.Config.DaemonInfos {
		ourGenesisBlock, err := t.Client.GenesisBlock(info.Port(config.PORT_REST))
		if err != nil {
			return nil, fmt.Errorf("Failed to query genesis block on node %s: %w", info.Name, err)
		}
		if seenBlock {
			if !reflect.DeepEqual(ourGenesisBlock, commonGenesisBlock) {
				return nil, fmt.Errorf("Node %s has genesis block %v, while node %s has genesis block %v, they don't agree", daemonReturningCommonGenesisBlock.Name, commonGenesisBlock, info.Name, ourGenesisBlock)
			}
		} else {
			seenBlock = true
			commonGenesisBlock = ourGenesisBlock
			daemonReturningCommonGenesisBlock = info
		}
	}
	if !seenBlock {
		panic("Unreachable(GenesisBlockAcrossNetwork): No daemon is running!")
	}
	return commonGenesisBlock, nil
}
