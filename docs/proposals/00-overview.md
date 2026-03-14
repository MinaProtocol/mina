# L1 Operator UX Improvements --- Overview

This directory contains proposals for improving the Mina Protocol L1 operator experience across the daemon, archive node, and Rosetta API.

## Proposals

| # | Title | Priority | Effort | Status |
|---|-------|----------|--------|--------|
| 01 | [Health Check Endpoints](01-health-endpoints.md) | Critical | Small (1-2d/service) | Proposed |
| 02 | [`mina doctor` Command](02-mina-doctor.md) | Critical | Medium (3-5d) | Proposed |
| 03 | [Logging Improvements](03-logging-improvements.md) | High | Small-Medium (2-4d) | Proposed |
| 04 | [CLI Restructure](04-cli-restructure.md) | Medium | Medium (3-5d) | Proposed |
| 05 | [Config Validation](05-config-validation.md) | Medium | Medium (3-5d) | Proposed |
| 06 | [Shutdown & Systemd](06-shutdown-and-systemd.md) | Medium | Small (1-2d) | Proposed |
| 07 | [Monitoring Package](07-monitoring-package.md) | Medium | Medium (3-5d) | Proposed |
| 08 | [SDK & BP Tools](08-sdk-and-block-producer-tools.md) | Medium | Large (2-4w total) | Proposed |
| 09 | [Docs Improvements](09-docs-improvements.md) | Medium | Medium-Large | Proposed |
| 10 | [Load Testing & Local Network](10-load-testing-and-local-network.md) | Nice-to-have | Medium (1-2w) | Proposed |
| 11 | [Bugs Found](11-bugs-found.md) | Critical (bugs) | Small (1-2d) | Proposed |
| 12 | [Health Check App](12-health-check-app.md) | Critical | Medium (4-5d) | Proposed |

## Quick Wins (< 1 day each)

1. Fix `failwith "test"` in Rosetta CLI (`src/app/rosetta/lib/cli.ml:22`)
2. Fix dead `codaprotocol.com` URL in crash handler
3. Fix SIGTERM exit code (130 -> 0) for systemd
4. Fix `archive prune` exit code on failure
5. Fix `docs/daemon.md` title ("Coda" -> "Mina")
6. Delete stale `docs/docker.md` and `docs/demo.md`
7. Update `snarkyjs` -> `o1js` in local network README
8. Add `MINA_ROSETTA_MAX_DB_POOL_SIZE` default in Rosetta

## Comparison with Other L1s

Mina is behind Ethereum, Solana, and Cosmos in operator tooling:
- No health endpoints (all three have them)
- No diagnostic command (Solana has `solana-watchtower`)
- No pre-built monitoring dashboards (Ethereum/Cosmos ship them)
- No single-command local devnet (Ethereum has Anvil, Solana has test-validator)
- No upgrade guide or CHANGELOG
- No error catalog or troubleshooting guide
- Limited block producer tooling (no slot schedule, no reward calculator)
- Good Prometheus metrics coverage
- Good GraphQL API breadth
- Good subscription support (newBlock, chainReorg)
