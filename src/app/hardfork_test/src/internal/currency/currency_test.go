package currency

import (
	"encoding/json"
	"testing"
)

func TestParseMinaToNanomina(t *testing.T) {
	t.Parallel()

	valid := []struct {
		in   string
		want uint64
	}{
		{"0.000000000", 0},
		{"11550000.000000000", 11_550_000_000_000_000},
		{"499.000000000", 499_000_000_000},
		{"0.000000001", 1},
		{"1", 1_000_000_000},
		{"65500.5", 65_500_500_000_000},
	}
	for _, tc := range valid {
		got, err := parseMinaToNanomina(tc.in)
		if err != nil {
			t.Errorf("parseMinaToNanomina(%q) errored: %v", tc.in, err)
		} else if got != tc.want {
			t.Errorf("parseMinaToNanomina(%q) = %d, want %d", tc.in, got, tc.want)
		}
	}

	invalid := []string{"", "abc", "1.0000000001", "-1.0", "1.2.3"}
	for _, in := range invalid {
		if _, err := parseMinaToNanomina(in); err == nil {
			t.Errorf("parseMinaToNanomina(%q) should have errored", in)
		}
	}
}

func TestNanominaUnmarshalJSON(t *testing.T) {
	t.Parallel()

	// A decimal-mina string unmarshals straight into nanomina.
	var n Nanomina
	if err := json.Unmarshal([]byte(`"65500.5"`), &n); err != nil {
		t.Fatalf("unmarshal valid amount errored: %v", err)
	}
	if n != 65_500_500_000_000 {
		t.Errorf("Nanomina = %d, want 65_500_500_000_000", n)
	}

	// A malformed amount surfaces as an error, not a zero value.
	if err := json.Unmarshal([]byte(`"1.2.3"`), &n); err == nil {
		t.Error("expected unmarshal to fail on a malformed amount string")
	}
	// A non-string amount is rejected too (the ledger encodes amounts as strings).
	if err := json.Unmarshal([]byte(`123`), &n); err == nil {
		t.Error("expected unmarshal to fail on a non-string amount")
	}
}
