package itn_orchestrator

import (
	"encoding/json"
	"sort"
	"time"
)

type WaitParams struct {
	Minutes int
	Slot    int
	Seconds int
}

type WaitAction struct{}

func (WaitAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params WaitParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	delay := time.Minute*time.Duration(params.Minutes) + time.Second*time.Duration(params.Seconds)
	if params.Slot > 0 {
		at := config.GenesisTimestamp.Add(time.Millisecond*time.Duration(config.SlotDurationMs)*time.Duration(params.Slot) + delay)
		delay = time.Until(at)
		if delay > 0 {
			time.Sleep(delay)
		}
	} else {
		time.Sleep(delay)
	}
	return nil
}

var _ Action = WaitAction{}

// NextPermutation generates the next permutation of the
// sortable collection x in lexical order.  It returns false
// if the permutations are exhausted.
//
// Knuth, Donald (2011), "Section 7.2.1.2: Generating All Permutations",
// The Art of Computer Programming, volume 4A.
func NextPermutation(x sort.Interface) bool {
	n := x.Len() - 1
	if n < 1 {
		return false
	}
	j := n - 1
	for ; !x.Less(j, j+1); j-- {
		if j == 0 {
			return false
		}
	}
	l := n
	for !x.Less(j, l) {
		l--
	}
	x.Swap(j, l)
	for k, l := j+1, n; k < l; {
		x.Swap(k, l)
		k++
		l--
	}
	return true
}

func filterLte(s []int, n int) []int {
	for len(s) > 0 && s[len(s)-1] > n {
		s = s[:len(s)-1]
	}
	return s
}

func filterGt(s []int, n int) []int {
	for len(s) > 0 && s[0] <= n {
		s = s[1:]
	}
	return s
}
