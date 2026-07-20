// Package plan reads the network plan emitted by mina-local-network.
//
// The Python planner allocates the ports a network listens on, so the plan it
// writes is the only source of truth for them. Ports are allocated from a
// probed free base and differ between runs, so a plan must be written once and
// read back — never regenerated to re-derive the same ports.
package plan

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

// FileName is the plan file the planner writes under a network state root.
const FileName = "network-plan.json"

// PathFor returns the plan path for the network state root *root*.
func PathFor(root string) string {
	return filepath.Join(root, FileName)
}

// Endpoint is a single host/port a node listens on.
type Endpoint struct {
	Port int    `json:"port"`
	Host string `json:"host"`
}

// Node is a planned daemon. Endpoints are keyed by endpoint name ("client",
// "rest", "external", "metrics", "libp2p_metrics", and "itn_graphql" when the
// node has the itn_graphql capability).
type Node struct {
	Name      string              `json:"name"`
	Endpoints map[string]Endpoint `json:"endpoints"`
}

// Worker is a planned external snark worker.
type Worker struct {
	Name            string `json:"name"`
	CoordinatorNode string `json:"coordinator_node"`
	CoordinatorPort int    `json:"coordinator_port"`
	DaemonAddress   string `json:"daemon_address"`
}

// Plan is the subset of network-plan.json the orchestrator reads.
type Plan struct {
	Nodes   []Node   `json:"nodes"`
	Workers []Worker `json:"workers"`
}

// Load parses the plan written by `mina-local-network.py plan topology` or
// `patch topology`.
func Load(path string) (*Plan, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read network plan %s: %w", path, err)
	}

	var p Plan
	if err := json.Unmarshal(data, &p); err != nil {
		return nil, fmt.Errorf("failed to parse network plan %s: %w", path, err)
	}
	if len(p.Nodes) == 0 {
		return nil, fmt.Errorf("network plan %s declares no nodes", path)
	}
	return &p, nil
}

// Node returns the planned node named *name*.
func (p *Plan) Node(name string) (*Node, bool) {
	for i := range p.Nodes {
		if p.Nodes[i].Name == name {
			return &p.Nodes[i], true
		}
	}
	return nil, false
}

// NodeNames returns every planned node name, for diagnostics.
func (p *Plan) NodeNames() []string {
	names := make([]string, 0, len(p.Nodes))
	for i := range p.Nodes {
		names = append(names, p.Nodes[i].Name)
	}
	return names
}
