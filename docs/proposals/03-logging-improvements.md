# Proposal: Logging UX Improvements

## Problem

Default stdout logging is raw JSON --- unreadable without piping through `logproc` (which is undiscoverable). The startup message "Booting may take several seconds" is inaccurate (actual: 5-15 minutes). Log rotation is hardcoded and not configurable.

## Current State

- Stdout: Raw JSON by default. `--log-json` flag exists but default is ALSO JSON (just different processor).
- `Logger.Processor.Pretty` exists but is not used by default.
- `logproc` binary exists but is not mentioned in daemon help text.
- Log rotation: hardcoded 10MB x 50 rotations for `mina.log`.
- No logrotate.d config shipped.
- Startup message is misleading.

## Proposed Changes

### 1. Default to human-readable stdout

Change the default stdout processor from `Logger.Processor.Raw` to `Logger.Processor.Pretty`. Add `--log-format=json|text` flag (default: `text`).

**Files**: `src/app/cli/src/cli_entrypoint/mina_cli_entrypoint.ml`

### 2. Fix startup timing message

Change "Booting may take several seconds, please wait" to:
"Initializing genesis state. First run may take 5-15 minutes. Subsequent starts are faster."

Add periodic progress logging during genesis initialization (every 30 seconds).

**Files**: `src/app/cli/src/cli_entrypoint/mina_cli_entrypoint.ml`, genesis initialization code

### 3. Emit structured "node ready" event

When the node first transitions to `Synced` state, emit a distinct structured log:
```json
{"event_id": "node_synced", "message": "Node is synced and ready", "level": "Info", "block_height": 12345}
```

Also log the GraphQL endpoint URL when the server starts.

### 4. Configurable log rotation

Add CLI flags: `--log-max-size` (default: 10MB), `--log-rotations` (default: 50).
Or accept these in `daemon.json`.

### 5. Ship logrotate.d config

Create `scripts/logrotate.d/mina`:
```
/var/log/mina/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
}
```

### 6. Publish event ID catalog

Create `docs/log-events.md` documenting all structured log event IDs used for alerting.

## Effort Estimate

Small-Medium --- 2-4 days total.
