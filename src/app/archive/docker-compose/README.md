# Mina Archive Node Docker Compose

Run a Mina archive node — a Postgres database that ingests blocks from a connected daemon, plus a missing-blocks guardian that backfills gaps from the daily archive dumps. Use this if you need historical chain state beyond the daemon's transition frontier (last `k` blocks).

## Services

| Service | Description | Default Port |
|---------|-------------|--------------|
| `postgres` | PostgreSQL 17 with health checks | 5432 (container), configurable host port |
| `bootstrap_db` | One-shot: downloads and imports the latest daily archive dump | - |
| `mina_archive` | Archive process, stores block data in PostgreSQL | 3086 |
| `missing_blocks_guardian` | Monitors and recovers missing blocks between nightly dumps and chain tip | - |
| `mina_node` | Mina daemon connected to the archive process via `--archive-address` | 3085 (GraphQL), 8302 (P2P) |

## Quick start

1. Copy the example env for your network:

```bash
# For devnet
cp example.devnet.env .env

# For mainnet
cp example.mainnet.env .env

# Or use make
make devnet
make mainnet
```

2. Edit `.env` — set `MINA_LIBP2P_PASS` and review `POSTGRES_PASSWORD`.

3. Start services:

```bash
docker compose up -d
```

4. Check logs:

```bash
docker compose logs -f
docker compose logs -f mina_archive
docker compose logs -f mina_node
```

## Connecting to the database

```bash
# From host
psql postgres://postgres:postgres@localhost:5433/archive

# From within a container
psql postgres://postgres:postgres@postgres:5432/archive
```

## Data persistence

| Path | Contents |
|------|----------|
| `./archive/postgresql/data` | Postgres data |
| `./archive/data` | Archive node data |
| `./mina_node/.mina-config` | Daemon config, keys, peers |

## Make targets

| Command | Description |
|---------|-------------|
| `make devnet` | Copy devnet env and start services |
| `make mainnet` | Copy mainnet env and start services |
| `make stop` | Stop services |
| `make clean` | Stop services, remove volumes, print host-side cleanup instructions for `./archive` and `./mina_node` (root-owned) |
| `make logs` | Follow logs |
| `make status` | Container status |
| `make health` | Postgres + GraphQL + container summary |

## Verifying the deployment

```bash
make health

# Mina node sync status
curl -s http://localhost:3085/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{ syncStatus }"}' | jq .

# Latest block in archive
psql postgres://postgres:postgres@localhost:5433/archive \
  -tAc "SELECT max(height) FROM blocks"

# Missing-blocks guardian progress
docker compose logs --tail=50 missing_blocks_guardian
```

## Clean start

```bash
make clean
docker compose up -d
```

> **Warning**: `make clean` deletes the entire archive database and the daemon's `.mina-config` (including any keys). The next start will re-download the latest archive dump (~30+ GB on mainnet).

## Configuration reference

See `example.devnet.env` and `example.mainnet.env`. Key differences between networks:

| Variable | Devnet | Mainnet |
|----------|--------|---------|
| `MINA_NETWORK` | `devnet` | `mainnet` |
| `MINA_PEERLIST_URL` | devnet seeds | mainnet bootnodes |
| `ARCHIVE_DUMP_PREFIX` | `devnet-archive-dump` | `mainnet-archive-dump` |
| `GUARDIAN_PRECOMPUTED_BLOCKS_URL` | devnet bucket | mainnet bucket |
| Docker image tags | `*-devnet` | `*-mainnet` |
