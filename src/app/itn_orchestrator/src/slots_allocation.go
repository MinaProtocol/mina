package itn_orchestrator

import (
	"container/heap"
	"encoding/json"
	"errors"
	"sort"
	"strconv"
	"strings"
)

type AllocateSlotsParams struct {
	Groups []int

	SlotsWon []SlotsWonOutput

	// Minimum number of slots to split equally among groups
	MinSlots int
	// Maximum number of slots to split equally among groups
	MaxSlots int
}

type slotEntry struct {
	slots []int
	ips   []string
}

type slotTuple struct {
	// List of length equaling the number of groups
	// Entries are sorted by length of their slot lists (ASC order)
	entries slotEntries

	// Difference in slot lengths between last and first entries
	diff int
}

type slotEntries []slotEntry

func (h slotEntries) Len() int { return len(h) }
func (h slotEntries) Less(i, j int) bool {
	return len(h[i].slots) < len(h[j].slots)
}

func (pq slotEntries) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
}

func mergeSlotTuplesDo(x, y slotTuple) slotTuple {
	groups := len(y.entries)
	entries := make(slotEntries, groups)
	for i := 0; i < groups; i++ {
		ips := make([]string, len(x.entries[i].ips)+len(y.entries[i].ips))
		copy(ips, x.entries[i].ips)
		copy(ips[len(x.entries[i].ips):], y.entries[i].ips)
		entries[i] = slotEntry{
			ips:   ips,
			slots: joinSlots(x.entries[i].slots, y.entries[i].slots),
		}
	}
	sort.Sort(entries)
	diff := len(entries[len(entries)-1].slots) - len(entries[0].slots)
	return slotTuple{entries: entries, diff: diff}
}

func (x slotTuple) mergeWith(y slotTuple) (res slotTuple) {
	ys := slotEntries(y.entries)
	groups := len(ys)
	if groups <= 5 {
		// Small enough to run through all permutations to find the best
		r := mergeSlotTuplesDo(x, y)
		if r.diff == 0 {
			return r
		}
		for NextPermutation(y.entries) {
			c := mergeSlotTuplesDo(x, y)
			if c.diff == 0 {
				return c
			} else if c.diff < r.diff {
				r = c
			}
		}
		return r
	} else {
		for i, j := 0, len(ys)-1; i < j; i, j = i+1, j-1 {
			ys[i], ys[j] = ys[j], ys[i]
		}
		return mergeSlotTuplesDo(x, y)
	}
}

type slotHeap []slotTuple

func (h slotHeap) Len() int { return len(h) }
func (h slotHeap) Less(i, j int) bool {
	return h[i].diff > h[j].diff
}

func (pq slotHeap) Swap(i, j int) {
	pq[i], pq[j] = pq[j], pq[i]
}

func (pq *slotHeap) Push(x interface{}) {
	*pq = append(*pq, x.(slotTuple))
}

func (h *slotHeap) PopTuple() (l slotTuple, has bool) {
	if h.Len() > 0 {
		l = heap.Pop(h).(slotTuple)
		has = true
	}
	return
}
func (pq *slotHeap) Pop() interface{} {
	old := *pq
	n := len(old)
	item := old[n-1]
	*pq = old[0 : n-1]
	return item
}

// Implements a variant of Karmarkar–Karp algorithm (also known as Largest differencing method).
//
// It takes slot sets organized by the string id (ipToSLots map), number of groups to split to and
// the maximum slot value.
//
// Algorithm runs O(n) iterations (each of `O(logn + n)` complexity) trying to heauristically construct
// such partition of string ids into groups that their joint slot sets are of roghly equal size.
//
// Note that complexity of whole algorithm is `O(n * (logn + n))` but can be reduced to `O(nlogn)` with
// the use of balanced tree (and wasn't done so because performance for expected sample size should be
// fine even with quadratic algorithm)
func partitionNumSets(ipToSlots map[string][]int, groups, endSlot int) slotTuple {
	tuples := make(slotHeap, 0, len(ipToSlots))
	for ip, slots := range ipToSlots {
		slots = filterLte(slots, endSlot)
		if len(slots) == 0 {
			continue
		}
		entries := make([]slotEntry, groups)
		entries[groups-1] = slotEntry{
			slots: slots,
			ips:   []string{ip},
		}
		tuples = append(tuples, slotTuple{
			entries: entries,
			diff:    len(slots),
		})
	}
	heap.Init(&tuples)
	for {
		x, hasX := tuples.PopTuple()
		if !hasX {
			panic("partitionNumSets: empty heap")
		}
		y, hasY := tuples.PopTuple()
		if !hasY {
			return x
		}
		heap.Push(&tuples, x.mergeWith(y))
	}
}

// Takes two asc-ordered int slices and merges them into a single
// one, also sorted and without duplicates.
func joinSlots(a, b []int) []int {
	r := make([]int, 0, len(a)+len(b))
	i := 0
	j := 0
	for i < len(a) && j < len(b) {
		if len(r) > 0 && a[i] == r[len(r)-1] {
			i++
		} else if len(r) > 0 && b[j] == r[len(r)-1] {
			j++
		} else if a[i] <= b[j] {
			r = append(r, a[i])
			i++
		} else {
			r = append(r, b[j])
			j++
		}
	}
	for ; i < len(a); i++ {
		if len(r) == 0 || a[i] != r[len(r)-1] {
			r = append(r, a[i])
		}
	}
	for ; j < len(b); j++ {
		if len(r) == 0 || b[j] != r[len(r)-1] {
			r = append(r, b[j])
		}
	}
	return r
}

// Given mapping from ip to addresses, allocation of ips to groups of roughly-equal slot allocation
// and `groups` slice of integers summing up to the number of groups, joins the groups in larger
// groups according to what's specified in the `groups`.
func arrangeGroups(ipToAddrs map[string][]NodeAddress, tuple slotTuple, groups []int, outputGroup func(int, []NodeAddress, []int)) {
	i := 0
	for j, n := range groups {
		addrs := make([]NodeAddress, 0)
		slots := make([]int, 0)
		for _, entry := range tuple.entries[i : i+n] {
			for _, ip := range entry.ips {
				addrs = append(addrs, ipToAddrs[ip]...)
			}
			slots = joinSlots(slots, entry.slots)
		}
		outputGroup(j, addrs, slots)
		i += n
	}
}

// Iterates through slots from `endSlot` to `maxEndSlot` and calls `partitionNumSets` to find
// the allocation of minimal slot difference between groups in allocation.
func allocateSlotsDo(groups, endSlot, maxEndSlot int, ipToSlots map[string][]int) (slotTuple, int) {
	bestTuple := partitionNumSets(ipToSlots, groups, endSlot)
	bestSlot := endSlot
	if bestTuple.diff > 0 {
		for endSlot++; endSlot <= maxEndSlot; endSlot++ {
			t := partitionNumSets(ipToSlots, groups, endSlot)
			if t.diff == 0 {
				bestTuple, bestSlot = t, endSlot
				break
			} else if t.diff < bestTuple.diff {
				bestTuple, bestSlot = t, endSlot
			}
		}
	}
	return bestTuple, bestSlot
}

// Given slots won for different nodes, calculate node groups s.t. each group collectively wins a roughly equal number of slots
//
// Function finds the first empty slot `E` (not present in any node) and from that slot it tries to find minimal sequence of
// slots for which there exists a perfectly equal split among nodes (s.t. each group collectively won equal number of slots).
//
// The sequence in question has maximal slot between `E + MinSlots` and `E + MaxSlots`. If no sequence with perfectly equal split is found,
// the sequence with minimal relative slot difference between groups is chosen.
func AllocateSlots(config Config, params AllocateSlotsParams, outputGroup func(int, []NodeAddress), outputNextEmptySlot func(int), outputLastSlot func(int)) error {
	groups := 0
	for _, n := range params.Groups {
		groups += n
		if n <= 0 {
			return errors.New("groups should be positive")
		}
	}
	ipToAddrs := make(map[string][]NodeAddress)
	ipToSlots := make(map[string][]int)
	var allSlots []int
	for _, sw := range params.SlotsWon {
		if len(sw.SlotsWon) == 0 {
			continue
		}
		addr := string(sw.Address)
		ip := addr[:strings.IndexRune(addr, ':')]
		ipToAddrs[ip] = append(ipToAddrs[ip], sw.Address)
		ipToSlots[ip] = joinSlots(ipToSlots[ip], sw.SlotsWon)
		allSlots = joinSlots(allSlots, sw.SlotsWon)
	}
	if len(ipToSlots) == 0 {
		return errors.New("no slots won provided")
	}
	emptySlot := allSlots[0]
	for _, slot := range allSlots[1:] {
		emptySlot++
		if slot > emptySlot {
			break
		}
	}
	outputNextEmptySlot(emptySlot)
	for ip := range ipToAddrs {
		ipToSlots[ip] = filterGt(ipToSlots[ip], emptySlot)
	}
	bestTuple, bestEndSlot := allocateSlotsDo(groups, emptySlot+params.MinSlots, emptySlot+params.MaxSlots, ipToSlots)
	outputLastSlot(bestEndSlot)
	config.Log.Infof("Split to %d groups: %d difference, last slot %d", groups, bestTuple.diff, bestEndSlot)
	arrangeGroups(ipToAddrs, bestTuple, params.Groups, func(i int, addrs []NodeAddress, slots []int) {
		outputGroup(i, addrs)
		config.Log.Infof("Slots for group %d: %v", i, slots)
	})
	return nil
}

type AllocateSlotsAction struct{}

func (AllocateSlotsAction) Run(config Config, rawParams json.RawMessage, output OutputF) error {
	var params AllocateSlotsParams
	if err := json.Unmarshal(rawParams, &params); err != nil {
		return err
	}
	return AllocateSlots(config, params, func(groupId int, nodeGroup []NodeAddress) {
		output("group"+strconv.Itoa(groupId), nodeGroup, false, false)
	}, func(nextSlot int) {
		output("nextEmptySlot", nextSlot, false, false)
	}, func(lastSlot int) {
		output("lastSlot", lastSlot, false, false)
	})
}

func (AllocateSlotsAction) Name() string { return "allocate-slots" }

var _ Action = AllocateSlotsAction{}
