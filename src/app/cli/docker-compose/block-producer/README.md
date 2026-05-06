# Mina Block Producer Docker Compose

Run a Mina block producer node. Includes a one-shot wallet key generator and the daemon configured for block production.

## Services

| Service | Description | Default Port |
|---------|-------------|--------------|
| `generate_wallet_key` | One-shot: generates the block producer keypair (skipped if one already exists) | - |
| `mina_block_producer` | Mina daemon running with `--block-producer-key` | 3085 (GraphQL), 8302 (P2P) |

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

2. Edit `.env` — set `MINA_PRIVKEY_PASS` and `MINA_LIBP2P_PASS`. Both are required.

3. Start services:

```bash
docker compose up -d
```

4. Check logs:

```bash
docker compose logs -f                       # all services
docker compose logs -f mina_block_producer   # daemon only
```

## Funding the block producer

After the wallet key is generated, your block producer's public key is at `./mina_node/.mina-config/keys/wallet-key.pub`. Block production only kicks in once that account holds (or is delegated) staking funds.

```bash
cat ./mina_node/.mina-config/keys/wallet-key.pub
```

## Data persistence

| Path | Contents |
|------|----------|
| `./mina_node/.mina-config` | Daemon config, block producer key, libp2p key, peers |

## Make targets

| Command | Description |
|---------|-------------|
| `make devnet` | Copy devnet env and start services |
| `make mainnet` | Copy mainnet env and start services |
| `make stop` | Stop services |
| `make clean` | Stop services, remove volumes and `.mina-config` |
| `make logs` | Follow logs |
| `make status` | Container status |
| `make health` | GraphQL + sync status + container summary |

## Verifying the deployment

```bash
make health

docker compose exec mina_block_producer mina client status

curl -s http://localhost:3085/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{ daemonStatus { syncStatus blockchainLength } }"}' | jq .
```

## Clean start

```bash
make clean
docker compose up -d
```

> **Warning**: `make clean` removes `./mina_node/.mina-config`, which contains your **block producer key**. Back up `./mina_node/.mina-config/keys/` before running it if you want to keep the key.

## Configuration reference

See `example.devnet.env` and `example.mainnet.env`. Key differences between networks:

| Variable | Devnet | Mainnet |
|----------|--------|---------|
| `MINA_NETWORK` | `devnet` | `mainnet` |
| `MINA_PEERLIST_URL` | devnet seeds | mainnet bootnodes |
| `MINA_DAEMON_IMAGE` | `*-devnet` | `*-mainnet` |
