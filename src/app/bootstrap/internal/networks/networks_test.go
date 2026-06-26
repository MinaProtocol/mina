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

func TestBlockHeight(t *testing.T) {
	mainnet, _ := Lookup("mainnet")
	devnet, _ := Lookup("devnet")

	tests := []struct {
		name     string
		net      Network
		filename string
		want     int
		wantErr  bool
	}{
		{
			name:     "mainnet plain",
			net:      mainnet,
			filename: "mainnet-50000-3NLfKanQ53X2MRKx5ZRvb9nVCEB9eJpcnssGCTpT3J1cojhB5M19.json",
			want:     50000,
		},
		{
			name:     "devnet plain",
			net:      devnet,
			filename: "devnet-100-3NKabc.json",
			want:     100,
		},
		{
			name:     "leading directory ignored",
			net:      mainnet,
			filename: "./blocks/mainnet-1-3NKgenesis.json",
			want:     1,
		},
		{
			name:     "wrong network prefix errors",
			net:      mainnet,
			filename: "devnet-50000-3NLf.json",
			wantErr:  true,
		},
		{
			name:     "missing height-hash separator errors",
			net:      mainnet,
			filename: "mainnet-50000.json",
			wantErr:  true,
		},
		{
			name:     "non-numeric height errors",
			net:      mainnet,
			filename: "mainnet-abc-3NLf.json",
			wantErr:  true,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := tt.net.BlockHeight(tt.filename)
			if (err != nil) != tt.wantErr {
				t.Fatalf("BlockHeight(%q) err = %v, wantErr %v", tt.filename, err, tt.wantErr)
			}
			if !tt.wantErr && got != tt.want {
				t.Errorf("BlockHeight(%q) = %d, want %d", tt.filename, got, tt.want)
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
