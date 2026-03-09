# Mina Environment Variables

The Mina daemon and its associated tools read several environment variables on
startup. This page documents all of them.

---

## Daemon

### `MINA_CLIENT_TRUSTLIST`

A comma-separated list of CIDR masks that are allowed to connect to the
daemon's client (RPC) port. Only the listed IP ranges may issue RPC commands.
By default only `127.0.0.0/8` (localhost) is trusted.

**Example:**
```
MINA_CLIENT_TRUSTLIST="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
```

The list can also be managed at runtime with
`mina advanced client-trustlist add|remove|list`.

### `MINA_CONFIG_FILE`

Path to an alternative runtime configuration file. When set, the daemon reads
genesis constants and other runtime configuration from this file, overriding
compiled-in defaults where specified.

**Example:**
```
MINA_CONFIG_FILE=/etc/mina/runtime_config.json
```

### `MINA_PRIVKEY_PASS`

Passphrase used to decrypt wallet private keys and the block-producer key. When
this variable is set the daemon (and CLI tools such as `mina accounts`) will use
it non-interactively rather than prompting for a passphrase.

### `MINA_BP_PRIVKEY`

Path to a private key file for the block producer. Setting this variable is
equivalent to passing `--block-producer-key` to the daemon.

> **Note:** The `--block-producer-key` CLI flag is deprecated in favour of this
> environment variable.

### `MINA_LIBP2P_PASS`

Passphrase used to decrypt the libp2p keypair. Required when the libp2p key
file is encrypted.

### `UPTIME_PRIVKEY_PASS`

Passphrase used to decrypt the uptime-service keypair.

### `ITN_FEATURES`

When set (to any value) the daemon enables incentivised testnet (ITN) features.

---

## Networking

### `MINA_LIBP2P_HELPER_RESTART_INTERVAL_BASE`

Base interval **in minutes** at which the libp2p helper process is
automatically restarted. When this variable is not set the helper is not
restarted automatically.

The actual restart time is `base ± MINA_LIBP2P_HELPER_RESTART_INTERVAL_DELTA`
(capped at `base / 2`).

### `MINA_LIBP2P_HELPER_RESTART_INTERVAL_DELTA`

Jitter in minutes applied to `MINA_LIBP2P_HELPER_RESTART_INTERVAL_BASE`. The
restart time is chosen uniformly in `[base − delta, base + delta]`.

Defaults to `2.5` minutes when not set.

### `MINA_EXPECTED_PER_BLOCK_DOWNLOAD_TIME`

Expected download time per block **in seconds** during catchup. Used to
estimate how long it will take to download a batch of blocks and set an
appropriate timeout.

Default: `15.0`

### `MINA_FRONTIER_DIFF_BUFFER_FLUSH_SIZE`

Overrides the flush-size of the persistent frontier diff buffer (integer
number of diffs). When not set the compiled-in default capacity is used.

---

## Performance and Memory

### `MINA_COMPACTION_MS`

Duration of each OCaml GC compaction call **in milliseconds**.

Default: `6000` (6 seconds)

### `MINA_COMPACTION_INTERVAL_MS`

Interval between successive OCaml GC compaction calls **in milliseconds**.
When not set the compiled-in default interval is used.

---

## Key and Ledger Caching

### `MINA_KEYS_PATH`

Directory that the daemon searches for pre-computed proving/verification keys.
When not set the default path `/var/lib/coda` is used (a legacy path name from
when the project was called Coda).

### `MINA_LEDGER_S3_BUCKET`

Base URL of the S3 bucket from which snark keys are fetched when they are not
found locally.

Default: `https://s3-us-west-2.amazonaws.com/snark-keys-ro.o1test.net`

---

## Hard Fork

### `MINA_HARDFORK_STATE_DIR`

Config directory expected by the hard-fork dispatcher. If this variable is set
and does not match the daemon's actual config directory, the daemon raises an
error on startup.

---

## Block Upload (Google Cloud Storage)

The following three variables must all be set to enable block uploads to GCS.

### `GCLOUD_KEYFILE`

Path to a Google Cloud service-account JSON key file used to authenticate
block uploads.

### `GCLOUD_BLOCK_UPLOAD_BUCKET`

Name of the GCS bucket that blocks are uploaded to.

### `NETWORK_NAME`

Name of the network. Used as a path component when uploading blocks to GCS and
as a filter in the delegation-verification tool.

---

## Rosetta API

### `MINA_ROSETTA_MAX_DB_POOL_SIZE`

**Required.** Maximum number of connections in the Postgres connection pool
used by the Rosetta API server. Typical values are `64` or `128`.

### `MINA_ROSETTA_PG_DATA_INTERVAL`

Interval **in seconds** at which the Rosetta server polls the Postgres archive
database.

Default: `30.0`

### `MINA_ROSETTA_MAX_HEIGHT_DELTA`

Maximum allowed difference between the Rosetta-reported chain height and the
actual best-tip height. Requests that exceed this delta are rejected.

Default: `0` (no tolerance)

---

## zkSNARK / Pickles

### `MINA_DUMP_CIRCUIT_DATA`

Set to `true`, `1`, or `yes` to write Pickles circuit data (constraint counts,
gate types, etc.) to disk for debugging.

### `PICKLES_PROFILING`

Enable detailed timing instrumentation inside the Pickles SNARK library. Set to
any non-empty string (other than `0` or `false`) to enable.

### `ERROR_ON_PROOF`

Set to `true` or `t` to treat a proof-cache miss as a fatal error instead of
regenerating the proof. Useful in CI to ensure the proof cache is up to date.

### `PROOF_CACHE_OUT`

Directory where proof cache files are written during tests.

### `MAX_VERIFIER_BATCH_SIZE`

Maximum number of SNARK proofs processed in a single verifier batch. Useful for
tuning memory usage on machines with limited RAM.

---

## Debugging

### `MINA_FRONTIER_CURRENCY_VISUALIZATION`

When set (to any value), enables total currency computation in the transition
frontier mask visualization. This is used during frontier shutdown to display
currency totals across attached ledger masks. **Warning:** enabling this causes
the frontier mask visualization at shutdown to be exceptionally slow on mainnet.

### `MINA_TIME_OFFSET`

Offset in seconds added to the system clock when computing block times. Used in
demo mode and testing to simulate a different genesis time.

Default: `0`

---

## Archive Node and Testing

### `MINA_TEST_POSTGRES`

PostgreSQL connection URI used by archive-node unit tests.

**Example:**
```
MINA_TEST_POSTGRES="postgresql://localhost:5432/archivedb"
```

### `MINA_TEST_POSTGRES_URI`

PostgreSQL connection URI used by the `mina_automation` test fixtures for the
archive node.

### `MINA_TEST_NETWORK_DATA`

Path to the directory containing network data files used by `mina_automation`
integration test fixtures.

### `POSTGRES_URI`

PostgreSQL connection URI used by various tools (e.g. the archive benchmark).

---

## Build and CI

### `MINA_COMMIT_SHA1`

Git commit SHA embedded into the binary at build time and reported by
`mina version`. This variable is set by the build system, not by the operator.

### `RUNTIME_CONFIG`

Path to a runtime configuration file. Used by the `ledger_export_benchmark`
tool.

### `CACHE_DEADLOCK_TEST_DIR`

Directory used by the disk-cache deadlock test.

### `CACHE_DEADLOCK_TEST_TIMEOUT`

Timeout in seconds for the disk-cache deadlock test.
