# Mina Node Docker Compose

Run a full Mina node stack: daemon, archive, Rosetta API, Postgres, and missing blocks guardian.

## Services

| Service | Description | Default Port |
|---------|-------------|--------------|
| `postgres` | Archive database | 5433 (host) -> 5432 (container) |
| `bootstrap_db` | One-shot: runs [`mina-bootstrap archive`](../../bootstrap/) to download and import the daily archive dump | - |
| `mina_archive` | Archive process connected to Postgres | 3086 |
| `mina_node` | Mina daemon (block producer / seed) | 3085 (GraphQL), 8302 (P2P) |
| `mina_rosetta` | Rosetta API for exchanges/wallets | 3087 |
| `missing_blocks_guardian` | Monitors and recovers missing blocks | - |

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

2. Edit `.env` — at minimum set `MINA_LIBP2P_PASS` and review `POSTGRES_PASSWORD`.

3. Start all services:

```bash
docker compose up -d
```

4. Check logs:

```bash
docker compose logs -f              # all services
docker compose logs -f mina_node    # single service
```

## Connecting to the database

```bash
# From host
psql postgres://postgres:postgres@localhost:5433/archive

# From within a container
psql postgres://postgres:postgres@postgres:5432/archive
```

## Data persistence

Bind mounts preserve data across restarts:

| Path | Contents |
|------|----------|
| `./archive/postgresql/data` | Postgres data |
| `./archive/data` | Archive node data |
| `./mina_node/.mina-config` | Daemon config, keys, peers |
| `./mina_rosetta/.mina-config` | Rosetta config |

## Make targets

| Command | Description |
|---------|-------------|
| `make devnet` | Copy devnet env and start all services |
| `make mainnet` | Copy mainnet env and start all services |
| `make stop` | Stop all services |
| `make clean` | Stop services, remove volumes and all data |
| `make logs` | Follow logs for all services |
| `make status` | Show container status |
| `make health` | Check health of all endpoints |

## Health checks

```bash
# All-in-one
make health

# Manual checks:

# Mina node sync status
curl -s http://localhost:3085/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query":"{ syncStatus }"}' | jq .

# Rosetta network list
curl -s http://localhost:3087/network/list \
  -H 'Content-Type: application/json' -d '{}' | jq .

# Postgres block count
psql postgres://postgres:postgres@localhost:5433/archive \
  -tAc "SELECT count(*) FROM blocks"
```

## Clean start

```bash
make clean
docker compose up -d
```

## Configuration reference

See `example.devnet.env` and `example.mainnet.env` for all available variables.

Key differences between networks:

| Variable | Devnet | Mainnet |
|----------|--------|---------|
| `MINA_NETWORK` | `devnet` | `mainnet` |
| `MINA_PEERLIST_URL` | devnet seeds | mainnet bootnodes |
| Docker image tags | `*-devnet` | `*-mainnet` |

`bootstrap_db` runs the [`mina-bootstrap`](../../bootstrap/) CLI as a one-shot init container. The archive-dump URL and prefix are baked into the CLI per `--network`, so the compose stack no longer needs `ARCHIVE_DUMP_BASE_URL` / `ARCHIVE_DUMP_PREFIX` env vars.
