# zkApp-heavy precomputed-block corpus

Static data for the **archive-node end-to-end memory benchmark**
(`src/test/archive/archive_memory_bench`, CI job `ArchiveMemoryBench`).

`precomputed_blocks.tar.xz` is a chain of **49 precomputed blocks** produced by a local
`compatible` network (devnet profile, `--proof-level none`), loaded with heavy zkApp
traffic:

- **94 zkApp commands**, carrying **14,720 event fields + 14,720 action fields**
  (20 event arrays and 20 action arrays of 8 fields each per `update-state`).

That volume is what exercises the archive's `zkapp_field_array` / event / action insert
paths, where per-connection prepared-statement growth shows up most. `genesis.json` is
the configuration of the network that produced the blocks.

The blocks must be decodable by the `archive_blocks` of the branch that replays them: a
corpus produced on another release line (e.g. `develop`) does not parse here, because
the serialised proofs differ. Regenerate it on the same line.

## What the benchmark does

It replays these blocks through the real archive insert path
(`archive_blocks --precomputed` → `Processor.add_block_aux_precomputed` → the
`Mina_caqti` helpers) into PostgreSQL, and samples the resident memory of both the
`archive_blocks` process and the serving PostgreSQL backend. The result is published to
the perf InfluxDB (measurement `archive_memory_bench`).

**The Caqti pool is pinned to one connection that is never recycled**
(`CAQTI_POOL_MAX_SIZE=1`, `CAQTI_POOL_MAX_IDLE_SIZE=1`, `CAQTI_POOL_MAX_IDLE_AGE=none`,
`CAQTI_POOL_MAX_USE_COUNT=none`). Caqti keeps prepared statements per connection, so
growth only accumulates while one connection stays open; by default `archive_blocks`
spreads the ingest over several connections and retires each after 100 uses. The
summary reports how many backends were seen and how often the backend changed; anything
other than one stable backend means the numbers understate the growth.

**Growth is measured against inserted zkApp arrays, not elapsed time.** The bench counts
the rows in `zkapp_field_array` and `zkapp_events` and fits a least-squares line of RSS
against that count (`pg_backend_rss_kib_per_1k_arrays`, with r²). The end-to-end
difference, peak and tail average are reported too.

No threshold is applied: the job measures, it does not gate. Nothing is published if no
block was ingested, or if more than `--max-failed-blocks` (default 0) failed:
`archive_blocks` exits 0 even when every block fails.

The backend RSS is read from `/proc/<pid>/status`, so PostgreSQL must share the host's
PID namespace (`RunWithPostgres` starts it with `--pid=host`).

## Run it locally

```bash
docker run -d --name pg-bench --pid=host -e POSTGRES_PASSWORD=bench \
  -e POSTGRES_USER=bench -e POSTGRES_DB=archive -p 127.0.0.1:55441:5432 postgres:17-alpine
psql postgresql://bench:bench@127.0.0.1:55441/archive -f src/app/archive/create_schema.sql

export MINA_PROFILE=devnet
dune build src/app/archive_blocks/archive_blocks.exe \
  src/test/archive/archive_memory_bench/archive_memory_bench.exe
./_build/default/src/test/archive/archive_memory_bench/archive_memory_bench.exe \
  --uri postgresql://bench:bench@127.0.0.1:55441/archive
```

`--limit N` replays only the first N blocks; `-help` lists the rest.

## Regenerate the corpus

`generate_corpus.py` starts a local network (`scripts/mina-local-network`), deploys a
zkApp account, submits heavy `update-state` commands through `zkapp_test_transaction`,
then extracts the produced precomputed blocks into `precomputed_blocks.tar.xz` and the
network configuration into `genesis.json`.

```bash
export MINA_PROFILE=devnet
dune build \
  src/app/cli/src/mina.exe \
  src/app/archive/archive.exe \
  src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
  src/app/mina_graphql_client/mina_graphql_client_app.exe \
  src/app/logproc/logproc.exe

./src/test/archive/sample_zkapp_heavy/generate_corpus.py \
  --network-dir /tmp/zkapp-corpus-net \
  --count 120 --num-events 20 --num-actions 20 --elements-per 8
```

The network directory is deleted and recreated. A `libp2p_helper` must be on `PATH`. The
script prints the block / event / action counts it extracted; commands still in the
mempool after `--drain-sec` are not in the corpus.

> The zkApp deploy uses the **same** key as fee payer and sender: with distinct keys
> `create_zkapp_command` sets the sender's nonce precondition to `succ(sender_nonce)`,
> which no external nonce satisfies.
