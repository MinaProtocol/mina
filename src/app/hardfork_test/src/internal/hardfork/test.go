package hardfork

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/graphql"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/utils"
	"github.com/tidwall/gjson"
)

// Constants for indexing block data fields
const (
	IxStateHash     = 0
	IxHeight        = 1
	IxSlot          = 2
	IxNonEmpty      = 3
	IxCurEpochHash  = 4
	IxCurEpochSeed  = 5
	IxNextEpochHash = 6
	IxNextEpochSeed = 7
	IxStagedHash    = 8
	IxSnarkedHash   = 9
	IxEpoch         = 10
)

// HardforkTest represents the main hardfork test logic
type HardforkTest struct {
	Config        *config.Config
	Client        *graphql.Client
	Logger        *utils.Logger
	ScriptDir     string
	MainGenesisTs int64
	ForkGenesisTs int64
}

// NewHardforkTest creates a new instance of the hardfork test
func NewHardforkTest(cfg *config.Config) *HardforkTest {
	mainGenesisTs, forkGenesisTs := cfg.CalculateTimestamps()

	return &HardforkTest{
		Config:        cfg,
		Client:        graphql.NewClient(),
		Logger:        utils.NewLogger(),
		ScriptDir:     filepath.Join(cfg.WorkDir, "scripts", "hardfork"),
		MainGenesisTs: mainGenesisTs,
		ForkGenesisTs: forkGenesisTs,
	}
}

// StopNodes stops the nodes running on the specified ports
func (t *HardforkTest) StopNodes(execPath string) error {
	t.Logger.Info("Stopping nodes...")

	// Stop node on port 10301
	cmd1 := exec.Command(execPath, "client", "stop-daemon", "--daemon-port", "10301")
	if err := cmd1.Run(); err != nil {
		return fmt.Errorf("failed to stop daemon on port 10301: %w", err)
	}

	// Stop node on port 10311
	cmd2 := exec.Command(execPath, "client", "stop-daemon", "--daemon-port", "10311")
	if err := cmd2.Run(); err != nil {
		return fmt.Errorf("failed to stop daemon on port 10311: %w", err)
	}

	t.Logger.Info("Nodes stopped successfully")
	return nil
}

// RunMainNetwork starts the main network
func (t *HardforkTest) RunMainNetwork() (*exec.Cmd, error) {
	t.Logger.Info("Starting main network...")

	// Set environment variables
	mainGenesisTimestamp := config.FormatTimestamp(t.MainGenesisTs)

	// Prepare run-localnet.sh command
	cmd := exec.Command(
		filepath.Join(t.ScriptDir, "run-localnet.sh"),
		"-m", t.Config.MainMinaExe,
		"-i", strconv.Itoa(t.Config.MainSlot),
		"-s", strconv.Itoa(t.Config.MainSlot),
		"--slot-tx-end", strconv.Itoa(t.Config.SlotTxEnd),
		"--slot-chain-end", strconv.Itoa(t.Config.SlotChainEnd),
	)

	// Set environment variable
	cmd.Env = append(os.Environ(), "GENESIS_TIMESTAMP="+mainGenesisTimestamp)

	// Start command
	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start main network: %w", err)
	}

	t.Logger.Info("Main network started successfully")
	return cmd, nil
}

// WaitForBlockHeight waits until the specified block height is reached
func (t *HardforkTest) WaitForBlockHeight(port int, minHeight int, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)

	for time.Now().Before(deadline) {
		height, err := t.Client.GetHeight(port)
		if err != nil {
			t.Logger.Debug("Failed to get block height: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}

		if height >= minHeight {
			return nil
		}

		time.Sleep(5 * time.Second)
	}

	return fmt.Errorf("timed out waiting for block height >= %d", minHeight)
}

// FindLatestNonEmptyBlock processes block data to find the latest non-empty block
// and collects other important information
func (t *HardforkTest) FindLatestNonEmptyBlock(blocks []graphql.BlockData) (
	maxSlot int,
	epochs map[int]string, // map from epoch to snarked ledger hash
	latestBlock graphql.BlockData,
	err error) {

	if len(blocks) == 0 {
		return 0, nil, graphql.BlockData{}, fmt.Errorf("no blocks provided")
	}

	maxSlot = 0
	epochs = make(map[int]string)
	latestSlot := 0
	latestNonEmptyBlock := graphql.BlockData{}

	// Process each block
	for _, block := range blocks {
		// Update max slot
		if block.Slot > maxSlot {
			maxSlot = block.Slot
		}

		// Track snarked ledger hash per epoch
		if _, exists := epochs[block.Epoch]; !exists || block.Slot > latestSlot {
			epochs[block.Epoch] = block.SnarkedHash
		}

		// Track latest non-empty block
		if block.NonEmpty && block.Slot > latestSlot {
			latestNonEmptyBlock = block
			latestSlot = block.Slot
		}
	}

	if latestSlot == 0 {
		return maxSlot, epochs, graphql.BlockData{}, fmt.Errorf("no non-empty blocks found")
	}

	return maxSlot, epochs, latestNonEmptyBlock, nil
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

// Run executes the hardfork test process
func (t *HardforkTest) Run() error {
	var err error

	// 1. Start the main network
	mainNetCmd, err := t.RunMainNetwork()
	if err != nil {
		return err
	}

	// Clean up the main network at the end
	defer func() {
		if mainNetCmd.Process != nil {
			mainNetCmd.Process.Kill()
		}
	}()

	// Calculate sleep time until best chain query
	sleepDuration := time.Duration(t.Config.MainSlot*t.Config.BestChainQueryFrom)*time.Second -
		time.Duration(time.Now().Unix()%60)*time.Second +
		time.Duration(t.Config.MainDelay*60)*time.Second

	t.Logger.Info("Sleeping for %v until best chain query...", sleepDuration)
	time.Sleep(sleepDuration)

	// 2. Check block height at slot BestChainQueryFrom
	blockHeight, err := t.Client.GetHeight(10303)
	if err != nil {
		return fmt.Errorf("failed to get block height: %w", err)
	}

	t.Logger.Info("Block height is %d at slot %d.", blockHeight, t.Config.BestChainQueryFrom)

	// Check if block occupancy is above 50%
	if 2*blockHeight < t.Config.BestChainQueryFrom {
		t.Logger.Error("Assertion failed: slot occupancy is below 50%%")
		t.StopNodes(t.Config.MainMinaExe)
		return fmt.Errorf("slot occupancy is below 50%%")
	}

	// Get blocks data to find the first non-empty block for epoch hashes
	blocks, err := t.Client.GetBlocks(10303)
	if err != nil {
		return fmt.Errorf("failed to get blocks: %w", err)
	}

	// Find the first non-empty block to get genesis epoch hashes
	var firstEpochBlock graphql.BlockData
	for _, block := range blocks {
		if block.NonEmpty {
			firstEpochBlock = block
			break
		}
	}

	if firstEpochBlock.StateHash == "" {
		return fmt.Errorf("no non-empty blocks found in the first query")
	}

	genesisEpochStakingHash := firstEpochBlock.CurEpochHash
	genesisEpochNextHash := firstEpochBlock.NextEpochHash

	t.Logger.Info("Genesis epoch staking/next hashes: %s, %s",
		genesisEpochStakingHash, genesisEpochNextHash)

	// Collect blocks from BestChainQueryFrom to SlotChainEnd
	var allBlocks []graphql.BlockData
	for i := t.Config.BestChainQueryFrom; i <= t.Config.SlotChainEnd; i++ {
		port := 10303
		if i%2 == 1 {
			port = 10313
		}

		blocksBatch, err := t.Client.GetBlocks(port)
		if err != nil {
			t.Logger.Debug("Failed to get blocks for slot %d: %v", i, err)
		} else {
			allBlocks = append(allBlocks, blocksBatch...)
		}

		time.Sleep(time.Duration(t.Config.MainSlot) * time.Second)
	}

	// Process blocks to find latest non-empty block and other data
	maxSlot, epochs, latestBlock, err := t.FindLatestNonEmptyBlock(allBlocks)
	if err != nil {
		return fmt.Errorf("failed to find latest non-empty block: %w", err)
	}

	t.Logger.Info("Last occupied slot of pre-fork chain: %d", maxSlot)
	if maxSlot >= t.Config.SlotChainEnd {
		t.Logger.Error("Assertion failed: block with slot %d created after slot chain end", maxSlot)
		t.StopNodes(t.Config.MainMinaExe)
		return fmt.Errorf("block with slot %d created after slot chain end", maxSlot)
	}

	t.Logger.Info("Latest non-empty block: %s, height: %d, slot: %d",
		latestBlock.StateHash, latestBlock.BlockHeight, latestBlock.Slot)

	if latestBlock.Slot >= t.Config.SlotTxEnd {
		t.Logger.Error("Assertion failed: non-empty block with slot %d created after slot tx end", latestBlock.Slot)
		t.StopNodes(t.Config.MainMinaExe)
		return fmt.Errorf("non-empty block with slot %d created after slot tx end", latestBlock.Slot)
	}

	// Create expected fork data
	expectedForkData := map[string]interface{}{
		"fork": map[string]interface{}{
			"blockchain_length":         latestBlock.BlockHeight,
			"global_slot_since_genesis": latestBlock.Slot,
			"state_hash":                latestBlock.StateHash,
		},
		"next_seed":    latestBlock.NextEpochSeed,
		"staking_seed": latestBlock.CurEpochSeed,
	}

	expectedForkDataJson, err := json.Marshal(expectedForkData)
	if err != nil {
		return fmt.Errorf("failed to marshal expected fork data: %w", err)
	}

	t.Logger.Info("Expected fork data: %s", string(expectedForkDataJson))

	// 4. Check that no new blocks are created after SlotChainEnd
	t.Logger.Info("Waiting to verify no new blocks are created after chain end...")
	height1, err := t.Client.GetHeight(10303)
	if err != nil {
		return fmt.Errorf("failed to get height1: %w", err)
	}

	time.Sleep(5 * time.Minute)

	height2, err := t.Client.GetHeight(10303)
	if err != nil {
		return fmt.Errorf("failed to get height2: %w", err)
	}

	if height2 > height1 {
		t.Logger.Error("Assertion failed: there should be no change in blockheight after slot chain end %s", "")
		t.StopNodes(t.Config.MainMinaExe)
		return fmt.Errorf("unexpected block height increase from %d to %d after chain end", height1, height2)
	}

	// 6. Extract transition root into a new runtime config
	os.MkdirAll("localnet", 0755)

	for {
		forkConfig, err := t.Client.GetForkConfig(10313)
		if err != nil {
			return fmt.Errorf("failed to get fork config: %w", err)
		}

		// Write fork config to file
		err = os.WriteFile("localnet/fork_config.json", []byte(forkConfig.Raw), 0644)
		if err != nil {
			return fmt.Errorf("failed to write fork config: %w", err)
		}

		// Check if file is valid
		fileInfo, err := os.Stat("localnet/fork_config.json")
		if err != nil {
			return fmt.Errorf("failed to stat fork config file: %w", err)
		}

		if fileInfo.Size() > 0 {
			// Read the first 4 bytes to check for "null"
			data, err := os.ReadFile("localnet/fork_config.json")
			if err != nil {
				return fmt.Errorf("failed to read fork config file: %w", err)
			}

			if len(data) >= 4 && string(data[:4]) != "null" {
				break
			}
		}

		t.Logger.Info("Failed to fetch valid fork config, retrying...")
		time.Sleep(1 * time.Minute)
	}

	// 7. Stop main network nodes
	t.StopNodes(t.Config.MainMinaExe)

	// Process fork config
	forkConfigData, err := os.ReadFile("localnet/fork_config.json")
	if err != nil {
		return fmt.Errorf("failed to read fork config file: %w", err)
	}

	forkData := gjson.Get(string(forkConfigData), "{fork:.proof.fork,next_seed:.epoch_data.next.seed,staking_seed:.epoch_data.staking.seed}")
	if forkData.Raw != string(expectedForkDataJson) {
		t.Logger.Error("Assertion failed: unexpected fork data %s", "")
		t.Logger.Error("Expected: %s", string(expectedForkDataJson))
		t.Logger.Error("Actual: %s", forkData.Raw)
		return fmt.Errorf("unexpected fork data")
	}

	// Generate prefork hardfork ledgers
	os.MkdirAll("localnet/prefork_hf_ledgers", 0755)

	cmd := exec.Command(
		t.Config.MainRuntimeGenesisLedger,
		"--config-file", "localnet/fork_config.json",
		"--genesis-dir", "localnet/prefork_hf_ledgers",
		"--hash-output-file", "localnet/prefork_hf_ledger_hashes.json",
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run main runtime genesis ledger: %w", err)
	}

	// Calculate slot_tx_end_epoch
	slotTxEndEpoch := latestBlock.Slot / 48

	// Find expected staking and next hashes
	expectedStakingHash, err := t.FindStakingHash(slotTxEndEpoch, genesisEpochStakingHash, genesisEpochNextHash, epochs)
	if err != nil {
		return fmt.Errorf("failed to find staking hash: %w", err)
	}

	expectedNextHash, err := t.FindStakingHash(slotTxEndEpoch+1, genesisEpochStakingHash, genesisEpochNextHash, epochs)
	if err != nil {
		return fmt.Errorf("failed to find next hash: %w", err)
	}

	// Create expected prefork hashes
	expectedPreforkHashes := map[string]interface{}{
		"epoch_data": map[string]interface{}{
			"next": map[string]interface{}{
				"hash": expectedNextHash,
			},
			"staking": map[string]interface{}{
				"hash": expectedStakingHash,
			},
		},
		"ledger": map[string]interface{}{
			"hash": latestBlock.StagedHash,
		},
	}

	expectedPreforkHashesJson, err := json.Marshal(expectedPreforkHashes)
	if err != nil {
		return fmt.Errorf("failed to marshal expected prefork hashes: %w", err)
	}

	// Read prefork hashes from file
	preforkHashesData, err := os.ReadFile("localnet/prefork_hf_ledger_hashes.json")
	if err != nil {
		return fmt.Errorf("failed to read prefork hashes file: %w", err)
	}

	// Select only the fields we want to compare
	preforkHashesSelect := "{epoch_data:{staking:{hash:.epoch_data.staking.hash},next:{hash:.epoch_data.next.hash}},ledger:{hash:.ledger.hash}}"
	preforkHashes := gjson.Get(string(preforkHashesData), preforkHashesSelect)

	// Compare expected and actual prefork hashes
	if preforkHashes.Raw != string(expectedPreforkHashesJson) {
		t.Logger.Error("Assertion failed: unexpected ledgers in fork_config %s", "")
		t.Logger.Error("Expected: %s", string(expectedPreforkHashesJson))
		t.Logger.Error("Actual: %s", preforkHashes.Raw)
		return fmt.Errorf("unexpected ledgers in fork_config")
	}

	// Create hardfork ledgers directory
	os.RemoveAll("localnet/hf_ledgers")
	os.MkdirAll("localnet/hf_ledgers", 0755)

	// Generate hardfork ledgers with fork executable
	cmd = exec.Command(
		t.Config.ForkRuntimeGenesisLedger,
		"--config-file", "localnet/fork_config.json",
		"--genesis-dir", "localnet/hf_ledgers",
		"--hash-output-file", "localnet/hf_ledger_hashes.json",
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run fork runtime genesis ledger: %w", err)
	}

	// Create runtime config
	forkGenesisTimestamp := config.FormatTimestamp(t.ForkGenesisTs)
	os.MkdirAll("localnet/config", 0755)

	cmd = exec.Command(filepath.Join(t.ScriptDir, "create_runtime_config.sh"))
	cmd.Env = append(os.Environ(),
		"GENESIS_TIMESTAMP="+forkGenesisTimestamp,
		"FORKING_FROM_CONFIG_JSON=localnet/config/base.json",
		"SECONDS_PER_SLOT="+strconv.Itoa(t.Config.MainSlot),
		"FORK_CONFIG_JSON=localnet/fork_config.json",
		"LEDGER_HASHES_JSON=localnet/hf_ledger_hashes.json",
	)

	configOutput, err := cmd.Output()
	if err != nil {
		return fmt.Errorf("failed to create runtime config: %w", err)
	}

	// Write config to file
	err = os.WriteFile("localnet/config.json", configOutput, 0644)
	if err != nil {
		return fmt.Errorf("failed to write config.json: %w", err)
	}

	// Calculate expected genesis slot
	expectedGenesisSlot := (t.ForkGenesisTs - t.MainGenesisTs) / int64(t.Config.MainSlot)

	// Create expected modified fork data
	expectedModifiedForkData := map[string]interface{}{
		"blockchain_length":         latestBlock.BlockHeight,
		"global_slot_since_genesis": expectedGenesisSlot,
		"state_hash":                latestBlock.StateHash,
	}

	expectedModifiedForkDataJson, err := json.Marshal(expectedModifiedForkData)
	if err != nil {
		return fmt.Errorf("failed to marshal expected modified fork data: %w", err)
	}

	// Read modified fork data from config
	configData, err := os.ReadFile("localnet/config.json")
	if err != nil {
		return fmt.Errorf("failed to read config.json: %w", err)
	}

	modifiedForkData := gjson.Get(string(configData), ".proof.fork")

	// Compare expected and actual modified fork data
	if modifiedForkData.Raw != string(expectedModifiedForkDataJson) {
		t.Logger.Error("Assertion failed: unexpected modified fork data %s", "")
		t.Logger.Error("Expected: %s", string(expectedModifiedForkDataJson))
		t.Logger.Error("Actual: %s", modifiedForkData.Raw)
		return fmt.Errorf("unexpected modified fork data")
	}

	t.Logger.Info("Config for the fork is correct, starting a new network")

	// 8. Start a new network with the fork executable
	cmd = exec.Command(
		filepath.Join(t.ScriptDir, "run-localnet.sh"),
		"-m", t.Config.ForkMinaExe,
		"-d", strconv.Itoa(t.Config.ForkDelay),
		"-i", strconv.Itoa(t.Config.ForkSlot),
		"-s", strconv.Itoa(t.Config.ForkSlot),
		"-c", "localnet/config.json",
		"--genesis-ledger-dir", "localnet/hf_ledgers",
	)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to start fork network: %w", err)
	}

	_ = cmd.Process.Pid // Save pid for future reference if needed

	// Clean up fork network at the end
	defer func() {
		if cmd.Process != nil {
			cmd.Process.Kill()
		}
		t.StopNodes(t.Config.ForkMinaExe)
	}()

	// Sleep until fork genesis
	t.Logger.Info("Sleeping for %d minutes until fork genesis...", t.Config.ForkDelay)
	time.Sleep(time.Duration(t.Config.ForkDelay) * time.Minute)

	// Wait for the earliest block to appear
	var earliestHeight, earliestSlot int
	for {
		height, slot, err := t.Client.GetHeightAndSlotOfEarliest(10303)
		if err == nil && height > 0 {
			earliestHeight = height
			earliestSlot = slot
			break
		}

		time.Sleep(time.Duration(t.Config.ForkSlot) * time.Second)
	}

	// Check earliest height
	if earliestHeight != latestBlock.BlockHeight+1 {
		t.Logger.Error("Assertion failed: unexpected block height %d at the beginning of the fork", earliestHeight)
		t.StopNodes(t.Config.ForkMinaExe)
		return fmt.Errorf("unexpected block height %d at beginning of fork", earliestHeight)
	}

	// Check earliest slot
	if earliestSlot < int(expectedGenesisSlot) {
		t.Logger.Error("Assertion failed: unexpected slot %d at the beginning of the fork", earliestSlot)
		t.StopNodes(t.Config.ForkMinaExe)
		return fmt.Errorf("unexpected slot %d at beginning of fork", earliestSlot)
	}

	// 9. Check that network eventually creates some blocks
	t.Logger.Info("Waiting for blocks to be produced...")
	time.Sleep(time.Duration(t.Config.ForkSlot*10) * time.Second)

	height1, err = t.Client.GetHeight(10303)
	if err != nil {
		return fmt.Errorf("failed to get height after fork: %w", err)
	}

	if height1 == 0 {
		t.Logger.Error("Assertion failed: block height %d should be greater than 0", height1)
		t.StopNodes(t.Config.ForkMinaExe)
		return fmt.Errorf("block height after fork is 0")
	}

	t.Logger.Info("Blocks are produced.")

	// Wait and check that there are blocks with user commands
	allBlocksEmpty := true
	for i := 0; i < 10; i++ {
		time.Sleep(time.Duration(t.Config.ForkSlot) * time.Second)

		userCmds, err := t.Client.BlocksWithUserCommands(10303)
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
		t.StopNodes(t.Config.ForkMinaExe)
		return fmt.Errorf("all blocks in fork chain are empty")
	}

	// Stop nodes and return success
	t.StopNodes(t.Config.ForkMinaExe)
	t.Logger.Info("Hardfork test completed successfully!")

	return nil
}
