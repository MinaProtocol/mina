package hardfork

// Archive-node bug reproduction integrated into the hardfork test.
//
// When --repro-archive-bugs is set, the test drives real transaction load across
// the fork and asserts the archive node is free of two known bugs:
//
//   - #18941 "tokens_value_key": at post-fork archive startup, add_genesis_accounts
//     re-inserts an already-owned custom token as ownerless and collides on the
//     tokens_value_key UNIQUE(value) constraint.
//   - "element_ids btree overflow": the Mesa archive cannot insert a max-cost
//     zkApp's 1024-element field array into the UNIQUE btree on
//     zkapp_field_array.element_ids (index row exceeds the btree page maximum).
//
// To produce real triggering data: a custom-token ITN load on the pre-fork
// (compatible) network mints an OWNED custom token that the compatible archive
// records; at the fork transition the shared archive DB is migrated to the Mesa
// schema; a max-cost ITN load on the post-fork (Mesa) network makes the Mesa
// archive ingest the overflowing field array; and the post-fork archive node runs
// add_genesis_accounts at its own startup over the fork genesis config (the #18941
// path), exercised on the real live node rather than a synthetic probe.
//
// Buggy binaries + the migration that keeps the element_ids UNIQUE reproduce both
// bugs and AssertArchiveBugsAbsent returns an error (the test exits non-zero);
// the fixed archive + the element_ids-dropping migration reproduce neither and the
// test passes.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// itnPort returns the seed daemon's ITN GraphQL port (daemon base port + 5).
func (t *HardforkTest) itnPort() int { return t.Config.SeedStartPort + 5 }

// forkGenesisConfigPath returns the post-fork seed daemon.json (moved into place by
// CleanUpNetworkForForkPhase), the genesis config the live archive node loads at
// startup to run add_genesis_accounts (the #18941 path).
func (t *HardforkTest) forkGenesisConfigPath() string {
	for _, info := range t.Config.DaemonInfos {
		if info.Name == "seed" {
			return filepath.Join(info.NodeDirRel(t.Config.Root), "daemon.json")
		}
	}
	if len(t.Config.DaemonInfos) > 0 {
		return filepath.Join(t.Config.DaemonInfos[0].NodeDirRel(t.Config.Root), "daemon.json")
	}
	return ""
}

// firstLine returns the first line of s (for compact logging).
func firstLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return s[:i]
	}
	return s
}

// lineContaining returns the first line of s containing sub (trimmed), or "".
// Used to echo a spawned archive's decisive raw log line into the main test log,
// so each run is self-contained — the raw DB-side error (e.g. the tokens_value_key
// violation) otherwise lands only in the shared Postgres log, not the test output.
func lineContaining(s, sub string) string {
	for _, line := range strings.Split(s, "\n") {
		if strings.Contains(line, sub) {
			return strings.TrimSpace(line)
		}
	}
	return ""
}

// InitArchiveRepro prepares the environment for the archive-bug reproduction:
// fills in derived config, generates the ITN auth key, resets the shared archive
// DB, and exports the env vars that network.go / mina-local-network.sh read to
// wire the live archive node and the ITN endpoints. No-op unless enabled.
func (t *HardforkTest) InitArchiveRepro() error {
	if !t.Config.ReproArchiveBugs {
		return nil
	}
	c := t.Config
	// Default the #18941 verdict to inconclusive; StartForkArchive overwrites it at the
	// live archive's startup. If that never runs, the assertion fails closed.
	t.bug18941 = bugInconclusive
	t.bug18941Detail = "the live post-fork archive was never started"

	if c.ItnKeyPath == "" {
		// The ITN auth key MUST live outside Root: mina-local-network.sh does
		// `rm -rf $ROOT` when it (re)initializes the main network (config=reset),
		// which would delete a key placed inside Root. The daemon would still hold
		// its pubkey (passed via --itn-keys before the wipe), but the client would
		// then have no matching private key and ITN auth would fail for the whole
		// run. A sibling path survives the wipe and keeps the keypair consistent
		// across both the pre-fork (reset) and post-fork (inherit) networks.
		// Clean first: a trailing slash on --root would otherwise yield
		// "<root>/.itn_key.pem" (inside Root), which the wipe would delete.
		root := filepath.Clean(c.Root)
		c.ItnKeyPath = filepath.Join(filepath.Dir(root), filepath.Base(root)+".itn_key.pem")
	}
	c.ArchivePgUri = fmt.Sprintf("postgresql://%s@%s:%d/%s",
		c.ArchivePgUser, c.ArchivePgHost, c.ArchivePgPort, c.ArchivePgDb)

	for _, p := range []struct{ name, val string }{
		{"--main-archive-exe", c.MainArchiveExe},
		{"--fork-archive-exe", c.ForkArchiveExe},
		{"--create-schema-file", c.CreateSchemaFile},
		{"--migration-sql", c.MigrationSql},
	} {
		if p.val == "" {
			return fmt.Errorf("--repro-archive-bugs requires %s", p.name)
		}
		if _, err := os.Stat(p.val); err != nil {
			return fmt.Errorf("%s: %s: %w", p.name, p.val, err)
		}
	}

	if err := os.MkdirAll(c.Root, 0755); err != nil {
		return err
	}
	// Generate the ITN ed25519 auth keypair in-process (crypto/ed25519). The base64
	// of the 32-byte public key is the value the daemon receives via --itn-keys; the
	// matching private key stays in memory and signs ITN requests directly, so the
	// main-network root wipe can no longer strand the client (it never reads a file).
	itn, err := newItnAuth()
	if err != nil {
		return err
	}
	t.itn = itn
	c.ItnPubKey = itn.pubB64
	if err := itn.writePEM(c.ItnKeyPath); err != nil {
		t.Logger.Info("Archive repro: could not write ITN key PEM %s (non-fatal): %v", c.ItnKeyPath, err)
	}
	t.Logger.Info("Archive repro: ITN key %s pub=%s", c.ItnKeyPath, itn.pubB64)

	// Reset the shared archive DB; mina-local-network.sh recreates+schemas it.
	maint := fmt.Sprintf("postgresql://%s@%s:%d/%s",
		c.ArchivePgUser, c.ArchivePgHost, c.ArchivePgPort, c.ArchivePgUser)
	if out, err := exec.Command("psql", maint, "-c",
		"DROP DATABASE IF EXISTS "+c.ArchivePgDb+";").CombinedOutput(); err != nil {
		t.Logger.Info("Archive repro: drop DB warning: %v: %s", err, strings.TrimSpace(string(out)))
	}

	// Env consumed by network.go (archive + ITN wiring) and mina-local-network.sh
	// (Postgres connection + schema). The pre-fork archive is compatible-lineage,
	// the post-fork archive is Mesa-lineage (bin_io must match the phase daemon).
	os.Setenv("HARDFORK_ARCHIVE_PORT", strconv.Itoa(c.ArchivePort))
	// The post-fork (inherit-mode) archive is started by Go (StartForkArchive), not by
	// mina-local-network.sh, so it can run add_genesis_accounts at startup and exercise
	// #18941 on the real node. The pre-fork (reset-mode) archive is still script-spawned.
	os.Setenv("HARDFORK_ARCHIVE_EXTERNAL", "1")
	os.Setenv("MAIN_ARCHIVE_EXE", c.MainArchiveExe)
	os.Setenv("FORK_ARCHIVE_EXE", c.ForkArchiveExe)
	os.Setenv("CREATE_SCHEMA_FILE", c.CreateSchemaFile)
	os.Setenv("HARDFORK_ITN_KEYS_MAIN", c.ItnPubKey)
	os.Setenv("HARDFORK_ITN_KEYS_FORK", c.ItnPubKey)
	os.Setenv("PG_HOST", c.ArchivePgHost)
	os.Setenv("PG_PORT", strconv.Itoa(c.ArchivePgPort))
	os.Setenv("PG_USER", c.ArchivePgUser)
	os.Setenv("PG_PW", "")
	os.Setenv("PG_DB", c.ArchivePgDb)
	// Keep BOTH networks quiet apart from their ITN loads. Post-fork: the only zkApp
	// traffic the Mesa archive sees is the max-cost overflow trigger. Pre-fork: the
	// custom-token ITN load (driven in-daemon over GraphQL) is the only traffic, and
	// it alone produces Bug A's owned-token data. Disabling the built-in value-transfer
	// loop here is also essential for resource reasons: it spawns a `mina client
	// send-payment` subprocess (each forking a `brew --prefix` shell) per payment,
	// which — concurrently with 2 daemons, snark workers, the archive and Postgres —
	// exhausts the cgroup pid limit (pids.max=512) and crashes the run with
	// "fork: Resource temporarily unavailable". The chain still produces blocks (the
	// pre-fork validations check slot occupancy, not user commands), so this is safe.
	os.Setenv("HARDFORK_VALUE_TRANSFERS_MAIN", "0")
	os.Setenv("HARDFORK_VALUE_TRANSFERS_FORK", "0")
	return nil
}

// psqlQuery runs a single-value query against the archive DB.
func (t *HardforkTest) psqlQuery(query string) (string, error) {
	out, err := exec.Command("psql", t.Config.ArchivePgUri, "-tAc", query).CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("psql query failed: %v: %s", err, strings.TrimSpace(string(out)))
	}
	return strings.TrimSpace(string(out)), nil
}

func (t *HardforkTest) psqlCount(query string) int {
	out, err := t.psqlQuery(query)
	if err != nil {
		return -1
	}
	n, err := strconv.Atoi(out)
	if err != nil {
		return -1
	}
	return n
}

func (t *HardforkTest) ownedTokenCount() int {
	return t.psqlCount("select count(*) from tokens where owner_public_key_id is not null;")
}

// feePayerKeys discovers the offline whale private keys to use as ITN fee payers.
func (t *HardforkTest) feePayerKeys() []string {
	dir := filepath.Join(t.Config.Root, "offline_whale_keys")
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil
	}
	var keys []string
	for _, e := range entries {
		name := e.Name()
		if strings.HasSuffix(name, ".pub") || !strings.HasPrefix(name, "offline_whale_account_") {
			continue
		}
		cmd := exec.Command(t.Config.MainMinaExe, "advanced", "dump-keypair",
			"--privkey-path", filepath.Join(dir, name))
		cmd.Env = append(os.Environ(), "MINA_PRIVKEY_PASS=naughty blue worm")
		out, err := cmd.Output()
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(out), "\n") {
			if strings.HasPrefix(line, "Private key: ") {
				keys = append(keys, strings.TrimSpace(strings.TrimPrefix(line, "Private key: ")))
			}
		}
	}
	return keys
}

func (t *HardforkTest) waitItnAuth(port, attempts int) bool {
	url := itnURL(port)
	var lastErr error
	for i := 0; i < attempts; i++ {
		if _, _, err := t.itn.auth(url); err == nil {
			t.Logger.Info("Archive repro: ITN authenticated on :%d after %d attempt(s)", port, i+1)
			return true
		} else {
			lastErr = err
		}
		// Surface the real client error (connection refused / 401 / GraphQL) instead
		// of silently retrying — the swallowed error previously hid auth failures.
		if i == 0 || (i+1)%6 == 0 {
			t.Logger.Info("Archive repro: ITN auth :%d attempt %d/%d not ready (err=%v)",
				port, i+1, attempts, lastErr)
		}
		time.Sleep(5 * time.Second)
	}
	t.Logger.Error("Archive repro: ITN auth never succeeded on :%d after %d attempts; last err=%v",
		port, attempts, lastErr)
	return false
}

// scheduleWithBestTipRetry runs an ITN schedule mutation, retrying until the daemon
// has a best-tip ledger (the scheduler rejects the request otherwise).
func (t *HardforkTest) scheduleWithBestTipRetry(schedule func() (string, error), attempts int) error {
	for i := 0; i < attempts; i++ {
		handle, err := schedule()
		if err == nil {
			t.Logger.Info("Archive repro: ITN scheduled (handle %s)", firstLine(handle))
			return nil
		}
		t.Logger.Info("Archive repro: ITN schedule attempt %d not ready: %v", i+1, err)
		time.Sleep(8 * time.Second)
	}
	return fmt.Errorf("ITN schedule did not succeed after %d attempts", attempts)
}

// DriveTokenLoadPreFork schedules the persistent custom-token ITN load on the
// pre-fork network and blocks until an owned custom token is recorded in the
// archive DB (so it carries into the fork genesis ledger).
func (t *HardforkTest) DriveTokenLoadPreFork() error {
	port := t.itnPort()
	url := itnURL(port)
	t.Logger.Info("Archive repro: driving pre-fork custom-token load on ITN :%d", port)
	if !t.waitItnAuth(port, 120) {
		return fmt.Errorf("pre-fork ITN endpoint did not authenticate on :%d", port)
	}
	keys := t.feePayerKeys()
	if len(keys) == 0 {
		return fmt.Errorf("no fee payer (offline whale) keys found under %s", t.Config.Root)
	}
	load := zkappLoadParams{
		feePayers: keys, numZkapps: 0, numNewAccounts: 0,
		durationMin: 6, tps: 0.5, memoPrefix: "tokload", nonDefaultToken: true,
	}
	if err := t.scheduleWithBestTipRetry(func() (string, error) {
		return t.itn.scheduleZkappCommands(url, load)
	}, 60); err != nil {
		return err
	}
	t.Logger.Info("Archive repro: waiting for the owned custom token in the archive DB...")
	for i := 0; i < 150; i++ {
		if n := t.ownedTokenCount(); n >= 1 {
			t.Logger.Info("Archive repro: owned custom token recorded in archive DB (count=%d)", n)
			return nil
		}
		time.Sleep(10 * time.Second)
	}
	return fmt.Errorf("owned custom token never appeared in the archive DB (pre-fork load failed)")
}

// ApplyMigration runs the Berkeley->Mesa migration on the shared archive DB at the
// fork transition (pre-fork archive stopped, post-fork archive not yet started).
func (t *HardforkTest) ApplyMigration() error {
	if !t.Config.ReproArchiveBugs {
		return nil
	}
	t.Logger.Info("Archive repro: applying migration %s", t.Config.MigrationSql)
	out, err := exec.Command("psql", t.Config.ArchivePgUri, "-v", "ON_ERROR_STOP=1",
		"-q", "-f", t.Config.MigrationSql).CombinedOutput()
	if err != nil {
		return fmt.Errorf("migration failed: %v: %s", err, strings.TrimSpace(string(out)))
	}
	ver, _ := t.psqlQuery("select max(migration_version) from migration_history;")
	t.Logger.Info("Archive repro: migration applied (version=%s)", ver)
	return nil
}

// DriveMaxCostLoadPostFork schedules the max-cost zkApp load on the post-fork
// (Mesa) network so the Mesa archive ingests a Shape-B 1024-element field array,
// the element_ids btree overflow trigger.
func (t *HardforkTest) DriveMaxCostLoadPostFork() error {
	port := t.itnPort()
	url := itnURL(port)
	t.Logger.Info("Archive repro: driving post-fork max-cost load on ITN :%d", port)
	if !t.waitItnAuth(port, 60) {
		return fmt.Errorf("post-fork ITN endpoint did not authenticate on :%d", port)
	}
	keys := t.feePayerKeys()
	if len(keys) == 0 {
		return fmt.Errorf("no fee payer keys for the post-fork max-cost load")
	}
	load := zkappLoadParams{
		feePayers: []string{keys[0]}, numZkapps: 2, numUpdates: 15,
		durationMin: 5, tps: 0.3, memoPrefix: "maxcost", maxCost: true,
	}
	return t.scheduleWithBestTipRetry(func() (string, error) {
		return t.itn.scheduleZkappCommands(url, load)
	}, 60)
}

// bugStatus is the three-valued result of a bug check. The detection is
// fail-closed: only bugClean lets the test pass, so an indeterminate check
// (bugInconclusive) fails the run rather than masquerading as either a clean
// fix (false exit 0) or a reproduced bug (false exit 1).
type bugStatus int

const (
	bugReproduced   bugStatus = iota // the bug definitively reproduced
	bugClean                         // the bug is definitively absent (fix verified)
	bugInconclusive                  // neither could be established (setup/timing issue)
)

// DetectElementIdsOverflow reports whether the element_ids btree overflow
// reproduced on the Mesa archive.
//   - bugReproduced: the live Mesa archive logged the btree-overflow error.
//   - bugClean: a large (Shape-B, >=100-element) element_ids array was archived
//     successfully — only possible once the UNIQUE index is dropped (the fix).
//   - bugInconclusive: neither signal is present, i.e. the max-cost load delivered
//     no Shape-B 1024-element command to the archive, so the overflow could be
//     neither triggered nor shown fixed. (We must NOT treat "only small Shape-A
//     arrays archived" as reproduced — that false-positives the fixed run.)
func (t *HardforkTest) DetectElementIdsOverflow() (bugStatus, string) {
	// The btree-overflow error surfaces in the live archive's log (now Go-owned,
	// t.forkArchiveLog) and — for older/script-spawned setups — in fork-network.log.
	var s string
	for _, logPath := range []string{t.forkArchiveLog, filepath.Join(t.Config.Root, "fork-network.log")} {
		if logPath == "" {
			continue
		}
		if data, err := os.ReadFile(logPath); err == nil {
			s += string(data)
		}
	}
	if strings.Contains(s, "exceeds btree") ||
		strings.Contains(s, "zkapp_field_array_element_ids_key") ||
		strings.Contains(s, "zkapp_events_element_ids_key") {
		if raw := lineContaining(s, "exceeds btree"); raw != "" {
			t.Logger.Info("Archive repro: element_ids raw signal: %s", raw)
		}
		return bugReproduced, "Mesa archive logged the element_ids btree-overflow error"
	}
	large := t.psqlCount("select count(*) from zkapp_field_array where coalesce(array_length(element_ids,1),0) >= 100;")
	total := t.psqlCount("select count(*) from zkapp_field_array;")
	t.Logger.Info("Archive repro: element_ids check: total field-array rows=%d, large(>=100)=%d", total, large)
	if large >= 1 {
		return bugClean, fmt.Sprintf("a large (>=100) element_ids array was archived (count=%d): btree overflow fixed", large)
	}
	return bugInconclusive, fmt.Sprintf(
		"no btree-overflow error was logged and no large element_ids array was archived (total field-array rows=%d); "+
			"the max-cost load delivered no Shape-B 1024-element command to the archive, so the overflow is undetermined", total)
}

// StartForkArchive starts the post-fork (Mesa) archive node the way production does —
// with the fork genesis config, so it runs add_genesis_accounts at startup, the code
// path where #18941 lives. This is the live archive node the fork daemons stream blocks
// to (it binds the archive server port), so #18941 is exercised on the REAL node
// startup rather than a synthetic post-teardown probe. The verdict is recorded in
// t.bug18941 for AssertArchiveBugsAbsent. Called after ApplyMigration, before the fork
// daemons start, so the node is listening before any fork block is produced.
//
//   - fixed archive: add_genesis_accounts succeeds ("Archive process ready"); the node
//     stays up and ingests the fork blocks, incl. the max-cost element_ids array.
//   - buggy archive: add_genesis_accounts collides on tokens_value_key and the node
//     exits (#18941 reproduced at real startup). The collision happens before the fork
//     network's first block, so we then start a FALLBACK archive WITHOUT the genesis
//     config (skipping add_genesis_accounts) on the same port, so the fork blocks are
//     still archived and the element_ids check has its data.
func (t *HardforkTest) StartForkArchive(genesisConfig string) error {
	t.forkArchiveLog = filepath.Join(t.Config.Root, "fork-archive.log")
	// The fork genesis config references its ledger by hash (not inline accounts), so
	// the archive must load the ledger tarball to materialize the genesis accounts.
	// Those tars live under the fork node's chain-state dir, NOT in the archive's search
	// path — without staging them add_genesis_accounts dies with "Could not find a
	// ledger tar file ..." before the collision, masking #18941.
	if n := t.stageGenesisLedgerTars(); n == 0 {
		t.bug18941 = bugInconclusive
		t.bug18941Detail = "no genesis/epoch ledger tars were staged; the live archive could not run " +
			"add_genesis_accounts (would mask #18941)"
		t.Logger.Error("Archive repro: %s", t.bug18941Detail)
		// Still bring up a plain archive so the element_ids path remains testable.
		cmd, err := t.spawnForkArchive(genesisConfig, false)
		if err != nil {
			return err
		}
		t.forkArchiveCmd = cmd
		return nil
	}
	t.Logger.Info("Archive repro: starting post-fork archive with add_genesis_accounts "+
		"(fork genesis %s over %s)", genesisConfig, t.Config.ArchivePgUri)
	cmd, err := t.spawnForkArchive(genesisConfig, true) // WITH --config-file -> add_genesis_accounts
	if err != nil {
		return err
	}
	st, detail := t.watchForkArchiveStartup(cmd)
	t.bug18941, t.bug18941Detail = st, detail
	switch st {
	case bugClean:
		t.Logger.Info("Archive repro: #18941 absent at live archive startup: %s", detail)
		t.forkArchiveCmd = cmd // healthy live archive; keep it running to ingest blocks
		return nil
	case bugReproduced:
		t.Logger.Error("Archive repro: REPRODUCED #18941 at live archive startup: %s", detail)
	default:
		t.Logger.Error("Archive repro: #18941 inconclusive at live archive startup: %s", detail)
	}
	// #18941 reproduced or inconclusive: the add_genesis_accounts archive is gone.
	// Start a fallback archive WITHOUT the genesis config so the fork blocks (and the
	// element_ids max-cost array) are still archived for the element_ids check.
	t.stopProc(cmd)
	fb, err := t.spawnForkArchive(genesisConfig, false)
	if err != nil {
		return fmt.Errorf("failed to start fallback fork archive: %w", err)
	}
	t.forkArchiveCmd = fb
	t.Logger.Info("Archive repro: fallback fork archive started (no add_genesis_accounts) for the element_ids check")
	return nil
}

// spawnForkArchive starts a Mesa archive node on the archive server port, appending its
// output to t.forkArchiveLog. With withConfig it passes --config-file (running
// add_genesis_accounts at startup); without it, the archive skips genesis loading and
// simply archives incoming blocks via RPC.
func (t *HardforkTest) spawnForkArchive(genesisConfig string, withConfig bool) (*exec.Cmd, error) {
	args := []string{"run",
		"--postgres-uri", t.Config.ArchivePgUri,
		"--server-port", strconv.Itoa(t.Config.ArchivePort)}
	if withConfig {
		args = append(args, "--config-file", genesisConfig)
	}
	cmd := exec.Command(t.Config.ForkArchiveExe, args...)
	f, err := os.OpenFile(t.forkArchiveLog, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return nil, fmt.Errorf("open fork archive log: %w", err)
	}
	cmd.Stdout = f
	cmd.Stderr = f
	if err := cmd.Start(); err != nil {
		f.Close()
		return nil, fmt.Errorf("start fork archive: %w", err)
	}
	return cmd, nil
}

// watchForkArchiveStartup watches a just-started add_genesis_accounts archive for its
// decisive signal, reading t.forkArchiveLog. It does NOT kill the process: on bugClean
// the caller keeps it running as the live archive. Ledger-load failures / exit-without-
// signal / timeout are inconclusive (never "fixed"): an archive that never ran the
// collision path proves nothing.
func (t *HardforkTest) watchForkArchiveStartup(cmd *exec.Cmd) (bugStatus, string) {
	done := make(chan struct{})
	go func() { cmd.Wait(); close(done) }()
	read := func() string {
		data, _ := os.ReadFile(t.forkArchiveLog)
		return string(data)
	}
	classify := func(s string) (bool, bugStatus, string) {
		if strings.Contains(s, "tokens_value_key") || strings.Contains(s, "Failed to add genesis accounts") {
			if raw := lineContaining(s, "tokens_value_key"); raw != "" {
				t.Logger.Info("Archive repro: archive raw signal: %s", raw)
			}
			return true, bugReproduced, "add_genesis_accounts hit tokens_value_key at live archive startup (#18941 reproduced)"
		}
		if strings.Contains(s, "Could not find a ledger tar file") ||
			strings.Contains(s, "Could not get precomputed values") ||
			strings.Contains(s, "Could not find or generate") {
			return true, bugInconclusive, "live archive could not load the fork genesis ledger: " + firstLine(tail(s, 400))
		}
		if strings.Contains(s, "Archive process ready") {
			if raw := lineContaining(s, "Archive process ready"); raw != "" {
				t.Logger.Info("Archive repro: archive raw signal: %s", raw)
			}
			return true, bugClean, "live archive ran add_genesis_accounts and reported ready (#18941 absent)"
		}
		return false, bugInconclusive, ""
	}
	// add_genesis_accounts loads the hash-referenced genesis ledger and inserts accounts
	// in chunks before the collision, which can take minutes on a loaded box.
	timeout := time.After(600 * time.Second)
	for {
		if decided, st, detail := classify(read()); decided {
			return st, detail
		}
		select {
		case <-done:
			if decided, st, detail := classify(read()); decided {
				return st, detail
			}
			return bugInconclusive, "live archive exited during startup without a decisive signal: " +
				firstLine(tail(read(), 400))
		case <-timeout:
			return bugInconclusive, "live archive did not reach a decisive add_genesis_accounts signal within timeout"
		case <-time.After(2 * time.Second):
		}
	}
}

// StopForkArchive stops the Go-owned fork archive node (live or fallback), if any.
func (t *HardforkTest) StopForkArchive() {
	if t.forkArchiveCmd != nil {
		t.Logger.Info("Archive repro: stopping the post-fork archive node")
		t.stopProc(t.forkArchiveCmd)
		t.forkArchiveCmd = nil
	}
}

// stopProc terminates a process (SIGTERM, then wait) started by the archive-repro code.
func (t *HardforkTest) stopProc(cmd *exec.Cmd) {
	if cmd == nil || cmd.Process == nil {
		return
	}
	_ = cmd.Process.Signal(syscall.SIGTERM)
	done := make(chan struct{})
	go func() { cmd.Wait(); close(done) }()
	select {
	case <-done:
	case <-time.After(15 * time.Second):
		_ = cmd.Process.Kill()
	}
}

// tail returns the last n bytes of s.
func tail(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[len(s)-n:]
}

// ledgerCacheDir returns the autogen ledger cache the archive searches
// (Cache_dir.autogen_path = $TMPDIR/coda_cache_dir, defaulting TMPDIR to /tmp).
func ledgerCacheDir() string {
	tmp := os.Getenv("TMPDIR")
	if tmp == "" {
		tmp = "/tmp"
	}
	return filepath.Join(tmp, "coda_cache_dir")
}

// stageGenesisLedgerTars copies the fork node's genesis + epoch ledger tarballs
// from the per-node chain-state dirs (where the fork daemon wrote them) into the
// archive's autogen ledger cache, so the #18941 probe can resolve the fork genesis
// config's hash-referenced ledger and run add_genesis_accounts. No-op-safe: missing
// dirs / already-present tars are skipped. The archive selects the right tar by
// hash, so staging every matching tar (incl. the pre-fork ones) is harmless.
func (t *HardforkTest) stageGenesisLedgerTars() int {
	cacheDir := ledgerCacheDir()
	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		t.Logger.Error("Archive repro: could not create ledger cache %s: %v", cacheDir, err)
		return 0
	}
	nodesDir := filepath.Join(t.Config.Root, "nodes")
	staged := 0
	_ = filepath.Walk(nodesDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		name := info.Name()
		if !strings.HasSuffix(name, ".tar.gz") ||
			!(strings.HasPrefix(name, "genesis_ledger_") || strings.HasPrefix(name, "epoch_ledger_")) {
			return nil
		}
		dst := filepath.Join(cacheDir, name)
		if _, err := os.Stat(dst); err == nil {
			return nil // already staged
		}
		data, err := os.ReadFile(path)
		if err != nil {
			t.Logger.Error("Archive repro: could not read ledger tar %s: %v", path, err)
			return nil
		}
		if err := os.WriteFile(dst, data, 0644); err != nil {
			t.Logger.Error("Archive repro: could not stage ledger tar %s: %v", dst, err)
			return nil
		}
		staged++
		return nil
	})
	t.Logger.Info("Archive repro: staged %d genesis/epoch ledger tar(s) into %s for add_genesis_accounts", staged, cacheDir)
	return staged
}

// AssertArchiveBugsAbsent evaluates the two archive-bug checks and returns nil when the
// archive is healthy (fixes applied), or a non-nil error enumerating the reproduced bugs
// otherwise, so the hardfork test exits non-zero against the buggy archive/migration and
// passes against the fixed ones. The #18941 verdict was recorded earlier at the live
// archive node's add_genesis_accounts startup (StartForkArchive); element_ids is detected
// here from the (now-ingested) archive log + DB.
func (t *HardforkTest) AssertArchiveBugsAbsent() error {
	t.Logger.Info("===== Archive bug assertion: checking #18941 + element_ids overflow =====")
	var reproduced, inconclusive []string

	record := func(name string, st bugStatus, detail string) {
		switch st {
		case bugReproduced:
			t.Logger.Error("REPRODUCED %s: %s", name, detail)
			reproduced = append(reproduced, name+" ("+detail+")")
		case bugInconclusive:
			t.Logger.Error("INCONCLUSIVE %s: %s", name, detail)
			inconclusive = append(inconclusive, name+" ("+detail+")")
		default:
			t.Logger.Info("%s NOT reproduced: %s", name, detail)
		}
	}

	st, detail := t.DetectElementIdsOverflow()
	record("element_ids btree overflow", st, detail)

	// #18941 was decided at the live archive's startup (add_genesis_accounts).
	record("#18941 tokens_value_key", t.bug18941, t.bug18941Detail)

	// Fail-closed: a reproduced bug OR an indeterminate check both fail the run, so
	// the test only passes (exit 0) when BOTH checks definitively show the bug absent.
	if len(reproduced) > 0 {
		return fmt.Errorf("archive-node bug(s) reproduced: %s", strings.Join(reproduced, "; "))
	}
	if len(inconclusive) > 0 {
		return fmt.Errorf("archive-bug check inconclusive (failing closed — neither confirmed present nor "+
			"definitively absent): %s", strings.Join(inconclusive, "; "))
	}
	t.Logger.Info("===== Archive healthy: neither #18941 nor the element_ids overflow reproduced =====")
	return nil
}
