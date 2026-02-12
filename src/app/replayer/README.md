Replayer
========

The `replayer` tool is a powerful utility for replaying blockchain transactions
from a Mina archive database. It processes transactions in sequence, applying
them to reconstruct the ledger state at any point in the blockchain's history. 
This is particularly useful for hard fork preparation, ledger validation, and
debugging blockchain state issues.

Features
--------

- Replay all transactions from a Mina archive database, starting from a genesis
  ledger configuration
- Apply transactions in the correct order, respecting global slot and sequence
  number
- Generate epoch ledger snapshots required for hard forks
- Create checkpoints to resume processing from specific slots
- Verify ledger consistency by comparing computed Merkle roots with recorded
  ledger hashes
- Process user commands, internal commands, and zkApp transactions

Prerequisites
------------

Before using the `replayer` tool, you need:

1. A PostgreSQL database containing Mina archive data, populated by an archive
   node.

2. A JSON input file that specifies the starting ledger configuration and other
   parameters.

3. The database connection URI in the format 
   `postgres://<username>:<password>@<host>:<port>/<dbname>`.

Compilation
----------

To compile the `replayer` executable, run:

```shell
$ dune build src/app/replayer/replayer.exe --profile=dev
```

The executable will be built at:
`_build/default/src/app/replayer/replayer.exe`

Usage
-----

The basic syntax for running the `replayer` is:

```shell
$ replayer --input-file INPUT.json --archive-uri URI [OPTIONS]
```

### Required Parameters

- `--input-file PATH`: Path to the JSON file containing the starting ledger
  configuration.

- `--archive-uri URI`: URI for connecting to the archive database
  (e.g., postgres://username@localhost:5432/mina_archive).

### Optional Parameters

- `--output-file PATH`: Path where the resulting ledger will be saved as JSON.

- `--continue-on-error`: Continue processing after encountering errors.

- `--checkpoint-interval N`: Write checkpoint files every N slots.

- `--checkpoint-output-folder PATH`: Directory where checkpoint files will be
  saved.

- `--checkpoint-file-prefix STRING`: Prefix for checkpoint filenames
  (default: "replayer").

- `--genesis-ledger-dir PATH`: Directory containing the genesis ledger files.

### Logging Options

- `--log-json`: Output logs in JSON format.

- `--log-level LEVEL`: Set the console log level (Spam, Trace, Debug, Info,
  Warn, Error, Fatal).

- `--log-file PATH`: Write logs to the specified file.

- `--file-log-level LEVEL`: Set the file log level.

Input File Format
---------------

The input file is a JSON document specifying the starting configuration:

```json
{
  "target_epoch_ledgers_state_hash": "STATE_HASH",
  "start_slot_since_genesis": 0,
  "genesis_ledger": {
    "base": {
      "accounts": [
        {
          "pk": "PUBLIC_KEY",
          "balance": "AMOUNT",
          "delegate": "DELEGATE_KEY"
        },
        ...
      ]
    },
    "add_genesis_winner": false
  },
  "first_pass_ledger_hashes": [],
  "last_snarked_ledger_hash": null
}
```

- `target_epoch_ledgers_state_hash`: State hash of the target block for which
  epoch ledgers should be generated.
- `start_slot_since_genesis`: Slot number to start replaying from (0 for genesis).
- `genesis_ledger`: Initial ledger configuration.
- `first_pass_ledger_hashes`: Optional list of ledger hashes from previous runs.
- `last_snarked_ledger_hash`: Optional snarked ledger hash from a previous run.

Output File Format
----------------

If an output file is specified, the tool produces a JSON document with:

```json
{
  "target_epoch_ledgers_state_hash": "STATE_HASH",
  "target_fork_state_hash": "FORK_STATE_HASH",
  "target_genesis_ledger": { ... },
  "target_epoch_data": {
    "staking": { ... },
    "next": { ... }
  }
}
```

This output contains the ledger state and epoch data needed for a hard fork.

Examples
--------

Replay transactions from genesis:

```shell
$ replayer --input-file genesis_input.json \
    --archive-uri "postgres://username@localhost:5432/mina_archive" \
    --output-file output.json
```

Continue replaying from a checkpoint with regular checkpoint creation:

```shell
$ replayer --input-file checkpoint-123456.json \
    --archive-uri "postgres://username@localhost:5432/mina_archive" \
    --output-file output.json \
    --checkpoint-interval 1000 \
    --checkpoint-output-folder "./checkpoints"
```

Technical Notes
--------------

- The replayer reconstructs the ledger state by replaying all transactions in
  order, applying the same transaction logic as the Mina daemon.

- If transaction application fails, the tool will report detailed error
  information and exit (unless `--continue-on-error` is specified).

- The tool verifies ledger Merkle roots against the expected ledger hashes stored
  in the archive database to ensure correctness.

- For large archives, the process can take significant time and memory. Use
  checkpoints to break the operation into manageable chunks.

- The tool automatically updates epoch ledgers when processing transactions that
  affect them.

- There are special handling mechanisms for certain historical blocks with known
  issues to avoid disrupting the replay process.