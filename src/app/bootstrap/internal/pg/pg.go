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
	"strconv"
	"strings"
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

// MaxBlockHeight returns the highest height present in the archive DB's
// `blocks` table, or 0 when the table is empty. It is used to work out which
// precomputed blocks still need to be backfilled after a dump restore.
func MaxBlockHeight(ctx context.Context, uri string) (int, error) {
	out, err := query(ctx, uri, "SELECT COALESCE(MAX(height), 0) FROM blocks")
	if err != nil {
		return 0, err
	}
	return parseMaxHeight(out)
}

// parseMaxHeight parses the raw stdout of the MAX(height) query into an int.
func parseMaxHeight(out string) (int, error) {
	s := strings.TrimSpace(out)
	h, err := strconv.Atoi(s)
	if err != nil {
		return 0, fmt.Errorf("parse max block height %q: %w", s, err)
	}
	return h, nil
}

// HeightsBetween returns the distinct block heights present in [lo, hi]
// (inclusive), ascending. Used to verify a catchup left no gap.
func HeightsBetween(ctx context.Context, uri string, lo, hi int) ([]int, error) {
	out, err := query(ctx, uri, fmt.Sprintf(
		"SELECT DISTINCT height FROM blocks WHERE height BETWEEN %d AND %d ORDER BY height", lo, hi))
	if err != nil {
		return nil, err
	}
	return parseHeights(out)
}

// parseHeights parses newline-separated integer heights from psql -tA output.
func parseHeights(out string) ([]int, error) {
	var heights []int
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		h, err := strconv.Atoi(line)
		if err != nil {
			return nil, fmt.Errorf("parse height %q: %w", line, err)
		}
		heights = append(heights, h)
	}
	return heights, nil
}

// query runs a single SQL statement with psql in tuples-only, unaligned mode
// (-tA) and returns its stdout. Stderr is streamed through so psql connection
// errors stay visible.
func query(ctx context.Context, uri, sql string) (string, error) {
	cmd := exec.CommandContext(ctx, "psql", uri, "-tAc", sql)
	cmd.Stderr = os.Stderr
	slog.Debug("exec", "cmd", "psql", "sql", sql)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("psql query: %w", err)
	}
	return string(out), nil
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
