// Package archiveblocks shells out to the existing mina-archive-blocks
// binary to ingest precomputed block JSON files into an archive database.
//
// mina-archive-blocks runs update_chain_status per block and requires each
// block's parent to already be present, so callers must pass files in
// ascending height order.
package archiveblocks

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"os/exec"
)

// applyBatchSize bounds how many file paths are handed to a single
// mina-archive-blocks invocation, keeping the argument list well under
// ARG_MAX when backfilling large gaps. Files are applied batch-by-batch in
// the order given, so chain-status ordering is preserved across batches.
const applyBatchSize = 500

// Apply ingests the given precomputed block files into the archive DB at
// archiveURI by invoking `bin --precomputed --archive-uri <uri> <files...>`.
// files must be ordered by ascending block height.
func Apply(ctx context.Context, bin, archiveURI string, files []string) error {
	if len(files) == 0 {
		return nil
	}
	start := 0
	for _, b := range batches(files, applyBatchSize) {
		args := append([]string{"--precomputed", "--archive-uri", archiveURI}, b...)
		slog.Info("applying precomputed blocks",
			"bin", bin, "batch_start", start, "batch_size", len(b))
		cmd := exec.CommandContext(ctx, bin, args...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("%s (batch starting at file %d): %w", bin, start, err)
		}
		start += len(b)
	}
	return nil
}

// batches splits files into consecutive chunks of at most size, preserving
// order. A non-positive size yields a single batch containing everything.
func batches(files []string, size int) [][]string {
	if size <= 0 {
		return [][]string{files}
	}
	var out [][]string
	for i := 0; i < len(files); i += size {
		end := i + size
		if end > len(files) {
			end = len(files)
		}
		out = append(out, files[i:end])
	}
	return out
}
