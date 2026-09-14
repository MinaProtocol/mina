# Missing Blocks Guardian

`mina-missing-blocks-guardian` audits a Mina archive database and fills the
gaps it finds.

An archive has a gap when it holds a block whose parent is not there. The
guardian finds every such block, downloads the missing parent from a block
source, and writes it to the archive, repeating until the branch reaches a
block the archive already holds. It can also report the gaps without touching
anything.

Every response from the block source is checked for its status code, its
content type and its JSON before the bytes reach the database, so a bucket
that answers with an error page cannot be stored as if it were a block. Blocks
are written through the archive library in process, so a block the archive
rejects reports the reason the archive gave. Nothing is run as a subprocess,
and neither `jq`, `curl` nor `psql` is needed.

The walk has a floor. It stops at height 1, or at `--min-height` on an archive
that starts at a hard fork, so it never asks for a block that cannot exist.
And a branch it cannot close is set aside with its reason and reported at the
end, rather than stopping the pass: the walk goes lowest first, so one
unreachable block at the bottom would otherwise hide every gap above it.

## Subcommands

| Subcommand | What it does |
| --- | --- |
| `audit` | Reports the gaps. Writes nothing. |
| `single-run` | Audits, fills every gap it can, then exits. |
| `daemon` | Repeats `single-run` on a timer, forever. |

### Exit codes

Every subcommand answers the same way: **0 when there is nothing wrong, 1 when
there is.** There is no bit mask to decode — each problem is logged as an error
line naming what is wrong, and one run reports all of them.

`audit` exits 1 when any of these holds:

- some blocks have no parent in the archive;
- the archive holds no genesis block and no first post-hard-fork block, and no
  `--min-height` was given;
- the archive holds no canonical block at all;
- some blocks at or below the highest canonical block are still `pending`;
- the canonical chain is shorter than the range of heights it covers;
- a block along the canonical chain has another chain status.

On an archive that starts at a hard fork or was restored from a truncated
dump, pass `--min-height` to `audit` as well. It says where the chain is meant
to start, so the earliest block counts as the bottom of the archive rather than
a missing parent, and the chain length is measured from there. Without it such
an archive can never report healthy.

`single-run` exits 1 when a gap is left: a block that is not in the block
source, one the archive rejected, a pass that stopped at `--max-blocks` with
gaps remaining, or any `--dry-run` that found a block it could not fetch.

A failure to run at all — an unreachable database, an un-migrated schema, a
missing or malformed setting — also exits 1, with a fatal log line saying what
is wrong.

`daemon` runs until it is stopped, and exits 1 after
`--max-consecutive-failures` passes fail in a row.

One branch that cannot be closed does not stop the others. A block that is not
in the bucket, or one the archive rejects, sets that branch aside; the pass
carries on with the remaining branches and reports every branch it left open at
the end. This matters because the walk goes lowest first: without it, one
unreachable block at the bottom of the archive would hide every gap above it.

## Settings

Every setting can be given as a command line flag or as an environment
variable. The flag wins when both are given.

| Flag | Environment variable | Default | Meaning |
| --- | --- | --- | --- |
| `--archive-uri` | `PG_CONN`, or `DB_USERNAME` + `PGPASSWORD` + `DB_HOST` + `DB_PORT` + `DB_NAME` | required | archive database to read and repair |
| `--precomputed-blocks-url` | `PRECOMPUTED_BLOCKS_URL` | required except for `audit` | where the block files are: an `http`, `https` or `file` URL, or a local directory |
| `--network` | `MINA_NETWORK` | required except for `audit` | block file name prefix |
| `--block-format` | `BLOCKS_FORMAT` | `precomputed` | `precomputed` or `extensional` |
| `--interval` | `TIMEOUT` | `600` | seconds between checks in `daemon` mode |

These flags have no environment variable:

| Flag | Default | Meaning |
| --- | --- | --- |
| `--idle-multiplier` | `6` | in `daemon` mode, wait this many times `--interval` after a pass that closed every gap. A pass that left a gap open comes back at the normal interval |
| `--http-timeout` | `60` | seconds allowed for one block download |
| `--retries` | `3` | extra attempts for a download that failed for a transient reason. A missing or malformed block is never retried |
| `--retry-delay` | `5` | seconds between download attempts |
| `--max-blocks` | no limit | stop after adding this many blocks in one repair pass |
| `--min-height` | `1` | treat this height as the bottom of the archive: never fetch below it, do not report the block there as missing a parent, and measure the canonical chain from it |
| `--max-consecutive-failures` | `5` | exit in `daemon` mode after this many failed passes in a row. `0` means never exit |
| `--dry-run` | off | report and validate what would be downloaded, and write nothing |

`MISSING_BLOCKS_AUDITOR` and `ARCHIVE_BLOCKS` are not used: the guardian
audits and ingests by itself. A warning is logged if either is set.

### Block file names

A block is looked up as `<network>-<height>-<state hash>.json` under
`--precomputed-blocks-url`. This is the layout of the public archive block
buckets and the layout `mina-extract-blocks --include-block-height-in-name`
writes.

## Building

```
$ dune build src/app/missing_blocks_guardian/missing_blocks_guardian.exe --profile=dev
```

or

```
$ make build-missing-blocks-guardian
```

The executable is at
`_build/default/src/app/missing_blocks_guardian/missing_blocks_guardian.exe`.
The `mina-archive-*` Debian packages install it as
`/usr/local/bin/mina-missing-blocks-guardian`.

## Examples

Report the gaps in a local archive:

```
$ mina-missing-blocks-guardian audit \
    --archive-uri postgres://mina@localhost:5432/archive
```

Fill the gaps once from the public devnet bucket:

```
$ mina-missing-blocks-guardian single-run \
    --archive-uri postgres://mina@localhost:5432/archive \
    --precomputed-blocks-url https://storage.googleapis.com/mina_network_block_data \
    --network devnet
```

Check that the blocks are reachable without writing anything:

```
$ mina-missing-blocks-guardian single-run --dry-run \
    --archive-uri postgres://mina@localhost:5432/archive \
    --precomputed-blocks-url https://storage.googleapis.com/mina_network_block_data \
    --network devnet
```

Run as a service, the way the Docker Compose stacks in
`src/app/archive/docker-compose` and `src/app/rosetta/docker-compose` do:

```
$ PRECOMPUTED_BLOCKS_URL=https://storage.googleapis.com/mina_network_block_data \
  MINA_NETWORK=devnet \
  DB_USERNAME=mina DB_HOST=postgres DB_PORT=5432 DB_NAME=archive PGPASSWORD=... \
  mina-missing-blocks-guardian daemon
```

On an archive that was restored from a dump that starts at a hard fork whose
fork block the archive does not hold, stop the walk at the fork height instead
of letting it run down to height 1:

```
$ mina-missing-blocks-guardian single-run --min-height 296373 ...
```

## Output

The output is the JSON log lines the Mina logger writes, so `mina-logproc`
and `jq` read it. The audit logs one line per finding, for example:

```
[Info] Querying missing blocks
[Info] Block has no parent in archive db
  {"block_id": 1250, "state_hash": "3NKdP1...", "height": 1250, "parent_hash": "3NLGst...", "parent_height": 1249, "missing_blocks_gap": 2}
[Info] Querying for gaps in chain statuses
[Info] There are no gaps in the chain statuses
[Info] Length of canonical chain is 1249 blocks
[Info] All blocks along the canonical chain have a valid chain status
```

## Notes

- The audit reads the archive only; it never writes.
- Run the audit when the archive is not being written to, if possible. A block
  added while the recursive canonical-chain query runs can make the chain
  length look wrong.
- `missing_blocks_gap` is the size of the height gap below the reported block:
  how many blocks are between it and the highest block below it.
