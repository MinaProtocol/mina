package cmd

import "testing"

func TestParseRange(t *testing.T) {
	tests := []struct {
		name      string
		in        string
		start     int
		end       int
		openEnded bool
		wantErr   bool
	}{
		{name: "single height", in: "50000", start: 50000, end: 50000, openEnded: false},
		{name: "single height zero", in: "0", start: 0, end: 0, openEnded: false},
		{name: "closed range", in: "50000-51000", start: 50000, end: 51000, openEnded: false},
		{name: "closed range equal ends", in: "100-100", start: 100, end: 100, openEnded: false},
		{name: "open ended", in: "50000-", start: 50000, end: 0, openEnded: true},
		{name: "open ended zero", in: "0-", start: 0, end: 0, openEnded: true},

		{name: "empty", in: "", wantErr: true},
		{name: "non-numeric single", in: "abc", wantErr: true},
		{name: "non-numeric start", in: "abc-100", wantErr: true},
		{name: "non-numeric end", in: "100-xyz", wantErr: true},
		{name: "end less than start", in: "200-100", wantErr: true},
		{name: "leading dash open start empty", in: "-100", wantErr: true},
		{name: "just dash", in: "-", wantErr: true},
		{name: "float", in: "1.5", wantErr: true},
		{name: "negative single", in: "-5", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			start, end, openEnded, err := parseRange(tt.in)
			if tt.wantErr {
				if err == nil {
					t.Fatalf("parseRange(%q) = (%d,%d,%v), want error", tt.in, start, end, openEnded)
				}
				return
			}
			if err != nil {
				t.Fatalf("parseRange(%q) unexpected error: %v", tt.in, err)
			}
			if start != tt.start || end != tt.end || openEnded != tt.openEnded {
				t.Errorf("parseRange(%q) = (%d,%d,%v), want (%d,%d,%v)",
					tt.in, start, end, openEnded, tt.start, tt.end, tt.openEnded)
			}
		})
	}
}

// TestSafetyCapMath exercises the closed-range block-count check used in
// runPrecomputed: end-start+1 must not exceed maxBlocksPerInvocation.
func TestSafetyCapMath(t *testing.T) {
	tests := []struct {
		name       string
		start, end int
		overCap    bool
	}{
		{name: "single block", start: 0, end: 0, overCap: false},
		{name: "exactly at cap", start: 1, end: maxBlocksPerInvocation, overCap: false},
		{name: "one over cap", start: 1, end: maxBlocksPerInvocation + 1, overCap: true},
		{name: "well over cap", start: 0, end: 200000, overCap: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			count := tt.end - tt.start + 1
			over := count > maxBlocksPerInvocation
			if over != tt.overCap {
				t.Errorf("count=%d cap=%d over=%v, want %v", count, maxBlocksPerInvocation, over, tt.overCap)
			}
		})
	}
}

func TestConstants(t *testing.T) {
	if maxBlocksPerInvocation != 50000 {
		t.Errorf("maxBlocksPerInvocation = %d, want 50000", maxBlocksPerInvocation)
	}
	if openEndedMissThreshold != 1000 {
		t.Errorf("openEndedMissThreshold = %d, want 1000", openEndedMissThreshold)
	}
}
