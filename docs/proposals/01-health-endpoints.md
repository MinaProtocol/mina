# Proposal: Health Check Endpoints for Daemon, Archive, and Rosetta

## Problem

No lightweight health endpoints exist for any Mina service. The daemon's `/status` returns a massive JSON blob (hundreds of lines). Kubernetes/Docker health probes have no suitable target. Archive and Rosetta have zero health endpoints.

## Current State

- **Daemon**: `GET /status` returns full daemon status JSON (HTTP 200 always, even when Bootstrapping/Offline). `GET /` returns "intentionally left blank".
- **Archive**: No HTTP endpoints at all. Only Prometheus metrics via `--metrics-port`.
- **Rosetta**: No `/healthz`. Only way to check is calling a real Rosetta endpoint like `POST /network/list`.

## Proposed Changes

### Daemon (`src/app/cli/src/init/mina_run.ml`)

Add two endpoints to the existing REST server:

- `GET /healthz` --- Liveness probe
  - Returns HTTP 200 + `{"status": "ok", "sync_status": "Synced"}` when sync status is `Synced`
  - Returns HTTP 503 + `{"status": "unhealthy", "sync_status": "Bootstrapping"}` otherwise
  - Lightweight --- no heavy computation

- `GET /ready` --- Readiness probe
  - Returns HTTP 200 once node has completed initial bootstrapping and GraphQL is accepting queries
  - Returns HTTP 503 during bootstrap

- Change `GET /` to return minimal useful info: `{"version": "...", "sync_status": "...", "chain_id": "..."}`

### Archive (`src/app/archive/`)

Add a simple HTTP server (or piggyback on metrics port) with:

- `GET /healthz` --- Returns 200 if PostgreSQL connection is alive, 503 otherwise
- Response body: `{"status": "ok", "max_block_height": 12345, "missing_blocks": 0}`

### Rosetta (`src/app/rosetta/`)

Add:

- `GET /healthz` --- Returns 200 if DB pool is reachable, 503 otherwise
- `GET /ready` --- Returns 200 if both archive DB and daemon GraphQL are reachable

## Files to Modify

- `src/app/cli/src/init/mina_run.ml` (daemon REST routes)
- `src/app/archive/lib/` (add HTTP health server)
- `src/app/rosetta/lib/rosetta.ml` (add health routes)

## Impact

- Unblocks Kubernetes liveness/readiness probes for all three services
- Enables simple monitoring scripts (`curl -f http://localhost:3085/healthz`)
- Standard pattern used by every other L1 (Ethereum beacon API, Cosmos, Solana)

## Effort Estimate

Small --- 1-2 days per service. No protocol changes needed.
