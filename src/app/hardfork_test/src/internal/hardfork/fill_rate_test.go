package hardfork

import (
	"testing"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

func TestExpectedPreForkFillUpperBound(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name                string
		numWhales           int
		activeStakePerWhale float64
		inactiveStakePortion float64
		numDormantWhales    int
	}{
		{
			name:                 "typical values",
			numWhales:            2,
			activeStakePerWhale:  11550000,
			inactiveStakePortion: 0.684,
			numDormantWhales:     1,
		},
		{
			name:                 "no whales",
			numWhales:            0,
			activeStakePerWhale:  11550000,
			inactiveStakePortion: 0.5,
			numDormantWhales:     1,
		},
		{
			name:                 "single whale",
			numWhales:            1,
			activeStakePerWhale:  11550000,
			inactiveStakePortion: 0.3,
			numDormantWhales:     1,
		},
		{
			name:                 "zero balance",
			numWhales:            2,
			activeStakePerWhale:  0,
			inactiveStakePortion: 0.0,
			numDormantWhales:     1,
		},
		{
			name:                 "many whales",
			numWhales:            10,
			activeStakePerWhale:  11550000,
			inactiveStakePortion: 0.9,
			numDormantWhales:     5,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ht := &HardforkTest{
				Config: &config.Config{
					NumWhales:           tt.numWhales,
					ActiveStakePerWhale: tt.activeStakePerWhale,
					InactiveStakePortion: tt.inactiveStakePortion,
					NumDormantWhales:    tt.numDormantWhales,
				},
			}
			result := ht.expectedPreForkFillUpperBound()
			if result < 0 || result > 1.0 {
				t.Errorf("expectedPreForkFillUpperBound() = %f, want in [0,1]", result)
			}
		})
	}
}
