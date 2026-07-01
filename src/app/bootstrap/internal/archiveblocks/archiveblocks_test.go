package archiveblocks

import (
	"reflect"
	"testing"
)

func TestBatches(t *testing.T) {
	tests := []struct {
		name  string
		files []string
		size  int
		want  [][]string
	}{
		{
			name:  "empty input",
			files: nil,
			size:  3,
			want:  nil,
		},
		{
			name:  "single full batch",
			files: []string{"a", "b"},
			size:  3,
			want:  [][]string{{"a", "b"}},
		},
		{
			name:  "exact multiple",
			files: []string{"a", "b", "c", "d"},
			size:  2,
			want:  [][]string{{"a", "b"}, {"c", "d"}},
		},
		{
			name:  "trailing partial batch preserves order",
			files: []string{"a", "b", "c", "d", "e"},
			size:  2,
			want:  [][]string{{"a", "b"}, {"c", "d"}, {"e"}},
		},
		{
			name:  "non-positive size yields one batch",
			files: []string{"a", "b", "c"},
			size:  0,
			want:  [][]string{{"a", "b", "c"}},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := batches(tt.files, tt.size)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("batches(%v, %d) = %v, want %v", tt.files, tt.size, got, tt.want)
			}
		})
	}
}
