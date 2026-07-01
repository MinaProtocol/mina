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
// archive ingest the overflowing field array; and finally a probe starts the Mesa
// archive over the fork genesis config to exercise add_genesis_accounts.
//
// Buggy binaries + the migration that keeps the element_ids UNIQUE reproduce both
// bugs and AssertArchiveBugsAbsent returns an error (the test exits non-zero);
// the fixed archive + the element_ids-dropping migration reproduce neither and the
// test passes.

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// itnPort returns the seed daemon's ITN GraphQL port (daemon base port + 5).
func (t *HardforkTest) itnPort() int { return t.Config.SeedStartPort + 5 }

// forkGenesisConfigPath returns the post-fork seed daemon.json (moved into place
// by CleanUpNetworkForForkPhase), used as the genesis config for the #18941 probe.
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

	if c.ProbeArchiveExe == "" {
		c.ProbeArchiveExe = c.ForkArchiveExe
	}
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
	bugReproduced  bugStatus = iota // the bug definitively reproduced
	bugClean                        // the bug is definitively absent (fix verified)
	bugInconclusive                 // neither could be established (setup/timing issue)
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
	logPath := filepath.Join(t.Config.Root, "fork-network.log")
	if data, err := os.ReadFile(logPath); err == nil {
		s := string(data)
		if strings.Contains(s, "exceeds btree") ||
			strings.Contains(s, "zkapp_field_array_element_ids_key") ||
			strings.Contains(s, "zkapp_events_element_ids_key") {
			if raw := lineContaining(s, "exceeds btree"); raw != "" {
				t.Logger.Info("Archive repro: element_ids raw signal: %s", raw)
			}
			return bugReproduced, "Mesa archive logged the element_ids btree-overflow error"
		}
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

// ProbeAddGenesisAccounts starts the Mesa probe archive over the shared DB with
// the fork genesis config and reports whether #18941 (tokens_value_key) reproduced
// in add_genesis_accounts:
//   - bugReproduced: add_genesis_accounts hit tokens_value_key (buggy archive).
//   - bugClean: the archive logged "Archive process ready" (genesis accounts added
//     without collision — the fix).
//   - bugInconclusive: the probe could not even reach add_genesis_accounts (no
//     ledger tars staged, or it failed to load the hash-referenced fork genesis
//     ledger), or it timed out / exited without a decisive signal. These must NOT
//     be read as "fixed": a probe that never ran the collision path proves nothing.
func (t *HardforkTest) ProbeAddGenesisAccounts(genesisConfig string) (bugStatus, string) {
	t.Logger.Info("Archive repro: probing add_genesis_accounts (%s over %s)",
		t.Config.ProbeArchiveExe, t.Config.ArchivePgUri)
	// The fork genesis config references its ledger by hash (not inline accounts),
	// so the probe archive must load the ledger tarball to materialize the genesis
	// accounts. Those tars live under the fork node's chain-state dir, which is NOT
	// in the archive's ledger search path — without staging them the probe dies with
	// "Could not find a ledger tar file for hash ..." before add_genesis_accounts
	// runs, masking #18941. Stage them into the autogen cache the archive searches.
	if n := t.stageGenesisLedgerTars(); n == 0 {
		return bugInconclusive, "no genesis/epoch ledger tars were staged; the probe cannot load the fork " +
			"genesis ledger and would never reach add_genesis_accounts (would mask #18941)"
	}
	cmd := exec.Command(t.Config.ProbeArchiveExe, "run",
		"--postgres-uri", t.Config.ArchivePgUri,
		"--server-port", strconv.Itoa(t.Config.ArchivePort+10),
		"--config-file", genesisConfig)
	var buf bytes.Buffer
	cmd.Stdout = &buf
	cmd.Stderr = &buf
	if err := cmd.Start(); err != nil {
		return bugInconclusive, fmt.Sprintf("failed to start probe archive: %v", err)
	}
	done := make(chan struct{})
	go func() { cmd.Wait(); close(done) }()
	kill := func() {
		if cmd.Process != nil {
			cmd.Process.Kill()
		}
	}
	// scan returns (decided, status). A genesis-ledger load failure is treated as
	// inconclusive (the probe never reached add_genesis_accounts), NOT as clean.
	scan := func() (bool, bugStatus) {
		s := buf.String()
		if strings.Contains(s, "tokens_value_key") || strings.Contains(s, "Failed to add genesis accounts") {
			return true, bugReproduced
		}
		if strings.Contains(s, "Could not find a ledger tar file") ||
			strings.Contains(s, "Could not get precomputed values") ||
			strings.Contains(s, "Could not find or generate") {
			return true, bugInconclusive
		}
		if strings.Contains(s, "Archive process ready") {
			return true, bugClean
		}
		// Not yet decided. The bugStatus here is a sentinel only — every caller gates
		// on the bool (decided) first, so this value is never consumed while
		// decided==false; bugInconclusive makes the "undetermined" intent explicit.
		return false, bugInconclusive
	}
	// Loading the hash-referenced genesis ledger and inserting accounts in chunks of
	// 100 before the collision can take minutes on a loaded box, so allow ample time;
	// a timeout is inconclusive, never "fixed".
	timeout := time.After(600 * time.Second)
	decide := func(st bugStatus) (bugStatus, string) {
		s := buf.String()
		switch st {
		case bugReproduced:
			// Echo the raw DB-side collision so it lands in the main test log; it
			// otherwise appears only in the shared Postgres log.
			if raw := lineContaining(s, "tokens_value_key"); raw != "" {
				t.Logger.Info("Archive repro: probe raw signal: %s", raw)
			}
			return bugReproduced, "add_genesis_accounts hit tokens_value_key (#18941 reproduced)"
		case bugClean:
			if raw := lineContaining(s, "Archive process ready"); raw != "" {
				t.Logger.Info("Archive repro: probe raw signal: %s", raw)
			}
			return bugClean, "probe archive started cleanly (add_genesis_accounts succeeded; #18941 fixed)"
		default:
			return bugInconclusive, "probe could not load the fork genesis ledger / no decisive signal: " +
				firstLine(tail(buf.String(), 400))
		}
	}
	for {
		if decided, st := scan(); decided {
			kill()
			return decide(st)
		}
		select {
		case <-done:
			if _, st := scan(); st == bugReproduced {
				return decide(bugReproduced)
			}
			// The fixed archive stays running (decided clean above before exit), so a
			// process exit here means a crash without the collision — inconclusive.
			return bugInconclusive, "probe archive exited without a decisive signal: " +
				firstLine(tail(buf.String(), 400))
		case <-timeout:
			kill()
			return bugInconclusive, "probe timed out without a decisive signal: " + firstLine(tail(buf.String(), 400))
		case <-time.After(2 * time.Second):
		}
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
	t.Logger.Info("Archive repro: staged %d genesis/epoch ledger tar(s) into %s for the #18941 probe", staged, cacheDir)
	return staged
}

// AssertArchiveBugsAbsent runs the post-fork bug probes and detection. Returns nil
// when the archive is healthy (fixes applied) and a non-nil error enumerating the
// reproduced bugs otherwise, so the hardfork test exits non-zero against the buggy
// archive/migration and passes against the fixed ones.
func (t *HardforkTest) AssertArchiveBugsAbsent(genesisConfig string) error {
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

	if genesisConfig == "" {
		record("#18941 tokens_value_key", bugInconclusive, "no fork genesis config available for the probe")
	} else {
		st, detail := t.ProbeAddGenesisAccounts(genesisConfig)
		record("#18941 tokens_value_key", st, detail)
	}

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
