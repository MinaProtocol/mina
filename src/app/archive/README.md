Archive
=======

The Mina daemon does not remember the entire history of the blockchain.
On the contrary, it only remembers a couple of blocks backwards, called
the *transition frontier*. If storing historic transaction data is
desired, this Archive needs to be set up next to the daemon itself.

Prerequisites
-------------

The Archive stores its data in a PostgreSQL database, so its necessary
to set one up before proceeding to run the Archive. The way one
installs Postgres software depends the operating system. However, in
some setups it might be more convenient to use the [official Postgres
Docker image](https://hub.docker.com/_/postgres) instead. In that case
the following command will set the database up:

```shell
$ docker run -d --name pg-mina-archive \
    -p 5432:5432 \
    -e POSTGRES_PASSWORD='*******' \
    -e POSTGRES_HOST_AUTH_METHOD=trust \
    -e POSTGRES_DB=mina_archive \
    -e POSTGRES_USER=pguser \
    postgres:latest
```

Note that setting the authentication method to `trust` is very unsafe,
because it allows anyone to connect without giving a password. While
convenient and acceptable in development settings, this option should
never be used in production. Also note that even with authentication
method set to `trust``, its still necessary to provide a password for
the database user.

The Docker container creates the database with the given name automatically.
In case a native database installation was chosen, the database must be
created manually:

```shell
$ createdb mina_archive
```

When set up, the database needs to be initialised. The following command
will put the schema in place:

```shell
$ psql -h localhost -d mina_archive -f src/app/archive/create_schema.sql
```

Note that the database should be dropped and recreated when a new
blockchain is to be used (for instance when restarting a sandbox blockchain).

When started, the archive will try to pull the blocks from the
*transition frontier* from nodes on the network. It won't, however, as
discused above, be able to get the entire history of blocks produced
prior to that. For this reason, when joining an existing network, it
might be desirable to load its history from a database dump
instead.

Additionally, when running the Mina daemon (see the main `README.md` for
exact instructions on how to do it), it is necessary to pass an additional
option to it: `--archive-address 3086`. The daemon will the try to feed
blocks it receives to the Archive for storage.

Compilation
-----------

To compile the Archive, use the following command:

```shell
$ make build-archive
```

This will build the archive executable in the _build directory. For mainnet signatures, use:

```shell
$ dune build src/app/archive/archive_mainnet_signatures.exe --profile=mainnet
```

For testnet signatures:

```shell
$ dune build src/app/archive/archive_testnet_signatures.exe --profile=dev
```

Running the Archive
-------------------

When the setup described above is complete, it is possible to start the
archive:

```shell
$ "_build/default/src/app/archive/archive.exe" run \
    --config-file daemon.json \
    --postgres-uri "postgres://localhost:5432/mina_archive" \
    --server-port 3086
```

Note that `--config-file` parameter should be identical to the one passed
to the daemon itself. Also `--server-port` should be the same as
`--archive-address` passed to the daemon. The `--postgres-uri` should have
the form:
`--archive-uri postgres://<username>:<password>@<host>:<port>/<dbname>`.

Available Commands
-----------------

The archive executable supports the following commands:

### Run

Run an archive process that stores all the data of Mina.

```shell
$ archive run \
    --config-file <PATH> \
    --postgres-uri <URI> \
    --server-port <PORT> \
    [--metrics-port <PORT>] \
    [--missing-blocks-width <INT>] \
    [--delete-older-than <INT>]
```

Parameters:
- `--config-file`: Path to the configuration file containing the genesis ledger
- `--postgres-uri`: PostgreSQL connection URI
- `--server-port`: Port for the archive server (default: 3086)
- `--metrics-port`: Optional port for Prometheus metrics server
- `--missing-blocks-width`: Optional width of block heights to report missing blocks
- `--delete-older-than`: Optional parameter to delete blocks older than N blocks
  from the maximum height

### Prune

Prune old blocks and their transactions from the archive database.

```shell
$ archive prune \
    --postgres-uri <URI> \
    [--height <INT>] \
    [--num-blocks <INT>] \
    [--timestamp <TIMESTAMP>]
```

Parameters:
- `--postgres-uri`: PostgreSQL connection URI
- `--height`: Delete blocks with height lower than the given height
- `--num-blocks`: Delete blocks that are more than N blocks lower than the
  maximum seen block
- `--timestamp`: Delete blocks older than the given timestamp (format:
  YYYY-MM-DD HH:MM:SS+ZZZZ)

The Archive does not have its own interface for retrieving its data – for
that one can use Rosetta (see `src/app/rosetta`) or query the Postgres
database directly.

Recovering Blocks from Precomputed Block Logs
---------------------------------------------

The Mina daemon supports three options for preserving precomputed blocks that
can be used to recover missing archive data:

- `--precomputed-blocks-dir DIR`: Write each precomputed block to its own file
  in `DIR`, named `<network>-<height>-<state-hash>.json`. This is the
  **recommended approach**. The name is the same one the precomputed block
  bucket gives its objects, so the directory can be uploaded to that bucket
  unchanged, and any tool that already reads the bucket can read the directory.
  Each file is written under a temporary name and renamed into place, so a
  reader never sees a partly written block. `DIR` must exist; the daemon
  refuses to start if it does not.
- `--precomputed-blocks-file PATH`: **Deprecated.** Append every block to one
  file as a single-line JSON object. The file grows without limit, nothing
  rotates it, and finding one block means reading the whole file. Use
  `--precomputed-blocks-dir` instead.
- `--log-precomputed-blocks true`: Include precomputed blocks inline in the
  standard daemon log output.

Blocks are written by a background job, so a slow disk delays the dump rather
than block processing. If that job falls more than 16 blocks behind, the oldest
queued blocks are dropped and each drop is logged as an error naming the block,
so a gap in the dump is always visible in the log.

### Warning: Log Truncation

Precomputed blocks can be very large — sometimes several megabytes each.
When using `--log-precomputed-blocks`, these large blocks are written as
single log entries. This can cause truncation in two ways:

1. **Mina's internal log limit**: The Mina daemon enforces a maximum log
   line length of 1 MB (1,048,576 bytes). Log entries exceeding this limit
   are replaced with a truncation notice in the normal log, while the full
   content is redirected to a separate file named `mina-oversized-logs.log`
   in the daemon's configuration directory (defaults to `~/.mina-config/`, configurable via `--config-directory`).

2. **External logging service limits**: Log aggregators and shipping services
   (such as Loki, Elasticsearch, Splunk, Fluentd, etc.) typically impose
   their own per-entry size limits. A precomputed block log entry that exceeds
   these limits will be silently truncated, resulting in invalid JSON that
   cannot be used for archive recovery.

A truncated precomputed block cannot be imported into the archive database.

### Recommended Configuration

To reliably preserve precomputed blocks for archive recovery, use the
`--precomputed-blocks-dir` flag instead of `--log-precomputed-blocks`:

```shell
$ mkdir -p /path/to/precomputed-blocks
$ mina daemon \
    --archive-address 3086 \
    --precomputed-blocks-dir /path/to/precomputed-blocks \
    [other options]
```

This writes each precomputed block to its own file, bypassing the logging
subsystem entirely and avoiding any size-based truncation:

```
/path/to/precomputed-blocks/mainnet-548147-3NKHyxzg....json
/path/to/precomputed-blocks/mainnet-548148-3NLZmKAD....json
```

If you must use `--log-precomputed-blocks` with an external logging service,
ensure that service is configured to handle log entries of at least 10 MB (a conservative guideline, as blocks of several MB have been observed in practice).

### Recovering Blocks from the Oversized Log File

If you used `--log-precomputed-blocks` and some blocks were truncated in
transit to an external logging service, the full content of those blocks may
still be available locally in `mina-oversized-logs.log` in the daemon's
configuration directory. This file captures log entries that exceeded Mina's
internal 1 MB log line limit.

To import a precomputed block from either source into the archive database,
use the `archive_blocks` tool (see `src/app/archive_blocks/README.md`):

```shell
$ archive_blocks \
    --archive-uri "postgres://username@localhost:5432/mina_archive" \
    --precomputed \
    block.json
```
