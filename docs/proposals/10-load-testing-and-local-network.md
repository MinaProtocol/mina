# Proposal: Load Testing Package & Local Network Improvements

## Load Testing Tool: `batch_txn_tool`

### Current State

Located at `src/app/batch_txn_tool/`. Three subcommands:
- `gen-keys`: Generate N key pairs to stdout
- `gen-txns`: Generate shell scripts that invoke Mina CLI for payments (rate-limited)
- `gen-there-and-back-txns`: Directly submit transactions between two accounts via GraphQL

README is well-written with all parameters documented.

### Limitations
- No zkApp transaction support (payments only)
- No built-in metrics/reporting (TPS, latency, inclusion rate)
- `gen-txns` outputs shell scripts --- operator must pipe to `bash` themselves
- Private key passwords visible in `ps` output (security concern)
- **Not packaged as a Debian package**

### Should We Ship It?

**Yes.** Packaging `batch_txn_tool` as `mina-batch-txn-tool` Debian package is valuable for:
- Operators benchmarking their node's mempool handling
- Testing archive node ingestion under load
- Pre-production validation of node setup
- Load testing before hard forks or protocol upgrades

### Required Work
1. Add `make build-batch-txn-tool` target
2. Add Debian packaging recipe in `scripts/debian/`
3. Fix password exposure (use `MINA_PRIVKEY_PASS` exclusively, remove CLI password arg)
4. Add basic metrics output (transactions submitted, confirmed, average latency)

### Future Enhancements
- Add zkApp transaction support
- Add configurable transaction patterns (varying sizes, fees, nonces)
- Add result reporting (CSV/JSON output of per-transaction status)

**Effort**: Small --- 2-3 days for packaging + password fix. Medium for metrics.

---

## Local Network: `mina-local-network`

### Current State

Located at `scripts/mina-local-network/`. A bash script that:
- Generates genesis ledgers (via Python helper)
- Spawns multiple node processes (seed, whale/fish BPs, snark coordinator, archive)
- Manages port allocation
- Monitors processes

### Quality Assessment

| Aspect | Rating | Notes |
|--------|--------|-------|
| Documentation | 4/5 | Excellent README with all options, advanced configs, troubleshooting |
| Functionality | 3/5 | Works but requires pre-built binaries |
| Ease of use | 2/5 | Must build entire OCaml codebase first (10GB+ RAM, hours) |
| Production readiness | 1/5 | Local processes only, hardcoded passwords, no service management |
| Docker support | 0/5 | No Docker Compose file exists |

### Comparison with Other L1s

| L1 | Local Devnet Tool | Setup Time | Requirements |
|----|-------------------|-----------|--------------|
| Ethereum | `anvil` / `hardhat node` | Seconds | Single binary or `npx` |
| Solana | `solana-test-validator` | Seconds | Single binary from package |
| Cosmos | `simd` testnode | Seconds | Single binary |
| Mina | `mina-local-network.sh` | Hours | Full source build OR specific Docker tag |

### Should We Ship It?

**Yes, but with a Docker Compose wrapper.** The current bash script is not shippable as-is to external developers. However, wrapping it in Docker Compose using pre-built `lightnet` images would be transformative:

```yaml
# docker-compose.yml (proposed)
version: '3.8'
services:
  seed:
    image: minaprotocol/mina-daemon:latest-lightnet
    ...
  block-producer-1:
    image: minaprotocol/mina-daemon:latest-lightnet
    ...
  archive:
    image: minaprotocol/mina-archive:latest
    depends_on: [postgres]
    ...
  postgres:
    image: postgres:15
    ...
```

### Proposed Improvements

1. **Docker Compose local network** --- The single highest-impact improvement. Lets any developer run `docker compose up` to get a working Mina network with block production, archive node, and funded accounts.

2. **`mina-lightnet` package** --- Ship a Debian/Snap package containing the lightnet daemon + a `mina-local-network` wrapper script. Target: `apt install mina-lightnet && mina-local-network start`.

3. **Pre-funded test accounts** --- Include a set of well-known test accounts (with published private keys) in the lightnet genesis, similar to Hardhat's pre-funded accounts.

4. **Faucet endpoint** --- Add a simple GraphQL mutation or HTTP endpoint for minting test tokens on local networks (lightnet profile only).

5. **Fix outdated references** --- Update `snarkyjs` -> `o1js` in README.

### Is It Worth the Investment?

**Absolutely.** Every successful L1 ecosystem has an easy local devnet:
- Ethereum's ecosystem exploded partly because Ganache/Hardhat made local development trivial
- Solana's `test-validator` is the entry point for all new Solana developers
- A Docker Compose local network requires ~3-5 days of work and pays dividends in developer adoption

The lightnet profile already exists and is designed for this. The missing piece is packaging and discoverability.

**Effort**:
- Docker Compose: 3-5 days
- Debian package: 2-3 days
- Pre-funded accounts + docs: 1-2 days
