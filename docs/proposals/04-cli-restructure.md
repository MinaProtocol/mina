# Proposal: CLI Restructure for Operators

## Problem

`mina advanced` is a catch-all of ~30 commands mixing operator-relevant and developer-internal commands. Peer management, status, and key operations are not discoverable. The CLI naming doesn't match operator mental models.

## Current Structure

```
mina
├── daemon          # Start daemon
├── client          # Balance, payments, status, stop
├── accounts        # Account management
├── advanced        # 30+ mixed commands (peers, snark pool, tracing, VRF, trust, archive, receipt chain, constraints...)
├── ledger          # Export, hash, currency
├── libp2p          # Keypair management
└── internal        # Internal/testing
```

## Proposed Structure

```
mina
├── daemon           # Start daemon (unchanged)
├── doctor           # NEW: diagnostic checks
├── status           # NEW: shortcut for quick health summary
├── client           # Payments, delegations, stop (unchanged)
├── accounts         # Account management (unchanged)
├── peers            # NEW group (promoted from advanced)
│   ├── list         # Get connected peers
│   ├── add          # Add peers
│   ├── ban          # Ban IP
│   ├── unban        # Unban IP
│   └── trust-status # Show trust scores
├── snark            # NEW group (promoted from advanced)
│   ├── pool         # Show SNARK pool
│   ├── pending      # Show pending work
│   ├── set-worker   # Set SNARK worker
│   └── set-fee      # Set SNARK work fee
├── vrf              # NEW group (promoted from advanced)
│   ├── evaluate     # Evaluate VRF for slot
│   └── batch        # Batch VRF evaluation
├── ledger           # Export, hash (unchanged)
├── libp2p           # Keypair management (unchanged)
├── advanced         # Remaining developer/internal commands
└── internal         # Internal/testing (unchanged)
```

### Key Changes

1. **`mina status`** --- top-level shortcut that prints 5-line health summary (sync, height, peers, next block, uptime)
2. **`mina peers`** --- promote peer management to top-level
3. **`mina snark`** --- promote SNARK worker management to top-level
4. **`mina vrf`** --- promote VRF tools to top-level
5. **`mina doctor`** --- new diagnostic command (see proposal 02)
6. Keep `mina advanced` as a catch-all for developer/internal commands, with deprecation aliases

### Backward Compatibility

All `mina advanced <cmd>` invocations continue to work (aliases). New groups are additions, not breaking changes.

## Files to Modify

- `src/app/cli/src/cli_entrypoint/mina_cli_entrypoint.ml` --- restructure command groups

## Effort Estimate

Medium --- 3-5 days. Needs careful alias handling for backward compatibility.
