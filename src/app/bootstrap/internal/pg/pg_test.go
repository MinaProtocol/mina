package pg

import "testing"

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
