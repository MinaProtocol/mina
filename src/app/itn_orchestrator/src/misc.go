package itn_orchestrator

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"math/rand"
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

func (WaitAction) Name() string { return "wait" }

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

type JoinParams struct {
	Group1 []json.RawMessage
	Group2 []json.RawMessage
	Group3 []json.RawMessage
	Group4 []json.RawMessage
	Group5 []json.RawMessage
	Group6 []json.RawMessage
	Group7 []json.RawMessage
	Group8 []json.RawMessage
	Group9 []json.RawMessage
}

type JoinAction struct{}

func (JoinAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params JoinParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	iterate := func(group []json.RawMessage) {
		for _, n := range group {
			output("group", n, true, false)
		}
	}
	iterate(params.Group1)
	iterate(params.Group2)
	iterate(params.Group3)
	iterate(params.Group4)
	iterate(params.Group5)
	iterate(params.Group5)
	iterate(params.Group6)
	iterate(params.Group7)
	iterate(params.Group8)
	iterate(params.Group9)
	return nil
}

func (JoinAction) Name() string { return "join" }

var _ Action = JoinAction{}

type ExceptParams struct {
	Group  []NodeAddress
	Except []NodeAddress
}

type ExceptAction struct{}

func (ExceptAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params ExceptParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	exceptMap := map[NodeAddress]struct{}{}
	for _, e := range params.Except {
		exceptMap[e] = struct{}{}
	}
	for _, addr := range params.Group {
		if _, has := exceptMap[addr]; has {
			continue
		}
		output("group", addr, true, false)
	}
	return nil
}

func (ExceptAction) Name() string { return "except" }

var _ Action = ExceptAction{}

type SampleParams struct {
	Group  []NodeAddress
	Ratios []float64
}

type SampleAction struct{}

func (SampleAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params SampleParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	s := 0.0
	for _, r := range params.Ratios {
		if r < 0 || r > 1 {
			return errors.New("invalid ratios entry")
		}
		s += r
	}
	if s > 1 {
		return errors.New("ratios' sum > 1")
	}
	group := params.Group
	groupLen := len(group)
	rand.Shuffle(groupLen, func(i, j int) {
		group[i], group[j] = group[j], group[i]
	})
	for i, r := range params.Ratios {
		take := int(math.Round(r * float64(groupLen)))
		output(fmt.Sprintf("group%d", i+1), group[:take], false, false)
		group = group[take:]
	}
	output("rest", group, false, false)
	return nil
}

func (SampleAction) Name() string { return "sample" }

var _ Action = SampleAction{}

func selectNodes(tps, minTps float64, nodes []NodeAddress) (float64, []NodeAddress) {
	nodesF := math.Floor(tps / minTps)
	nodesMax := int(nodesF)
	if nodesMax >= len(nodes) {
		return tps / float64(len(nodes)), nodes
	}
	rand.Shuffle(len(nodes), func(i, j int) {
		nodes[i], nodes[j] = nodes[j], nodes[i]
	})
	return tps / nodesF, nodes[:nodesMax]
}

// TODO change API and remove this function
func formatMina(amount uint64) string {
	i, rem := amount/1e9, int(amount%1e9)
	is := fmt.Sprintf("%d", i)
	if rem == 0 {
		return is
	}
	s := []byte(".000000000")
	rs := fmt.Sprintf("%d", rem)
	copy(s[(10-len(rs)):], rs)
	return is + string(s)
}
