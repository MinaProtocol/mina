package config

import (
	"os"
	"path/filepath"
	"testing"
)

// validTestConfig returns a config whose path checks pass, so Validate()
// reaches the unstaking-specific checks
func validTestConfig(t *testing.T) *Config {
	t.Helper()

	dir := t.TempDir()
	exe := filepath.Join(dir, "exe")
	if err := os.WriteFile(exe, []byte("#!/bin/sh\n"), 0755); err != nil {
		t.Fatal(err)
	}

	cfg := DefaultConfig()
	cfg.MainMinaExe = exe
	cfg.MainRuntimeGenesisLedger = exe
	cfg.ForkMinaExe = exe
	cfg.ForkRuntimeGenesisLedger = exe
	cfg.ScriptDir = dir
	cfg.Root = dir
	cfg.ForkMethods = ForkMethodSet{Legacy: {}}
	return cfg
}

func TestValidateUnstaking(t *testing.T) {
	t.Parallel()

	// The CI configuration: unstaking, legacy only
	cfg := validTestConfig(t)
	cfg.UnstakingTest = true
	if err := cfg.Validate(); err != nil {
		t.Errorf("expected valid unstaking config, got: %v", err)
	}

	// Unstaking off: fork method mix is unconstrained
	cfg = validTestConfig(t)
	cfg.ForkMethods = ForkMethodSet{Legacy: {}, Advanced: {}, Auto: {}}
	if err := cfg.Validate(); err != nil {
		t.Errorf("expected valid non-unstaking config, got: %v", err)
	}

	// Unstaking requires at least one lazy whale
	cfg = validTestConfig(t)
	cfg.UnstakingTest = true
	cfg.NumLazyWhales = 0
	if err := cfg.Validate(); err == nil {
		t.Error("expected error for unstaking test with 0 lazy whales")
	}

	// Unstaking requires the legacy fork method only
	cfg = validTestConfig(t)
	cfg.UnstakingTest = true
	cfg.ForkMethods = ForkMethodSet{Legacy: {}, Advanced: {}}
	if err := cfg.Validate(); err == nil {
		t.Error("expected error for unstaking test with mixed fork methods")
	}

	cfg = validTestConfig(t)
	cfg.UnstakingTest = true
	cfg.ForkMethods = ForkMethodSet{Advanced: {}}
	if err := cfg.Validate(); err == nil {
		t.Error("expected error for unstaking test with the advanced fork method")
	}
}
