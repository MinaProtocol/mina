Missing Blocks Guardian
=======================

`mina-missing-blocks-guardian` finds the blocks that an archive database
lacks and restores them from a bucket of block files. It replaces the bash
script `scripts/archive/missing-blocks-guardian.sh`.

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

Each flag falls back to the environment variable the bash script used, so
the program is configured the same way as before. A flag wins over its
variable.

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

Examples
--------

With flags:

```
mina-missing-blocks-guardian single-run \
  --archive-uri postgres://postgres:postgres@localhost:5432/archive \
  --precomputed-blocks-url https://storage.googleapis.com/mina_network_block_data \
  --network mainnet
```

With the environment of the bash script:

```
DB_USERNAME=postgres PGPASSWORD=postgres DB_HOST=localhost DB_PORT=5432 DB_NAME=archive \
PRECOMPUTED_BLOCKS_URL=https://storage.googleapis.com/mina_network_block_data \
MINA_NETWORK=mainnet TIMEOUT=3600 \
mina-missing-blocks-guardian daemon
```

Modules
-------

- `missing_blocks_guardian.ml`: the command line and the recovery loop.
- `auditor.ml`: runs the auditor and reads the missing parent from its log.
- `app_log.ml`: parses the JSON log of a Mina program and relays it.
- `subprocess.ml`: runs a program and collects its output.
- `download.ml`: fetches a block file; HTTPS checks the host name.
- `sql.ml`: the queries on the archive database.
