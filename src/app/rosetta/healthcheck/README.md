# rosetta-healthcheck

Slim CLI focused on answering **"is the Rosetta server healthy right now?"**
Designed for Kubernetes exec probes, Docker `HEALTHCHECK`, CI gates, and
CI pre-flight checks.

For arbitrary Rosetta API calls — `/block`, `/account/*`, `/mempool`,
`/search/*`, `/construction/*` — use the sibling
[`rosetta-client`](../client/README.md) binary.  Both share the same
underlying HTTP library (`src/lib/rosetta_client/`).

## Commands

### Probes

| Command | Endpoint(s) | Exit 0 when |
|---------|-------------|-------------|
| `ready` | composite | `connectivity` + `tip-recency` + `/network/options` all pass |
| `wait` | poll `ready` | passes before `--deadline` expires |
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
rosetta-healthcheck wait --deadline 600 --interval 10 --json
```

The rosetta-cli audit configuration (`config.json` and the Construction
DSL files it names) is not handled by this binary.  It ships in the
`mina-rosetta` Debian package at
`/etc/mina/rosetta/rosetta-cli-config/`, and
`buildkite/scripts/tests/rosetta/integration-tests.sh` copies it to a
writable directory and fills in its `PLACEHOLDER_*` fields before
invoking rosetta-cli.

To make a single Rosetta API call for debugging, use
`rosetta-client network status` / `rosetta-client block get` /
etc.

## Flags

| Flag | Alias | Default | Environment override | Applies to |
|------|-------|---------|----------------------|------------|
| `--rosetta-uri` | | `http://localhost:3087` | `MINA_ROSETTA_URI` | all probes |
| `--network` | | `testnet` | `MINA_ROSETTA_NETWORK` | all probes |
| `--blockchain` | | `mina` | `MINA_ROSETTA_BLOCKCHAIN` | all probes |
| `--json` | `-j` | off | | every subcommand |
| `--max-age` | | 360 | | `tip-recency`, `ready`, `wait` |
| `--timeout` | | 5 | | all probes |
| `--deadline` | `-d` | 600 | | `wait` |
| `--interval` | `-i` | 10 | | `wait` |

`--interval` and `--deadline` must be at least 1 second, `--max-age` at
least 0 and `--timeout` positive.  A value below the floor is refused
before any request goes out: `--interval 0` asks for a poll loop with no
pause at all, which turns the probe into a load generator pointed at the
server it is checking.

A flag always wins over its environment variable.  The connection flags
themselves come from `Rosetta_client.Flags` and their fallbacks from
`Rosetta_client.Defaults` -- the same place `rosetta-client` gets them
-- so the two binaries cannot drift apart.
`--timeout` bounds one request/response exchange -- the same thing it
means to `rosetta-client` -- and defaults low because a probe wants a
quick verdict; raise it for a Rosetta that answers `/network/status` out
of a loaded archive database.  `--deadline` bounds the whole `wait`
loop, which is a different quantity and so has a different name.

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Check passed |
| 1 | Check failed (one line on stdout, or one JSON record on stdout with `--json`) |
| 2 | Usage error (a flag value below its floor); the message goes to stderr and no request is sent |

## JSON output contract

When `--json` is set, every probe emits exactly one JSON record on stdout
and exits. On success:

```json
{ "healthy": true, ... }
{ "ready":   true, ... }
```

On failure the process exits with code 1 and the same record carries the
reason plus any metrics gathered up to that point: `connectivity` and
`tip-recency` add `"error"`, while `ready` and `wait` list one line per
failed check in `"problems"` -- they check three things, so a single
`error` string would only be those lines joined up.

The records are typed (`health_output.ml`), and a field that has no value
is left out rather than emitted as `null`.  The probes that produce them
are in `health_probes.ml` and never print or exit; `rosetta_healthcheck.ml`
owns the flags, the text/JSON choice and the exit code.  A probe that could not reach
the server therefore prints:

```json
{ "healthy": false, "error": "connection refused to http://localhost:3087/network/list" }
```

All error messages are produced by `Rosetta_client.Errors` and are
guaranteed to be short, human-readable, and free of raw OCaml exception
syntax.

Diagnostics -- `wait`'s per-attempt progress -- go to stderr through
Mina's `Logger`, the way every other Mina binary reports, so a probe
running in a pod is collected and filtered like the daemon beside it.
The processor follows `--json`: one JSON record per line when it is set,
prose when it is not.  Stdout stays the result channel either way.

## Known limitation

A probe that times out closes its connection in every case except one: a
server that completes the TCP connect and then never sends a response
line at all. cohttp-async 5.0.0 exposes no handle on that connection, so
`wait` against such a server holds one socket per attempt until the
process exits. It is bounded by a single run of a short-lived CLI, and no
usable `--deadline` / `--interval` pair reaches the default descriptor
limit. See the comment on `with_request` in
`src/lib/rosetta_client/http.ml`.

## Kubernetes integration

`timeoutSeconds` is not optional here.  Kubelet defaults an exec probe
to 1 second and kills the process when it expires, while a probe waits
up to `--timeout` (5s by default) for a server that accepts the
connection and then goes quiet.  Left at the default, the examples below
would report failure on exactly the server they are meant to wait for.
Keep `timeoutSeconds` above `--timeout`; `ready` runs its three checks
concurrently, so its ceiling is the same one exchange.

```yaml
# Liveness: is the Rosetta server answering at all?
livenessProbe:
  exec:
    command: ["rosetta-healthcheck", "connectivity",
              "--rosetta-uri", "http://localhost:3087",
              "--network", "testnet"]
  initialDelaySeconds: 30
  periodSeconds: 30
  timeoutSeconds: 10

# Readiness: are all discovery endpoints healthy and the tip fresh?
readinessProbe:
  exec:
    command: ["rosetta-healthcheck", "ready",
              "--rosetta-uri", "http://localhost:3087",
              "--max-age", "360"]
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 10
```

## Docker integration

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD ["rosetta-healthcheck", "connectivity", \
       "--rosetta-uri", "http://localhost:3087"]
```

## Building

```bash
dune build src/app/rosetta/healthcheck/rosetta_healthcheck.exe
```
