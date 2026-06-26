package cmd

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/spf13/cobra"

	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/download"
	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/networks"
)

var (
	precomputedRange string
	precomputedOut   string
)

// Hardcoded safety cap: refuse to fetch more than this many blocks in one
// invocation. Operators who genuinely need more should run the tool in
// multiple chunks. The cap exists to prevent a typo from triggering tens of
// thousands of HTTP requests against the public bucket.
const maxBlocksPerInvocation = 50_000

// When --range END is omitted, the tool walks heights upward until it sees
// this many consecutive missing heights and assumes it's past chain tip.
// Mina has empty slots so the value has to be comfortably higher than the
// expected longest gap; 1000 slots ≈ 3 hours of slots, well beyond any
// realistic skip.
const openEndedMissThreshold = 1000

var precomputedCmd = &cobra.Command{
	Use:   "precomputed",
	Short: "Fetch precomputed blocks for archive backfill",
	Long: `Downloads precomputed block JSON files from the Mina Foundation's
public GCS bucket (mina_network_block_data) for a height range, used to
backfill missing blocks in an archive node's database.

Precomputed block filenames embed the network name, block height, and
state hash, e.g. mainnet-50000-3NLfKanQ53X2MRKx5ZRvb9nVCEB9eJpcnssGCTpT3J1cojhB5M19.json.

Range formats:
  --range 50000                single block at height 50000
  --range 50000-51000          explicit range, inclusive on both ends
  --range 50000-               open-ended, from 50000 to chain tip; stops
                               after enough consecutive missing heights to
                               conclude the tip is reached

After download, apply the blocks with the existing mina-archive-blocks
tool — that part remains a separate operator step.`,
	RunE: runPrecomputed,
}

func init() {
	precomputedCmd.Flags().StringVar(&precomputedRange, "range", "", "Height range, e.g. 50000-51000 (inclusive). Single height (50000) or open-ended (50000-) also accepted. Required.")
	precomputedCmd.Flags().StringVar(&precomputedOut, "out", "./blocks", "Directory to write the downloaded block files.")
}

func runPrecomputed(_ *cobra.Command, _ []string) error {
	if precomputedRange == "" {
		return errors.New("--range is required, e.g. --range 50000-51000 or --range 50000- (open-ended)")
	}
	start, end, openEnded, err := parseRange(precomputedRange)
	if err != nil {
		return err
	}
	if !openEnded && end-start+1 > maxBlocksPerInvocation {
		return fmt.Errorf("range %d-%d covers %d blocks, exceeds the %d-block safety cap. "+
			"Split into smaller ranges and re-run", start, end, end-start+1, maxBlocksPerInvocation)
	}

	net, err := networks.Lookup(network)
	if err != nil {
		return err
	}

	if err := os.MkdirAll(precomputedOut, 0o755); err != nil {
		return err
	}

	ctx := context.Background()

	// Per-height prefix lookups. The bucket holds 500k+ mainnet blocks; listing
	// the whole `mainnet-` prefix takes minutes. By prefixing each query with
	// the specific block height we get one HTTP roundtrip per height (each
	// returns 0-N keys, usually 1 canonical block).
	wanted, err := discoverBlocks(ctx, net, start, end, openEnded)
	if err != nil {
		return err
	}
	slog.Info("found blocks in range", "count", len(wanted), "range_start", start, "open_ended", openEnded)

	if _, err := downloadBlocks(ctx, net, wanted, precomputedOut); err != nil {
		return err
	}

	fmt.Fprintf(os.Stdout, "Downloaded %d precomputed blocks to %s\n", len(wanted), precomputedOut)
	return nil
}

// downloadBlocks fetches each block key from the network's precomputed bucket
// into outDir and returns the local file paths in the same order.
func downloadBlocks(ctx context.Context, net networks.Network, keys []string, outDir string) ([]string, error) {
	paths := make([]string, 0, len(keys))
	for _, key := range keys {
		dst := filepath.Join(outDir, key)
		if err := download.GCSObject(ctx, net.PrecomputedBucket, key, dst); err != nil {
			return nil, fmt.Errorf("download %s: %w", key, err)
		}
		paths = append(paths, dst)
	}
	return paths, nil
}

func discoverBlocks(ctx context.Context, net networks.Network, start, end int, openEnded bool) ([]string, error) {
	var wanted []string
	consecutiveMisses := 0
	for h := start; openEnded || h <= end; h++ {
		prefix := fmt.Sprintf("%s%d-", net.PrecomputedFilenamePrefix, h)
		keys, err := download.ListGCSObjects(ctx, net.PrecomputedBucket, prefix, 0)
		if err != nil {
			return nil, fmt.Errorf("list height %d: %w", h, err)
		}
		hit := false
		for _, k := range keys {
			if strings.HasSuffix(k, ".json") {
				wanted = append(wanted, k)
				hit = true
			}
		}
		if openEnded {
			if hit {
				consecutiveMisses = 0
			} else {
				consecutiveMisses++
				if consecutiveMisses >= openEndedMissThreshold {
					slog.Info("hit consecutive-miss threshold, stopping",
						"last_height_checked", h, "threshold", openEndedMissThreshold)
					break
				}
			}
		}
		if len(wanted) >= maxBlocksPerInvocation {
			return nil, fmt.Errorf("hit %d-block safety cap while walking from %d (currently at height %d). "+
				"Re-run with a closed --range to fetch the rest", maxBlocksPerInvocation, start, h)
		}
	}
	return wanted, nil
}

// parseRange accepts:
//
//	"N"        single height — returns (N, N, false)
//	"N-"       open-ended    — returns (N, 0, true)
//	"N-M"      explicit      — returns (N, M, false)
func parseRange(s string) (start, end int, openEnded bool, err error) {
	if !strings.Contains(s, "-") {
		v, perr := strconv.Atoi(s)
		if perr != nil {
			return 0, 0, false, fmt.Errorf("range must be N, N-, or N-M; got %q", s)
		}
		return v, v, false, nil
	}
	parts := strings.SplitN(s, "-", 2)
	startV, perr := strconv.Atoi(parts[0])
	if perr != nil {
		return 0, 0, false, fmt.Errorf("range start must be an integer, got %q", parts[0])
	}
	if parts[1] == "" {
		return startV, 0, true, nil
	}
	endV, perr := strconv.Atoi(parts[1])
	if perr != nil {
		return 0, 0, false, fmt.Errorf("range end must be an integer, got %q", parts[1])
	}
	if endV < startV {
		return 0, 0, false, fmt.Errorf("range end (%d) is less than start (%d)", endV, startV)
	}
	return startV, endV, false, nil
}
