// Package currency holds the protocol's currency primitive shared by the
// GraphQL client and the genesis-ledger parser.
package currency

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// The protocol's fixed currency scale: 1 MINA = 10^9 nanomina.
// decimals is the same fact expressed as a fractional-digit count.
const (
	nanominasPerMina = 1_000_000_000
	decimals         = 9
)

// Mina is one MINA expressed in nanomina, so amounts can be written in mina
// units as e.g. 5 * currency.Mina — mirroring time.Second.
const Mina Nanomina = nanominasPerMina

// Nanomina is an integer nanomina amount (1 mina = 1e9 nanomina). Making it a
// distinct type lets currency values name their unit through the type instead
// of a field-name suffix.
//
// UnmarshalJSON expects the decimal-*mina* text the genesis ledger file uses
// (e.g. "11550000.000000000"); the daemon's GraphQL integer-nanomina scalars
// are read via gjson (.Uint()) at construction, not through this method, so the
// two encodings never collide.
type Nanomina uint64

func (n *Nanomina) UnmarshalJSON(b []byte) error {
	var s string
	if err := json.Unmarshal(b, &s); err != nil {
		return fmt.Errorf("currency amount must be a decimal mina string: %w", err)
	}
	v, err := parseMinaToNanomina(s)
	if err != nil {
		return err
	}
	*n = Nanomina(v)
	return nil
}

// parseMinaToNanomina parses a decimal *mina* amount as emitted by
// generate-mina-local-network-ledger.py (e.g. "11550000.000000000") into an
// integer *nanomina* count, exactly (no float rounding).
func parseMinaToNanomina(balance string) (uint64, error) {
	whole, frac, found := strings.Cut(balance, ".")
	if !found {
		frac = "0"
	}
	wholeN, err := strconv.ParseUint(whole, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid balance %q: %w", balance, err)
	}
	if len(frac) > decimals {
		return 0, fmt.Errorf("invalid balance %q: more than %d fractional digits", balance, decimals)
	}
	frac = frac + strings.Repeat("0", decimals-len(frac))
	fracN, err := strconv.ParseUint(frac, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("invalid balance %q: %w", balance, err)
	}
	return wholeN*nanominasPerMina + fracN, nil
}
