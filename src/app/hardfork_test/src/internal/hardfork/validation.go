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
	// PreForkPoolNonces is the nonce every value_transfer pool account reached on
	// the pre-fork chain, keyed by account ref. The fork network inherits those
	// accounts; the fork phase asserts each nonce carried over unchanged.
	PreForkPoolNonces map[string]int
}

func (t *HardforkTest) WaitForBestTip(di *config.DaemonInfo, pred func(client.BlockData) bool, predDescription string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)

	t.Logger.Info("Waiting for best tip on node %q to satisfy condition: %s", di.Name, predDescription)

	for time.Now().Before(deadline) {
		bestTip, err := t.Client.BestTip(di)
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
	return fmt.Errorf("timed out waiting for condition: %s on node %q", predDescription, di.Name)
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
func (t *HardforkTest) ValidateNoNewBlocks(di *config.DaemonInfo) error {
	t.Logger.Info("Waiting to verify no new blocks are created after chain end...")

	bestTip1, err := t.Client.BestTip(di)
	if err != nil {
		return fmt.Errorf("failed to get bestTip on node %q: %w", di.Name, err)
	}

	time.Sleep(time.Duration(t.Config.NoNewBlocksWaitSeconds) * time.Second)

	bestTip2, err := t.Client.BestTip(di)
	if err != nil {
		return fmt.Errorf("failed to get bestTip on node %q: %w", di.Name, err)
	}

	if bestTip2.BlockHeight > bestTip1.BlockHeight {
		return fmt.Errorf("unexpected block height increase from %d to %d after chain end", bestTip2.BlockHeight, bestTip1.BlockHeight)
	}

	return nil
}

func (t *HardforkTest) ReportBlocksInfo(di *config.DaemonInfo, blocks []client.BlockData) {
	t.Logger.Info("================================================")
	for _, block := range blocks {
		t.Logger.Info("node %q has block %v", di.Name, block)
	}
}

func (t *HardforkTest) ConsensusStateOnNode(di *config.DaemonInfo) (*ConsensusState, error) {

	state := new(ConsensusState)

	recentBlocks, err := t.Client.RecentBlocks(di, t.ConsensusParams.K)

	t.ReportBlocksInfo(di, recentBlocks)

	if err != nil {
		return nil, fmt.Errorf("failed to collect blocks on node %q: %w", di.Name, err)
	}

	if len(recentBlocks) == 0 {
		return nil, fmt.Errorf("no blocks is tracked on node %q!", di.Name)
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
		return nil, fmt.Errorf("no blocks with slot > 0 on node %q", di.Name)
	}

	return state, nil
}

type SnarkedHashByEpoch map[int]string

func (t *HardforkTest) CollectEpochHashes(mainGenesisTs int64) (*SnarkedHashByEpoch, error) {
	// NOTE: we're only tracking epoch ledgers on a single node, we're relying that
	// epoch hashes having stronger consensus guarantee because it's updated much
	// slower than blocks
	slotPerCheck := t.ConsensusParams.K / 2
	// Very unlikely to happen but we have it here for fail-safe
	if slotPerCheck < 1 {
		slotPerCheck = 1
	}

	slotChainEnd := t.Config.MainSlotChainEnd(mainGenesisTs)
	sleepDuration := time.Duration(t.Config.MainSlot*slotPerCheck) * time.Second

	snarkedHashByEpoch := make(SnarkedHashByEpoch)
	lastSlotPerEpoch := make(map[int]int)
	// The snarked ledger hash each epoch froze at, and the slot it was first seen
	// frozen at. See checkSnarkedHashFrozen.
	frozenHash := make(map[int]string)
	frozenSlot := make(map[int]int)
	for time.Now().Before(slotChainEnd) {
		recentBlocks, err := t.Client.RecentBlocks(t.Config.AnyDaemon(), t.ConsensusParams.K)
		if err != nil {
			return nil, err
		}

		for _, block := range recentBlocks {
			if err := t.checkSnarkedHashFrozen(block, frozenHash, frozenSlot); err != nil {
				return nil, err
			}
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

// checkSnarkedHashFrozen asserts that the snarked ledger hash does not move once
// slot-tx-end is reached.
//
// The daemon guarantees this: from slot-tx-end on, a block's staged ledger diff
// must be empty, and "empty" includes carrying no completed SNARK work
// (Staged_ledger_diff.is_empty). No completed work can be applied, so the scan
// state cannot emit a ledger proof, so the snarked ledger cannot advance. It is
// enforced when blocks are validated rather than only when they are produced,
// so it holds for every block the network accepts.
//
// Asserted rather than assumed because the fork is cut from this settled state:
// the fork config's ledger and epoch_data hashes are taken from it. If it ever
// did move, the run would fail somewhere far away — a ledger hash mismatch, or
// nodes computing different chain ids — rather than here, saying the ledger did
// not freeze.
//
// Per epoch, not globally: an epoch boundary can fall between slot-tx-end and
// slot-chain-end, and each epoch's ledger freezes at its own hash.
func (t *HardforkTest) checkSnarkedHashFrozen(
	block client.BlockData, frozenHash map[int]string, frozenSlot map[int]int,
) error {
	if block.Slot < t.Config.SlotTxEnd {
		return nil
	}
	seen, ok := frozenHash[block.Epoch]
	if !ok {
		frozenHash[block.Epoch] = block.SnarkedHash
		frozenSlot[block.Epoch] = block.Slot
		return nil
	}
	if seen != block.SnarkedHash {
		return fmt.Errorf(
			"snarked ledger hash of epoch %d changed after slot-tx-end (%d): it was %s at slot %d, "+
				"but block %s at slot %d has %s. No block from slot-tx-end on may carry completed "+
				"SNARK work, so the snarked ledger cannot advance past it — the fork is cut from "+
				"this state and would be taken from a moving ledger",
			block.Epoch, t.Config.SlotTxEnd, seen, frozenSlot[block.Epoch],
			block.StateHash, block.Slot, block.SnarkedHash)
	}
	return nil
}

func (t *HardforkTest) ConsensusAcrossNodesAfterSlotChainEnd() (*ConsensusState, error) {
	allAliveDaemons := t.Config.AllDaemonSatisfying("alive(non-auto)", func(di *config.DaemonInfo) bool { return di.ForkMethod != config.Auto })

	var wg sync.WaitGroup

	states := make([]*ConsensusState, len(allAliveDaemons)) // store results
	errors := make([]error, len(allAliveDaemons))

	for i, daemon := range allAliveDaemons {
		wg.Add(1)
		go func(i int, daemon *config.DaemonInfo) {
			defer wg.Done()
			state, err := t.ConsensusStateOnNode(daemon)
			states[i] = state
			errors[i] = err
		}(i, daemon)
	}

	wg.Wait()

	for i, daemon := range allAliveDaemons {
		if errors[i] != nil {
			return nil, fmt.Errorf("Failed to query consensus state on node %s: %w", daemon.Name, errors[i])
		}
	}

	for i := range allAliveDaemons {
		if i == 0 {
			continue
		}

		state := states[i]
		last_state := states[i-1]

		if state.LastBlockBeforeTxEnd != last_state.LastBlockBeforeTxEnd {
			// The fork is cut at this block, so the nodes must agree on which one it
			// is. What buries it is the run of empty blocks between slot-tx-end and
			// slot-chain-end; if that gap is too short, the block is still shallow
			// enough when the chain stops for the nodes to differ.
			return nil, fmt.Errorf(
				"Node %s and node %s doesn't agree on last block seen before tx end! The previous has %v while the later has %v. "+
					"The fork block is buried by the %d slots between slot-tx-end (%d) and slot-chain-end (%d); "+
					"widening that gap gives the nodes more blocks to converge on it before the chain stops (k=%d blocks)",
				allAliveDaemons[i-1].Name, allAliveDaemons[i].Name, last_state, state,
				t.Config.SlotChainEnd-t.Config.SlotTxEnd, t.Config.SlotTxEnd, t.Config.SlotChainEnd,
				t.ConsensusParams.K)
		}
	}

	if len(allAliveDaemons) == 0 {
		return nil, fmt.Errorf("Unreachable: no nodes are running after slot-chain-end!")
	}

	return states[0], nil
}

func (t *HardforkTest) GenesisBlockAcrossNetwork() (*client.BlockData, error) {
	seenBlock := false
	var commonGenesisBlock *client.BlockData
	var daemonReturningCommonGenesisBlock config.DaemonInfo

	for _, info := range t.Config.DaemonInfos {
		ourGenesisBlock, err := t.Client.GenesisBlock(&info)
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

// AnalyzeBlocks performs comprehensive block analysis including finding genesis epoch hashes
func (t *HardforkTest) AnalyzeBlocksOnMainNetwork(mainGenesisTs int64) (*BlockAnalysisResult, error) {

	genesisBlock, err := t.GenesisBlockAcrossNetwork()
	if err != nil {
		return nil, fmt.Errorf("main network doesn't have a common genesis: %w", err)
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

	consensus, err := t.ConsensusAcrossNodesAfterSlotChainEnd()
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
func (t *HardforkTest) ValidateBlockWithUserCommandCreatedForkNetwork(di *config.DaemonInfo) error {
	allBlocksEmpty := true
	for i := 0; i < t.Config.UserCommandCheckMaxIterations; i++ {
		time.Sleep(time.Duration(t.Config.ForkSlot) * time.Second)

		userCmds, err := t.Client.NumUserCommandsInBestChain(di)
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
