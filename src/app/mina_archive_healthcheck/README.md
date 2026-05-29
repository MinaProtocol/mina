# mina-archive-healthcheck

Lightweight CLI for probing the health of a Mina archive node via PostgreSQL.
Designed for Kubernetes exec probes, Docker HEALTHCHECK, and monitoring.

## Commands

| Command | Description | Exit 0 when |
|---------|-------------|-------------|
| `db-ready` | Check database connectivity | DB reachable |
| `block-height` | Report max block height | Always (if DB reachable) |
| `block-recency` | Check latest block timestamp | Within `--max-delay` seconds |
| `missing-blocks` | Count height gaps in sliding window | Count <= `--max-missing` |
| `unparented-blocks` | Count orphan blocks | Count <= `--max-unparented` |
| `ready` | Combined readiness check | All checks pass |
| `wait` | Block until ready or timeout | Archive becomes ready |

## Usage

```bash
# Check if archive DB is reachable
mina-archive-healthcheck db-ready --postgres-uri postgres://user@localhost:5432/archive

# Get current block height
mina-archive-healthcheck block-height --postgres-uri postgres://...

# Check if latest block is recent (within 6 minutes)
mina-archive-healthcheck block-recency --postgres-uri postgres://... --max-delay 360

# Check for missing blocks in the last 2000 block window
mina-archive-healthcheck missing-blocks --postgres-uri postgres://... --max-missing 10

# Combined readiness check
mina-archive-healthcheck ready --postgres-uri postgres://... --max-delay 360 --max-missing 10

# Wait for archive to become ready (init container / CI)
mina-archive-healthcheck wait --postgres-uri postgres://... --timeout 600 --interval 10

# Wait only for the DB schema to respond — useful for "is the archive
# process up at all?" gates where you can't wait for ingestion (e.g. a
# freshly-bootstrapped archive that hasn't received any blocks yet,
# init containers, integration test fixtures).  Skips recency /
# missing / unparented checks.
mina-archive-healthcheck wait --db-only --postgres-uri postgres://... --timeout 30 --interval 1
```

## Flags

Flags are accepted per-subcommand.

| Flag | Alias | Default | Description |
|------|-------|---------|-------------|
| `--postgres-uri` | `-p` | (required) | PostgreSQL connection URI |
| `--json` | `-j` | off | Output as JSON instead of text |
| `--max-delay` | | 360 | Max seconds since last block |
| `--max-missing` | | 10 | Max acceptable missing blocks |
| `--max-unparented` | | 5 | Max acceptable unparented blocks |
| `--window` | | 2000 | Block window for missing blocks check |
| `--timeout` | `-t` | 600 | Max seconds to wait (wait only) |
| `--interval` | `-i` | 10 | Poll interval in seconds (wait only) |
| `--db-only` | | off | Wait only for the DB to respond, skip recency / missing / unparented (wait only) |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Check passed |
| 1 | Check failed (details on stderr) |

## Kubernetes integration

```yaml
# Liveness: is the archive DB reachable?
livenessProbe:
  exec:
    command: ["mina-archive-healthcheck", "db-ready",
              "--postgres-uri", "$(ARCHIVE_URI)"]
  initialDelaySeconds: 30
  periodSeconds: 30

# Readiness: is the archive up-to-date?
readinessProbe:
  exec:
    command: ["mina-archive-healthcheck", "ready",
              "--postgres-uri", "$(ARCHIVE_URI)",
              "--max-delay", "360"]
  initialDelaySeconds: 60
  periodSeconds: 30
```

## Docker integration

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD ["mina-archive-healthcheck", "db-ready", \
       "--postgres-uri", "postgres://user@localhost:5432/archive"]
```

## Relationship to missing-blocks-auditor

Both tools share SQL queries via the `archive_health_queries` library.

- **mina-archive-healthcheck**: Fast, lightweight probes for operational health.
  Answers "is the archive working right now?"
- **mina-missing-blocks-auditor**: Deep integrity audit with bitmask exit codes.
  Answers "is the archive data complete and consistent?"
  Paired with the guardian script for auto-repair.

Use the healthcheck for k8s probes (every 10-30s) and the auditor for
periodic deep checks (every 10min via the guardian daemon).

## Building

```bash
dune build src/app/mina_archive_healthcheck/mina_archive_healthcheck.exe
```
