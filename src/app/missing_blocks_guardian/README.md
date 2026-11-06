Missing Blocks Guardian
=======================

`mina-missing-blocks-guardian` finds the blocks that an archive database
lacks and restores them from a bucket of block files.

It runs `mina-missing-blocks-auditor` to find the first block whose parent
is missing, downloads that parent as
`<network>-<height>-<state hash>.json` from the bucket, writes it to the
database with the library of `mina-archive-blocks`, and repeats until the
auditor reports no missing parent.

The guardian needs a profile, as `mina-archive-blocks` does: `MINA_PROFILE`,
or the file `/etc/coda/build_config/PROFILE` that packages and configured
docker images have. Without one it stops at start, before it reads its
settings, for each subcommand.

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
| `--precomputed-blocks-url URL` | `PRECOMPUTED_BLOCKS_URL` | `single-run`, `daemon` | Bucket with the block files: an `http`, `https` or `file` URL. The block file names are added to this URL. |
| `--network NAME` | `MINA_NETWORK` | `single-run`, `daemon` | Prefix of the block file names. |
| `--block-format precomputed\|extensional` | `BLOCKS_FORMAT` | `single-run`, `daemon` | Format of the block files. Default `precomputed`. |
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
  again. The rosetta image has no service manager, so
  `src/app/rosetta/scripts/docker-start.sh` runs it in a loop.

`single-run` and `daemon` also check the bucket at start. They ask the
bucket for one file that starts with `<network>-`. The first path segment
of the URL is the bucket, as in
`https://storage.googleapis.com/<bucket>`, and the other segments are the
start of the file name. A bucket on its own host name with more path, as in
`https://<bucket>.storage.googleapis.com/<path>`, is not supported: use the
form with the bucket in the path.

- A public Google Cloud Storage or S3 bucket lists its files. An empty list
  stops the program: the URL or the network name is wrong, or the bucket
  does not have the files of this network.
- A 404 for a URL with no path past the bucket stops the program. Google
  Cloud Storage and S3 answer 404 when a bucket does not exist.
- A connection failure stops the program.
- Each other answer lets the program continue, because it cannot show that
  the files are absent: for example 403 from a private bucket, a page from a
  plain HTTP server, or a 404 below a longer path.

A `gs://` or `s3://` URL is rejected with the https URL to use instead.

A block cannot be restored when:

- the bucket answers with an HTTP status that is not a success, for example
  404 when the file does not exist. The error page is not saved. The fatal
  line shows how the URL of the file was built from the bucket URL and the
  network name;
- the auditor cannot be run, is killed, or logs an error. The fatal line of
  the guardian repeats the error of the program, or what it wrote to stderr;
- the block file cannot be read or written to the database. The fatal line
  has the reason;
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

- `missing_blocks_guardian.ml`: the commands. They log a failure and exit.
- `recovery.ml`: restores blocks one by one and returns the reason of a
  failure.
- `cli.ml`: the flags, the log setup, the check of the settings and the
  report of the settings in use.
- `config.ml`: the settings, their sources and their validation.
- `auditor.ml`: runs the auditor and reads the missing parent from its log.
- `archive_blocks.ml`: writes a block file to the database with the library
  `archive_blocks_lib`.
- `bucket.ml`: the names and the URLs of the block files in a bucket.
- `app_log.ml`: parses the JSON log of a Mina program, relays it and finds
  the errors in it.
- `subprocess.ml`: runs a program and collects its output.
- `download.ml`: fetches a block file; HTTPS checks the host name.
- `sql.ml`: the queries on the archive database.

Tests
-----

`MINA_PROFILE=dev dune runtest src/app/missing_blocks_guardian` runs the
unit tests of the settings, the log reading, the download with a local HTTP
server, and the recovery with a fake auditor program.
