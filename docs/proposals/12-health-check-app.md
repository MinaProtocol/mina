# Proposal: Standalone `mina-health-check` App

## Problem

Operators have no lightweight tool to verify their Mina infrastructure is healthy. The `mina` CLI binary is a monolith (~hundreds of MB) that links the entire daemon — SNARK machinery, cryptographic backends, consensus — even for simple status queries. It cannot be installed on monitoring hosts without the full daemon. Its startup overhead (500ms-2s due to Rust FFI initialization) makes it impractical for frequent health probes.

## Decision: Why a New App (Not a CLI Subcommand)

We evaluated adding `mina health-check` as a subcommand of the existing `mina` CLI vs. creating a standalone binary. The standalone approach wins on every dimension:

| Dimension | `mina health-check` (subcommand) | `mina-health-check` (standalone) |
|---|---|---|
| Binary size | ~hundreds of MB (full daemon deps) | ~5-10 MB |
| Startup time | 500ms-2s (Rust FFI, SNARK init) | <50ms |
| OCaml deps | mina_lib, pickles, kimchi, consensus, transaction_snark, ... | cohttp-async, caqti, core, yojson |
| Install on monitoring host | Requires full `mina` binary | Own Debian package |
| Kubernetes liveness probe | Impractical (too heavy, too slow) | Fast and lightweight |
| Precedent in codebase | N/A | `mina-logproc`, `mina-missing-blocks-auditor` |

### Root Cause of CLI Bloat

The `mina` executable depends on the `init` library (`src/app/cli/src/init/dune`) which lists 60+ dependencies including:
- `mina_lib` (entire daemon coordinator)
- `pickles`, `pickles.backend` (recursive zk-SNARK system)
- `kimchi_backend`, `kimchi_pasta` (Rust FFI cryptographic backends)
- `transaction_snark` (SNARK circuit code)
- `blockchain_snark` (blockchain proof generation)
- `mina_graphql` (server-side GraphQL schema — itself depends on everything above)

Even the existing `mina_graphql_client` library has a transitive dependency on `mina_graphql` (server-side), pulling the entire daemon into any binary that uses it.

### Design Principle

The health check binary must use **raw HTTP/JSON** to query endpoints — NOT any `mina_*` OCaml libraries that have transitive dependencies on daemon internals. The daemon is a black box queried over the network, exactly as `curl` would.

## Prerequisite: GraphQL Client Library Refactor

> **See [Proposal 13: Decouple mina_graphql_client](13-graphql-client-refactor.md)**

The original design called for raw `cohttp-async` HTTP calls with no `mina_*` library dependencies, because the `mina_graphql_client` library currently pulls in the entire daemon through a transitive dependency on `mina_graphql` (server-side).

However, the root cause is that `mina_graphql_client` depends on `mina_graphql` for just 3 lines of code (input type constructors). Proposal 13 extracts these into a lightweight shared library, making `mina_graphql_client` genuinely lightweight.

**After the Proposal 13 refactor is complete**, the health check app should use `mina_graphql_client` instead of raw HTTP. This gives us:
- Type-safe GraphQL queries (compile-time checked against the schema)
- Built-in retry logic with exponential backoff
- Structured error handling
- No code duplication

### Updated Dependencies (post-refactor)

```
(libraries
  core
  async
  mina_graphql_client  ; NOW lightweight after Proposal 13
  caqti                ; DB abstraction for archive checks
  caqti-async
  caqti-driver-postgresql
  yojson
  uri)
```

This replaces the original design's `cohttp-async` with the proper typed client library.

## Proposed Design

### Binary Name

`mina-health-check`

### Location

`src/app/health_check/`

### Dependencies (dune)

```
(libraries
  core
  async
  cohttp-async     ; HTTP client for GraphQL queries
  caqti             ; DB abstraction for archive checks
  caqti-async
  caqti-driver-postgresql
  yojson            ; JSON parsing
  uri)
```

**No `mina_*` libraries.** Zero dependency on any Mina protocol code.

### CLI Interface

```
mina-health-check [OPTIONS]

OPTIONS:
  --daemon-graphql URL    Daemon GraphQL endpoint (default: http://127.0.0.1:3085/graphql)
  --archive-uri URI       Archive PostgreSQL URI (optional, skip archive checks if omitted)
  --json                  Output as JSON (default: human-readable text)
  --check CHECK           Run only specific check(s), comma-separated
  --timeout SECONDS       Per-check timeout (default: 5)
  --quiet                 Only output failures
  --exit-code             Exit 0 if all checks pass, 1 if any fail (default behavior)
```

### Checks

| Check ID | What It Does | How | Requires |
|----------|-------------|-----|----------|
| `daemon.reachable` | Daemon GraphQL responds | HTTP POST to `/graphql` with `{ syncStatus }` query | `--daemon-graphql` |
| `daemon.synced` | Sync status is `SYNCED` | Parse `syncStatus` from GraphQL response | `--daemon-graphql` |
| `daemon.peers` | Peer count >= 3 | GraphQL query `{ getPeers { host } }` | `--daemon-graphql` |
| `daemon.block_production` | Next block slot is scheduled | GraphQL query `{ daemonStatus { nextBlockProduction } }` | `--daemon-graphql` |
| `daemon.uptime` | Daemon has been running | GraphQL query `{ daemonStatus { uptimeSecs } }` | `--daemon-graphql` |
| `archive.reachable` | PostgreSQL connection succeeds | `SELECT 1` via caqti | `--archive-uri` |
| `archive.height` | Archive has recent blocks | `SELECT MAX(height) FROM blocks` | `--archive-uri` |
| `archive.missing_blocks` | No gaps in block sequence | Count gaps in block heights within last 1000 blocks | `--archive-uri` |
| `system.disk_space` | Config dir has >10% free | `Unix.statvfs` on config directory | Always |
| `system.fd_limit` | `ulimit -n` >= 10240 | Read `/proc/self/limits` or `getrlimit` | Always |
| `system.stack_size` | `ulimit -s` >= 65532 | Read `/proc/self/limits` or `getrlimit` | Always |
| `system.time_sync` | Clock within 30s of expected | Compare system time vs daemon's consensus time | `--daemon-graphql` |

### Output Format (Human-Readable)

```
$ mina-health-check --daemon-graphql http://localhost:3085/graphql --archive-uri postgres://mina:mina@localhost:5432/archive

Mina Health Check
=================

Daemon (http://localhost:3085/graphql)
  [pass] daemon.reachable      Daemon is responding
  [pass] daemon.synced         Sync status: SYNCED (height: 345678)
  [pass] daemon.peers          Connected peers: 12
  [pass] daemon.block_production  Next block: slot 456 (~3 min away)
  [pass] daemon.uptime         Uptime: 4d 12h 33m

Archive (postgres://...@localhost:5432/archive)
  [pass] archive.reachable     PostgreSQL connection OK
  [pass] archive.height        Max height: 345678
  [FAIL] archive.missing_blocks 3 missing blocks in last 1000

System
  [pass] system.disk_space     42 GB free (71%)
  [pass] system.fd_limit       File descriptors: 65536 (>= 10240)
  [pass] system.stack_size     Stack size: 65536 KB (>= 65532)
  [pass] system.time_sync      Clock offset: +2ms

Result: 11/12 checks passed. 1 FAILED.
Exit code: 1
```

### Output Format (JSON)

```json
{
  "timestamp": "2026-03-14T10:30:00Z",
  "summary": {
    "total": 12,
    "passed": 11,
    "failed": 1,
    "warnings": 0
  },
  "checks": [
    {
      "id": "daemon.reachable",
      "status": "pass",
      "message": "Daemon is responding",
      "duration_ms": 12
    },
    {
      "id": "archive.missing_blocks",
      "status": "fail",
      "message": "3 missing blocks in last 1000",
      "details": {"missing_count": 3, "window": 1000},
      "duration_ms": 45
    }
  ]
}
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All checks passed |
| 1 | One or more checks failed |
| 2 | Configuration error (bad arguments, unreachable endpoints) |

Simple, scriptable, standard. No bitmask trickery.

## Packaging

### Debian Package: `mina-health-check`

Following the pattern of `mina-logproc`:

- Package name: `mina-health-check`
- Install location: `/usr/local/bin/mina-health-check`
- Dependencies: `libssl3, libpq-dev` (for PostgreSQL driver)
- Listed as `Suggests:` (not `Depends:`) of `mina-devnet` / `mina-mainnet` packages

### Build Integration

Add to `scripts/debian/build.sh`:
```bash
build_health_check_deb() {
  ...
}
```

Add `make build-health-check` target.

## Use Cases

### 1. Kubernetes Liveness Probe

```yaml
livenessProbe:
  exec:
    command: ["mina-health-check", "--check", "daemon.reachable", "--quiet"]
  initialDelaySeconds: 300
  periodSeconds: 30
```

### 2. Kubernetes Readiness Probe

```yaml
readinessProbe:
  exec:
    command: ["mina-health-check", "--check", "daemon.synced", "--quiet"]
  initialDelaySeconds: 600
  periodSeconds: 60
```

### 3. Monitoring Script (Cron)

```bash
#!/bin/bash
mina-health-check --json --archive-uri "$ARCHIVE_URI" | \
  curl -X POST -H "Content-Type: application/json" -d @- "$ALERTING_WEBHOOK"
```

### 4. Operator Quick Triage

```bash
$ mina-health-check
# Instant visual summary of entire stack health
```

### 5. Remote Monitoring Host

Install `mina-health-check` on a separate monitoring server:
```bash
apt install mina-health-check
mina-health-check --daemon-graphql http://node1:3085/graphql --archive-uri postgres://...@archive1:5432/archive
```

No need to install the full `mina` daemon on the monitoring host.

## Implementation Plan

### Phase 1: Core App (2-3 days)

1. Create `src/app/health_check/` with `dune` file and `health_check.ml`
2. Implement daemon checks (reachable, synced, peers) using raw `cohttp-async`
3. Implement system checks (disk, fd_limit, stack_size)
4. Human-readable and JSON output
5. Exit code handling

### Phase 2: Archive Checks (1 day)

1. Add archive checks using `caqti` (reachable, height, missing_blocks)
2. Make `--archive-uri` optional (skip archive checks if not provided)

### Phase 3: Packaging (1 day)

1. Add `build_health_check_deb()` to `scripts/debian/builder-helpers.sh`
2. Add to `scripts/debian/build.sh`
3. Add `make build-health-check` target
4. Test package install/uninstall

### Phase 4: Documentation (0.5 day)

1. `src/app/health_check/README.md`
2. Update `docs/proposals/00-overview.md`

**Total: 4-5 days**

## Relationship to Other Proposals

- **[Proposal 01](01-health-endpoints.md)**: Server-side `/healthz` endpoints are complementary. `mina-health-check` can use them when available, but works without them by querying GraphQL directly.
- **[Proposal 02](02-mina-doctor.md)**: The `mina doctor` proposal can be replaced by this standalone app. All checks proposed in `mina doctor` are covered here, without the CLI bloat.
- **[Proposal 07](07-monitoring-package.md)**: The monitoring starter pack can reference `mina-health-check` in alerting examples.

## Files to Create

- `src/app/health_check/dune` — build configuration
- `src/app/health_check/health_check.ml` — main entry point
- `src/app/health_check/checks.ml` — individual check implementations
- `src/app/health_check/output.ml` — text and JSON formatters
- `src/app/health_check/README.md` — documentation
