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
	// Set of public keys that actually produced a block in the observed window
	// (block creators reported by consensus). This is the on-chain evidence of
	// which producers were live, independent of the key files the harness reads.
	ObservedProducerPks map[string]struct{} `json:"observed_producer_pks"`
}

type BlockAnalysisResult struct {
	Consensus          ConsensusState
	GenesisBlock       client.BlockData
	SnarkedHashByEpoch SnarkedHashByEpoch

	// Pre-fork slot occupancy and genesis stake breakdown, recorded during
	// the main network phase so the fork network phase can assert against
	// them (only populated in unstaking test mode)
	PreForkOccupancy  float64
	PreForkStakeStats StakeStats
	// Lazy whale public keys, classified once against the genesis ledger during
	// the main network phase and reused by the fork phases (fork-config
	// --unstake-pk args and the post-fork delegate check) rather than
	// re-reading the key files and ledger each time. Only populated in
	// unstaking test mode.
	LazyWhalePks []string
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

// ComputeSlotOccupancy computes the slot fill rate over the half-open window
// (startBlock.Slot, boundarySlot]: the fraction of those slots that produced a
// block. startBlock is the window's lower anchor and its own slot is excluded —
// it is genesis, not a VRF-produced slot. Block heights are dense along a
// chain, so the height delta counts exactly the blocks produced after
// startBlock up to lastBlock; startBlock must therefore be an ancestor of
// lastBlock.
//
// The denominator is boundarySlot − startBlock.Slot, NOT lastBlock.Slot −
// startBlock.Slot. The window runs to an intended boundary (e.g. slot_tx_end),
// not to the last observed block: anchoring the denominator on lastBlock would
// end the window on a guaranteed hit and silently drop the empty slots between
// the last block and the boundary, biasing the fill rate upward. boundarySlot
// must be at or beyond lastBlock.Slot; callers pass the last block that falls
// before the boundary, so no block lives in (lastBlock.Slot, boundarySlot] and
// the height-delta numerator still counts every block in the window. When the
// boundary coincides with lastBlock.Slot the window ends on a hit — the
// residual upward bias callers accept when no boundary past the tip exists.
func (t *HardforkTest) ComputeSlotOccupancy(startBlock, lastBlock client.BlockData, boundarySlot int) (float64, error) {
	t.Logger.Info("Calculating slot occupancy between block %v and %v over a window ending at slot %d", startBlock, lastBlock, boundarySlot)

	if lastBlock.Slot <= startBlock.Slot {
		return 0, fmt.Errorf("last block (slot %d) is not after starting block (slot %d), can't calculate slot occupancy!", lastBlock.Slot, startBlock.Slot)
	}
	if lastBlock.BlockHeight <= startBlock.BlockHeight {
		return 0, fmt.Errorf("last block height (%d) is not above starting block height (%d), can't calculate slot occupancy!", lastBlock.BlockHeight, startBlock.BlockHeight)
	}
	if boundarySlot < lastBlock.Slot {
		return 0, fmt.Errorf("window boundary slot (%d) is before the last block's slot (%d); the boundary must be at or beyond the last observed block", boundarySlot, lastBlock.Slot)
	}

	return float64(lastBlock.BlockHeight-startBlock.BlockHeight) / float64(boundarySlot-startBlock.Slot), nil
}

// ValidateSlotOccupancy checks if block occupancy is above 50% over the window
// (startBlock.Slot, boundarySlot]; see ComputeSlotOccupancy for the window
// convention.
func (t *HardforkTest) ValidateSlotOccupancy(startBlock, lastBlock client.BlockData, boundarySlot int) error {
	expectedOccupancy := 0.5

	actualOccupancy, err := t.ComputeSlotOccupancy(startBlock, lastBlock, boundarySlot)
	if err != nil {
		return err
	}

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
	state.ObservedProducerPks = make(map[string]struct{})

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

		// Record the producer of every VRF-produced (non-genesis) block, so the
		// active-stake classification can be cross-checked against which
		// producers were actually live.
		if block.Slot > 0 && block.Creator != "" {
			state.ObservedProducerPks[block.Creator] = struct{}{}
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
		recentBlocks, err := t.Client.RecentBlocks(t.Config.AnyDaemon().Port(config.PORT_REST), config.ProtocolK)
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

func (t *HardforkTest) ConsensusAcrossNodesAfterSlotChainEnd() (*ConsensusState, error) {
	allAliveDaemons := t.Config.AllDaemonSatisfying("alive(non-auto)", func(di *config.DaemonInfo) bool { return di.ForkMethod != config.Auto })

	var wg sync.WaitGroup

	states := make([]*ConsensusState, len(allAliveDaemons)) // store results
	errors := make([]error, len(allAliveDaemons))

	for i, daemon := range allAliveDaemons {
		wg.Add(1)
		go func(i int, daemon *config.DaemonInfo) {
			defer wg.Done()
			state, err := t.ConsensusStateOnNode(daemon.Port(config.PORT_REST))
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
			return nil, fmt.Errorf(
				"Node %s and node %s doesn't agree on last block seen before tx end! The previous has %v while the later has %v",
				allAliveDaemons[i-1].Name, allAliveDaemons[i].Name, last_state, state)
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
