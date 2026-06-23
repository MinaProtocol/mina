// Package pg wraps the small set of psql operations mina-bootstrap performs.
//
// We shell out to psql rather than using a native Go Postgres driver because
// (a) loading a multi-gigabyte SQL dump streams better via psql's -f than via
// any go-pg flavor and (b) the operator already needs postgresql-client
// installed for ongoing maintenance, so there's no extra dependency to ship.
package pg

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
)

// TuningSettings are the ALTER SYSTEM values applied before loading the
// archive dump. Mirrors the values the existing Rosetta docker-compose
// bootstrap service uses.
var TuningSettings = map[string]string{
	"max_connections":                "500",
	"max_locks_per_transaction":      "100",
	"max_pred_locks_per_relation":    "100",
	"max_pred_locks_per_transaction": "5000",
}

// ApplyTuning runs ALTER SYSTEM for each TuningSettings entry.
//
// Note: ALTER SYSTEM writes to postgresql.auto.conf and requires a Postgres
// restart to take effect. Most operators will restart the postgres container
// after bootstrap completes; see README.md.
func ApplyTuning(ctx context.Context, uri string) error {
	args := []string{uri}
	for k, v := range TuningSettings {
		args = append(args, "-c", fmt.Sprintf("ALTER SYSTEM SET %s = %s", k, v))
	}
	return run(ctx, "psql", args...)
}

// LoadSQLFile applies the contents of sqlPath to the database at uri.
func LoadSQLFile(ctx context.Context, uri, sqlPath string) error {
	slog.Info("loading sql dump", "path", sqlPath)
	return run(ctx, "psql", uri, "-f", sqlPath)
}

func run(ctx context.Context, name string, args ...string) error {
	cmd := exec.CommandContext(ctx, name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	slog.Debug("exec", "cmd", name, "args", args)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	return nil
}
