//go:build integration

// End-to-end catchup test against a real, already-restored archive database
// and the live precomputed-blocks bucket. Excluded from the default
// `go test ./...` run via the `integration` build tag.
//
// It verifies the property the catchup command exists to guarantee: after
// backfilling, there is no gap between the archive DB's pre-catchup tip and
// the blocks pulled from the bucket — every expected block was inserted.
//
// Provide a connection string for whichever networks you want to exercise.
// The DB must already have an archive dump restored into it (e.g. via
// `mina-bootstrap archive restore`); this test only performs the forward catchup:
//
//	BOOTSTRAP_TEST_MAINNET_PG_URI=postgres://mina:pw@localhost:5432/archive \
//	BOOTSTRAP_TEST_DEVNET_PG_URI=postgres://mina:pw@localhost:5433/archive \
//	  go test -tags integration ./cmd/... -run TestCatchupNoGap -v
//
// Optional knobs:
//
//	BOOTSTRAP_TEST_CATCHUP_BLOCKS    bounded number of heights to backfill (default 25)
//	BOOTSTRAP_TEST_ARCHIVE_BLOCKS_BIN  path to mina-archive-blocks (default on PATH)
//
// The test skips any network whose URI env var is unset, and skips entirely
// when none are set. Requires psql and mina-archive-blocks on PATH.
package cmd

import (
	"context"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/archiveblocks"
	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/networks"
	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/pg"
)

func TestCatchupNoGap(t *testing.T) {
	cases := []struct {
		network string
		envVar  string
	}{
		{"mainnet", "BOOTSTRAP_TEST_MAINNET_PG_URI"},
		{"devnet", "BOOTSTRAP_TEST_DEVNET_PG_URI"},
	}

	ran := false
	for _, c := range cases {
		uri := os.Getenv(c.envVar)
		if uri == "" {
			continue
		}
		ran = true
		t.Run(c.network, func(t *testing.T) {
			runCatchupNoGap(t, c.network, uri)
		})
	}
	if !ran {
		t.Skip("set BOOTSTRAP_TEST_MAINNET_PG_URI and/or BOOTSTRAP_TEST_DEVNET_PG_URI to run")
	}
}

func runCatchupNoGap(t *testing.T, network, uri string) {
	t.Helper()

	net, err := networks.Lookup(network)
	if err != nil {
		t.Fatalf("Lookup(%q): %v", network, err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Minute)
	defer cancel()

	maxBefore, err := pg.MaxBlockHeight(ctx, uri)
	if err != nil {
		t.Fatalf("MaxBlockHeight: %v", err)
	}
	if maxBefore == 0 {
		t.Fatalf("DB has no blocks; restore an archive dump before running this test")
	}
	t.Logf("%s: DB tip before catchup = %d", network, maxBefore)

	// Bound the work: backfill only a small forward window so the test stays
	// tractable. The invariant (no gap, every expected block inserted) holds
	// for any window.
	nBlocks := envInt(t, "BOOTSTRAP_TEST_CATCHUP_BLOCKS", 25)
	start := maxBefore + 1
	end := maxBefore + nBlocks

	wanted, err := discoverBlocks(ctx, net, start, end, false)
	if err != nil {
		t.Fatalf("discoverBlocks(%d-%d): %v", start, end, err)
	}
	if len(wanted) == 0 {
		t.Skipf("no precomputed blocks in bucket for %s heights %d-%d; DB may already be at tip", network, start, end)
	}

	// Expected heights, derived from the discovered filenames.
	expected := map[int]bool{}
	for _, key := range wanted {
		h, err := net.BlockHeight(key)
		if err != nil {
			t.Fatalf("BlockHeight(%q): %v", key, err)
		}
		expected[h] = true
	}
	t.Logf("%s: discovered %d blocks spanning %d distinct heights in %d-%d",
		network, len(wanted), len(expected), start, end)

	outDir := t.TempDir()
	paths, err := downloadBlocks(ctx, net, wanted, outDir)
	if err != nil {
		t.Fatalf("downloadBlocks: %v", err)
	}

	bin := os.Getenv("BOOTSTRAP_TEST_ARCHIVE_BLOCKS_BIN")
	if bin == "" {
		bin = "mina-archive-blocks"
	}
	if err := archiveblocks.Apply(ctx, bin, uri, paths); err != nil {
		t.Fatalf("Apply: %v", err)
	}

	// Verify: every expected height is now present, and the chain is gap-free
	// from the pre-catchup tip through the highest backfilled height.
	maxAfter, err := pg.MaxBlockHeight(ctx, uri)
	if err != nil {
		t.Fatalf("MaxBlockHeight after: %v", err)
	}
	t.Logf("%s: DB tip after catchup = %d", network, maxAfter)

	present, err := pg.HeightsBetween(ctx, uri, start, maxAfter)
	if err != nil {
		t.Fatalf("HeightsBetween: %v", err)
	}
	presentSet := map[int]bool{}
	for _, h := range present {
		presentSet[h] = true
	}

	// (1) Every expected block was inserted.
	for h := range expected {
		if !presentSet[h] {
			t.Errorf("expected block at height %d was not inserted", h)
		}
	}

	// (2) No gap from the pre-catchup tip to the highest backfilled height.
	highest := maxBefore
	for h := range expected {
		if h > highest {
			highest = h
		}
	}
	for h := maxBefore + 1; h <= highest; h++ {
		if !presentSet[h] {
			t.Errorf("gap detected: height %d missing between DB tip %d and backfilled tip %d", h, maxBefore, highest)
		}
	}
}

func envInt(t *testing.T, name string, def int) int {
	t.Helper()
	v := os.Getenv(name)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		t.Fatalf("%s=%q is not an integer: %v", name, v, err)
	}
	return n
}
