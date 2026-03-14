> **Note**: This proposal has been superseded by [Proposal 12: Standalone Health Check App](12-health-check-app.md), which achieves the same goals without the CLI binary bloat. The `mina doctor` concept is implemented as the standalone `mina-health-check` binary instead of a subcommand.

# Proposal: `mina doctor` Diagnostic Command

## Problem

Operators have no single command to verify their node setup is correct. Diagnosing issues requires manually checking sync status, peer count, key files, disk space, file descriptors, and port accessibility separately.

## Comparison with Other L1s

- **Solana**: `solana-watchtower` monitors and alerts on validator health
- **Ethereum**: Lighthouse has built-in validator health checks
- **Cosmos**: `gaiad tendermint show-validator` + extensive query commands

Mina has nothing equivalent.

## Proposed Command

```
mina doctor [--daemon-port PORT] [--config-dir DIR] [--json]
```

### Checks to perform:

| Check | Pass Condition | Source |
|-------|---------------|--------|
| Daemon reachable | RPC port responds | `Daemon_rpcs.Get_status` |
| Sync status | `Synced` or `Catchup` | Status RPC |
| Peer count | >= 3 peers | Status RPC |
| Block production | Next slot scheduled (if BP key set) | Status RPC |
| Key files readable | All tracked keys decrypt | Wallet check |
| Disk space | > 10% free in config dir | `statvfs` |
| File descriptors | `ulimit -n` >= 10240 | System check |
| Stack size | `ulimit -s` >= 65532 | System check |
| libp2p keypair | Keypair file exists | File check |
| GraphQL port | Port is listening | TCP check |
| Metrics port | Port is listening (if configured) | TCP check |
| Time sync | System clock within 30s of NTP | NTP query |
| Config files | All referenced config files parse correctly | Config validation |

### Output

```
mina doctor
  Daemon reachable on port 3085                    PASS
  Sync status: Synced (height: 345678)             PASS
  Connected peers: 12                              PASS
  Next block production: slot 456 (~3 min)         PASS
  Block producer key: B62q... (unlocked)           PASS
  Disk space: 45GB free (72%)                      PASS
  File descriptors: 65536 (ok)                     PASS
  Stack size: 65532 (ok)                           PASS
  libp2p keypair: /home/mina/.mina-config/libp2p-keypair  PASS
  GraphQL server: listening on :3085               PASS
  Metrics port: not configured (recommend --metrics-port 9100)  WARN
  System clock: synchronized (offset: +2ms)        PASS
  Config files: 2 files parsed successfully        PASS

Result: 12/13 checks passed. 1 warning.
```

With `--json`, output structured JSON for scripting.

## Files to Create/Modify

- `src/app/cli/src/cli_entrypoint/mina_cli_entrypoint.ml` --- add `doctor` subcommand
- `src/lib/doctor/` --- new library with diagnostic checks

## Effort Estimate

Medium --- 3-5 days. No protocol changes. Pure CLI tooling.
