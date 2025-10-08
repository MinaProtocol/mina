package config

import (
	"errors"
	"fmt"
)

var (
	ErrMissingMainMinaExe              = errors.New("missing main Mina executable path")
	ErrMissingMainRuntimeGenesisLedger = errors.New("missing main runtime genesis ledger executable path")
	ErrMissingForkMinaExe              = errors.New("missing fork Mina executable path")
	ErrMissingForkRuntimeGenesisLedger = errors.New("missing fork runtime genesis ledger executable path")

	// Errors related to file existence and permissions
	ErrFileNotExists = errors.New("file does not exist")
	ErrNotExecutable = errors.New("file is not executable")
)

// FileValidationError creates a formatted error message for file validation issues
func FileValidationError(filePath string, err error) error {
	return fmt.Errorf("validation error for %s: %w", filePath, err)
}
