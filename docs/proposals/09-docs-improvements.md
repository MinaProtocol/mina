# Proposal: Documentation Overhaul

## Critical Issues (Fix Immediately)

### 1. Dead/Stale Documentation Files

| File | Issue | Action |
|------|-------|--------|
| `docs/docker.md` | References `codaprotocol/coda-daemon` (dead), old port 8303 (Kademlia, replaced by libp2p), dead GitHub links | **Delete or completely rewrite** |
| `docs/demo.md` | References `codaprotocol/coda-demo` (dead image) | **Delete or rewrite** |
| `docs/daemon.md` | Title says "Care and feeding of your Coda daemon" | **Fix title** |
| `docs/testnet-guardian-runbook.md` | References `codaprotocol.com`, Notion internal docs, old GCP infra | **Mark as internal/legacy or rewrite** |
| `docs/environment-variables.md` | References `/var/lib/coda` legacy path | **Add migration note** |
| `scripts/mina-local-network/README.md` | References `snarkyjs` (now `o1js`) | **Update to o1js** |
| Crash handler in `mina_run.ml` | Links to `https://codaprotocol.com/docs/troubleshooting/` (dead) | **Fix URL** |

### 2. Missing Critical Documents

| Document | Why It's Needed |
|----------|----------------|
| `CHANGELOG.md` | No rolled-up changelog exists. Only PR-level fragments in `changes/` directory. Operators upgrading have no way to know what changed. |
| `docs/upgrade-guide.md` | No upgrade procedure documentation. Operators don't know if config changed, if DB migration is needed, or what the rollback procedure is. |
| `docs/troubleshooting.md` | No structured error catalog. Operators hitting errors have no in-repo reference. |
| `docs/monitoring-guide.md` | Prometheus metrics are exported but undocumented. Operators can't build dashboards. |
| `docs/security-hardening.md` | No guidance on firewall rules, port exposure, key file permissions, systemd hardening. |
| `docs/performance-tuning.md` | No hardware requirements, OS tuning, storage IOPS guidance, or PostgreSQL sizing for archive. |
| `docs/architecture.md` | No architecture diagram in repo. Lucy README links to inaccessible Google Drive. |
| `docs/graphql-api-reference.md` | Raw schema dump exists but no human-friendly API reference. |

## Documentation Compared to Other L1s

| Category | Ethereum | Solana | Cosmos | Mina |
|----------|----------|--------|--------|------|
| Operator setup guide | Extensive | Extensive | Extensive | External only (docs2 repo) |
| CHANGELOG | Per release | Per release | Per release | None |
| Upgrade guide | Yes | Yes | Yes | None |
| Error catalog | EVM error codes | Yes | Yes | None |
| Monitoring guide | Dashboards | Yes | Yes | None |
| Performance tuning | Yes | Yes | Yes | None |
| Security hardening | Yes | Yes | Yes | None |
| Local devnet docs | Hardhat/Anvil | test-validator | simapp | Exists but outdated |
| Architecture diagrams | In repo | Yes | Yes | Google Drive only |
| API reference | Yes | Yes | Yes | Raw schema only |

## Proposed Action Plan

### Phase 1: Cleanup (1-2 days)
- Delete or mark as deprecated: `docs/docker.md`, `docs/demo.md`
- Fix "Coda" references in `docs/daemon.md`
- Fix dead URL in crash handler
- Update snarkyjs -> o1js in local network README

### Phase 2: Essential Docs (1-2 weeks)
- Create `CHANGELOG.md` (automate from `changes/` directory)
- Create `docs/upgrade-guide.md`
- Create `docs/troubleshooting.md` (start with top 20 error messages)
- Create `docs/monitoring-guide.md` with metrics catalog

### Phase 3: Complete Documentation (2-4 weeks)
- Create `docs/architecture.md` with Mermaid diagrams
- Create `docs/graphql-api-reference.md`
- Create `docs/security-hardening.md`
- Create `docs/performance-tuning.md`

## Effort Estimate

Phase 1: 1-2 days. Phase 2: 1-2 weeks. Phase 3: 2-4 weeks.
