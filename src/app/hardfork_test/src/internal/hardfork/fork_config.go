package hardfork

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
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
func (t *HardforkTest) ExtractForkConfig(port int, forkConfigPath string) ([]byte, error) {
	for attempt := 1; attempt <= t.Config.ForkConfigMaxRetries; attempt++ {
		forkConfig, err := t.Client.GetForkConfig(port)
		if err != nil {
			return nil, fmt.Errorf("failed to get fork config: %w", err)
		}
		forkConfigBytes := []byte(forkConfig.Raw)

		// Write fork config to file
		err = os.WriteFile(forkConfigPath, forkConfigBytes, 0644)
		if err != nil {
			return nil, fmt.Errorf("failed to write fork config: %w", err)
		}

		if len(forkConfigBytes) > 4 && string(forkConfigBytes[:4]) != "null" {
			return forkConfigBytes, nil
		}

		t.Logger.Info("Failed to fetch valid fork config (attempt %d/%d), retrying...", attempt, t.Config.ForkConfigMaxRetries)
		if attempt < t.Config.ForkConfigMaxRetries {
			time.Sleep(time.Duration(t.Config.ForkConfigRetryDelaySeconds) * time.Second)
		}
	}

	return nil, fmt.Errorf("failed to extract valid fork config after %d attempts", t.Config.ForkConfigMaxRetries)
}

// CreateRuntimeConfig creates the runtime configuration for the fork
func (t *HardforkTest) CreateRuntimeConfig(forkGenesisTimestamp, forkConfigPath, configFile, baseConfigFile, forkHashesFile string) ([]byte, error) {
	cmd := exec.Command(filepath.Join(t.ScriptDir, "create_runtime_config.sh"))
	cmd.Env = append(os.Environ(),
		"GENESIS_TIMESTAMP="+forkGenesisTimestamp,
		"FORKING_FROM_CONFIG_JSON="+baseConfigFile,
		"SECONDS_PER_SLOT="+strconv.Itoa(t.Config.MainSlot),
		"FORK_CONFIG_JSON="+forkConfigPath,
		"LEDGER_HASHES_JSON="+forkHashesFile,
	)

	// Redirect stderr to main process stderr
	cmd.Stderr = os.Stderr

	configOutput, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("failed to create runtime config: %w", err)
	}

	// Write config to file
	err = os.WriteFile(configFile, configOutput, 0644)
	if err != nil {
		return configOutput, fmt.Errorf("failed to write config.json: %w", err)
	}

	return configOutput, nil
}
