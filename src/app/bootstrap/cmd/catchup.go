package cmd

import (
	"context"
	"fmt"
	"log/slog"
	"os"

	"github.com/spf13/cobra"

	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/archiveblocks"
	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/networks"
	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/pg"
)

var (
	catchupPgURI            string
	catchupOut              string
	catchupArchiveBlocksBin string
	catchupSkipApply        bool
	catchupFromHeight       int
	catchupToHeight         int
)

var catchupCmd = &cobra.Command{
	Use:   "catchup",
	Short: "Backfill an archive DB up to chain tip with precomputed blocks",
	Long: `Reads the highest block height already present in the target archive
database, then downloads (and, unless --skip-apply, applies) every precomputed
block from that height up to the chain tip from the Mina Foundation's public
GCS bucket.

This is the post-restore step for an operator who has just loaded an archive
dump (e.g. via 'mina-bootstrap archive restore'): the dump is hours old, so this
command fetches only the diff between the dump's tip and the current chain
tip and feeds it to mina-archive-blocks.

It intentionally does NOT chase missing-block gaps below the dump's tip — it
only grabs the forward diff. Use the missing-blocks guardian for gap repair.

By default the start height is (max height in DB) + 1 and the end is the chain
tip (discovered by walking heights until a long run of empty slots). Override
either with --from-height / --to-height for fine-grained control.`,
	RunE: runCatchup,
}

func init() {
	catchupCmd.Flags().StringVar(&catchupPgURI, "pg-uri", "", "Postgres URI of the archive DB to read height from and apply blocks to (postgres://user:pw@host:port/db). Required.")
	catchupCmd.Flags().StringVar(&catchupOut, "out", "./blocks", "Directory to write the downloaded block files.")
	catchupCmd.Flags().StringVar(&catchupArchiveBlocksBin, "archive-blocks-bin", "mina-archive-blocks", "Path to the mina-archive-blocks binary used to apply blocks.")
	catchupCmd.Flags().BoolVar(&catchupSkipApply, "skip-apply", false, "Download the diff only; skip the mina-archive-blocks apply step.")
	catchupCmd.Flags().IntVar(&catchupFromHeight, "from-height", 0, "Override the start height. Default: (max height in DB) + 1.")
	catchupCmd.Flags().IntVar(&catchupToHeight, "to-height", 0, "Override the end height (inclusive). Default: open-ended up to chain tip.")
}

func runCatchup(_ *cobra.Command, _ []string) error {
	if catchupPgURI == "" {
		return fmt.Errorf("--pg-uri is required")
	}

	net, err := networks.Lookup(network)
	if err != nil {
		return err
	}

	ctx := context.Background()

	maxHeight := catchupFromHeight - 1
	if catchupFromHeight <= 0 {
		maxHeight, err = pg.MaxBlockHeight(ctx, catchupPgURI)
		if err != nil {
			return fmt.Errorf("read max block height: %w", err)
		}
		slog.Info("current archive DB tip", "max_height", maxHeight)
	}

	start, end, openEnded, err := catchupBounds(maxHeight, catchupFromHeight, catchupToHeight)
	if err != nil {
		return err
	}

	slog.Info("catching up", "network", net.Name, "from_height", start, "open_ended", openEnded, "to_height", end)

	wanted, err := discoverBlocks(ctx, net, start, end, openEnded)
	if err != nil {
		return err
	}
	if len(wanted) == 0 {
		fmt.Fprintf(os.Stdout, "Archive DB already at chain tip (no blocks at or above height %d). Nothing to do.\n", start)
		return nil
	}
	slog.Info("found blocks to backfill", "count", len(wanted), "from_height", start)

	if err := os.MkdirAll(catchupOut, 0o755); err != nil {
		return err
	}

	paths, err := downloadBlocks(ctx, net, wanted, catchupOut)
	if err != nil {
		return err
	}

	if catchupSkipApply {
		fmt.Fprintf(os.Stdout, "Downloaded %d precomputed blocks to %s. Skipping apply (--skip-apply).\n", len(paths), catchupOut)
		return nil
	}

	if err := archiveblocks.Apply(ctx, catchupArchiveBlocksBin, catchupPgURI, paths); err != nil {
		return fmt.Errorf("apply blocks: %w", err)
	}

	fmt.Fprintf(os.Stdout, "Catchup complete: backfilled %d blocks into the archive DB.\n", len(paths))
	return nil
}

// catchupBounds derives the precomputed-block discovery range from the archive
// DB's current max height and optional --from-height / --to-height overrides.
//
//   - start defaults to maxHeight+1 (the first height not yet in the DB).
//   - end is open-ended (walk to chain tip) unless toOverride is set.
//
// It returns an error for a closed range that is empty (end < start) or that
// exceeds the per-invocation safety cap.
func catchupBounds(maxHeight, fromOverride, toOverride int) (start, end int, openEnded bool, err error) {
	start = fromOverride
	if start <= 0 {
		start = maxHeight + 1
	}
	if start < 1 {
		start = 1
	}
	end = toOverride
	openEnded = toOverride <= 0
	if !openEnded {
		if end < start {
			return start, end, false, fmt.Errorf("--to-height %d is below the start height %d; the DB is already past it", end, start)
		}
		if end-start+1 > maxBlocksPerInvocation {
			return start, end, false, fmt.Errorf("range %d-%d covers %d blocks, exceeds the %d-block safety cap; re-run with a narrower --to-height",
				start, end, end-start+1, maxBlocksPerInvocation)
		}
	}
	return start, end, openEnded, nil
}
