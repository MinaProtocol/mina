# Archive Hardfork Toolbox

The Archive Hardfork Toolbox is a utility for verifying the integrity of archive database migrations and validating hardfork operations in the Mina protocol. This tool helps ensure that database schema upgrades and fork transitions maintain data consistency.

## Overview

This toolbox provides commands to:
- Verify fork block candidates before migration
- Validate database schema upgrades
- Ensure fork block integrity and ancestry

## Commands

### fork-candidate

A group of commands for pre-fork verifications to validate that a candidate block is suitable for forking.

#### is-in-best-chain

Verifies that the fork block is in the best chain of the blockchain.

**Usage:**
```bash
archive_hardfork_toolbox fork-candidate is-in-best-chain \
  --postgres-uri "postgresql://user:pass@host:port/db" \
  --fork-state-hash "3NKx..." \
  --fork-height 12345 \
  --fork-slot 67890
```

**Parameters:**
- `--postgres-uri`: URI for connecting to the mainnet archive database
- `--fork-state-hash`: Hash of the fork state
- `--fork-height`: Height of the fork block
- `--fork-slot`: Global slot since genesis of the fork block

#### confirmations

Verifies that the fork block has the required number of confirmations.

**Usage:**
```bash
archive_hardfork_toolbox fork-candidate confirmations \
  --postgres-uri "postgresql://user:pass@host:port/db" \
  --fork-state-hash "3NKx..." \
  --fork-slot 67890 \
  --required-confirmations 290
```

**Parameters:**
- `--postgres-uri`: URI for connecting to the mainnet archive database
- `--fork-state-hash`: Hash of the fork state
- `--fork-slot`: Global slot since genesis of the fork block
- `--required-confirmations`: Number of confirmations required for the fork block

#### no-commands-after

Verifies that no commands were executed after the fork block, ensuring a clean fork point.

**Usage:**
```bash
archive_hardfork_toolbox fork-candidate no-commands-after \
  --postgres-uri "postgresql://user:pass@host:port/db" \
  --fork-state-hash "3NKx..." \
  --fork-slot 67890
```

**Parameters:**
- `--postgres-uri`: URI for connecting to the mainnet archive database
- `--fork-state-hash`: Hash of the fork state
- `--fork-slot`: Global slot since genesis of the fork block

### verify-upgrade

Verifies the upgrade from pre-fork to post-fork database schema.

**Usage:**
```bash
archive_hardfork_toolbox verify-upgrade \
  --postgres-uri "postgresql://user:pass@host:port/db" \
  --version "3.2.0"
```

**Parameters:**
- `--postgres-uri`: URI for connecting to the pre-fork mainnet archive database
- `--version`: Version to upgrade to (e.g., "3.2.0")

### validate-fork

Validates the fork block and its ancestors to ensure blockchain integrity.

**Usage:**
```bash
archive_hardfork_toolbox validate-fork \
  --postgres-uri "postgresql://user:pass@host:port/db" \
  --fork-state-hash "3NKx..." \
  --fork-slot 67890
```

**Parameters:**
- `--postgres-uri`: URI for connecting to the mainnet archive database
- `--fork-state-hash`: Hash of the fork state
- `--fork-slot`: Global slot since genesis of the fork block

### convert-chain-to-canonical

Marks the chain leading to a target block as `canonical` (and orphans the competing
blocks of that protocol version). This is the post-fork repair step for the pre-fork
tail: at a hard fork the last ~k pre-fork blocks (including the fork block's parent)
are left `pending` because the canonical watermark jumps to the fork genesis and never
walks back below it. This command finalizes them.

**Usage (auto-detect the latest boundary):**
```bash
archive_hardfork_toolbox convert-chain-to-canonical \
  --postgres-uri "postgresql://user:pass@host:port/db" \
  --dry-run
```
With no target/protocol flags it auto-detects the latest hard-fork boundary — the
parent of the highest block with `global_slot_since_hard_fork = 0` — and uses that
block's protocol version. Run with `--dry-run` first to review the change plan and
summary, then re-run without it to apply.

If the fork does **not** bump the protocol version (some emergency hard forks), the
post-fork chain shares the protocol version with the pre-fork chain. The command
detects the fork boundary and leaves blocks at or beyond it untouched, so the
post-fork chain is never orphaned.

**Usage (explicit target):**
```bash
archive_hardfork_toolbox convert-chain-to-canonical \
  --postgres-uri "postgresql://user:pass@host:port/db" \
  --protocol-version "3.0.0" \
  --target-block-hash "3NKx..."
```

**Parameters:**
- `--postgres-uri`: URI for connecting to the archive database
- `--target-block-hash`: State hash of the block that should remain canonical (default: parent of the latest hard-fork block)
- `--fork-height`: Height of the block that should remain canonical (alternative to `--target-block-hash`)
- `--protocol-version`: Protocol version `<transaction>.<network>.<patch>` (default: the target block's own protocol version)
- `--stop-at-slot`: If provided, stops marking blocks older than this global slot since genesis
- `--dry-run`: Print the blocks that would change and a summary without writing any changes
- `--json`: Emit the change plan as JSON (target, fork block, boundary slot, summary, and a per-block `changes` array) instead of the human-readable table

To repair an earlier boundary (e.g. on a network with more than one hard fork), pass
`--protocol-version` and `--target-block-hash`/`--fork-height` explicitly instead of
relying on auto-detection, which always targets the latest boundary.

## Typical Workflow

1. **Pre-fork validation**: Use the `fork-candidate` commands to ensure the chosen fork point is valid:
   - Check if the block is in the best chain
   - Verify sufficient confirmations
   - Ensure no commands after the fork point

2. **Schema upgrade**: Use `verify-upgrade` to validate the database migration process

3. **Post-fork validation**: Use `validate-fork` to ensure the fork block and its ancestry remain intact

4. **Post-fork tail repair**: Use `convert-chain-to-canonical` (with `--dry-run` first) to finalize the pre-fork tail that would otherwise stay `pending`

## Database Connection

All commands require an `--postgres-uri` parameter that should be a PostgreSQL connection string in the format:
```
postgresql://username:password@hostname:port/database_name
```
