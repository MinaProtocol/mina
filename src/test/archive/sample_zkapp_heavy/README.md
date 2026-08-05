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
of both the `archive_blocks` process and the serving PostgreSQL backend. A leaking build
grows the backend RSS roughly with blocks ingested; a fixed build keeps it flat. The
result is published to the perf-infra InfluxDB (measurement `archive_memory_bench`).

## Run it locally

The database it connects to comes from the environment, as in CI: `POSTGRES_URI` with the
archive schema already loaded, and `POSTGRES_DB` (used to find the serving backends in
`pg_stat_activity`).

```bash
nix develop mina
# from the repo root, against a database created with src/app/archive/create_schema.sql:
export POSTGRES_URI=postgres://user:password@localhost:5432/archive_bench
export POSTGRES_DB=archive_bench
./buildkite/scripts/tests/archive-memory-bench.py --perf-file /tmp/archive_memory.perf
```

It builds `archive_blocks`, unpacks this corpus, feeds it, and prints the growth curve, a
summary (archive RSS growth, PG-backend RSS peak, tail average), and the InfluxDB line it
would upload. `--limit N` replays only the first N blocks and `--skip-build` reuses an
existing `archive_blocks.exe`, which together make a local run quick; `--help` lists the
rest.

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
