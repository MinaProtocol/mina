package pg

import (
	"reflect"
	"testing"
)

func TestTuningSettings(t *testing.T) {
	want := map[string]string{
		"max_connections":                "500",
		"max_locks_per_transaction":      "100",
		"max_pred_locks_per_relation":    "100",
		"max_pred_locks_per_transaction": "5000",
	}

	if len(TuningSettings) != len(want) {
		t.Errorf("TuningSettings has %d entries, want %d", len(TuningSettings), len(want))
	}
	for k, v := range want {
		got, ok := TuningSettings[k]
		if !ok {
			t.Errorf("TuningSettings missing key %q", k)
			continue
		}
		if got != v {
			t.Errorf("TuningSettings[%q] = %q, want %q", k, got, v)
		}
	}
	// Guard against accidental extra keys creeping in.
	for k := range TuningSettings {
		if _, ok := want[k]; !ok {
			t.Errorf("TuningSettings has unexpected key %q", k)
		}
	}
}

func TestParseMaxHeight(t *testing.T) {
	tests := []struct {
		name    string
		out     string
		want    int
		wantErr bool
	}{
		{name: "plain", out: "12345", want: 12345},
		{name: "trailing newline", out: "12345\n", want: 12345},
		{name: "surrounding whitespace", out: "  42 \n", want: 42},
		{name: "empty db coalesced to zero", out: "0\n", want: 0},
		{name: "empty output errors", out: "\n", wantErr: true},
		{name: "non-numeric errors", out: "(0 rows)\n", wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseMaxHeight(tt.out)
			if (err != nil) != tt.wantErr {
				t.Fatalf("parseMaxHeight(%q) err = %v, wantErr %v", tt.out, err, tt.wantErr)
			}
			if !tt.wantErr && got != tt.want {
				t.Errorf("parseMaxHeight(%q) = %d, want %d", tt.out, got, tt.want)
			}
		})
	}
}

func TestParseHeights(t *testing.T) {
	tests := []struct {
		name    string
		out     string
		want    []int
		wantErr bool
	}{
		{name: "empty result", out: "\n", want: nil},
		{name: "single", out: "100\n", want: []int{100}},
		{
			name: "multiple ascending with blank lines",
			out:  "100\n101\n\n102\n",
			want: []int{100, 101, 102},
		},
		{name: "non-numeric errors", out: "100\nfoo\n", wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := parseHeights(tt.out)
			if (err != nil) != tt.wantErr {
				t.Fatalf("parseHeights(%q) err = %v, wantErr %v", tt.out, err, tt.wantErr)
			}
			if !tt.wantErr && !reflect.DeepEqual(got, tt.want) {
				t.Errorf("parseHeights(%q) = %v, want %v", tt.out, got, tt.want)
			}
		})
	}
}
