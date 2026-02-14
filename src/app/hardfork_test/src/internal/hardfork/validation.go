package hardfork

import (
	"encoding/json"
	"fmt"
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
	Consensus                 ConsensusState
	GenesisBlock              client.BlockData
	SnarkedHashByEpoch        SnarkedHashByEpoch
	CandidatePortBasesForFork []int
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
	checkPerSlot := config.ProtocolK / 2
	// Very unlikely to happen but we have it here for fail-safe
	if checkPerSlot < 1 {
		checkPerSlot = 1
	}

	slotChainEnd := t.Config.MainSlotChainEnd(mainGenesisTs)
	sleepDuration := time.Duration(t.Config.MainSlot*checkPerSlot) * time.Second

	snarkedHashByEpoch := make(SnarkedHashByEpoch)
	lastSlotPerEpoch := make(map[int]int)
	for time.Now().Before(slotChainEnd) {
		recentBlocks, err := t.Client.RecentBlocks(t.AnyPortOfType(PORT_REST), config.ProtocolK)
		if err != nil {
			return nil, err
		}

		for _, block := range recentBlocks {
			// NOTE: If it's equal, we're likely to have a chain-reorg, so always accept
			// new data.
			if block.Slot >= lastSlotPerEpoch[block.Epoch] {
				snarkedHashByEpoch[block.Epoch] = block.SnarkedHash
				lastSlotPerEpoch[block.Epoch] = block.Slot
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

func (t *HardforkTest) ConsensusAcrossNodes() (*ConsensusState, []int, error) {
	allRestPorts := t.AllPortOfType(PORT_REST)
	consensusStateVote := make(map[string][]int)

	var majorityConsensusState ConsensusState
	majorityCount := 0

	var wg sync.WaitGroup

	states := make([]*ConsensusState, len(allRestPorts)) // store results
	errors := make([]error, len(allRestPorts))

	for i, port := range allRestPorts {
		wg.Add(1)
		go func(i, port int) {
			defer wg.Done()
			state, err := t.ConsensusStateOnNode(port)
			states[i] = state
			errors[i] = err
		}(i, port)
	}

	wg.Wait()

	for i, port := range allRestPorts {
		if errors[i] != nil {
			return nil, nil, fmt.Errorf("Failed to query consensus state on port %d: %w", port, errors[i])
		}
	}

	for i, port := range allRestPorts {
		state := states[i]

		keyBytes, err := json.Marshal(state.LastBlockBeforeTxEnd)

		if err != nil {
			return nil, nil, fmt.Errorf("Failed to marshal consensus state on port %d: %w", port, err)
		}

		key := string(keyBytes)

		consensusStateVote[key] = append(consensusStateVote[key], port-int(PORT_REST))

		if len(consensusStateVote[key]) > majorityCount {
			majorityCount = len(consensusStateVote[key])
			majorityConsensusState = *state
		}
	}

	if len(allRestPorts) == 0 {
		return nil, nil, fmt.Errorf("Unreachable: no nodes are running!")
	}

	if float64(majorityCount)/float64(len(allRestPorts)) <= 0.5 {
		return nil, nil, fmt.Errorf(
			"The majority state hash at slot_tx_end %d is less than 50%%: %v",
			t.Config.SlotTxEnd, consensusStateVote)
	}
	majorityKeyBytes, err := json.Marshal(majorityConsensusState.LastBlockBeforeTxEnd)
	if err != nil {
		return nil, nil, fmt.Errorf("Failed to marshal majority consensus state to string!")
	}
	candidateRestPortsForFork := consensusStateVote[string(majorityKeyBytes)]

	return &majorityConsensusState, candidateRestPortsForFork, nil
}

// AnalyzeBlocks performs comprehensive block analysis including finding genesis epoch hashes
func (t *HardforkTest) AnalyzeBlocks(mainGenesisTs int64) (*BlockAnalysisResult, error) {

	portUsed := t.AnyPortOfType(PORT_REST)
	genesisBlock, err := t.Client.GenesisBlock(portUsed)
	if err != nil {
		return nil, fmt.Errorf("failed to get genesis block on port %d: %w", portUsed, err)
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

	consensus, candidatePortBasesForFork, err := t.ConsensusAcrossNodes()
	if err != nil {
		return nil, err
	}

	return &BlockAnalysisResult{
		Consensus:                 *consensus,
		GenesisBlock:              *genesisBlock,
		SnarkedHashByEpoch:        *snarkedHashByEpoch,
		CandidatePortBasesForFork: candidatePortBasesForFork,
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

// waitForEarliestBlock waits for the earliest block to appear in the fork network with retry mechanism
// Returns the height and slot of the earliest block, or an error if max retries exceeded
func (t *HardforkTest) waitForEarliestBlockInForkNetwork(port int) (height int, slot int, err error) {
	for attempt := 1; attempt <= t.Config.ForkEarliestBlockMaxRetries; attempt++ {
		genesisBlock, queryError := t.Client.GenesisBlock(port)
		if queryError == nil && genesisBlock.BlockHeight > 0 {
			return genesisBlock.BlockHeight, genesisBlock.Slot, nil
		}

		if attempt < t.Config.ForkEarliestBlockMaxRetries {
			t.Logger.Debug("Waiting for earliest block (attempt %d/%d)...", attempt, t.Config.ForkEarliestBlockMaxRetries)
			time.Sleep(time.Duration(t.Config.ForkSlot) * time.Second)
		} else {
			err = queryError
		}
	}

	if err != nil {
		return 0, 0, fmt.Errorf("failed to get earliest block after %d attempts: %w", t.Config.ForkEarliestBlockMaxRetries, err)
	}
	return 0, 0, fmt.Errorf("no blocks found after %d attempts", t.Config.ForkEarliestBlockMaxRetries)
}

// ValidateFirstBlockOfForkChain checks that the fork network is producing blocks
func (t *HardforkTest) ValidateFirstBlockOfForkChain(port int, latestPreForkHeight int, expectedGenesisSlot int64) error {
	// Wait for the earliest block to appear
	earliestHeight, earliestSlot, err := t.waitForEarliestBlockInForkNetwork(port)
	if err != nil {
		return err
	}

	// Check earliest height
	if earliestHeight != latestPreForkHeight+1 {
		t.Logger.Error("Assertion failed: unexpected block height %d at the beginning of the fork", earliestHeight)
		return fmt.Errorf("unexpected block height %d at beginning of fork", earliestHeight)
	}

	// Check earliest slot
	if earliestSlot < int(expectedGenesisSlot) {
		t.Logger.Error("Assertion failed: unexpected slot %d at the beginning of the fork", earliestSlot)
		return fmt.Errorf("unexpected slot %d at beginning of fork", earliestSlot)
	}

	return nil
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
