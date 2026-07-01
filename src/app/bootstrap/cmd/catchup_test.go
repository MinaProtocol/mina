package cmd

import "testing"

func TestCatchupBounds(t *testing.T) {
	tests := []struct {
		name          string
		maxHeight     int
		fromOverride  int
		toOverride    int
		wantStart     int
		wantEnd       int
		wantOpenEnded bool
		wantErr       bool
	}{
		{
			name:          "default open-ended from db tip",
			maxHeight:     12345,
			wantStart:     12346,
			wantOpenEnded: true,
		},
		{
			name:          "empty db starts at genesis height 1",
			maxHeight:     0,
			wantStart:     1,
			wantOpenEnded: true,
		},
		{
			name:          "from-height override wins over db tip",
			maxHeight:     12345,
			fromOverride:  500,
			wantStart:     500,
			wantOpenEnded: true,
		},
		{
			name:       "closed range with to-height",
			maxHeight:  100,
			toOverride: 150,
			wantStart:  101,
			wantEnd:    150,
		},
		{
			name:         "from and to both set",
			fromOverride: 200,
			toOverride:   250,
			wantStart:    200,
			wantEnd:      250,
		},
		{
			name:       "to-height below start errors",
			maxHeight:  300,
			toOverride: 100,
			wantErr:    true,
		},
		{
			name:       "range over safety cap errors",
			maxHeight:  0,
			toOverride: maxBlocksPerInvocation + 5,
			wantErr:    true,
		},
		{
			name:         "range exactly at safety cap ok",
			fromOverride: 1,
			toOverride:   maxBlocksPerInvocation,
			wantStart:    1,
			wantEnd:      maxBlocksPerInvocation,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			start, end, openEnded, err := catchupBounds(tt.maxHeight, tt.fromOverride, tt.toOverride)
			if (err != nil) != tt.wantErr {
				t.Fatalf("catchupBounds err = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.wantErr {
				return
			}
			if start != tt.wantStart {
				t.Errorf("start = %d, want %d", start, tt.wantStart)
			}
			if end != tt.wantEnd {
				t.Errorf("end = %d, want %d", end, tt.wantEnd)
			}
			if openEnded != tt.wantOpenEnded {
				t.Errorf("openEnded = %v, want %v", openEnded, tt.wantOpenEnded)
			}
		})
	}
}
