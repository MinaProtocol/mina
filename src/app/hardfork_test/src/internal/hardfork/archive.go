package hardfork

import (
	"encoding/json"
	"fmt"
	"net"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/MinaProtocol/mina/src/app/hardfork_test/src/internal/client"
)

// The archive across the fork, as in the real procedure:
//
//  1. the main network writes its blocks to the archive database;
//  2. between the networks, the fork version's upgrade.sql upgrades it;
//  3. the fork network continues in the same database, its archive started
//     with the fork runtime config;
//  4. the archive hardfork toolbox repairs the data: it settles the pending
//     pre-fork blocks and writes the fork genesis ledger to genesis_accounts;
//  5. the test checks the result.

// archiveNetworkArgs returns the mina-local-network.sh arguments that start an
// archive node in the database of --pg-uri.
func (t *HardforkTest) archiveNetworkArgs() ([]string, error) {
	u, err := url.Parse(t.Config.PgURI)
	if err != nil {
		return nil, fmt.Errorf("invalid --pg-uri: %w", err)
	}
	password, _ := u.User.Password()
	port := u.Port()
	if port == "" {
		port = "5432"
	}
	return []string{
		"--archive-server-port", strconv.Itoa(t.Config.ArchivePort),
		"--pg-host", u.Hostname(),
		"--pg-port", port,
		"--pg-user", u.User.Username(),
		"--pg-passwd", password,
		"--pg-db", strings.TrimPrefix(u.Path, "/"),
	}, nil
}

// archiveForkConfigFile is the runtime config of the fork archive and of the
// toolbox: the fork config of a node merged with the network config, in the
// same order as the fork daemon loads them.
func (t *HardforkTest) archiveForkConfigFile() string {
	return filepath.Join(t.Config.Root, "archive_fork_config.json")
}

// psql runs one SQL statement and returns its unaligned, tuples-only output.
func (t *HardforkTest) psql(sql string) (string, error) {
	cmd := exec.Command("psql", "-X", "-A", "-t", "-v", "ON_ERROR_STOP=1", t.Config.PgURI, "-c", sql)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("psql %q failed: %w: %s", sql, err, string(out))
	}
	return strings.TrimSpace(string(out)), nil
}

func (t *HardforkTest) psqlInt(sql string) (int, error) {
	out, err := t.psql(sql)
	if err != nil {
		return 0, err
	}
	n, err := strconv.Atoi(out)
	if err != nil {
		return 0, fmt.Errorf("psql %q: expected an integer, got %q", sql, out)
	}
	return n, nil
}

// runToolbox runs the fork archive hardfork toolbox against the database.
func (t *HardforkTest) runToolbox(args ...string) error {
	args = append(args, "--postgres-uri", t.Config.PgURI)
	t.Logger.Info("Running archive hardfork toolbox: %s", strings.Join(args[:len(args)-2], " "))
	cmd := exec.Command(t.Config.ForkArchiveToolboxExe, args...)
	cmd.Env = append(os.Environ(), "MINA_KEYS_PATH="+t.forkGenesisDir)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("archive hardfork toolbox %s failed: %w", args[0], err)
	}
	return nil
}

// RecordPreforkGenesisAccounts reads the public keys of the main network's
// genesis ledger. Call it before CleanUpNetworkForForkPhase removes the
// ledger from daemon.json.
func (t *HardforkTest) RecordPreforkGenesisAccounts() error {
	data, err := os.ReadFile(filepath.Join(t.Config.Root, "daemon.json"))
	if err != nil {
		return err
	}
	var cfg struct {
		Ledger struct {
			Accounts []struct {
				Pk string `json:"pk"`
			} `json:"accounts"`
		} `json:"ledger"`
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		return fmt.Errorf("failed to parse daemon.json: %w", err)
	}
	for _, account := range cfg.Ledger.Accounts {
		t.preforkGenesisAccounts = append(t.preforkGenesisAccounts, account.Pk)
	}
	if len(t.preforkGenesisAccounts) == 0 {
		return fmt.Errorf("daemon.json has no genesis ledger accounts")
	}
	t.Logger.Info("Recorded %d accounts of the main network genesis ledger", len(t.preforkGenesisAccounts))
	return nil
}

// EnsureMainArchiveStopped checks that the archive of the main network has
// stopped. Otherwise it can still write to the database during the upgrade,
// and the fork archive cannot start on the same port.
func (t *HardforkTest) EnsureMainArchiveStopped() error {
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", t.Config.ArchivePort))
	if err != nil {
		return fmt.Errorf("archive port %d is still in use after the main network stopped: %w", t.Config.ArchivePort, err)
	}
	return listener.Close()
}

var upgradeSetting = regexp.MustCompile(`(?m)^SET archive\.(target_protocol_version|migration_version) = '([^']+)';`)

// UpgradeArchiveSchema applies the fork version's upgrade.sql to the database
// of the main network and checks the recorded migration.
func (t *HardforkTest) UpgradeArchiveSchema() error {
	script, err := os.ReadFile(t.Config.ForkArchiveUpgradeScript)
	if err != nil {
		return err
	}
	settings := map[string]string{}
	for _, m := range upgradeSetting.FindAllStringSubmatch(string(script), -1) {
		settings[m[1]] = m[2]
	}
	protocolVersion, migrationVersion := settings["target_protocol_version"], settings["migration_version"]
	if protocolVersion == "" || migrationVersion == "" {
		return fmt.Errorf("%s does not set archive.target_protocol_version and archive.migration_version", t.Config.ForkArchiveUpgradeScript)
	}

	t.Logger.Info("Upgrading the archive schema with %s (protocol %s, migration %s)...", t.Config.ForkArchiveUpgradeScript, protocolVersion, migrationVersion)
	cmd := exec.Command("psql", "-X", "-v", "ON_ERROR_STOP=1", t.Config.PgURI, "-f", t.Config.ForkArchiveUpgradeScript)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("archive upgrade script failed: %w", err)
	}

	return t.runToolbox("verify-upgrade", "--protocol-version", protocolVersion, "--migration-version", migrationVersion)
}

// mergeJSON returns base with overlay merged into it: objects merge key by
// key, any other overlay value replaces the base value.
func mergeJSON(base, overlay any) any {
	baseObj, baseIsObj := base.(map[string]any)
	overlayObj, overlayIsObj := overlay.(map[string]any)
	if !baseIsObj || !overlayIsObj {
		return overlay
	}
	merged := map[string]any{}
	for k, v := range baseObj {
		merged[k] = v
	}
	for k, v := range overlayObj {
		if b, ok := merged[k]; ok {
			merged[k] = mergeJSON(b, v)
		} else {
			merged[k] = v
		}
	}
	return merged
}

// WriteArchiveForkConfig writes the runtime config of the fork archive. Call
// it after CleanUpNetworkForForkPhase.
func (t *HardforkTest) WriteArchiveForkConfig() error {
	seed := t.Config.DaemonInfos[0]
	readJSON := func(path string) (any, error) {
		data, err := os.ReadFile(path)
		if err != nil {
			return nil, err
		}
		var v any
		if err := json.Unmarshal(data, &v); err != nil {
			return nil, fmt.Errorf("failed to parse %s: %w", path, err)
		}
		return v, nil
	}
	// The fork daemon loads its config-directory daemon.json (the fork
	// config) first, then overlays the network daemon.json.
	forkConfig, err := readJSON(filepath.Join(seed.NodeDirRel(t.Config.Root), "daemon.json"))
	if err != nil {
		return err
	}
	networkConfig, err := readJSON(filepath.Join(t.Config.Root, "daemon.json"))
	if err != nil {
		return err
	}
	merged, err := json.Marshal(mergeJSON(forkConfig, networkConfig))
	if err != nil {
		return err
	}
	if err := os.WriteFile(t.archiveForkConfigFile(), merged, 0644); err != nil {
		return err
	}
	t.Logger.Info("Wrote the fork archive config %s (genesis ledgers in %s)", t.archiveForkConfigFile(), t.forkGenesisDir)
	return nil
}

// RepairAndValidateArchive repairs the archive data after the fork and checks
// it. forkGenesis is the genesis block of the fork network, and
// latestPreForkHeight the height of the last pre-fork block.
func (t *HardforkTest) RepairAndValidateArchive(forkGenesis client.BlockData, latestPreForkHeight int) error {
	t.Logger.Info("Waiting for the fork genesis block %s in the archive...", forkGenesis.StateHash)
	deadline := time.Now().Add(time.Duration(t.Config.ArchiveWaitMinutes) * time.Minute)
	for {
		n, err := t.psqlInt(fmt.Sprintf("SELECT count(*) FROM blocks WHERE state_hash = '%s'", forkGenesis.StateHash))
		if err == nil && n == 1 {
			break
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("fork genesis block %s is not in the archive after %d minutes (last error: %v)", forkGenesis.StateHash, t.Config.ArchiveWaitMinutes, err)
		}
		time.Sleep(time.Duration(t.Config.PollingIntervalSeconds) * time.Second)
	}

	t.Logger.Info("Settling the pending pre-fork blocks...")
	if err := t.runToolbox("convert-chain-to-canonical"); err != nil {
		return err
	}

	t.Logger.Info("Writing the fork genesis ledger to genesis_accounts...")
	if err := t.runToolbox("populate-genesis-accounts", "--config-file", t.archiveForkConfigFile()); err != nil {
		return err
	}

	if err := t.runToolbox("validate-fork",
		"--fork-state-hash", forkGenesis.StateHash,
		"--fork-slot", strconv.Itoa(forkGenesis.Slot)); err != nil {
		return err
	}

	return t.validateArchiveData(forkGenesis, latestPreForkHeight)
}

func (t *HardforkTest) validateArchiveData(forkGenesis client.BlockData, latestPreForkHeight int) error {
	pending, err := t.psqlInt(fmt.Sprintf(
		"SELECT count(*) FROM blocks WHERE chain_status = 'pending' AND global_slot_since_genesis < %d",
		forkGenesis.Slot))
	if err != nil {
		return err
	}
	if pending != 0 {
		return fmt.Errorf("archive still has %d pending pre-fork blocks after the repair", pending)
	}

	out, err := t.psql(fmt.Sprintf(
		"SELECT count(*), count(DISTINCT height), coalesce(min(height), 0), coalesce(max(height), 0) FROM blocks WHERE chain_status = 'canonical' AND height <= %d",
		latestPreForkHeight))
	if err != nil {
		return err
	}
	expected := fmt.Sprintf("%d|%d|1|%d", latestPreForkHeight, latestPreForkHeight, latestPreForkHeight)
	if out != expected {
		return fmt.Errorf("canonical pre-fork chain is not one block per height 1..%d: count|distinct|min|max = %s", latestPreForkHeight, out)
	}

	out, err = t.psql(fmt.Sprintf("SELECT public_key FROM genesis_accounts WHERE genesis_height = %d", forkGenesis.BlockHeight))
	if err != nil {
		return err
	}
	present := map[string]bool{}
	for _, pk := range strings.Fields(out) {
		present[pk] = true
	}
	for _, pk := range t.preforkGenesisAccounts {
		if !present[pk] {
			return fmt.Errorf("genesis_accounts has no row for %s at the fork genesis height %d (%d rows)", pk, forkGenesis.BlockHeight, len(present))
		}
	}

	t.Logger.Info("Archive is consistent: no pending pre-fork block, canonical chain 1..%d, %d genesis_accounts rows at height %d",
		latestPreForkHeight, len(present), forkGenesis.BlockHeight)
	return nil
}
