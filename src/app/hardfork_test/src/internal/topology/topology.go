package topology

import (
	"encoding/json"
	"fmt"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
)

// Port offsets within a node's port range (matching config.PortType).
const (
	portClient        = 0
	portRest          = 1
	portExternal      = 2
	portMetrics       = 3
	portLibp2pMetrics = 4
)

// Topology is the root JSON object passed to mina-local-network.py spawn topology.
type Topology struct {
	SchemaVersion    int                 `json:"schema_version"`
	Name             string              `json:"name"`
	RuntimeConfig    RuntimeConfig       `json:"runtime_config"`
	LedgerGeneration LedgerGeneration    `json:"ledger_generation"`
	Nodes            map[string]Node     `json:"nodes"`
	Workloads        map[string]Workload `json:"workloads,omitempty"`
	State            State               `json:"state"`
	Binaries         Binaries            `json:"binaries"`
}

type RuntimeConfig struct {
	Genesis GenesisConfig `json:"genesis"`
	Proof   ProofConfig   `json:"proof"`
	Daemon  DaemonConfig  `json:"daemon"`
}

type GenesisConfig struct {
	SlotsPerEpoch    int `json:"slots_per_epoch"`
	K                int `json:"k"`
	GracePeriodSlots int `json:"grace_period_slots"`
}

type ProofConfig struct {
	Level                 string `json:"level"`
	BlockWindowDurationMs int    `json:"block_window_duration_ms"`
}

type DaemonConfig struct {
	SlotTxEnd                int `json:"slot_tx_end"`
	SlotChainEnd             int `json:"slot_chain_end"`
	HardForkGenesisSlotDelta int `json:"hard_fork_genesis_slot_delta"`
}

type LedgerGeneration struct {
	Tiers             map[string]Tier    `json:"tiers"`
	Accounts          map[string]Account `json:"accounts"`
	ExtraAccountsFile string             `json:"extra_accounts_file,omitempty"`
}

type Tier struct {
	Count          int    `json:"count"`
	OfflineBalance string `json:"offline_balance"`
	OnlineBalance  string `json:"online_balance,omitempty"`
}

type Account struct {
	Balance string `json:"balance"`
	Kind    string `json:"kind"`
}

type Node struct {
	Capabilities Capabilities `json:"capabilities"`
	Ports        Ports        `json:"ports"`
}

type Capabilities struct {
	P2PSeed          *P2PSeedCap          `json:"p2p_seed,omitempty"`
	BlockProducer    *BlockProducerCap    `json:"block_producer,omitempty"`
	SnarkCoordinator *SnarkCoordinatorCap `json:"snark_coordinator,omitempty"`
}

type P2PSeedCap struct{}

type BlockProducerCap struct {
	Account string `json:"account"`
}

type SnarkCoordinatorCap struct {
	FeeReceiver string                `json:"fee_receiver"`
	WorkerPools map[string]WorkerPool `json:"worker_pools"`
}

type WorkerPool struct {
	Count int `json:"count"`
}

type Ports struct {
	Client        int `json:"client"`
	Rest          int `json:"rest"`
	External      int `json:"external"`
	Metrics       int `json:"metrics"`
	Libp2pMetrics int `json:"libp2p_metrics"`
}

type GenesisTimestamp struct {
	Value string `json:"value"`
}

type State struct {
	Root             string            `json:"root"`
	ExtraFilesRoot   string            `json:"extra_files_root,omitempty"`
	GenesisTimestamp *GenesisTimestamp `json:"genesis_timestamp,omitempty"`
}

type Binaries struct {
	Mina string `json:"mina"`
}

type Workload struct {
	Type   string         `json:"type"`
	Start  string         `json:"start"`
	Config WorkloadConfig `json:"config"`
}

type WorkloadConfig struct {
	Sender          string `json:"sender"`
	Receiver        string `json:"receiver"`
	Amount          string `json:"amount"`
	IntervalSeconds int    `json:"interval_seconds"`
}

// GenerateMainTopologyJSON produces the topology JSON for the pre-fork (main) network.
func GenerateMainTopologyJSON(cfg *config.Config, extraFilesRoot, extraAccountsFile, genesisTimestamp string) ([]byte, error) {
	topo := Topology{
		SchemaVersion: 1,
		Name:          "hf-test-main",
		RuntimeConfig: RuntimeConfig{
			Genesis: GenesisConfig{
				SlotsPerEpoch:    config.ProtocolSlotPerEpoch,
				K:                config.ProtocolK,
				GracePeriodSlots: 3,
			},
			Proof: ProofConfig{
				Level:                 "full",
				BlockWindowDurationMs: cfg.MainSlot * 1000,
			},
			Daemon: DaemonConfig{
				SlotTxEnd:                cfg.SlotTxEnd,
				SlotChainEnd:             cfg.SlotChainEnd,
				HardForkGenesisSlotDelta: cfg.HfSlotDelta,
			},
		},
		LedgerGeneration: LedgerGeneration{
			Tiers: map[string]Tier{
				"whale": {
					Count:          2,
					OfflineBalance: "11550000mina",
					OnlineBalance:  "499mina",
				},
				"snark_coordinator": {
					Count:          1,
					OfflineBalance: "5mina",
				},
			},
			Accounts: map[string]Account{
				"snark-fees": {
					Balance: "5nanomina",
					Kind:    "snark_fee",
				},
			},
		},
		Nodes: map[string]Node{
			"seed": {
				Capabilities: Capabilities{
					P2PSeed: &P2PSeedCap{},
					BlockProducer: &BlockProducerCap{
						Account: "whale-0",
					},
					SnarkCoordinator: &SnarkCoordinatorCap{
						FeeReceiver: "snark-fees",
						WorkerPools: map[string]WorkerPool{
							"default": {Count: 1},
						},
					},
				},
				Ports: Ports{
					Client:        cfg.SeedStartPort + portClient,
					Rest:          cfg.SeedStartPort + portRest,
					External:      cfg.SeedStartPort + portExternal,
					Metrics:       cfg.SeedStartPort + portMetrics,
					Libp2pMetrics: cfg.SeedStartPort + portLibp2pMetrics,
				},
			},
			"snark_coordinator": {
				Capabilities: Capabilities{
					BlockProducer: &BlockProducerCap{
						Account: "whale-1",
					},
				},
				Ports: Ports{
					Client:        cfg.SnarkCoordinatorPort + portClient,
					Rest:          cfg.SnarkCoordinatorPort + portRest,
					External:      cfg.SnarkCoordinatorPort + portExternal,
					Metrics:       cfg.SnarkCoordinatorPort + portMetrics,
					Libp2pMetrics: cfg.SnarkCoordinatorPort + portLibp2pMetrics,
				},
			},
		},
		Workloads: map[string]Workload{
			"value-transfer": {
				Type:  "value_transfer",
				Start: "after_sync",
				Config: WorkloadConfig{
					Sender:          "whale-1",
					Receiver:        "whale-0",
					Amount:          "1mina",
					IntervalSeconds: cfg.PaymentInterval,
				},
			},
		},
		State: State{
			Root: cfg.Root,
			GenesisTimestamp: &GenesisTimestamp{
				Value: genesisTimestamp,
			},
		},
		Binaries: Binaries{
			Mina: cfg.MainMinaExe,
		},
	}

	if extraFilesRoot != "" {
		topo.State.ExtraFilesRoot = extraFilesRoot
	}

	if extraAccountsFile != "" {
		topo.LedgerGeneration.ExtraAccountsFile = extraAccountsFile
	}

	data, err := json.MarshalIndent(topo, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("failed to marshal main topology: %w", err)
	}
	return data, nil
}

// GenerateForkTopologyJSON produces the topology JSON for the post-fork network.
func GenerateForkTopologyJSON(cfg *config.Config, extraFilesRoot string) ([]byte, error) {
	topo := Topology{
		SchemaVersion: 1,
		Name:          "hf-test-fork",
		RuntimeConfig: RuntimeConfig{
			Genesis: GenesisConfig{
				SlotsPerEpoch:    config.ProtocolSlotPerEpoch,
				K:                config.ProtocolK,
				GracePeriodSlots: 3,
			},
			Proof: ProofConfig{
				Level:                 "full",
				BlockWindowDurationMs: cfg.ForkSlot * 1000,
			},
			Daemon: DaemonConfig{
				SlotTxEnd:                cfg.SlotTxEnd,
				SlotChainEnd:             cfg.SlotChainEnd,
				HardForkGenesisSlotDelta: cfg.HfSlotDelta,
			},
		},
		LedgerGeneration: LedgerGeneration{
			Tiers: map[string]Tier{
				"whale": {
					Count:          2,
					OfflineBalance: "11550000mina",
					OnlineBalance:  "499mina",
				},
				"snark_coordinator": {
					Count:          1,
					OfflineBalance: "5mina",
				},
			},
			Accounts: map[string]Account{
				"snark-fees": {
					Balance: "5nanomina",
					Kind:    "snark_fee",
				},
			},
		},
		Nodes: map[string]Node{
			"seed": {
				Capabilities: Capabilities{
					P2PSeed: &P2PSeedCap{},
					BlockProducer: &BlockProducerCap{
						Account: "whale-0",
					},
					SnarkCoordinator: &SnarkCoordinatorCap{
						FeeReceiver: "snark-fees",
						WorkerPools: map[string]WorkerPool{
							"default": {Count: 1},
						},
					},
				},
				Ports: Ports{
					Client:        cfg.SeedStartPort + portClient,
					Rest:          cfg.SeedStartPort + portRest,
					External:      cfg.SeedStartPort + portExternal,
					Metrics:       cfg.SeedStartPort + portMetrics,
					Libp2pMetrics: cfg.SeedStartPort + portLibp2pMetrics,
				},
			},
			"snark_coordinator": {
				Capabilities: Capabilities{
					BlockProducer: &BlockProducerCap{
						Account: "whale-1",
					},
				},
				Ports: Ports{
					Client:        cfg.SnarkCoordinatorPort + portClient,
					Rest:          cfg.SnarkCoordinatorPort + portRest,
					External:      cfg.SnarkCoordinatorPort + portExternal,
					Metrics:       cfg.SnarkCoordinatorPort + portMetrics,
					Libp2pMetrics: cfg.SnarkCoordinatorPort + portLibp2pMetrics,
				},
			},
		},
		State: State{
			Root: cfg.Root + "-fork",
		},
		Binaries: Binaries{
			Mina: cfg.ForkMinaExe,
		},
	}

	// Fork topology intentionally omits workloads, extra_accounts_file, and extra_files_root.

	data, err := json.MarshalIndent(topo, "", "  ")
	if err != nil {
		return nil, fmt.Errorf("failed to marshal fork topology: %w", err)
	}
	return data, nil
}
