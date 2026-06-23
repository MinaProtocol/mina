// Package networks holds the bucket paths and naming conventions for the
// Mina Foundation's public artifact buckets.
//
// Sources verified against live buckets as of 2026-05-13:
//   - Archive dumps: GCS mina-archive-dumps (matches example.*.env in Rosetta compose)
//   - Precomputed blocks: GCS mina_network_block_data (the live, listable source;
//     the S3 URL in example.*.env points at a non-existent bucket — likely
//     stale config)
package networks

import "fmt"

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
}

func Lookup(name string) (Network, error) {
	n, ok := registry[name]
	if !ok {
		return Network{}, fmt.Errorf("unknown network %q (known: mainnet, devnet)", name)
	}
	return n, nil
}
