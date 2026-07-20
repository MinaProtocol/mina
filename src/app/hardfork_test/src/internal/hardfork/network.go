package hardfork

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/config"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/plan"
	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/topology"
)

// writeTopologyFile persists a topology JSON blob to a temp file for the
// given profile ("main" or "fork") and returns its path. The file is recorded
// so cleanupTopologyFiles can remove it when the test tears down.
func (t *HardforkTest) writeTopologyFile(topoJSON []byte, profile string) (string, error) {
	topoFile := filepath.Join(os.TempDir(), fmt.Sprintf("mina-hf-test-%s-topology.json", profile))
	if err := os.WriteFile(topoFile, topoJSON, 0644); err != nil {
		return "", fmt.Errorf("failed to write topology file for %s network: %w", profile, err)
	}
	t.topologyFiles = append(t.topologyFiles, topoFile)
	return topoFile, nil
}

// cleanupTopologyFiles removes the temp topology files written by
// writeTopologyFile. They are small, but the test should not leave anything of
// its own behind — the network root it is handed is cleaned up by its caller.
func (t *HardforkTest) cleanupTopologyFiles() {
	for _, f := range t.topologyFiles {
		if err := os.Remove(f); err != nil && !os.IsNotExist(err) {
			t.Logger.Error("Failed to remove topology file %s: %v", f, err)
		}
	}
	t.topologyFiles = nil
}

// mlnPythonPath returns the path to mina-local-network.py relative to ScriptDir.
func (t *HardforkTest) mlnPythonPath() string {
	return filepath.Join(t.ScriptDir, "../mina-local-network/mina-local-network.py")
}

// runMLN runs a mina-local-network.py subcommand to completion.
func (t *HardforkTest) runMLN(args ...string) error {
	cmd := exec.Command("python3", append([]string{t.mlnPythonPath()}, args...)...)
	cmd.Env = os.Environ()
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// queryMLN runs a mina-local-network.py subcommand and returns its stdout.
//
// Unlike runMLN, stdout is captured rather than forwarded, because these
// subcommands answer a question. stderr still goes to the log, so a failure
// explains itself where the rest of the run is.
func (t *HardforkTest) queryMLN(args ...string) (string, error) {
	cmd := exec.Command("python3", append([]string{t.mlnPythonPath()}, args...)...)
	cmd.Env = os.Environ()
	cmd.Stderr = os.Stderr

	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("mina-local-network.py %s failed: %w", strings.Join(args, " "), err)
	}
	return strings.TrimSpace(string(out)), nil
}

// AccountNonce asks mina-local-network for the ledger nonce of *accountRef* as
// seen by *nodeName*.
//
// mina-local-network resolves the ref, because it owns the mapping from an
// account ref to the key it materialized — a mapping this test would otherwise
// have to reimplement and keep in step.
func (t *HardforkTest) AccountNonce(accountRef, nodeName string) (int, error) {
	out, err := t.queryMLN("query", "account-nonce", t.Config.Root,
		"--account-ref", accountRef, "--node", nodeName)
	if err != nil {
		return 0, err
	}
	nonce, err := strconv.Atoi(out)
	if err != nil {
		return 0, fmt.Errorf(
			"could not read the nonce of account %s on node %s from %q: %w",
			accountRef, nodeName, out, err)
	}
	return nonce, nil
}

// PoolAccountRefs asks mina-local-network which accounts the value_transfer pool
// draws from. mina-local-network owns the pool definition and the ref→key
// mapping, so this test reads exactly the accounts that advance nonces without
// reimplementing either.
func (t *HardforkTest) PoolAccountRefs() ([]string, error) {
	out, err := t.queryMLN("query", "value-transfer-pool", t.Config.Root)
	if err != nil {
		return nil, err
	}
	var refs []string
	if err := json.Unmarshal([]byte(out), &refs); err != nil {
		return nil, fmt.Errorf("could not parse value-transfer pool %q: %w", out, err)
	}
	return refs, nil
}

// PreForkPoolNonces snapshots the nonce every value_transfer pool account reached
// on the pre-fork chain, so the fork network can be checked against it.
//
// Returns nil when the topology has no value_transfer workload: there is then no
// nonce activity to carry over and nothing to check.
//
// Read from a non-auto daemon, since auto daemons exit at slot-chain-end, and
// only once the chain has stopped, so the value cannot move underneath us.
func (t *HardforkTest) PreForkPoolNonces() (map[string]int, error) {
	if len(t.Topology.ValueTransferWorkloads()) == 0 {
		return nil, nil
	}

	daemon := t.Config.AnyDaemonSatisfying("non-auto", func(di *config.DaemonInfo) bool {
		return di.ForkMethod != config.Auto
	})
	if daemon == nil {
		return nil, fmt.Errorf("no non-auto daemon is alive to read pool nonces from")
	}

	refs, err := t.PoolAccountRefs()
	if err != nil {
		return nil, err
	}

	nonces := map[string]int{}
	for _, ref := range refs {
		nonce, err := t.AccountNonce(ref, daemon.Name)
		if err != nil {
			return nil, err
		}
		t.Logger.Info("Pre-fork: pool account %s reached nonce %d", ref, nonce)
		nonces[ref] = nonce
	}
	return nonces, nil
}

// loadPlanPorts reads the plan the planner just wrote and populates every
// daemon's ports from it.
//
// The planner allocates ports from a probed free base, so they differ between
// runs and are only knowable by reading the plan back. Must run after every
// plan/patch and before any daemon is queried.
func (t *HardforkTest) loadPlanPorts() error {
	p, err := plan.Load(plan.PathFor(t.Config.Root))
	if err != nil {
		return err
	}
	if err := t.Config.PopulatePortsFromPlan(p); err != nil {
		return err
	}
	return nil
}

// startNetworkCmd starts *cmd* in the background and registers it for cleanup.
func (t *HardforkTest) startNetworkCmd(cmd *exec.Cmd, profile string) (*exec.Cmd, error) {
	t.Logger.Info("Starting network %s...", profile)
	cmd.Env = os.Environ()
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return nil, fmt.Errorf("failed to start %s network: %w", profile, err)
	}

	t.registerCmd(cmd)

	t.Logger.Info("Network %s started successfully", profile)
	return cmd, nil
}

// startLocalNetwork spawns a network from a pre-built topology JSON blob.
//
// Planning is a separate step from spawning rather than one `spawn topology`
// call: the planner allocates the ports, and replanning allocates different
// ones, so the plan must be written once, read back for its ports, and then
// spawned from — not regenerated.
func (t *HardforkTest) startLocalNetwork(topoJSON []byte, profile string) (*exec.Cmd, error) {
	topoFile, err := t.writeTopologyFile(topoJSON, profile)
	if err != nil {
		return nil, err
	}

	if err := t.runMLN("plan", "topology", topoFile, "--overwrite"); err != nil {
		return nil, fmt.Errorf("failed to plan %s network: %w", profile, err)
	}
	if err := t.loadPlanPorts(); err != nil {
		return nil, fmt.Errorf("failed to read ports for %s network: %w", profile, err)
	}

	// Mirrors `spawn topology`, which materializes only when no manifest is
	// present and otherwise checks it against the plan.
	if _, err := os.Stat(filepath.Join(t.Config.Root, "materialized-manifest.json")); os.IsNotExist(err) {
		if err := t.runMLN("materialize", t.Config.Root); err != nil {
			return nil, fmt.Errorf("failed to materialize %s network: %w", profile, err)
		}
	}

	cmd := exec.Command("python3", t.mlnPythonPath(), "spawn", "instance", t.Config.Root)
	return t.startNetworkCmd(cmd, profile)
}

// startForkNetwork transitions the already-materialized main-network state
// root to the fork topology and spawns it.
//
// The fork topology intentionally differs from the main topology (different
// mina binary, proof/daemon runtime config) while the fork phase must reuse
// the exact keys and ledger materialized for the main network. `spawn
// topology --overwrite` replans unconditionally and trips the CLI's
// manifest-fingerprint safety check against the manifest materialized
// for the main plan; `patch topology` only accepts the new
// plan when it doesn't require any key beyond what's already on disk, then
// updates the manifest so `spawn instance` can run against it.
func (t *HardforkTest) startForkNetwork(topoJSON []byte) (*exec.Cmd, error) {
	topoFile, err := t.writeTopologyFile(topoJSON, "fork")
	if err != nil {
		return nil, err
	}

	if err := t.runMLN("patch", "topology", topoFile); err != nil {
		return nil, fmt.Errorf("failed to patch topology for fork network: %w", err)
	}

	// patch replans, so the fork network's ports are freshly allocated and
	// need not match the main network's.
	if err := t.loadPlanPorts(); err != nil {
		return nil, fmt.Errorf("failed to read ports for fork network: %w", err)
	}

	cmd := exec.Command("python3", t.mlnPythonPath(), "spawn", "instance", t.Config.Root)
	return t.startNetworkCmd(cmd, "fork")
}

// baseOverlay is the part of the overlay both networks share.
func (t *HardforkTest) baseOverlay() topology.Overlay {
	return topology.Overlay{
		Root:                     t.Config.Root,
		SlotTxEnd:                t.Config.SlotTxEnd,
		SlotChainEnd:             t.Config.SlotChainEnd,
		HardForkGenesisSlotDelta: t.Config.HfSlotDelta,
	}
}

// forkMethodArgs returns the per-node daemon arguments implied by each node's
// assigned fork method.
//
// Auto daemons self-generate their hardfork config at slot-chain-end, which
// needs --hardfork-handling migrate-exit to create the activated marker file.
// The old shell script read these from extra_args.txt on disk; the planner
// reads them from the topology.
func (t *HardforkTest) forkMethodArgs() map[string][]string {
	args := map[string][]string{}
	for _, di := range t.Config.DaemonInfos {
		if di.ForkMethod == config.Auto {
			args[di.Name] = []string{"--hardfork-handling", "migrate-exit"}
		}
	}
	return args
}

// RunMainNetwork starts the main (pre-fork) network.
func (t *HardforkTest) RunMainNetwork(extraFilesRoot string, mainGenesisTs int64) (*exec.Cmd, error) {
	o := t.baseOverlay()
	o.MinaExe = t.Config.MainMinaExe
	o.BlockWindowDurationMs = t.Config.MainSlot * 1000
	o.GenesisTimestamp = config.FormatTimestamp(mainGenesisTs)
	o.ExtraFilesRoot = extraFilesRoot
	o.ExtraArgs = t.forkMethodArgs()
	if t.Config.VestingTestEnabled && t.vestingAccount != nil {
		o.ExtraAccountsFile = t.vestingAccount.extraAccountFile
	}

	topoJSON, err := t.Topology.Render(o)
	if err != nil {
		return nil, fmt.Errorf("failed to render main topology: %w", err)
	}
	return t.startLocalNetwork(topoJSON, "main")
}

// RunForkNetwork starts the fork (post-fork) network.
//
// Same shape as the main network, but on the fork binary and slot duration, and
// without migrate-exit — the fork has already happened, so auto daemons run
// normally. The workloads carry over: phase 4 asserts the fork chain produces
// blocks containing user commands, which needs a transaction source.
//
// The genesis timestamp is stated rather than left out. It is the same instant
// the fork config carries, so mln is told what the daemons will actually do:
// leaving it out reads to mln as "no preference" and it invents one, which is
// how the plan came to name a genesis the network never had.
//
// preForkPoolNonces is the nonce every value_transfer pool account reached on the
// pre-fork chain; it is injected into the fork's value_transfer workloads so mln
// asserts the carry-over before its first send (see Overlay.ValueTransferCarryover).
func (t *HardforkTest) RunForkNetwork(
	mainGenesisTs int64, preForkPoolNonces map[string]int,
) (*exec.Cmd, error) {
	o := t.baseOverlay()
	o.MinaExe = t.Config.ForkMinaExe
	o.BlockWindowDurationMs = t.Config.ForkSlot * 1000
	// The same instant the fork config names, formatted by the same helper, so
	// the plan and the config the daemons read cannot spell it differently.
	o.GenesisTimestamp = config.FormatTimestamp(
		t.Config.ForkGenesisTsGivenMainGenesisTs(mainGenesisTs))
	o.ValueTransferCarryover = preForkPoolNonces

	topoJSON, err := t.Topology.Render(o)
	if err != nil {
		return nil, fmt.Errorf("failed to render fork topology: %w", err)
	}
	return t.startForkNetwork(topoJSON)
}

// WaitUntilBestChainQuery calculates and waits until it's time to query the best chain
func (t *HardforkTest) WaitUntilBestChainQuery(slotDurationSec int, genesisSlot int) {
	t.WaitForBestTip(t.Config.AnyDaemon(), func(block client.BlockData) bool {
		return block.Slot >= t.Config.BestChainQueryFrom+genesisSlot
	}, fmt.Sprintf("best tip reached slot %d", t.Config.BestChainQueryFrom),
		time.Duration(2*t.Config.BestChainQueryFrom*slotDurationSec)*time.Second,
	)
}
