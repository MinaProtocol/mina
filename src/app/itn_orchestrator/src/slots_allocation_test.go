package itn_orchestrator

import (
	"fmt"
	"math"
	"math/rand"
	"sort"
	"sync"
	"testing"

	"github.com/stretchr/testify/require"
)

func dedup(s []int) []int {
	dups := -1 // number of duplicates - 1
	for i, x := range s[1:] {
		if x == s[i] {
			dups++
		} else {
			s[i-dups] = x
		}
	}
	return s[:len(s)-dups-1]
}

func sortAndDedup(s []int) []int {
	sort.Ints(s)
	return dedup(s)
}

func checkSortedNoDups(s []int) bool {
	if len(s) == 0 {
		return true
	}
	for i, x := range s[1:] {
		if x <= s[i] {
			return false
		}
	}
	return true
}

func genIp(i int) string {
	return fmt.Sprintf("109.93.%d.%d", i/253+1, i%253+1)
}

func testcase(r *rand.Rand, n, minSlot int, sparsity float32, stakeDistribution []int) map[string][]int {
	n_ := int(sparsity * float32(n))
	totalStake := 0
	for _, st := range stakeDistribution {
		totalStake += st
	}
	res := make(map[string][]int)
	for pi, stake := range stakeDistribution {
		m := n * stake / totalStake
		if m == 0 {
			m = 1
		}
		slots := make([]int, m)
		for i := range slots {
			slots[i] = r.Intn(n_) + minSlot
		}
		res[genIp(pi)] = sortAndDedup(slots)
	}
	return res
}

func uniform(participants int) []int {
	res := make([]int, participants)
	for i := range res {
		res[i] = 1
	}
	return res
}

func checkSlots(ipToSlots map[string][]int, entries slotEntries, maxSlot int) int {
	allIps := map[string]struct{}{}
	lastSlotLen := 0
	for _, entry := range entries {
		if !checkSortedNoDups(entry.slots) {
			return -1
		}
		// Check all slots from ips are in the entry.slots and vice versa
		mCalc := make(map[int]struct{})
		mRet := make(map[int]struct{})
		for _, s := range entry.slots {
			mRet[s] = struct{}{}
		}
		for _, ip := range entry.ips {
			allIps[ip] = struct{}{}
			for _, s := range ipToSlots[ip] {
				if s <= maxSlot {
					mCalc[s] = struct{}{}
				}
			}
		}
		if len(mRet) != len(mCalc) {
			return -2
		}
		for s := range mRet {
			if _, has := mCalc[s]; !has {
				return -3
			}
			if s > maxSlot {
				return -4
			}
		}
		if lastSlotLen > len(mCalc) {
			return -5
		}
		lastSlotLen = len(mCalc)
	}
	expectedIps := map[string]struct{}{}
	for ip, slots := range ipToSlots {
		for _, s := range slots {
			if s <= maxSlot {
				expectedIps[ip] = struct{}{}
			}
		}
	}
	if len(allIps) != len(expectedIps) {
		return -6
	}
	for ip := range allIps {
		if _, has := expectedIps[ip]; !has {
			return -7
		}
	}
	return len(entries[len(entries)-1].slots) - len(entries[0].slots)
}

func TestPartitionNumSets3(t *testing.T) {
	seed := rand.Int63()
	t.Logf("Seed %d", seed)
	r := rand.New(rand.NewSource(seed))
	for i := 0; i < 100; i++ {
		for _, n := range []int{30, 100, 1000, 10000} {
			ipToSlots := testcase(r, 100, 1002, 2, uniform(3))
			for i, entry := range ipToSlots {
				require.True(t, checkSortedNoDups(entry), i)
			}
			tuple := partitionNumSets(ipToSlots, 3, 2000)
			for i, entry := range tuple.entries {
				require.Equal(t, 1, len(entry.ips), i)
				require.Equal(t, ipToSlots[entry.ips[0]], entry.slots, i)
			}
			require.Less(t, tuple.diff, n/10+10)
		}
	}
}

func normal(r *rand.Rand, n int) []int {
	res := make([]int, n)
	for i := range res {
		res[i] = int(math.Exp(-4.5*r.Float64()) * 1000.0)
	}
	return res
}

func TestParticipants(t *testing.T) {
	minSlot := 1002
	var wg sync.WaitGroup
	for j := 0; j < 10; j++ {
		seed := rand.Int63()
		t.Logf("Seed %d: %d", j, seed)
		r := rand.New(rand.NewSource(seed))
		wg.Add(1)
		go func(j int) {
			defer wg.Done()
			for _, sparsity := range []float32{2, 3, 0.5} {
				for _, participants := range []int{10, 100, 1000} {
					for _, groups := range []int{2, 3, 4} {
						for _, n := range []int{30, 100, 1000} {
							n_ := int(sparsity * float32(n))
							minEndSlot := minSlot + n_/4
							maxEndSlot := minSlot + n_*3/4
							var dist []int
							if j&1 > 0 {
								dist = uniform(participants)
							} else {
								dist = normal(r, participants)
							}
							ipToSlots := testcase(r, n, minSlot, sparsity, dist)
							for i, entry := range ipToSlots {
								require.True(t, checkSortedNoDups(entry), "i=%d groups=%d n=%d", i, groups, n)
							}
							{
								tuple := partitionNumSets(ipToSlots, groups, minEndSlot)
								require.GreaterOrEqualf(t, tuple.diff, 0, "groups=%d n=%d", groups, n)
								require.Equalf(t, checkSlots(ipToSlots, tuple.entries, minEndSlot), tuple.diff, "groups=%d n=%d", groups, n)
								require.Lessf(t, tuple.diff, n/5+10, "groups=%d n=%d", groups, n)
							}
							tuple, lastSlot := allocateSlotsDo(groups, minEndSlot, maxEndSlot, ipToSlots)
							require.GreaterOrEqualf(t, tuple.diff, 0, "groups=%d n=%d", groups, n)
							require.Equalf(t, checkSlots(ipToSlots, tuple.entries, lastSlot), tuple.diff, "groups=%d n=%d", groups, n)
							require.Lessf(t, tuple.diff, n/5+5, "groups=%d n=%d", groups, n)
						}
					}
				}
			}
		}(j)
	}
	wg.Wait()
}
