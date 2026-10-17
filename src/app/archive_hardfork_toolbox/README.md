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

Settles the hard fork boundary of the newest fork genesis in the archive. The chain
leading to the fork block becomes `canonical`, and the rest of the ended chain is
`orphaned`. It runs the same core as the archive node: `Archive_lib.Settle_pending_blocks`.
This is the post-fork repair step for the pre-fork tail, which would otherwise stay
`pending`.

**Usage:**
```bash
archive_hardfork_toolbox convert-chain-to-canonical \
  --postgres-uri "postgresql://user:pass@host:port/db" \
  --dry-run
```
Run with `--dry-run` first to see what would change. The change is rolled back and the
result is printed as JSON. Then run it again without `--dry-run` to apply.

**Parameters:**
- `--postgres-uri`: URI for connecting to the archive database
- `--dry-run`: roll the change back and print what a run would change

The former `--target-block-hash`, `--fork-height`, `--protocol-version`, `--stop-at-slot`
and `--json` flags were removed.

