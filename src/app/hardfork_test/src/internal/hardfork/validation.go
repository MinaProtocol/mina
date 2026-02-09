package hardfork

import (
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// BlockAnalysisResult holds the results of analyzing blocks
type BlockAnalysisResult struct {
	LastOccupiedSlot          int
	RecentSnarkedHashPerEpoch map[int]string // map from epoch to snarked ledger hash
	LastBlockBeforeTxEnd      client.BlockData
	GenesisBlock              client.BlockData
	CandidatePortBasesForFork []int
}

func (t *HardforkTest) WaitForBestTip(port int, pred func(client.BlockData) bool, predDescription string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)

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
func (t *HardforkTest) ValidateSlotOccupancy(startingHeight, blockHeight int) error {
	if 2*blockHeight < t.Config.BestChainQueryFrom {
		return fmt.Errorf("slot occupancy (%d/%d) is below 50%%", blockHeight, t.Config.BestChainQueryFrom)
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

func (t *HardforkTest) ValidateLatestLastBlockBeforeTxEndSlot(lastBlockBeforeTxEnd client.BlockData) error {
	t.Logger.Info("Last block before slot-tx-end: %s, height: %d, slot: %d",
		lastBlockBeforeTxEnd.StateHash, lastBlockBeforeTxEnd.BlockHeight, lastBlockBeforeTxEnd.Slot)

	if lastBlockBeforeTxEnd.Slot >= t.Config.SlotTxEnd {
		t.Logger.Error("Assertion failed: non-empty block with slot %d created after slot tx end", lastBlockBeforeTxEnd.Slot)
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

// NOTE: this is a weird implementation.
// CollectBlocks gathers blocks from multiple slots across different ports
func (t *HardforkTest) CollectBlocks(portUsed int, startSlot, endSlot int) ([]client.BlockData, error) {
	var allBlocks []client.BlockData
	collectedSlot := startSlot - 1

	for thisSlot := startSlot; thisSlot <= endSlot; thisSlot++ {
		t.WaitForBestTip(portUsed, func(block client.BlockData) bool {
			return block.Slot >= thisSlot
		}, fmt.Sprintf("best tip reached slot %d", startSlot),
			2*time.Duration(t.Config.MainSlot)*time.Second,
		)

		// this query returns recent blocks(closer to best tip) in increasing order.
		recentBlocks, err := t.Client.RecentBlocks(portUsed, 5)
		if err != nil {
			t.Logger.Debug("Failed to get blocks at slot %d: %v from port %d", thisSlot, err, portUsed)
		} else {
			for _, block := range recentBlocks {
				if block.Slot > collectedSlot {
					allBlocks = append(allBlocks, block)
					collectedSlot = block.Slot
				}
			}
		}
	}

	return allBlocks, nil
}

func (t *HardforkTest) ReportBlocksInfo(port int, blocks []client.BlockData) {
	t.Logger.Info("================================================")
	for _, block := range blocks {
		t.Logger.Info("node at %d has block %v", port, block)
	}
}

func (t *HardforkTest) ConsensusStateOnNode(port int) (*ConsensusState, error) {

	state := new(ConsensusState)

	blocks, err := t.CollectBlocks(port, t.Config.BestChainQueryFrom, t.Config.SlotChainEnd)

	t.ReportBlocksInfo(port, blocks)

	if err != nil {
		return nil, fmt.Errorf("failed to collect blocks at port %d: %w", port, err)
	}

	if len(blocks) == 0 {
		return nil, fmt.Errorf("no blocks is tracked at port %d!", port)
	}

	state.RecentSnarkedHashPerEpoch = make(map[int]string)
	latestSlotPerEpoch := make(map[int]int)

	// Process each block
	for _, block := range blocks {
		// Update max slot
		if block.Slot > state.LastOccupiedSlot {
			state.LastOccupiedSlot = block.Slot
		}

		// Track snarked ledger hash per epoch
		if block.Slot > latestSlotPerEpoch[block.Epoch] {
			state.RecentSnarkedHashPerEpoch[block.Epoch] = block.SnarkedHash
			latestSlotPerEpoch[block.Epoch] = block.Slot
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

func (t *HardforkTest) ConsensusAcrossNodes() (*ConsensusState, []int, error) {
	allRestPorts := t.Config.AllPortOfType(config.PORT_REST)
	consensusStateVote := make(map[string][]int)

	var majorityConsensusState ConsensusState
	// majorityKey := "<none>"
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

		consensusStateVote[key] = append(consensusStateVote[key], port-int(config.PORT_REST))

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
func (t *HardforkTest) AnalyzeBlocks() (*BlockAnalysisResult, error) {

	portUsed := t.Config.AnyPortOfType(config.PORT_REST)
	genesisBlock, err := t.Client.GenesisBlock(portUsed)
	if err != nil {
		return nil, fmt.Errorf("failed to get genesis block on port %d: %w", portUsed, err)
	}
	t.Logger.Info("Genesis block: %v", genesisBlock)

	consensus, candidatePortBasesForFork, err := t.ConsensusAcrossNodes()
	if err != nil {
		return nil, err
	}

	return &BlockAnalysisResult{
		LastOccupiedSlot:          consensus.LastOccupiedSlot,
		RecentSnarkedHashPerEpoch: consensus.RecentSnarkedHashPerEpoch,
		LastBlockBeforeTxEnd:      consensus.LastBlockBeforeTxEnd,
		GenesisBlock:              *genesisBlock,
		CandidatePortBasesForFork: candidatePortBasesForFork,
	}, nil
}

type ConsensusState struct {
	LastOccupiedSlot          int              `json:"last_occupied_slot"`
	RecentSnarkedHashPerEpoch map[int]string   `json:"recent_snarked_hash_per_epoch"`
	LastBlockBeforeTxEnd      client.BlockData `json:"last_block_before_tx_end"`
}

// FindStakingHash finds the staking ledger hash for the given epoch
func (t *HardforkTest) FindStakingHash(
	epoch int,
	genesisEpochStakingHash string,
	genesisEpochNextHash string,
	epochs map[int]string,
) (string, error) {
	// Handle special cases for genesis epochs
	if epoch == 0 {
		return genesisEpochStakingHash, nil
	}

	if epoch == 1 {
		return genesisEpochNextHash, nil
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
