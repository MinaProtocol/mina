# mina-bootstrap

Go CLI that automates the pre-staging steps required to run a Mina archive
node, daemon, or Rosetta stack. Replaces the long sequences of `curl` +
`gsutil` + `psql` invocations currently inlined in operator docs and
docker-compose stacks.

See [MinaProtocol/mina#18842](https://github.com/MinaProtocol/mina/issues/18842)
for the design discussion and full subcommand roadmap.

## Status

v1 — `archive` and `precomputed` subcommands working. Genesis ledger,
replayer checkpoint, daemon state, and verify commands are scoped for
follow-ups.

## Build

```bash
cd src/app/bootstrap
go build -o ./bin/mina-bootstrap .
```

The binary is statically linked and has no runtime dependencies other than
`psql` from `postgresql-client` (only when using the `archive` subcommand
without `--skip-pg`).

## Subcommands

### `mina-bootstrap archive`

Download today's archive dump and restore it into Postgres.

```bash
mina-bootstrap archive \
  --network mainnet \
  --pg-uri "postgres://postgres:postgres@localhost:5432/archive"
```

Flags:

| Flag | Default | Description |
|---|---|---|
| `--network` | `mainnet` | `mainnet` or `devnet` |
| `--pg-uri` | (required) | Postgres connection URI |
| `--date` | today (UTC) | Dump date in `YYYY-MM-DD` form |
| `--hour` | `0000` | Dump hour in `HHMM` form. Dumps are produced hourly (`0000`, `0100`, `0200`, ...) |
| `--work-dir` | `.` | Where to download and extract |
| `--skip-pg` | `false` | Download + extract only, skip the psql restore |

The tool applies the same `ALTER SYSTEM` tuning the Rosetta compose stack
uses (`max_connections=500`, `max_locks_per_transaction=100`, etc.) before
loading the dump. Restart Postgres after bootstrap to make the tuning take
effect.

### `mina-bootstrap precomputed`

Fetch a range of precomputed blocks for archive backfill.

```bash
mina-bootstrap precomputed --network mainnet --range 50000-51000 --out ./blocks
```

Range formats:

| Form | Meaning |
|---|---|
| `--range 50000` | Single block at height 50000 |
| `--range 50000-51000` | Closed range, inclusive on both ends |
| `--range 50000-` | Open-ended — from 50000 to chain tip. Stops after 1000 consecutive missing heights |

The tool refuses anything over 50,000 blocks per invocation. Operators backfilling large gaps should split into chunks. The cap exists to prevent a typo from triggering tens of thousands of HTTP requests against the public bucket.

After download, apply the blocks with the existing `mina-archive-blocks`
tool — keeping that step explicit so operators can decide ordering and
batch size. A future `mina-bootstrap apply-blocks` subcommand can wrap that
once we have demand.

## Authentication

The Mina Foundation's public buckets accept anonymous reads, so no
credentials are needed for the common operator flows. If the bucket policy
ever requires auth, the standard Google SDK chain applies:
`GOOGLE_APPLICATION_CREDENTIALS`, `gcloud` user credentials, GCE metadata.

## Usage in Docker

Built as `gcr.io/o1labs-192920/mina-bootstrap:<tag>` from
`dockerfiles/Dockerfile-mina-bootstrap`. Drop into any compose stack as a
one-shot init service:

```yaml
services:
  bootstrap:
    image: gcr.io/o1labs-192920/mina-bootstrap:3.0.4
    command:
      - archive
      - --network=mainnet
      - --pg-uri=postgres://postgres:postgres@postgres:5432/archive
    depends_on:
      postgres:
        condition: service_healthy

  archive:
    image: gcr.io/o1labs-192920/mina-archive:3.0.4
    depends_on:
      bootstrap:
        condition: service_completed_successfully
```

This replaces the inline bash in `src/app/rosetta/docker-compose/docker-compose.yml`'s
`bootstrap_db` service.

## Development

```bash
go test ./...
go vet ./...
golangci-lint run         # if installed
go build -o ./bin/mina-bootstrap .
./bin/mina-bootstrap --help
```

For local smoke tests against a real GCS bucket, the `--skip-pg` flag on
`archive` lets you exercise the download + extract path without a Postgres
dependency.
