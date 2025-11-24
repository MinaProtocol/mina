package hardfork

import (
	"fmt"
	"os"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
)

// ValidatePreforkLedgerHashes validates the generated prefork ledger hashes
func (t *HardforkTest) ValidatePreforkLedgerHashes(
	latestNonEmptyBlock client.BlockData,
	genesisEpochStaking string,
	genesisEpochNext string,
	latestSnarkedHashPerEpoch map[int]string,
	preforkHashesFile string,
) error {
	// Calculate slot_tx_end_epoch
	// 48 as specififed by mina-local-network.sh
	slotTxEndEpoch := latestNonEmptyBlock.Slot / 48

	// Find expected staking and next hashes
	expectedStakingHash, err := t.FindStakingHash(slotTxEndEpoch, genesisEpochStaking, genesisEpochNext, latestSnarkedHashPerEpoch)
	if err != nil {
		return fmt.Errorf("failed to find staking hash: %w", err)
	}

	expectedNextHash, err := t.FindStakingHash(slotTxEndEpoch+1, genesisEpochStaking, genesisEpochNext, latestSnarkedHashPerEpoch)
	if err != nil {
		return fmt.Errorf("failed to find next hash: %w", err)
	}

	// Read prefork hashes from file
	preforkHashesData, err := os.ReadFile(preforkHashesFile)
	if err != nil {
		return fmt.Errorf("failed to read prefork hashes file: %w", err)
	}

	preforkHashesJson := string(preforkHashesData)

	// Validate field values
	if err := validateStringField(preforkHashesJson, "epoch_data.staking.hash", expectedStakingHash); err != nil {
		return err
	}
	if err := validateStringField(preforkHashesJson, "epoch_data.next.hash", expectedNextHash); err != nil {
		return err
	}
	if err := validateStringField(preforkHashesJson, "ledger.hash", latestNonEmptyBlock.StagedHash); err != nil {
		return err
	}

	ledger_fields := []string{"hash", "s3_data_hash"}

	// Validate object structure - ensure only expected fields are present
	if err := t.validateObjectFields(preforkHashesJson, "epoch_data.staking", ledger_fields); err != nil {
		return err
	}
	if err := t.validateObjectFields(preforkHashesJson, "epoch_data.next", ledger_fields); err != nil {
		return err
	}
	if err := t.validateObjectFields(preforkHashesJson, "ledger", ledger_fields); err != nil {
		return err
	}
	if err := t.validateObjectFields(preforkHashesJson, "epoch_data", []string{"staking", "next"}); err != nil {
		return err
	}

	// Validate root object contains only expected top-level fields
	if err := t.validateRootObjectFields(preforkHashesJson, []string{"epoch_data", "ledger"}); err != nil {
		return err
	}

	t.Logger.Info("Prefork ledger hashes validated successfully")
	return nil
}

// ValidateForkConfigData validates the extracted fork config against expected values
func (t *HardforkTest) ValidateForkConfigData(latestNonEmptyBlock client.BlockData, forkConfigBytes []byte) error {
	forkConfigJson := string(forkConfigBytes)

	// Validate field values
	if err := validateIntField(forkConfigJson, "proof.fork.blockchain_length", latestNonEmptyBlock.BlockHeight); err != nil {
		return err
	}
	if err := validateIntField(forkConfigJson, "proof.fork.global_slot_since_genesis", latestNonEmptyBlock.Slot); err != nil {
		return err
	}
	if err := validateStringField(forkConfigJson, "proof.fork.state_hash", latestNonEmptyBlock.StateHash); err != nil {
		return err
	}
	if err := validateStringField(forkConfigJson, "epoch_data.next.seed", latestNonEmptyBlock.NextEpochSeed); err != nil {
		return err
	}
	if err := validateStringField(forkConfigJson, "epoch_data.staking.seed", latestNonEmptyBlock.CurEpochSeed); err != nil {
		return err
	}
	if err := validateStringField(forkConfigJson, "ledger.hash", latestNonEmptyBlock.StagedHash); err != nil {
		return err
	}
	if err := validateBoolField(forkConfigJson, "ledger.add_genesis_winner", false); err != nil {
		return err
	}

	// Validate object structure - ensure only expected fields are present
	if err := t.validateObjectFields(forkConfigJson, "proof.fork", []string{"blockchain_length", "global_slot_since_genesis", "state_hash"}); err != nil {
		return err
	}
	if err := t.validateObjectFields(forkConfigJson, "epoch_data.staking", []string{"seed", "accounts"}); err != nil {
		return err
	}
	if err := t.validateObjectFields(forkConfigJson, "epoch_data.next", []string{"seed", "accounts"}); err != nil {
		return err
	}
	if err := t.validateObjectFields(forkConfigJson, "ledger", []string{"hash", "accounts", "add_genesis_winner"}); err != nil {
		return err
	}
	if err := t.validateObjectFields(forkConfigJson, "epoch_data", []string{"staking", "next"}); err != nil {
		return err
	}
	if err := t.validateObjectFields(forkConfigJson, "proof", []string{"fork"}); err != nil {
		return err
	}

	// Validate root object contains only expected top-level fields
	if err := t.validateRootObjectFields(forkConfigJson, []string{"proof", "epoch_data", "ledger"}); err != nil {
		return err
	}

	t.Logger.Info("Fork config data validated successfully")
	return nil
}

// ValidateForkRuntimeConfig validates that the runtime config has correct fork data
func (t *HardforkTest) ValidateForkRuntimeConfig(latestNonEmptyBlock client.BlockData, configData []byte, forkGenesisTs, mainGenesisTs int64) error {
	// Calculate expected genesis slot
	expectedGenesisSlot := (forkGenesisTs - mainGenesisTs) / int64(t.Config.MainSlot)

	configJson := string(configData)

	// Validate field values
	if err := validateIntField(configJson, "proof.fork.blockchain_length", latestNonEmptyBlock.BlockHeight); err != nil {
		return err
	}
	if err := validateInt64Field(configJson, "proof.fork.global_slot_since_genesis", expectedGenesisSlot); err != nil {
		return err
	}
	if err := validateStringField(configJson, "proof.fork.state_hash", latestNonEmptyBlock.StateHash); err != nil {
		return err
	}
	if err := validateUnixTimestampField(configJson, "genesis.genesis_state_timestamp", forkGenesisTs); err != nil {
		return err
	}
	if err := t.validateObjectFields(configJson, "genesis", []string{"genesis_state_timestamp"}); err != nil {
		return err
	}

	// Validate object structure - ensure only expected fields are present
	if err := t.validateObjectFields(configJson, "proof.fork", []string{"blockchain_length", "global_slot_since_genesis", "state_hash"}); err != nil {
		return err
	}
	if err := t.validateObjectFields(configJson, "proof", []string{"fork"}); err != nil {
		return err
	}

	epochFields := []string{"hash", "s3_data_hash", "seed"}
	// Validate object structure - ensure only expected fields are present
	if err := t.validateObjectFields(configJson, "epoch_data.staking", epochFields); err != nil {
		return err
	}
	if err := t.validateObjectFields(configJson, "epoch_data.next", epochFields); err != nil {
		return err
	}
	if err := t.validateObjectFields(configJson, "epoch_data", []string{"staking", "next"}); err != nil {
		return err
	}

	// Validate ledger.add_genesis_winner is false
	if err := validateBoolField(configJson, "ledger.add_genesis_winner", false); err != nil {
		return err
	}

	ledgerFields := []string{"hash", "s3_data_hash", "add_genesis_winner"}
	if err := t.validateObjectFields(configJson, "ledger", ledgerFields); err != nil {
		return err
	}

	// Validate root object contains only expected top-level fields
	if err := t.validateRootObjectFields(configJson, []string{"proof", "epoch_data", "ledger", "genesis"}); err != nil {
		return err
	}
	t.Logger.Info("Config for the fork is correct, starting a new network")
	return nil
}
