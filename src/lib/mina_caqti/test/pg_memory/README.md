# mina_caqti postgres memory-usage benchmark

A small, deterministic benchmark of the PostgreSQL backend memory used by
`Mina_caqti`'s DB helpers, useful as a standard memory-usage / regression check
for them.

What it measures: Caqti keys its per-connection prepared-statement cache by
request-object *identity*. A helper that builds a fresh `Caqti_request.t` on
every call therefore makes the backend register a new server-side prepared
statement (`PREPARE _caqtiN`) per call, which lives for the connection's
lifetime. On long-lived pooled connections those accumulate without bound and
grow the backend's memory.

The benchmark drives one helper `N` times on a single long-lived connection and,
**on that same connection**, samples two deterministic signals in a single query:

- `pg_prepared_statements` — exact server-side prepared-statement count;
- `pg_backend_memory_contexts` — backend cache/plan memory (PostgreSQL 14+).

A helper that builds a request per call makes the count grow linearly with the
number of calls; one that reuses its request — or marks it `~oneshot:true` so it
is never cached — keeps it flat.

Whether the second signal is available is discovered by querying it rather than
by comparing version numbers: on a server without the view the sample query
fails once, and the run continues reporting the prepared-statement count alone.

## Scenarios

| helper | requests built per call |
| --- | --- |
| `select_insert_into_cols` | 2 (SELECT + INSERT) |
| `insert_multi_into_col` | 2 (INSERT + SELECT) |
| `upsert_into_cols_returning` | 1 |

Every scenario uses `text` columns, which keeps the call sites valid across
signature variants of these helpers (`insert_multi_into_col` has taken both a
`string list` and a `'col list` of values; with `'col = string` the call is
identical either way).

The shapes are deliberately not uniform — `select_insert_into_cols` runs against
a three-column unique key, `upsert_into_cols_returning` against a two-column one
with a payload column (and reuses every second key, so the `ON CONFLICT DO
UPDATE` branch is exercised too), and `insert_multi_into_col` inserts a list
whose length varies per call.

Column values come from Quickcheck generators seeded per (scenario, iteration):
payload lengths and contents vary from call to call, while two runs of the
benchmark still see the identical sequence, which is what keeps the numbers
comparable across builds. Values that must not collide carry the iteration index
as a prefix — a duplicate would silently turn an INSERT into a SELECT hit and
change what is being measured.

## Usage

Needs a live PostgreSQL. Each scenario creates one table named
`pg_memory_<uuid>`, and drops that table when it finishes; nothing else in the
database is touched, and the tool never drops a table it did not create:

```sh
dune build src/lib/mina_caqti/test/pg_memory/main.exe

./_build/default/src/lib/mina_caqti/test/pg_memory/main.exe \
  --uri postgresql://user@localhost:5432/scratch \
  --iterations 2000 --sample-every 1000
```

The URI may also be supplied via `MINA_CAQTI_TEST_PG_URI`. With neither, the
tool prints a skip notice and exits 0 (no-op where no database is available).

`--assert-max-prepared K` makes it exit non-zero if any scenario's final
prepared-statement count exceeds `K`, so it can double as a CI regression guard.

### Perf metrics (InfluxDB)

`--influxdb-file PATH` writes one InfluxDB line-protocol point per scenario,
using the same measurement/tag convention as `scripts/tests/rosetta-load.sh`
so runs land in the perf time-series database:

```
mina_caqti_pg_memory_bench,branch=<b>,commit=<c>,variant=<v>,scenario=<name> \
  prepared_final=<n>i,prepared_per_call=<f>,iterations=<n>i,backend_kib_final=<n>i <ns>
```

`backend_kib_final` is present only where the server exposes
`pg_backend_memory_contexts` (PostgreSQL 14+); on older servers the field is left
out of the point rather than written as a zero, so the series is visibly absent
instead of looking like a flat measurement.

Tags are taken from `--variant`/`--network`/`--git-branch`/`--git-commit`
(falling back to `$MINA_BENCH_VARIANT` / `$GIT_BRANCH` / `$GIT_COMMIT`). Run the
tool once per build variant to chart one against another on the perf infra.

## Example

```
== scenario: select_insert_into_cols (table pg_memory_1a5d2fc119c535f3) ==
   calls      prepared     backend_KiB
   0          0            1380
   1000       2000         ...
   2000       4000         34418          <- 2 prepared statements per call
```

On a server older than PostgreSQL 14 the `backend_KiB` column reads `n/a`.
