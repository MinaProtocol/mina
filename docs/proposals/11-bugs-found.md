# Bugs Found During L1 Operator UX Analysis

These are existing bugs in the codebase discovered during the analysis. They are NOT introduced by any PR --- they exist on `main`.

## Critical

### 1. `failwith "test"` in Rosetta CLI (Production Bug)
**File**: `src/app/rosetta/lib/cli.ml:22`
**Issue**: When an invalid log level is passed, the code crashes with `failwith "test"` --- a debug string left in production code.
**Impact**: Rosetta process crashes with unhelpful "test" error message.
**Fix**: Replace with proper error message listing valid log levels.

### 2. Dead Troubleshooting URL in Crash Handler
**File**: `src/app/cli/src/init/mina_run.ml`
**Issue**: `No_initial_peers` error references `https://codaprotocol.com/docs/troubleshooting/` which is a dead URL (domain no longer used).
**Impact**: Operators hitting their first connection failure get a broken link.
**Fix**: Update to `https://docs.minaprotocol.com/node-operators/troubleshooting`

## High

### 3. SIGTERM Exit Code 130 Breaks Systemd
**File**: `src/app/cli/src/init/mina_run.ml:~860`
**Issue**: `Async.shutdown 130` is called for ALL terminating signals. Code 130 is for SIGINT only. SIGTERM should exit 0 or 143.
**Impact**: Systemd treats exit code 130 as failure, triggering unnecessary restart loops.
**Fix**: Map signal to correct exit code (SIGTERM -> 0, SIGINT -> 130).

### 4. `archive prune` Exits 0 on Failure
**File**: `src/app/archive/cli/archive_cli.ml:131-137`
**Issue**: On database error during pruning, the command logs the error but returns `()` from `Command.async`, resulting in exit code 0.
**Impact**: CI/monitoring that checks exit codes thinks pruning succeeded when it failed.
**Fix**: Return non-zero exit code on error.

## Medium

### 5. `MINA_ROSETTA_MAX_DB_POOL_SIZE` Required With No Default
**File**: `src/app/rosetta/lib/rosetta.ml:207`
**Issue**: This environment variable is required but has no default. If unset, Rosetta silently starts and only crashes on first DB access (not at startup).
**Impact**: Operators discover the issue only when real traffic hits the server.
**Fix**: Add default value of 64, or fail at startup with clear message.

### 6. `docker-standalone-start.sh` Missing Required Env Var
**File**: Rosetta's `docker-standalone-start.sh`
**Issue**: Does not set `MINA_ROSETTA_MAX_DB_POOL_SIZE`, so Rosetta will panic on first DB use.
**Fix**: Add default value in the script.

### 7. Healthcheck Script Fetched from Unpinned Branch
**File**: `dockerfiles/Dockerfile-mina-archive:64`
**Issue**: `healthcheck-utilities.sh` is downloaded via `curl` from the `develop` branch at build time. Network failures break builds, and the content can change unexpectedly.
**Fix**: Pin to a specific commit hash or COPY the script from the repo.

## Low

### 8. `stop-daemon` RPC Skips Cleanup
**File**: `src/app/cli/src/init/mina_run.ml`
**Issue**: The `Stop_daemon` RPC calls `exit 0` directly, bypassing the `log_shutdown` handler that the signal handler uses.
**Impact**: Operator-initiated stops via `mina client stop-daemon` skip transition frontier dumps and cleanup.
**Fix**: Route through the same shutdown handler.

### 9. `--background` Loses Stderr
**File**: `src/app/cli/src/cli_entrypoint/mina_cli_entrypoint.ml`
**Issue**: When `--background` is used, stdout/stderr are redirected to `/dev/null`. Early boot errors before the file logger is initialized are lost entirely.
**Fix**: Log to a temporary file during early boot, or emit startup errors to stderr before daemonizing.
