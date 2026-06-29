package hardfork

// TODO: wire this test in CI (e.g. buildkite unit test step)

import (
	"testing"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

func TestExpectedPreForkFillUpperBound(t *testing.T) {
	tests := []struct {
		name            string
		numWhales       int
		activeStake     float64
		dormantBalance  float64
		expectedUpper   float64
	}{
		{
			name:           "default 2 whales 11.5M each, 50M dormant",
			numWhales:      2,
			activeStake:    11500000.0,
			dormantBalance: 50000000.0,
			// expected fill = 0.291, + 0.10 = 0.391
			expectedUpper: 0.391,
		},
		{
			name:           "1 whale 11.5M, 50M dormant",
			numWhales:      1,
			activeStake:    11500000.0,
			dormantBalance: 50000000.0,
			// expected fill = 11.5/61.5 = 0.187, + 0.10 = 0.287
			expectedUpper: 0.287,
		},
		{
			name:           "no dormant whale (fill near 100%)",
			numWhales:      2,
			activeStake:    11500000.0,
			dormantBalance: 0,
			// expected fill = 0.75, + 0.10 = 0.85
			expectedUpper: 0.85,
		},
		{
			name:           "50M dormant, zero active (edge case)",
			numWhales:      0,
			activeStake:    11500000.0,
			dormantBalance: 50000000.0,
			// expected fill = 0, + 0.10 = 0.10
			expectedUpper: 0.10,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ht := &HardforkTest{
				Config: &config.Config{
					NumWhales:           tt.numWhales,
					ActiveStakePerWhale: tt.activeStake,
					DormantWhaleBalance: tt.dormantBalance,
				},
			}
			got := ht.expectedPreForkFillUpperBound()
			if got < tt.expectedUpper-0.01 || got > tt.expectedUpper+0.01 {
				t.Errorf("expectedPreForkFillUpperBound() = %.4f, want %.4f", got, tt.expectedUpper)
			}
		})
	}
}
