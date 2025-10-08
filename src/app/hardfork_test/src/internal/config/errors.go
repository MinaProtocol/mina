package config

import "errors"

var (
	ErrMissingMainMinaExe              = errors.New("missing main Mina executable path")
	ErrMissingMainRuntimeGenesisLedger = errors.New("missing main runtime genesis ledger executable path")
	ErrMissingForkMinaExe              = errors.New("missing fork Mina executable path")
	ErrMissingForkRuntimeGenesisLedger = errors.New("missing fork runtime genesis ledger executable path")
)
