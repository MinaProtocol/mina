package hardfork

import (
	"bytes"
	"fmt"
	"time"
)

// ForkConfigData holds the expected fork configuration data
type ForkConfigData struct {
	BlockchainLength int    `json:"blockchain_length"`
	GlobalSlot       int    `json:"global_slot_since_genesis"`
	StateHash        string `json:"state_hash"`
	NextSeed         string `json:"next_seed"`
	StakingSeed      string `json:"staking_seed"`
}

// ExtractForkConfig extracts the fork configuration from the network
func (t *HardforkTest) GetForkConfig(port int) ([]byte, error) {
	for attempt := 1; attempt <= t.Config.ForkConfigMaxRetries; attempt++ {
		forkConfig, err := t.Client.ForkConfig(port)
		if err != nil {
			t.Logger.Error("Failed to get fork config: %v", err)
			continue
		}
		forkConfigBytes := []byte(forkConfig.Raw)

		if !bytes.Equal(forkConfigBytes, []byte("null")) {
			t.Logger.Info("Successfully queried fork config on node port %d", port)
			return forkConfigBytes, nil
		}

		t.Logger.Info("Failed to fetch valid fork config (attempt %d/%d), retrying...", attempt, t.Config.ForkConfigMaxRetries)
		if attempt < t.Config.ForkConfigMaxRetries {
			time.Sleep(time.Duration(t.Config.ForkConfigRetryDelaySeconds) * time.Second)
		}
	}

	return nil, fmt.Errorf("failed to extract valid fork config after %d attempts", t.Config.ForkConfigMaxRetries)
}
