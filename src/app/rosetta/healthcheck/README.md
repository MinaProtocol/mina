# rosetta-healthcheck

Slim CLI focused on answering **"is the Rosetta server healthy right now?"**
Designed for Kubernetes exec probes, Docker `HEALTHCHECK`, CI gates, and
CI pre-flight checks.

For arbitrary Rosetta API calls — `/block`, `/account/*`, `/mempool`,
`/search/*`, `/construction/*` — use the sibling
[`rosetta-client`](../rosetta_client/README.md) binary.  Both share
the same underlying HTTP library (`src/lib/rosetta_client/`).

## Commands

### Probes

| Command | Endpoint(s) | Exit 0 when |
|---------|-------------|-------------|
| `ready` | composite | `connectivity` + `tip-recency` + `/network/options` all pass |
| `wait` | poll `ready` | passes before `--timeout` expires |
| `tip-recency` | POST `/network/status` | tip returned AND its timestamp is within `--max-age` |
| `connectivity` | POST `/network/list` | `network_identifier` list advertises the expected network (lists the advertised set on mismatch) |

## Usage

```bash
# Is the server reachable and advertising our network?
rosetta-healthcheck connectivity --network testnet

# Is the tip fresh? (default tolerance: 360s)
rosetta-healthcheck tip-recency --max-age 360

# Composite readiness suitable for k8s readiness probes:
rosetta-healthcheck ready --max-age 360 --json

# Block until ready (CI / init containers):
rosetta-healthcheck wait --timeout 600 --interval 10 --json
```

To extract the embedded rosetta-cli config files, use
`rosetta-client config show` / `rosetta-client config export`.
To make a single Rosetta API call for debugging, use
`rosetta-client network status` / `rosetta-client block get` /
etc.

## Flags

| Flag | Alias | Default | Applies to |
|------|-------|---------|------------|
| `--online-uri` | `-o` | `http://localhost:3087` | all probes |
| `--network` | `-n` | `testnet` | all probes |
| `--blockchain` | | `mina` | all probes |
| `--json` | `-j` | off | every subcommand |
| `--max-age` | | 360 | `tip-recency`, `ready`, `wait` |
| `--timeout` | `-t` | 600 | `wait` |
| `--interval` | `-i` | 10 | `wait` |

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Check passed |
| 1 | Check failed (details on stderr, or in JSON record on stdout) |
| 2 | Environment / configuration error (malformed URI, etc.) |

## JSON output contract

When `--json` is set, every subcommand emits exactly one JSON record on
stdout and exits. On success:

```json
{ "healthy": true, ... }
{ "ready":   true, ... }
```

On failure the same record includes `"error": "<msg>"` and any metrics
gathered up to the point of failure; the process exits with code 1.

All error messages are produced by `Rosetta_client.Errors` and are
guaranteed to be short, human-readable, and free of raw OCaml exception
syntax.

## Kubernetes integration

```yaml
# Liveness: is the Rosetta server answering at all?
livenessProbe:
  exec:
    command: ["rosetta-healthcheck", "connectivity",
              "--online-uri", "http://localhost:3087",
              "--network", "testnet"]
  initialDelaySeconds: 30
  periodSeconds: 30

# Readiness: are all discovery endpoints healthy and the tip fresh?
readinessProbe:
  exec:
    command: ["rosetta-healthcheck", "ready",
              "--online-uri", "http://localhost:3087",
              "--max-age", "360"]
  initialDelaySeconds: 60
  periodSeconds: 30
```

## Docker integration

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD ["rosetta-healthcheck", "connectivity", \
       "--online-uri", "http://localhost:3087"]
```

## Building

```bash
dune build src/app/rosetta/healthcheck/rosetta_healthcheck.exe
```
