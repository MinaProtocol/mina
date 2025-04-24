Missing Blocks Auditor
=====================

The `missing_blocks_auditor` application audits a Mina archive database to find
gaps in the blockchain data. It identifies missing blocks, verifies chain status
consistency, and reports various integrity issues that might indicate problems
with the archive database.

This tool is crucial for maintaining the integrity of archive databases,
especially those used for transaction history, analytics, or network monitoring.

Problems Detected
----------------

The auditor checks for four main issues:

1. **Missing Blocks**: Blocks whose parent block is not present in the database
   (excluding the genesis block which has no parent).

2. **Pending Blocks Below Canonical**: Blocks marked as "pending" that have a
   height lower than the highest (most recent) canonical block. This can happen
   if blocks are added when there are missing blocks in the database.

3. **Chain Length Discrepancies**: Cases where the length of the canonical chain
   does not match the highest canonical block height, indicating potential
   internal inconsistencies.

4. **Chain Status Errors**: Blocks along the canonical chain that have a status
   other than "canonical".

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
$ make missing_blocks_auditor
```

The executable will be built at:
`_build/default/src/app/missing_blocks_auditor/missing_blocks_auditor.exe`

Usage
-----

The basic syntax for running `missing_blocks_auditor` is:

```shell
$ missing_blocks_auditor --archive-uri URI
```

### Required Parameters

- `--archive-uri URI`: URI for connecting to the archive database
  (e.g., postgres://username@localhost:5432/mina_archive)

### Exit Codes

The tool returns an exit code that encodes the different types of problems found:

- Bit 0 (1): Missing blocks detected
- Bit 1 (2): Pending blocks below highest canonical block detected
- Bit 2 (4): Chain length discrepancy detected
- Bit 3 (8): Chain status errors detected

A return code of 0 indicates no problems were found. A non-zero return code
indicates that one or more problems were detected. The specific issues can be
determined by the bits set in the exit code.

Example
-------

Audit an archive database:

```shell
$ missing_blocks_auditor --archive-uri "postgres://username@localhost:5432/mina_archive"
```

Example output when problems are found:

```
[Info] Successfully created Caqti pool for Postgresql
[Info] Querying missing blocks
[Info] Block has no parent in archive db
  {"block_id": 1250, "state_hash": "3NKdP1BmcvwUKvPzQXpzXUe2j7EgyJCbMfKN9smHJFAadjZf3xXS", "height": 1250, "parent_hash": "3NLGstS3qdz1w8HAshfLkSWUMWy97SX5w9pNBSXrVmCnHK9fvGnx", "parent_height": 1249, "missing_blocks_gap": 2}
[Info] Querying for gaps in chain statuses
[Info] There are 3 pending blocks lower than the highest canonical block
  {"max_height_canonical_block": "1500", "num_pending_blocks_below": "3"}
[Info] Length of canonical chain is 1499 blocks, expected: 1500
[Info] Canonical block has a chain_status other than "canonical"
  {"block_id": 1245, "state_hash": "3NLcYrz5isZXRR5SBzZkzRBPCskN1BHc2x5UuS7fGffNWJ8vbRRQ", "chain_status": "pending"}
```

Technical Notes
--------------

- The tool's execution is quite fast as it uses optimized SQL queries to examine
  the database structure without transferring large amounts of data.

- The auditor specifically excludes the genesis block (height=1) when checking
  for missing parent blocks, as the genesis block is expected to have no parent.

- When missing blocks are found, the tool also reports the size of the gap (how
  many blocks are missing) for each detected issue.

- This tool is intended for diagnostic purposes and does not modify any data
  in the archive database.