// Package networks holds the bucket paths and naming conventions for the
// Mina Foundation's public artifact buckets.
//
// Sources verified against live buckets as of 2026-05-13:
//   - Archive dumps: GCS mina-archive-dumps (matches example.*.env in Rosetta compose)
//   - Precomputed blocks: GCS mina_network_block_data (the live, listable source;
//     the S3 URL in example.*.env points at a non-existent bucket — likely
//     stale config)
package networks

import (
	"fmt"
	"path"
	"strconv"
	"strings"
)

type Network struct {
	Name string

	// Archive dumps: GCS, public-read.
	ArchiveDumpBucket string // e.g. "mina-archive-dumps"
	ArchiveDumpPrefix string // e.g. "mainnet-archive-dump"

	// Precomputed blocks: GCS, public-read.
	// Filenames live flat at bucket root: "<prefix><height>-<statehash>.json"
	PrecomputedBucket         string // e.g. "mina_network_block_data"
	PrecomputedFilenamePrefix string // e.g. "mainnet-"
}

var registry = map[string]Network{
	"mainnet": {
		Name:                      "mainnet",
		ArchiveDumpBucket:         "mina-archive-dumps",
		ArchiveDumpPrefix:         "mainnet-archive-dump",
		PrecomputedBucket:         "mina_network_block_data",
		PrecomputedFilenamePrefix: "mainnet-",
	},
	"devnet": {
		Name:                      "devnet",
		ArchiveDumpBucket:         "mina-archive-dumps",
		ArchiveDumpPrefix:         "devnet-archive-dump",
		PrecomputedBucket:         "mina_network_block_data",
		PrecomputedFilenamePrefix: "devnet-",
	},
	// mesa targets the "hetzner-pre-mesa-1" reference network, whose dumps and
	// precomputed blocks use the post-hardfork (version 4) block format. The
	// public mainnet/devnet block bucket still serves version 3, so this is the
	// network used to exercise the V4 archive toolchain (e.g. the catchup
	// integration test). It is a frozen test net (~2148 blocks).
	"mesa": {
		Name:                      "mesa",
		ArchiveDumpBucket:         "mina-archive-dumps",
		ArchiveDumpPrefix:         "hetzner-pre-mesa-1-archive-dump",
		PrecomputedBucket:         "mesa-hf-precomputed-blocks",
		PrecomputedFilenamePrefix: "hetzner-pre-mesa-1-",
	},
}

func Lookup(name string) (Network, error) {
	n, ok := registry[name]
	if !ok {
		return Network{}, fmt.Errorf("unknown network %q (known: mainnet, devnet, mesa)", name)
	}
	return n, nil
}

// BlockHeight extracts the height embedded in a precomputed block filename of
// the form "<PrecomputedFilenamePrefix><height>-<statehash>.json", e.g.
// "mainnet-50000-3NLf...json" -> 50000. A leading directory path is ignored.
func (n Network) BlockHeight(filename string) (int, error) {
	base := path.Base(filename)
	rest, ok := strings.CutPrefix(base, n.PrecomputedFilenamePrefix)
	if !ok {
		return 0, fmt.Errorf("filename %q lacks expected %q prefix", base, n.PrecomputedFilenamePrefix)
	}
	heightStr, _, ok := strings.Cut(rest, "-")
	if !ok {
		return 0, fmt.Errorf("filename %q missing height-hash separator", base)
	}
	h, err := strconv.Atoi(heightStr)
	if err != nil {
		return 0, fmt.Errorf("parse height from %q: %w", base, err)
	}
	return h, nil
}
