# mina_caqti postgres memory-usage benchmark

A small, deterministic benchmark of PostgreSQL backend memory used by
`Mina_caqti`'s DB helpers. It was written to reproduce and measure the leak in
[MinaProtocol/mina#18857][18857], and stays useful afterwards as a standard
memory-usage / regression check. Root cause it targets: several `Mina_caqti`
helpers build a **fresh `Caqti_request.t` on every call**. Caqti keys its per-connection
prepared-statement cache by request-object *identity*, so each call makes the
backend register a new server-side prepared statement (`PREPARE _caqtiN`) that
lives for the connection's lifetime. On the archive's long-lived pooled
connections these accumulate without bound and OOM the postgres backend
(observed: 1.5–2 GB RSS per idle backend, ~1 OOMKill / 2 h on ITN).

The benchmark drives one helper `N` times on a single long-lived connection and,
**on that same connection**, samples two deterministic signals:

- `pg_prepared_statements` — exact server-side prepared-statement count;
- `pg_backend_memory_contexts` — backend cache/plan memory (PostgreSQL 14+).

On unfixed code the prepared-statement count grows linearly with the number of
calls; once the offending requests are marked `~oneshot:true` (or hoisted to a
module-level constant) it stays flat.

## Scenarios

| helper | requests built per call | fixed by |
| --- | --- | --- |
| `select_insert_into_cols` | 2 (SELECT + INSERT) | [#18858][18858pr] (`~oneshot:true`) |
| `insert_multi_into_col` | 2 (INSERT + SELECT) | [#18860][18860pr] (parameter binding) / [#18858][18858pr] |
| `upsert_into_cols_returning` | 1 | **neither PR** — included to show the residual leak (runs on every block) |

Every scenario uses a `text` column so the exact same source compiles against
`develop`, #18858 and #18860 (the latter changed `insert_multi_into_col`'s
`values` from `string list` to `'col list`; with `'col = string` the call is
unchanged).

## Usage

Needs a live PostgreSQL. Point it at a throwaway database (the tool creates and
drops its own `mb_*` tables):

```sh
dune build src/lib/mina_caqti/test/pg_memory/main.exe

./_build/default/src/lib/mina_caqti/test/pg_memory/main.exe \
  --uri postgresql://user@localhost:5432/scratch \
  --iterations 2000 --sample-every 1000
```

The URI may also be supplied via `MINA_CAQTI_TEST_PG_URI`. With neither, the
tool prints a skip notice and exits 0 (no-op where no database is available).

`--assert-max-prepared K` makes it exit non-zero if any scenario's final
prepared-statement count exceeds `K`, so it can double as a CI regression guard
on the fixed code.

### Perf metrics (InfluxDB)

`--influxdb-file PATH` writes one InfluxDB line-protocol point per scenario,
using the same measurement/tag convention as `scripts/tests/rosetta-load.sh`
so runs land in the perf time-series database:

```
mina_caqti_pg_memory_bench,branch=<b>,commit=<c>,variant=<v>,scenario=<name> \
  prepared_final=<n>i,prepared_per_call=<f>,backend_kib_final=<n>i,iterations=<n>i <ns>
```

Tags are taken from `--variant`/`--network`/`--git-branch`/`--git-commit`
(falling back to `$MINA_BENCH_VARIANT` / `$GIT_BRANCH` / `$GIT_COMMIT`). Run the
tool once per build variant (e.g. `variant=baseline` on develop and
`variant=pr18858` on the fixed build) to chart the before/after on the perf
infra.

## Example (develop, unfixed)

```
== scenario: select_insert_into_cols ==
   calls      prepared     backend_KiB
   0          0            1380
   1000       2000         ...
   2000       4000         34418          <- 2 leaked prepared stmts / call
```

With #18858 applied, `select_insert_into_cols` and `insert_multi_into_col` hold
at `prepared=0`, while `upsert_into_cols_returning` still climbs — demonstrating
that the two PRs fully neutralise the helpers they touch but do not eliminate
the leak class.

## Running in CI

The Buildkite job `Test/MinaCaqtiPgMemoryBench`
(`buildkite/src/Jobs/Test/MinaCaqtiPgMemoryBench.dhall`, runner
`buildkite/scripts/tests/mina-caqti-pg-memory-bench.sh`) provisions PostgreSQL in
the toolchain image, builds and runs this benchmark, and uploads the
`--influxdb-file` output to the perf InfluxDB via
`buildkite/scripts/bench/send.sh`. It is triggered by `dirtyWhen` on
`src/lib/mina_caqti`, so a change that adds `~oneshot:true` (or otherwise
touches the helpers) re-measures the leak automatically.

[18857]: https://github.com/MinaProtocol/mina/issues/18857
[18858pr]: https://github.com/MinaProtocol/mina/pull/18858
[18860pr]: https://github.com/MinaProtocol/mina/pull/18860
