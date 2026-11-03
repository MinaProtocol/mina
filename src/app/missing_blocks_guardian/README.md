Missing Blocks Guardian
=======================

`mina-missing-blocks-guardian` finds the blocks that an archive database
lacks and restores them from a bucket of block files.

It runs `mina-missing-blocks-auditor` to find the first block whose parent
is missing, downloads that parent as
`<network>-<height>-<state hash>.json` from the bucket, writes it with
`mina-archive-blocks`, and repeats until the auditor reports no missing
parent.

Subcommands
-----------

- `audit`: run the auditor and report whether blocks are missing.
- `single-run`: audit, then restore the missing blocks once.
- `daemon`: `single-run` every `--interval` seconds; after a recovery, six
  times longer.

Flags and environment variables
-------------------------------

Each flag falls back to an environment variable. A flag wins over its
variable. A variable set to the empty string counts as unset.

| Flag | Environment variable | Subcommands | Meaning |
| --- | --- | --- | --- |
| `--archive-uri URI` | `DB_USERNAME`, `PGPASSWORD`, `DB_HOST`, `DB_PORT`, `DB_NAME` | all | Archive database, `postgres://user:password@host:port/db`, or built from the five variables. |
| `--missing-blocks-auditor PATH` | `MISSING_BLOCKS_AUDITOR` | all | The auditor program. Default `mina-missing-blocks-auditor`. |
| `--precomputed-blocks-url URL` | `PRECOMPUTED_BLOCKS_URL` | `single-run`, `daemon` | Bucket with the block files: an `http`, `https` or `file` URL. |
| `--network NAME` | `MINA_NETWORK` | `single-run`, `daemon` | Prefix of the block file names. |
| `--block-format precomputed\|extensional` | `BLOCKS_FORMAT` | `single-run`, `daemon` | Format of the block files. Default `precomputed`. |
| `--archive-blocks PATH` | `ARCHIVE_BLOCKS` | `single-run`, `daemon` | The program that writes blocks. Default `mina-archive-blocks`. |
| `--interval SECONDS` | `TIMEOUT` | `daemon` | Time between two checks. Default 600. |
| `--log-json`, `--log-level LEVEL` | none | all | Log format and level, as in the other Mina programs. |

Every setting is checked before anything runs. Each problem is logged on
its own line, `Cannot start: <setting>: <what is expected>`, and the
program exits with 1 after listing all of them. The settings in use are
logged at start, with the database password hidden.

Exit codes
----------

- `audit`: 0 when the archive holds no block without a parent, 1 when it
  does or when the auditor fails.
- `single-run`: 0 when the archive holds no block without a parent after
  the run, 1 when a block could not be restored.
- `daemon`: runs until a block cannot be restored, then exits with 1. A
  service manager such as docker-compose with `restart: always` starts it
  again.

A block cannot be restored when:

- the bucket answers with an HTTP status that is not a success, for example
  404 when the file does not exist. The error page is not saved;
- the auditor or `mina-archive-blocks` cannot be run, is killed, or logs an
  error. `mina-archive-blocks` exits with 0 when it cannot add a block, so
  its log decides. The fatal line of the guardian repeats the error of the
  program, or its exit code and what it wrote to stderr;
- after a block was added, the auditor still reports the same missing
  parent. That means the file in the bucket holds another block.

Examples
--------

With flags:

```
mina-missing-blocks-guardian single-run \
  --archive-uri postgres://postgres:postgres@localhost:5432/archive \
  --precomputed-blocks-url https://storage.googleapis.com/mina_network_block_data \
  --network mainnet
```

With environment variables:

```
DB_USERNAME=postgres PGPASSWORD=postgres DB_HOST=localhost DB_PORT=5432 DB_NAME=archive \
PRECOMPUTED_BLOCKS_URL=https://storage.googleapis.com/mina_network_block_data \
MINA_NETWORK=mainnet TIMEOUT=3600 \
mina-missing-blocks-guardian daemon
```

Modules
-------

- `missing_blocks_guardian.ml`: the command line and the recovery loop.
- `config.ml`: the settings, their sources and their validation.
- `auditor.ml`: runs the auditor and reads the missing parent from its log.
- `app_log.ml`: parses the JSON log of a Mina program, relays it and finds
  the errors in it.
- `subprocess.ml`: runs a program and collects its output.
- `download.ml`: fetches a block file; HTTPS checks the host name.
- `sql.ml`: the queries on the archive database.

Tests
-----

`MINA_PROFILE=dev dune runtest src/app/missing_blocks_guardian` runs the
unit tests of the settings, the log reading and the download, with a local
HTTP server.
