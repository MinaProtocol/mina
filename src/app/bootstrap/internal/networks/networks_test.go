package networks

import "testing"

func TestLookupKnownNetworks(t *testing.T) {
	tests := []struct {
		name                      string
		archiveDumpBucket         string
		archiveDumpPrefix         string
		precomputedBucket         string
		precomputedFilenamePrefix string
	}{
		{
			name:                      "mainnet",
			archiveDumpBucket:         "mina-archive-dumps",
			archiveDumpPrefix:         "mainnet-archive-dump",
			precomputedBucket:         "mina_network_block_data",
			precomputedFilenamePrefix: "mainnet-",
		},
		{
			name:                      "devnet",
			archiveDumpBucket:         "mina-archive-dumps",
			archiveDumpPrefix:         "devnet-archive-dump",
			precomputedBucket:         "mina_network_block_data",
			precomputedFilenamePrefix: "devnet-",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			net, err := Lookup(tt.name)
			if err != nil {
				t.Fatalf("Lookup(%q) returned error: %v", tt.name, err)
			}
			if net.Name != tt.name {
				t.Errorf("Name = %q, want %q", net.Name, tt.name)
			}
			if net.ArchiveDumpBucket != tt.archiveDumpBucket {
				t.Errorf("ArchiveDumpBucket = %q, want %q", net.ArchiveDumpBucket, tt.archiveDumpBucket)
			}
			if net.ArchiveDumpPrefix != tt.archiveDumpPrefix {
				t.Errorf("ArchiveDumpPrefix = %q, want %q", net.ArchiveDumpPrefix, tt.archiveDumpPrefix)
			}
			if net.PrecomputedBucket != tt.precomputedBucket {
				t.Errorf("PrecomputedBucket = %q, want %q", net.PrecomputedBucket, tt.precomputedBucket)
			}
			if net.PrecomputedFilenamePrefix != tt.precomputedFilenamePrefix {
				t.Errorf("PrecomputedFilenamePrefix = %q, want %q", net.PrecomputedFilenamePrefix, tt.precomputedFilenamePrefix)
			}
		})
	}
}

func TestLookupUnknownNetwork(t *testing.T) {
	for _, name := range []string{"", "testnet", "MAINNET", "main", "berkeley"} {
		t.Run(name, func(t *testing.T) {
			net, err := Lookup(name)
			if err == nil {
				t.Fatalf("Lookup(%q) = %+v, want error", name, net)
			}
			if net != (Network{}) {
				t.Errorf("Lookup(%q) returned non-zero Network on error: %+v", name, net)
			}
		})
	}
}
