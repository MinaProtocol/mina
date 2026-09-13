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

`Mina_caqti` memoises its requests on the SQL text, so this is bounded no
matter how a call site is written — 60,000 calls of these scenarios against a
local PostgreSQL 16 ran at ~4,100 calls/s with 40,000 prepared statements
before that, and ~9,400 calls/s with one per SQL shape after. The benchmark
guards both halves of that: the prepared-statement count, and the cache's own
count of requests it could *not* share.

The benchmark drives one helper `N` times on a single long-lived connection and,
**on that same connection**, samples two deterministic signals in a single query:

- `pg_prepared_statements` — exact server-side prepared-statement count;
- `pg_backend_memory_contexts` — backend cache/plan memory (PostgreSQL 14+).

A helper that builds a request per call makes the count grow linearly with the
number of calls; one that reuses its request keeps it at one per SQL shape, and
one marked `~oneshot:true` — the only option when the values are rendered into
the SQL text — keeps it at zero.

Whether the second signal is available is discovered by querying it rather than
by comparing version numbers: on a server without the view the sample query
fails once, and the run continues reporting the prepared-statement count alone.

## Scenarios

| helper | requests | prepared statements for any N calls |
| --- | --- | --- |
| `select_insert_into_cols` | 2 (SELECT + INSERT) | 2 |
| `insert_multi_into_col` | 2 (INSERT + SELECT), `~oneshot:true` | 0 |
| `upsert_into_cols_returning` | 1 | 1 |

Each scenario calls its helper afresh on every iteration, which is what a call
site looks like; the shared requests are what keeps that from preparing a new
statement each time. The row type, by contrast, is built once per scenario, as
a table module holds its `typ`: a product type rebuilt per call has a fresh
identity, and the cache would rightly refuse to share it.

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

`--assert-no-repeat-misses` fails if any query could not share its request —
a call site building its `Caqti_type` per call — or if the cache hit its entry
cap because some query's SQL text varies per call. Both are leaks that the
prepared-statement count alone can miss on a short run.

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
== scenario: select_insert_into_cols_s0 (table pg_memory_1a5d2fc119c535f3) ==
   calls      prepared     backend_KiB
   0          0            1541
   1000       2            2147
   2000       2            2147          <- flat: the 2 requests are shared

== request cache ==
   hits=17994 first_builds=6 repeat_misses=0 entries=6 capped=false
```

Before the requests were shared, the same run read `2000 -> 4000` prepared
statements and a backend growing past 34 MiB.

On a server older than PostgreSQL 14 the `backend_KiB` column reads `n/a`.
