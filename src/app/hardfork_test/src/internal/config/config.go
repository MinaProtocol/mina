package config

import (
	"time"
)

// Config represents the application configuration parameters
type Config struct {
	// Executable paths
	MainMinaExe              string
	MainRuntimeGenesisLedger string
	ForkMinaExe              string
	ForkRuntimeGenesisLedger string

	// Slot configuration
	SlotTxEnd    int
	SlotChainEnd int

	// Best chain query configuration
	BestChainQueryFrom int

	// Slot duration in seconds
	MainSlot int
	ForkSlot int

	// Delay before genesis slot in minutes
	MainDelay int
	ForkDelay int

	// Working directory
	WorkDir string

	// Test parameters
	TimeoutMinutes int
}

// DefaultConfig returns the default configuration with values
// matching those in the original shell script
func DefaultConfig() *Config {
	return &Config{
		SlotTxEnd:          30,
		SlotChainEnd:       38, // SlotTxEnd + 8
		BestChainQueryFrom: 25,
		MainSlot:           15,
		ForkSlot:           15,
		MainDelay:          20,
		ForkDelay:          10,
		WorkDir:            ".",
		TimeoutMinutes:     30,
	}
}

// Validate checks if the configuration is valid
func (c *Config) Validate() error {
	if c.MainMinaExe == "" {
		return ErrMissingMainMinaExe
	}
	if c.MainRuntimeGenesisLedger == "" {
		return ErrMissingMainRuntimeGenesisLedger
	}
	if c.ForkMinaExe == "" {
		return ErrMissingForkMinaExe
	}
	if c.ForkRuntimeGenesisLedger == "" {
		return ErrMissingForkRuntimeGenesisLedger
	}
	return nil
}

// CalculateTimestamps computes the UNIX timestamps for main and fork genesis
func (c *Config) CalculateTimestamps() (mainGenesisTs, forkGenesisTs int64) {
	now := time.Now().Unix()
	// Round to nearest minute
	nowRounded := now - (now % 60)

	// Calculate genesis timestamps as in the shell script
	mainGenesisTs = nowRounded + int64(c.MainDelay*60)
	forkGenesisTs = nowRounded + int64(c.ForkDelay*60)

	return mainGenesisTs, forkGenesisTs
}

// FormatTimestamp formats a UNIX timestamp into the format used by the shell script
func FormatTimestamp(unixTs int64) string {
	t := time.Unix(unixTs, 0).UTC()
	return t.Format("2006-01-02 15:04:05+00:00")
}
