//go:build integration

// Integration tests that hit the live public Mina buckets. They are excluded
// from the default `go test ./...` run via the `integration` build tag, so CI
// stays green and offline. Run explicitly with:
//
//	go test -tags integration ./internal/download/...
//
// Each test skips gracefully (t.Skip) if the network is unreachable.
package download

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/MinaProtocol/mina/src/app/bootstrap/internal/networks"
)

// TestArchiveDumpsAvailable verifies that, for both mainnet and devnet, at
// least one archive-dump object exists under the network's dump prefix.
func TestArchiveDumpsAvailable(t *testing.T) {
	for _, name := range []string{"mainnet", "devnet"} {
		name := name
		t.Run(name, func(t *testing.T) {
			net, err := networks.Lookup(name)
			if err != nil {
				t.Fatalf("Lookup(%q): %v", name, err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
			defer cancel()

			keys, err := ListGCSObjects(ctx, net.ArchiveDumpBucket, net.ArchiveDumpPrefix, 5)
			if err != nil {
				t.Skipf("could not list gs://%s/%s* (offline?): %v",
					net.ArchiveDumpBucket, net.ArchiveDumpPrefix, err)
			}
			if len(keys) == 0 {
				t.Fatalf("no archive dumps found under gs://%s/%s*",
					net.ArchiveDumpBucket, net.ArchiveDumpPrefix)
			}
			for _, k := range keys {
				if !strings.HasPrefix(k, net.ArchiveDumpPrefix) {
					t.Errorf("listed key %q does not start with prefix %q", k, net.ArchiveDumpPrefix)
				}
			}
			t.Logf("%s: found %d archive dump objects, e.g. %s", name, len(keys), keys[0])
		})
	}
}

// TestPrecomputedBlocksAvailable verifies that, for both mainnet and devnet,
// at least one precomputed block exists under the network's filename prefix.
func TestPrecomputedBlocksAvailable(t *testing.T) {
	for _, name := range []string{"mainnet", "devnet"} {
		name := name
		t.Run(name, func(t *testing.T) {
			net, err := networks.Lookup(name)
			if err != nil {
				t.Fatalf("Lookup(%q): %v", name, err)
			}
			ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
			defer cancel()

			keys, err := ListGCSObjects(ctx, net.PrecomputedBucket, net.PrecomputedFilenamePrefix, 5)
			if err != nil {
				t.Skipf("could not list gs://%s/%s* (offline?): %v",
					net.PrecomputedBucket, net.PrecomputedFilenamePrefix, err)
			}
			if len(keys) == 0 {
				t.Fatalf("no precomputed blocks found under gs://%s/%s*",
					net.PrecomputedBucket, net.PrecomputedFilenamePrefix)
			}
			t.Logf("%s: found precomputed blocks, e.g. %s", name, keys[0])
		})
	}
}
