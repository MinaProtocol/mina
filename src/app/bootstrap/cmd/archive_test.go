package cmd

import "testing"

func TestDumpTarballName(t *testing.T) {
	tests := []struct {
		name   string
		prefix string
		date   string
		hour   string
		want   string
	}{
		{
			name:   "mainnet midnight",
			prefix: "mainnet-archive-dump",
			date:   "2026-06-23",
			hour:   "0000",
			want:   "mainnet-archive-dump-2026-06-23_0000.sql.tar.gz",
		},
		{
			name:   "devnet noon",
			prefix: "devnet-archive-dump",
			date:   "2026-01-02",
			hour:   "1200",
			want:   "devnet-archive-dump-2026-01-02_1200.sql.tar.gz",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := dumpTarballName(tt.prefix, tt.date, tt.hour)
			if got != tt.want {
				t.Errorf("dumpTarballName(%q,%q,%q) = %q, want %q",
					tt.prefix, tt.date, tt.hour, got, tt.want)
			}
		})
	}
}

func TestValidateHour(t *testing.T) {
	tests := []struct {
		name    string
		hour    string
		wantErr bool
	}{
		{name: "midnight", hour: "0000", wantErr: false},
		{name: "noon", hour: "1200", wantErr: false},
		{name: "late", hour: "2359", wantErr: false},
		{name: "non-digit but 4 chars accepted", hour: "abcd", wantErr: false},
		{name: "too short", hour: "000", wantErr: true},
		{name: "too long", hour: "00000", wantErr: true},
		{name: "empty", hour: "", wantErr: true},
		{name: "single", hour: "0", wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateHour(tt.hour)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateHour(%q) error = %v, wantErr %v", tt.hour, err, tt.wantErr)
			}
		})
	}
}
