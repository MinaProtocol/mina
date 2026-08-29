# zkApp-heavy precomputed-block corpus

Static data for the **archive-node end-to-end memory benchmark**
(`buildkite/scripts/tests/archive-memory-bench.py`).

`precomputed_blocks.tar.xz` is a chain of **1273 precomputed blocks** produced by a local
`develop` network, deliberately loaded with heavy zkApp traffic:

- **89 zkApp commands**, carrying **~13,600 event fields + ~13,600 action fields**
  (≈1,700 event arrays and 1,700 action arrays of 8 fields each).

That volume is what exercises the archive's `zkapp_field_array` / event / action insert
paths, where the per-backend PostgreSQL memory leak (unbounded prepared-statement plan
caching, see the epic) shows up most.

## What the benchmark does

It replays these blocks through the real archive insert path
(`archive_blocks --precomputed` → `Processor.add_block_aux_precomputed` → the
`Mina_caqti` helpers) directly into a fresh PostgreSQL, and samples the resident memory
of both the `archive_blocks` process and the serving PostgreSQL backend. The result is
published to the perf-infra InfluxDB (measurement `archive_memory_bench`).

Two properties make those samples readable.

**The Caqti pool is pinned to one connection that is never recycled.** Caqti keys its
prepared-statement cache per connection, so the leak accumulates only while a connection
stays open. By default `archive_blocks` spreads the ingest over several pooled
connections and Caqti retires each one after `CAQTI_POOL_MAX_USE_COUNT` uses (100), which
throws the accumulated plan cache away. The benchmark therefore exports
`CAQTI_POOL_MAX_SIZE=1`, `CAQTI_POOL_MAX_IDLE_SIZE=1`, `CAQTI_POOL_MAX_IDLE_AGE=none` and
`CAQTI_POOL_MAX_USE_COUNT=none`. `--no-pin-pool` turns this off, for comparison only. The
summary reports how many backends were seen and how often the backend changed; anything
other than one stable backend means the numbers understate the leak.

**Growth is measured against inserted zkApp arrays, not against elapsed time.** The
corpus is a chain, so its zkApp commands land near the end of the replay. Against time,
"the heavy blocks started" and "memory is leaking" look the same. The benchmark therefore
counts the rows in `zkapp_field_array` and `zkapp_events` — the inserts that drive the
leaking helpers — and fits a least-squares line of RSS against that count, reporting
`pg_backend_rss_kib_per_1k_arrays` with its r². The end-to-end difference, the peak and
the tail average are still reported, but the slope is the leak measurement.

No baseline and no threshold are applied. The archive is known to leak, and has always
leaked; this job measures the size of it, it does not decide whether to fail.

PostgreSQL 14 or newer is expected (CI runs `postgres:17-alpine`). The benchmark warns on
an older server and still runs — its own RSS samples come from `/proc` — but
`pg_backend_memory_contexts`, which the companion `mina_caqti` micro-benchmark reads,
does not exist before 14.

## Run it locally

The database it connects to comes from the environment, as in CI: `PG_CONN`, the URI of a
database with the archive schema already loaded. `POSTGRES_URI` is accepted as well; when
it carries no database in its path -- which is how CI exports it -- `POSTGRES_DB` names
the database to join onto it.

```bash
nix develop mina
# from the repo root, against a database created with src/app/archive/create_schema.sql:
export PG_CONN=postgres://user:password@localhost:5432/archive_bench
./buildkite/scripts/tests/archive-memory-bench.py --perf-file /tmp/archive_memory.perf
```

It builds `archive_blocks`, unpacks this corpus, feeds it, and prints the growth curve, a
summary (archive RSS growth and slope, PG-backend RSS peak, tail average and slope,
backend stability), and the InfluxDB line it would upload. `--limit N` replays only the first N blocks and `--skip-build` reuses an
existing `archive_blocks.exe`, which together make a local run quick; `--help` lists the
rest.

Nothing is published if the replay ingested no block, or if more than
`--max-failed-blocks` (0 by default) failed to insert: `archive_blocks` exits 0 even when
every block fails, and a zeroed result reads on the dashboards as a leak-free build. On
any failure the tail of the `archive_blocks` log is printed.

## Regenerate / refresh the corpus (the zkApp-heavy load test)

Use the co-located `generate_corpus.py`. It bootstraps a small local network, submits
heavy zkApp `update-state` transactions (using `zkapp_test_transaction`'s
`--num-events` / `--num-actions` / `--elements-per` flags), then extracts and repackages
the produced precomputed blocks.

```bash
nix develop mina
# build the apps the generator needs
dune build \
  src/app/cli/src/mina.exe \
  src/app/archive/archive.exe \
  src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
  src/app/mina_graphql_client/mina_graphql_client_app.exe \
  src/app/logproc/logproc.exe

# generate ~120 heavy zkApp update-states and repackage the corpus in place
./src/test/archive/sample_zkapp_heavy/generate_corpus.py \
  --count 120 --num-events 20 --num-actions 20 --elements-per 8
```

Those four flags carry the defaults shown above; `--help` lists the rest (network
directory, GraphQL endpoint, genesis delay, drain time, output path). The script prints
the resulting block / event / action counts so you can confirm the corpus is heavy enough
(aim for ≥10 canonical blocks with zkApp commands, matching the archive test convention).

> Note: the zkApp deploy must use the **same** key as both fee-payer and sender —
> `create_zkapp_command` sets the sender's nonce precondition to `succ(sender_nonce)` when
> fee-payer ≠ sender, which no external nonce can satisfy. `generate_corpus.py` already
> does this.
