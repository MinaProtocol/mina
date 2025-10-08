package config

import (
	"fmt"
	"os"
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

	// Best chain query configuration, number of slots
	BestChainQueryFrom int

	// Slot duration in seconds
	MainSlot int
	ForkSlot int

	// Delay before genesis slot in minutes
	MainDelay int
	ForkDelay int

	// Script directory path
	ScriptDir string

	// Shutdown timeout in minutes before forcing kill
	ShutdownTimeoutMinutes int

	// Timing configuration (in seconds)
	PollingIntervalSeconds        int // Interval for polling height checks
	ForkConfigRetryDelaySeconds   int // Delay between fork config fetch retries
	ForkConfigMaxRetries          int // Max number of retries for fork config fetch
	NoNewBlocksWaitSeconds        int // Wait time to verify no new blocks after chain end
	UserCommandCheckMaxIterations int // Max iterations to check for user commands in blocks
	ForkEarliestBlockMaxRetries   int // Max retries to wait for earliest block in fork network
	HTTPClientTimeoutSeconds      int // HTTP client timeout for GraphQL requests
}

// DefaultConfig returns the default configuration with values
// matching those in the original shell script
func DefaultConfig() *Config {
	return &Config{
		SlotTxEnd:                     30,
		SlotChainEnd:                  38, // SlotTxEnd + 8
		BestChainQueryFrom:            25,
		MainSlot:                      15,
		ForkSlot:                      15,
		MainDelay:                     5,
		ForkDelay:                     5,
		ScriptDir:                     "$PWD/scripts/hardfork",
		ShutdownTimeoutMinutes:        10,
		PollingIntervalSeconds:        5,
		ForkConfigRetryDelaySeconds:   60,
		ForkConfigMaxRetries:          15,
		NoNewBlocksWaitSeconds:        300, // 5 minutes
		UserCommandCheckMaxIterations: 10,
		ForkEarliestBlockMaxRetries:   10,
		HTTPClientTimeoutSeconds:      10,
	}
}

// Validate checks if the configuration is valid
func (c *Config) Validate() error {
	// Check if required paths are specified
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

	// Check if executables exist and have proper permissions
	if err := validateExecutable(c.MainMinaExe); err != nil {
		return FileValidationError(c.MainMinaExe, err)
	}
	if err := validateExecutable(c.MainRuntimeGenesisLedger); err != nil {
		return FileValidationError(c.MainRuntimeGenesisLedger, err)
	}
	if err := validateExecutable(c.ForkMinaExe); err != nil {
		return FileValidationError(c.ForkMinaExe, err)
	}
	if err := validateExecutable(c.ForkRuntimeGenesisLedger); err != nil {
		return FileValidationError(c.ForkRuntimeGenesisLedger, err)
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

// validateExecutable checks if a file exists and has executable permissions
func validateExecutable(path string) error {
	// Check if file exists
	info, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return ErrFileNotExists
		}
		return err
	}

	// Check if it's a regular file (not a directory)
	if info.IsDir() {
		return fmt.Errorf("path is a directory, not an executable file")
	}

	// Check executable permission - mode & 0111 is checking for any execution bit (user, group, or others)
	if info.Mode().Perm()&0111 == 0 {
		return ErrNotExecutable
	}

	return nil
}
