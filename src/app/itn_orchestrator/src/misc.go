package itn_orchestrator

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"math/rand"
	"os"
	"os/exec"
	"sort"
	"strconv"
	"strings"
	"time"

	logging "github.com/ipfs/go-log/v2"
)

type WaitParams struct {
	Minutes int `json:"min,omitempty"`
	Slot    int `json:"slot,omitempty"`
	Seconds int `json:"sec,omitempty"`
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
	Group1 []json.RawMessage `json:"group1"`
	Group2 []json.RawMessage `json:"group2"`
	Group3 []json.RawMessage `json:"group3,omitempty"`
	Group4 []json.RawMessage `json:"group4,omitempty"`
	Group5 []json.RawMessage `json:"group5,omitempty"`
	Group6 []json.RawMessage `json:"group6,omitempty"`
	Group7 []json.RawMessage `json:"group7,omitempty"`
	Group8 []json.RawMessage `json:"group8,omitempty"`
	Group9 []json.RawMessage `json:"group9,omitempty"`
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
	Group  []NodeAddress `json:"group"`
	Except []NodeAddress `json:"except"`
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
	Group  []NodeAddress `json:"group"`
	Ratios []float64     `json:"ratios"`
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

func retryOnMultipleServers(servers []string, serverIx int, commandName string, log logging.StandardLogger, try func(string) error) (err error) {
	server := ""
	if len(servers) > 0 {
		server = servers[serverIx]
	}
	for retryPause := 1; retryPause <= 16; retryPause = retryPause * 2 {
		err = try(server)
		if err == nil {
			break
		}
		if retryPause <= 8 {
			log.Warnf("Failed to run %s command, retrying in %d minutes: %s", commandName, retryPause, err)
			time.Sleep(time.Duration(retryPause) * time.Minute)
		}
		if len(servers) > 0 {
			serverIx = (serverIx + 1) % len(servers)
			server = servers[serverIx]
		}
	}
	return
}

func listKeyfiles(dir string) ([]string, error) {
	keyFiles := []string{}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	for _, e := range entries {
		fname := e.Name()
		if strings.HasSuffix(fname, ".pub") {
			continue
		}
		keyFiles = append(keyFiles, dir+string(os.PathSeparator)+fname)
	}
	return keyFiles, nil
}

var pow10s []uint64

func init() {
	pow10s = []uint64{1, 10, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8}
}

func parseMina(str string) (uint64, error) {
	ix := strings.IndexRune(str, '.')
	if ix == -1 {
		u, err := strconv.ParseUint(str, 10, 64)
		return u * 1e9, err
	}
	var base uint64
	{
		var err error
		if base, err = strconv.ParseUint(str[:ix], 10, 64); err != nil {
			return 0, err
		}
	}
	base *= 1e9
	remlen := len(str) - ix - 1
	if remlen == 0 {
		return base, nil
	}
	if remlen > 9 {
		return 0, errors.New("too many digits after . in mina amount")
	}
	var rem uint64
	{
		var err error
		if rem, err = strconv.ParseUint(str[ix+1:], 10, 64); err != nil {
			return 0, err
		}
	}
	rem *= pow10s[9-remlen]
	return base + rem, nil
}

func execMina(ctx context.Context, minaExec string, args, env []string) error {
	ctx, cancelF := context.WithCancel(ctx)
	defer cancelF()
	cmd := exec.CommandContext(ctx, minaExec, args...)
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	cmd.Env = env
	return cmd.Run()
}

func execScanMina(ctx context.Context, minaExec string, args, env []string, scan func(*bufio.Scanner) error) error {
	ctx, cancelF := context.WithCancel(ctx)
	defer cancelF()
	cmd := exec.CommandContext(ctx, minaExec, args...)
	var stdout io.ReadCloser
	{
		var err error
		if stdout, err = cmd.StdoutPipe(); err != nil {
			return err
		}
	}
	cmd.Stderr = os.Stderr
	cmd.Env = env
	if err := cmd.Start(); err != nil {
		return err
	}
	scanner := bufio.NewScanner(stdout)
	scanner.Split(bufio.ScanWords)
	if err := scan(scanner); err != nil {
		return err
	}
	if err := stdout.Close(); err != nil {
		return err
	}
	return cmd.Wait()
}
