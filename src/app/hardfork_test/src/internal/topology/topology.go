// Package topology loads the network shape the hardfork test runs on.
//
// The shape is data, not code: it lives in mina-local-network's presets
// (scripts/mina-local-network/presets/hf-test-*.jsonc) and is the single source
// of truth for which daemons exist, what they are called, and what they can do.
// This package only overlays the handful of fields that cannot be known until
// the run — binaries, paths, the genesis timestamp, and per-node fork
// arguments — and hands the result to mina-local-network.
//
// The preset is read from a path the caller supplies rather than embedded, so
// that it lives next to the schema that governs it and can be edited without
// rebuilding this binary. Resolving a name to a path is the caller's job (see
// scripts/hardfork/build-and-test.sh); this package is handed a file.
//
// Node ports are deliberately never set here: the planner allocates them and
// the orchestrator reads them back (see internal/plan).
package topology

import (
	"encoding/json"
	"fmt"
	"os"
	"sort"
	"strings"
)

// Topology is a loaded network shape.
//
// doc is the whole document and is opaque: the schema belongs to
// mina-local-network and grows there, so a field this package does not know
// about must still survive the round trip to the planner (see Render). A field
// silently dropped here is a field the planner never sees.
//
// Everything the test needs is extracted from it once, at load, and stored
// alongside. Nothing reaches back into doc afterwards, so there is no second
// view of the document to fall out of step with it.
type Topology struct {
	doc            map[string]any
	nodeNames      []string
	seedName       string
	consensus      ConsensusParams
	valueTransfers []ValueTransferWorkload
}

// topologySpec is a typed view used only to extract the above at load. It is
// deliberately not a model of the whole schema, and is not retained.
type topologySpec struct {
	Nodes         map[string]nodeSpec `json:"nodes"`
	RuntimeConfig struct {
		Genesis struct {
			// Pointers so that an absent field is distinguishable from a zero one:
			// a missing k must fail, not silently mean 0.
			K             *int `json:"k"`
			SlotsPerEpoch *int `json:"slots_per_epoch"`
		} `json:"genesis"`
	} `json:"runtime_config"`
	Workloads map[string]workloadSpec `json:"workloads"`
}

type nodeSpec struct {
	Capabilities struct {
		// p2p_seed is a presence marker — an object with no fields — so only its
		// presence is meaningful.
		P2PSeed *struct{} `json:"p2p_seed"`
	} `json:"capabilities"`
}

// workloadSpec models only the parts of a workload this package reads. config
// differs per type — the schema selects its shape on `type` — so only the fields
// shared by the types we care about are named here.
type workloadSpec struct {
	Type string `json:"type"`
}

// ValueTransferWorkload is a workload that sends random payments across the
// account pool. It has no single sender — the pool is derived by
// mina-local-network — so this package only needs the workload's name.
type ValueTransferWorkload struct {
	// Name is the workload's key in the topology.
	Name string
}

// Load reads the topology preset at *path*.
//
// Everything the test requires of a topology is checked here, so a preset that
// cannot support a run is rejected before the run begins rather than partway
// through it.
func Load(path string) (*Topology, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read topology %s: %w", path, err)
	}
	return parse(stripComments(data), path)
}

func parse(data []byte, source string) (*Topology, error) {
	var doc map[string]any
	if err := json.Unmarshal(data, &doc); err != nil {
		return nil, fmt.Errorf("failed to parse topology %s: %w", source, err)
	}
	var spec topologySpec
	if err := json.Unmarshal(data, &spec); err != nil {
		return nil, fmt.Errorf("failed to parse topology %s: %w", source, err)
	}
	if len(spec.Nodes) == 0 {
		return nil, fmt.Errorf("topology %s declares no nodes", source)
	}

	nodeNames := make([]string, 0, len(spec.Nodes))
	for name := range spec.Nodes {
		nodeNames = append(nodeNames, name)
	}
	sort.Strings(nodeNames)

	seedName, err := seedOf(spec.Nodes)
	if err != nil {
		return nil, fmt.Errorf("topology %s: %w", source, err)
	}
	consensus, err := consensusOf(spec)
	if err != nil {
		return nil, fmt.Errorf("topology %s: %w", source, err)
	}

	return &Topology{
		doc:            doc,
		nodeNames:      nodeNames,
		seedName:       seedName,
		consensus:      consensus,
		valueTransfers: valueTransfersOf(spec.Workloads),
	}, nil
}

// valueTransfersOf picks out the value-transfer workloads, sorted by name so
// callers iterate them in a stable order.
func valueTransfersOf(workloads map[string]workloadSpec) []ValueTransferWorkload {
	var out []ValueTransferWorkload
	for name, wl := range workloads {
		if wl.Type != "value_transfer" {
			continue
		}
		out = append(out, ValueTransferWorkload{Name: name})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Name < out[j].Name })
	return out
}

// seedOf finds the node carrying the p2p_seed capability.
//
// Identified by capability rather than by name or position: the seed is the
// network's only P2P hub, and callers that must treat it specially cannot
// depend on where it happens to sort.
func seedOf(nodes map[string]nodeSpec) (string, error) {
	var seeds []string
	for name, node := range nodes {
		if node.Capabilities.P2PSeed != nil {
			seeds = append(seeds, name)
		}
	}
	sort.Strings(seeds)

	switch len(seeds) {
	case 1:
		return seeds[0], nil
	case 0:
		return "", fmt.Errorf("declares no p2p_seed node; the network has no peering hub")
	default:
		return "", fmt.Errorf("declares %d p2p_seed nodes (%s); expected exactly one",
			len(seeds), strings.Join(seeds, ", "))
	}
}

// consensusOf reads the consensus parameters the preset declares.
//
// The test reads them rather than carrying its own copies: the daemons are
// configured from this preset, so a second copy in Go is a number that agrees
// only until either side moves, and then disagrees silently.
//
// A missing parameter is an error rather than a default, for the same reason —
// defaulting would run the daemons on one value and the test's arithmetic on
// another.
func consensusOf(spec topologySpec) (ConsensusParams, error) {
	genesis := spec.RuntimeConfig.Genesis
	if genesis.K == nil {
		return ConsensusParams{}, fmt.Errorf("declares no runtime_config.genesis.k")
	}
	if genesis.SlotsPerEpoch == nil {
		return ConsensusParams{}, fmt.Errorf("declares no runtime_config.genesis.slots_per_epoch")
	}
	return ConsensusParams{K: *genesis.K, SlotsPerEpoch: *genesis.SlotsPerEpoch}, nil
}

// stripComments removes //-style line comments, which the .jsonc topologies use
// but encoding/json does not accept. Comment markers inside strings are left
// alone.
func stripComments(data []byte) []byte {
	var out strings.Builder
	for _, line := range strings.Split(string(data), "\n") {
		inString, escaped := false, false
		cut := -1
		for i := 0; i < len(line)-1; i++ {
			c := line[i]
			switch {
			case escaped:
				escaped = false
			case c == '\\' && inString:
				escaped = true
			case c == '"':
				inString = !inString
			case c == '/' && line[i+1] == '/' && !inString:
				cut = i
			}
			if cut >= 0 {
				break
			}
		}
		if cut >= 0 {
			line = line[:cut]
		}
		out.WriteString(line)
		out.WriteString("\n")
	}
	return []byte(out.String())
}

// ConsensusParams are the consensus parameters of the network under test.
type ConsensusParams struct {
	// K is the confirmation depth, in blocks. Note the unit: quantities the test
	// derives from it are usually counted in slots, and at the slot occupancy this
	// network runs at the two are far apart.
	K int
	// SlotsPerEpoch is the epoch length, in slots.
	SlotsPerEpoch int
}

// NodeNames returns every node in the topology, sorted, so the daemon list and
// the topology cannot disagree about which nodes exist.
func (t *Topology) NodeNames() []string { return t.nodeNames }

// SeedName returns the node carrying the p2p_seed capability.
func (t *Topology) SeedName() string { return t.seedName }

// Consensus returns the consensus parameters the preset declares.
func (t *Topology) Consensus() ConsensusParams { return t.consensus }

// ValueTransferWorkloads returns the topology's value-transfer workloads, sorted
// by name.
func (t *Topology) ValueTransferWorkloads() []ValueTransferWorkload { return t.valueTransfers }

// clone deep-copies the document so the main and fork overlays cannot disturb
// each other.
func (t *Topology) clone() map[string]any {
	data, err := json.Marshal(t.doc)
	if err != nil {
		panic(fmt.Sprintf("topology is not serializable: %v", err))
	}
	var out map[string]any
	if err := json.Unmarshal(data, &out); err != nil {
		panic(fmt.Sprintf("topology does not round trip: %v", err))
	}
	return out
}

// section returns doc[key] as an object, creating it when absent.
func section(doc map[string]any, key string) map[string]any {
	if s, ok := doc[key].(map[string]any); ok {
		return s
	}
	s := map[string]any{}
	doc[key] = s
	return s
}

// Overlay is everything about a network that the topology file cannot state
// because it is only known once the test is running.
type Overlay struct {
	// Root is the network state root.
	Root string
	// MinaExe is the daemon binary this network runs.
	MinaExe string
	// BlockWindowDurationMs is the slot duration.
	BlockWindowDurationMs    int
	SlotTxEnd                int
	SlotChainEnd             int
	HardForkGenesisSlotDelta int

	// GenesisTimestamp is when this network's genesis falls, RFC3339. Required.
	//
	// It has no "leave it out" option on purpose. mina-local-network fills in a
	// default when the topology does not name one, so an omission does not read
	// as "there is no genesis timestamp" — it reads as "pick one for me", and the
	// plan then describes a network that never runs. The caller always knows the
	// instant, so it always says it.
	GenesisTimestamp string
	// ExtraFilesRoot and ExtraAccountsFile are optional run-scoped paths.
	ExtraFilesRoot    string
	ExtraAccountsFile string
	// ExtraArgs are per-node daemon arguments, keyed by node name.
	ExtraArgs map[string][]string

	// ValueTransferCarryover is the ledger nonce each value_transfer pool account
	// reached before the fork, keyed by account ref (e.g. {"whale-0": 67}). Set on
	// the fork network only: it is injected into every value_transfer workload as
	// assert_carryover_nonces, and mina-local-network's worker asserts each pool
	// account inherited exactly this nonce before its first send. Empty on the main
	// network (nothing to carry over yet).
	ValueTransferCarryover map[string]int
}

// Render applies *o* and returns the topology JSON to hand to the planner.
func (t *Topology) Render(o Overlay) ([]byte, error) {
	doc := t.clone()

	state := section(doc, "state")
	state["root"] = o.Root
	if o.ExtraFilesRoot != "" {
		state["extra_files_root"] = o.ExtraFilesRoot
	} else {
		delete(state, "extra_files_root")
	}
	if o.GenesisTimestamp == "" {
		return nil, fmt.Errorf("overlay does not state a genesis timestamp; " +
			"leaving it out would let the planner choose one and the plan would name a " +
			"genesis the network does not use")
	}
	state["genesis_timestamp"] = map[string]any{"value": o.GenesisTimestamp}

	section(doc, "binaries")["mina"] = o.MinaExe

	rc := section(doc, "runtime_config")
	section(rc, "proof")["block_window_duration_ms"] = o.BlockWindowDurationMs
	daemon := section(rc, "daemon")
	daemon["slot_tx_end"] = o.SlotTxEnd
	daemon["slot_chain_end"] = o.SlotChainEnd
	daemon["hard_fork_genesis_slot_delta"] = o.HardForkGenesisSlotDelta

	lg := section(doc, "ledger_generation")
	if o.ExtraAccountsFile != "" {
		lg["extra_accounts_file"] = o.ExtraAccountsFile
	} else {
		delete(lg, "extra_accounts_file")
	}

	nodes := doc["nodes"].(map[string]any)
	for name, args := range o.ExtraArgs {
		node, ok := nodes[name].(map[string]any)
		if !ok {
			return nil, fmt.Errorf(
				"cannot set extra_args on node %q: the topology declares no such node (have: %s)",
				name, strings.Join(t.NodeNames(), ", "))
		}
		node["extra_args"] = args
	}

	if len(o.ValueTransferCarryover) > 0 {
		applyCarryover(doc, o.ValueTransferCarryover)
	}

	return json.MarshalIndent(doc, "", "  ")
}

// applyCarryover writes the pre-fork nonce baseline into every value_transfer
// workload's config as assert_carryover_nonces, so mina-local-network's worker
// verifies each pool account inherited its nonce across the fork before sending.
func applyCarryover(doc map[string]any, carryover map[string]int) {
	workloads, ok := doc["workloads"].(map[string]any)
	if !ok {
		return
	}
	for _, raw := range workloads {
		wl, ok := raw.(map[string]any)
		if !ok || wl["type"] != "value_transfer" {
			continue
		}
		cfg, ok := wl["config"].(map[string]any)
		if !ok {
			cfg = map[string]any{}
			wl["config"] = cfg
		}
		nonces := map[string]any{}
		for ref, nonce := range carryover {
			nonces[ref] = nonce
		}
		cfg["assert_carryover_nonces"] = nonces
	}
}
