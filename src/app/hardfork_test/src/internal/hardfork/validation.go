package hardfork

import (
	"fmt"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
)

// BlockAnalysisResult holds the results of analyzing blocks
type BlockAnalysisResult struct {
	LatestOccupiedSlot        int
	LatestSnarkedHashPerEpoch map[int]string // map from epoch to snarked ledger hash
	LatestNonEmptyBlock       client.BlockData
	GenesisEpochStaking       string
	GenesisEpochNext          string
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

// ValidateLatestNonEmptyBlockSlot checks that the latest non-empty block is before tx end slot
func (t *HardforkTest) ValidateLatestNonEmptyBlockSlot(latestNonEmptyBlock client.BlockData) error {
	t.Logger.Info("Latest non-empty block: %s, height: %d, slot: %d",
		latestNonEmptyBlock.StateHash, latestNonEmptyBlock.BlockHeight, latestNonEmptyBlock.Slot)

	if latestNonEmptyBlock.Slot >= t.Config.SlotTxEnd {
		t.Logger.Error("Assertion failed: non-empty block with slot %d created after slot tx end", latestNonEmptyBlock.Slot)
		return fmt.Errorf("non-empty block with slot %d created after slot tx end", latestNonEmptyBlock.Slot)
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
func (t *HardforkTest) CollectBlocks(startSlot, endSlot int) ([]client.BlockData, error) {
	var allBlocks []client.BlockData
	collectedSlot := startSlot - 1

	portUsed := t.AnyPortOfType(PORT_REST)

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

func (t *HardforkTest) EnsureConsensusOnSlotTxEnd() error {
	blocksAtSlotTxEndByPort := make(map[int]string)
	allRestPorts := t.AllPortOfType(PORT_REST)
	for _, port := range allRestPorts {
		blocks, err := t.Client.GetAllBlocks(port)
		if err != nil {
			return fmt.Errorf("failed to get blocks: %w from port %d", err, port)
		}
		for _, block := range blocks {
			if block.Slot == t.Config.SlotTxEnd {
				blocksAtSlotTxEndByPort[port] = block.StateHash
			}
		}
		_, seenSlotTxEndBlock := blocksAtSlotTxEndByPort[port]
		if !seenSlotTxEndBlock {
			t.Logger.Info("node at %d haven't seen block at slot %d, which is slot_tx_end", port, t.Config.SlotTxEnd)
			blocksAtSlotTxEndByPort[port] = "<none>"
		}
		t.ReportBlocksInfo(port, blocks)
	}
	counts := make(map[string]int)
	maxCount := 0
	majorityStateHashAtSlotTxEnd := ""
	for _, hash := range blocksAtSlotTxEndByPort {
		counts[hash]++
		if counts[hash] > maxCount {
			maxCount = counts[hash]
			majorityStateHashAtSlotTxEnd = hash
		}
	}

	if float64(maxCount)/float64(len(allRestPorts)) <= 0.5 {
		return fmt.Errorf(
			"The majority state hash at slot_tx_end %d is less than 50%%",
			t.Config.SlotTxEnd)
	}

	if majorityStateHashAtSlotTxEnd == "<none>" {
		return fmt.Errorf(
			"majority nodes in the network haven't reached slot_tx_end at %d yet",
			t.Config.SlotTxEnd,
		)
	}

	return nil
}

// AnalyzeBlocks performs comprehensive block analysis including finding genesis epoch hashes
func (t *HardforkTest) AnalyzeBlocks() (*BlockAnalysisResult, error) {
	// Get initial blocks to find genesis epoch hashes
	portUsed := t.AnyPortOfType(PORT_REST)
	blocks, err := t.Client.GetAllBlocks(portUsed)
	if err != nil {
		return nil, fmt.Errorf("failed to get blocks: %w from port %d", err, portUsed)
	}

	// Find the first non-empty block to get genesis epoch hashes
	var firstEpochBlock client.BlockData
	for _, block := range blocks {
		if block.NonEmpty && block.Epoch == 0 {
			firstEpochBlock = block
			break
		}
	}

	if firstEpochBlock.StateHash == "" {
		return nil, fmt.Errorf("no non-empty epoch 0 blocks found in the first query")
	}

	genesisEpochStakingHash := firstEpochBlock.CurEpochHash
	if genesisEpochStakingHash == "" {
		return nil, fmt.Errorf("genesis epoch staking hash is empty")
	}

	genesisEpochNextHash := firstEpochBlock.NextEpochHash
	if genesisEpochNextHash == "" {
		return nil, fmt.Errorf("genesis next staking hash is empty")
	}

	t.Logger.Info("Genesis epoch staking/next hashes: %s, %s",
		genesisEpochStakingHash, genesisEpochNextHash)

	// Collect blocks from BestChainQueryFrom to SlotChainEnd
	allBlocks, err := t.CollectBlocks(t.Config.BestChainQueryFrom, t.Config.SlotChainEnd)
	if err != nil {
		return nil, err
	}

	// Query from all nodes and ensure they agree on slot txn end.
	if err := t.EnsureConsensusOnSlotTxEnd(); err != nil {
		return nil, err
	}

	// Process blocks to find latest non-empty block and other data
	latestOccupiedSlot, latestSnarkedHashPerEpoch, latestNonEmptyBlock, err := t.FindLatestNonEmptyBlock(allBlocks)
	if err != nil {
		return nil, fmt.Errorf("failed to find latest non-empty block: %w", err)
	}

	return &BlockAnalysisResult{
		LatestOccupiedSlot:        latestOccupiedSlot,
		LatestSnarkedHashPerEpoch: latestSnarkedHashPerEpoch,
		LatestNonEmptyBlock:       latestNonEmptyBlock,
		GenesisEpochStaking:       genesisEpochStakingHash,
		GenesisEpochNext:          genesisEpochNextHash,
	}, nil
}

// FindLatestNonEmptyBlock processes block data to find the latest non-empty block
// and collects other important information
// This function assumes that there is at least one block with non-zero slot
func (t *HardforkTest) FindLatestNonEmptyBlock(blocks []client.BlockData) (
	latestOccupiedSlot int,
	latestSnarkedHashPerEpoch map[int]string, // map from epoch to snarked ledger hash
	latestNonEmptyBlock client.BlockData,
	err error) {

	if len(blocks) == 0 {
		err = fmt.Errorf("no blocks provided")
		return
	}

	latestSnarkedHashPerEpoch = make(map[int]string)
	latestSlotPerEpoch := make(map[int]int)

	// Process each block
	for _, block := range blocks {
		// Update max slot
		if block.Slot > latestOccupiedSlot {
			latestOccupiedSlot = block.Slot
		}

		// Track snarked ledger hash per epoch
		if block.Slot > latestSlotPerEpoch[block.Epoch] {
			latestSnarkedHashPerEpoch[block.Epoch] = block.SnarkedHash
			latestSlotPerEpoch[block.Epoch] = block.Slot
		}

		// Track latest non-empty block
		if block.NonEmpty && block.Slot > latestNonEmptyBlock.Slot {
			latestNonEmptyBlock = block
		}
	}

	if latestNonEmptyBlock.Slot == 0 {
		err = fmt.Errorf("no blocks with slot > 0")
		return
	}

	return
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
