# mina-healthcheck

Lightweight CLI for probing the health of a Mina daemon node. Designed as a
compiled replacement for `healthcheck-utilities.sh` that works with Kubernetes
exec probes, Docker HEALTHCHECK, shell scripts, and monitoring systems.

## Commands

| Command | Description | Exit 0 when |
|---------|-------------|-------------|
| `sync-status` | Query daemon sync state | SYNCED |
| `daemon-status` | Full status dump (always JSON) | Daemon reachable |
| `peer-count` | Check peers against threshold | `peer_count > --min-peers` |
| `chain-length` | Compare local vs network height | Heights match |
| `ready` | Combined check (sync + peers + chain) | All pass |
| `wait` | Block until ready or timeout | Node becomes ready |

## Usage

```bash
# Check if daemon is synced (exit 0 = synced, exit 1 = not synced)
mina-healthcheck sync-status

# Same, with JSON output
mina-healthcheck sync-status --json

# Full daemon status as JSON
mina-healthcheck daemon-status

# Check peer count against threshold (default: >2)
mina-healthcheck peer-count --min-peers 3

# Check if chain length matches highest received block
mina-healthcheck chain-length

# Combined readiness check (synced + peers + chain length)
mina-healthcheck ready --min-peers 2

# Point to a different daemon
mina-healthcheck sync-status --graphql-uri http://my-node:3085/graphql
```

### Waiting for daemon startup

The `wait` command blocks until the node passes all readiness checks
(synced, peers above threshold, chain caught up) or a timeout expires.
Progress is printed to stderr so stdout stays clean for scripts.

```bash
# Wait up to 10 minutes for the node to become fully ready
mina-healthcheck wait --timeout 600 --interval 10

# Wait with custom peer threshold
mina-healthcheck wait --timeout 300 --interval 5 --min-peers 3

# JSON output on success or timeout
mina-healthcheck wait --timeout 600 --json
```

Example progress output (stderr):

```
[  10s] Bootstrap   (peers: 0, chain: ?/?)
[  20s] Bootstrap   (peers: 2, chain: 50/1741)
[  30s] Catchup     (peers: 4, chain: 800/1741)
[  40s] Synced      (peers: 4, chain: 1741/1741)
READY
```

This is useful for:
- **Kubernetes init containers** — block pod startup until the node is ready
- **CI pipelines** — wait for a local-network node before running integration tests
- **Deployment scripts** — wait after restart before proceeding to the next node
- **Upgrade orchestration** — wait for catchup after a rolling update

## Global flags

| Flag | Alias | Default | Description |
|------|-------|---------|-------------|
| `--graphql-uri` | `-u` | `http://127.0.0.1:3085/graphql` | Daemon GraphQL endpoint |
| `--json` | `-j` | off | Output as JSON instead of text |
| `--min-peers` | `-n` | 2 | Minimum peer count threshold |
| `--timeout` | `-t` | 600 | Max seconds to wait (wait only) |
| `--interval` | `-i` | 10 | Poll interval in seconds (wait only) |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Check passed |
| 1 | Check failed (details on stderr) |

## Kubernetes integration

```yaml
# Init container: block until node is ready before starting the main workload
initContainers:
  - name: wait-for-mina
    image: mina-daemon:latest
    command: ["mina-healthcheck", "wait", "--timeout", "600", "--interval", "10"]

# Liveness: is the daemon process responding?
livenessProbe:
  exec:
    command: ["mina-healthcheck", "sync-status"]
  initialDelaySeconds: 300
  periodSeconds: 30

# Readiness: is the node fully synced and connected?
readinessProbe:
  exec:
    command: ["mina-healthcheck", "ready", "--min-peers", "2"]
  initialDelaySeconds: 60
  periodSeconds: 10
```

## Docker integration

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD ["mina-healthcheck", "sync-status"]
```

## Library

The healthcheck logic lives in `mina_healthcheck_lib` and can be used
from OCaml code directly without spawning a subprocess:

```ocaml
open Mina_healthcheck_lib

(* Wait for GraphQL to come up *)
let%bind _status = wait_for_graphql ~logger node_uri ~timeout:120 ~interval:5 in

(* Wait for full readiness *)
let%bind readiness = wait_for_ready ~logger node_uri ~min_peers:0 ~timeout:300 ~interval:5 in

(* One-shot checks *)
let%bind status    = get_sync_status ~logger node_uri in
let%bind ds        = get_daemon_status ~logger node_uri in
let%bind ok, count = check_peer_count ~logger node_uri ~min_peers:2 in
let%bind readiness = check_readiness ~logger node_uri ~min_peers:0 in
```

See `mina_healthcheck_lib.mli` for the full API.

## Building

From the mina repo root:

```bash
dune build src/app/mina_healthcheck/mina_healthcheck.exe
```

The binary is at `_build/default/src/app/mina_healthcheck/mina_healthcheck.exe`.
