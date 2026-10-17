Missing Blocks Auditor
=====================

The `missing_blocks_auditor` application audits a Mina archive database to find
gaps in the blockchain data. It identifies missing blocks, verifies chain status
consistency, and reports various integrity issues that might indicate problems
with the archive database.

This tool is crucial for maintaining the integrity of archive databases,
especially those used for transaction history, analytics, or network monitoring.

The audit itself is the `missing_blocks_auditor_lib` library
(`lib/audit.ml`); the executable reports it and sets the exit code.

Problems Detected
----------------

1. **Missing Blocks**: Blocks whose parent block is not present in the database
   (excluding the genesis or first post-fork block, which has no parent, and
   blocks at or below `--min-height`).

2. **Pending Blocks Below Canonical**: Blocks marked as "pending" that have a
   height lower than the highest (most recent) canonical block. This can happen
   if blocks are added when there are missing blocks in the database.

3. **Chain Length Discrepancies**: Cases where the length of the canonical chain
   does not match the range of heights it covers, measured from the genesis
   block, the first block after a hard fork, or `--min-height`.

4. **Chain Status Errors**: Blocks along the canonical chain that have a status
   other than "canonical".

5. **No Chain Start**: The archive holds no blocks, no canonical block, or
   (without `--min-height`) neither a genesis block nor the first block after
   the hard fork its lowest block follows.

Prerequisites
------------

Before using `missing_blocks_auditor`, you need:

1. A running PostgreSQL database containing Mina archive data.

2. The connection URI for accessing the Mina archive database, in the format
   `postgres://<username>:<password>@<host>:<port>/<dbname>`.

Compilation
----------

To compile the `missing_blocks_auditor` executable, run:

```shell
$ dune build src/app/missing_blocks_auditor/missing_blocks_auditor.exe --profile=dev
```

Or use the following make command:

```shell
$ make build-missing-blocks-auditor
```

The executable will be built at:
`_build/default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe`

Usage
-----

The basic syntax for running `missing_blocks_auditor` is:

```shell
$ missing_blocks_auditor --archive-uri URI
```

### Parameters

- `--archive-uri URI` (required): URI for connecting to the archive database
  (e.g., postgres://username@localhost:5432/mina_archive)
- `--min-height HEIGHT` (optional): height of the earliest block the archive
  is expected to hold, for an archive restored from a truncated dump or one
  that does not reach back to a genesis or hard-fork block

### Exit Codes

The tool returns an exit code that encodes the different types of problems found:

- Bit 0 (1): Missing blocks, or no chain start (problems 1 and 5)
- Bit 1 (2): Pending blocks below highest canonical block detected
- Bit 2 (4): Chain length discrepancy detected
- Bit 3 (8): Chain status errors detected

A return code of 0 indicates no problems were found. A database the auditor
cannot connect to or query exits 1. A non-zero return code
indicates that one or more problems were detected. The specific issues can be
determined by the bits set in the exit code.

Example
-------

Audit an archive database:

```shell
$ missing_blocks_auditor --archive-uri "postgres://username@localhost:5432/mina_archive"
```

Example output when problems are found (one JSON log line each; `message`
and `metadata` shown):

```
Successfully created Caqti pool for Postgresql
Querying missing blocks
Block has no parent in archive db
  {"block_id": 1250, "state_hash": "3NKdP1Bmcv…", "height": 1250, "parent_hash": "3NLGstS3qd…", "parent_height": 1249, "missing_blocks_gap": 2}
Querying for gaps in chain statuses
Canonical block has a chain_status other than "canonical"
  {"block_id": 1245, "state_hash": "3NLcYrz5is…", "chain_status": "pending"}
Some blocks have no parent in the archive
  {"blocks_without_parent": 1}
Some blocks at or below the highest canonical block are still pending
  {"num_pending_blocks_below": "3", "max_height_canonical_block": "1500"}
Some blocks along the canonical chain have another chain status
  {"blocks_with_wrong_chain_status": 1}
The archive is not healthy: $problem_count problems found
  {"problem_count": 3}
```

Technical Notes
--------------

- The tool's execution is quite fast as it uses optimized SQL queries to examine
  the database structure without transferring large amounts of data.

- The auditor excludes the genesis block, or the first block after a hard fork,
  when checking for missing parent blocks, as that block has no parent.

- When missing blocks are found, the tool also reports the size of the gap (how
  many blocks are missing) for each detected issue.

- This tool is intended for diagnostic purposes and does not modify any data
  in the archive database.