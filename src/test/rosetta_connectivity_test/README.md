# Rosetta connectivity test

`mina-rosetta-connectivity-test` joins devnet or mainnet and checks Rosetta
against the live chain. CI runs it as `RosettaDevnetConnect` (nightly) and
`RosettaMainnetConnect` (mainline nightly, release).

## What a run does

1. **Setup.** It creates the archive database and restores the network's
   newest public dump (at most 5 days old) from `mina-archive-dumps`. Then it
   starts two Rosetta instances (online and offline), an archive node, a daemon
   that joins the network, and the missing-blocks guardian. The guardian fills
   the gap between the dump and the daemon's first block.
2. **Sync.** It waits until Rosetta reports `Synced` and the daemon's best tip
   is less than 4 hours old.
3. **Sanity.** It sends one call per endpoint for fixed objects
   (`network.ml`) that every archive of the network contains.
4. **Load.** Each endpoint gets requests at a fixed rate, whether or not
   earlier requests have answered (an open loop). The request arguments are
   sampled from the archive. The run fails on any wrong response and on a p95
   latency above the endpoint's limit. Memory is reported to the bench
   database only.
5. **Compatibility.** It runs `upgrade.sql` twice, then `downgrade.sql` and
   `upgrade.sql` twice. After each round, the archive must write a new block.

On failure, the service logs, the daemon status and the daemon's top-level
logs go to `--artifacts-dir`.

## Local run

```sh
docker run -d --name rosetta-pg -p 127.0.0.1:5433:5432 \
  -e POSTGRES_USER=pguser -e POSTGRES_PASSWORD=pguser postgres:15

B=_build/default/src
$B/test/rosetta_connectivity_test/rosetta_connectivity_test.exe \
  --network devnet \
  --postgres-uri postgres://pguser:pguser@127.0.0.1:5433/archive \
  --mina $B/app/cli/src/mina.exe \
  --mina-archive $B/app/archive/archive.exe \
  --mina-rosetta $B/app/rosetta/rosetta.exe \
  --compatibility
```

Build the binaries with `DUNE_PROFILE=devnet` (or `mainnet`). The guardian
needs `mina-missing-blocks-guardian`, `mina-missing-blocks-auditor` and
`mina-archive-blocks` on `PATH`. Use `--no-backfill` to run without them.

To test an existing Rosetta (sanity and load only), give `--rosetta-uri` and
the `--postgres-uri` of its archive.

## Tuning

- `--load-rates endpoint=rps,...` and `--p95-limits endpoint=ms,...`
  override the defaults in `load.ml`.
- Endpoint names: `network_status`, `network_options`, `block`,
  `account_balance`, `payment_transaction`, `zkapp_transaction`.
