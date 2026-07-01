//go:build integration

// Integration test exercising the real psql-backed DB setup path. Excluded
// from the default `go test ./...` run via the `integration` build tag.
//
// Requires a reachable Postgres and the postgresql-client (psql) on PATH.
// Provide the connection string via BOOTSTRAP_TEST_PG_URI, e.g.:
//
//	BOOTSTRAP_TEST_PG_URI=postgres://mina:pw@localhost:5432/archive \
//	  go test -tags integration ./internal/pg/...
//
// The test skips (t.Skip) when the env var is unset.
package pg

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func testPgURI(t *testing.T) string {
	t.Helper()
	uri := os.Getenv("BOOTSTRAP_TEST_PG_URI")
	if uri == "" {
		t.Skip("BOOTSTRAP_TEST_PG_URI not set; skipping live Postgres setup test")
	}
	return uri
}

// TestApplyTuningAndLoadSQL applies the tuning settings and loads a tiny SQL
// file, asserting both succeed against a live Postgres.
func TestApplyTuningAndLoadSQL(t *testing.T) {
	uri := testPgURI(t)

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	if err := ApplyTuning(ctx, uri); err != nil {
		t.Fatalf("ApplyTuning: %v", err)
	}

	dir := t.TempDir()
	sqlPath := filepath.Join(dir, "tiny.sql")
	const sql = `
CREATE TABLE IF NOT EXISTS bootstrap_test_marker (id int PRIMARY KEY);
INSERT INTO bootstrap_test_marker (id) VALUES (1) ON CONFLICT DO NOTHING;
DROP TABLE bootstrap_test_marker;
`
	if err := os.WriteFile(sqlPath, []byte(sql), 0o644); err != nil {
		t.Fatalf("write sql: %v", err)
	}

	if err := LoadSQLFile(ctx, uri, sqlPath); err != nil {
		t.Fatalf("LoadSQLFile: %v", err)
	}
}
