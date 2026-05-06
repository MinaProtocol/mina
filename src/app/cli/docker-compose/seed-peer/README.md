# Mina Seed Peer Docker Compose

Run a Mina seed node — a publicly reachable peer that bootstraps newcomers into the network. Includes a one-shot libp2p keypair generator and the daemon configured with `--seed`.

## Services

| Service | Description | Default Port |
|---------|-------------|--------------|
| `generate_libp2p_key` | One-shot: generates the libp2p keypair | - |
| `mina_seed` | Mina daemon running with `--seed` and `--libp2p-keypair` | 3085 (GraphQL), 8302 (P2P) |

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

2. Edit `.env` — set `MINA_LIBP2P_PASS`. Required.

3. Start services:

```bash
docker compose up -d
```

4. Confirm reachability and find your peer ID:

```bash
make peer-id
```

## Building your relay-circuit address

Once the seed has its peer ID, build a multiaddr that other nodes can use as a `--peer`:

```
/ip4/<external-ip>/tcp/<libp2p-port>/p2p/<peer-id>
```

or with DNS:

```
/dns4/seed.example.com/tcp/8302/p2p/12D3Koo...
```

Submit a PR to [`MinaFoundation/seeds`](https://github.com/MinaFoundation/seeds) to get listed in the official seed peer list.

## Data persistence

| Path | Contents |
|------|----------|
| `./mina_node/.mina-config` | Daemon config, libp2p key, peers |

## Make targets

| Command | Description |
|---------|-------------|
| `make devnet` | Copy devnet env and start services |
| `make mainnet` | Copy mainnet env and start services |
| `make stop` | Stop services |
| `make clean` | Stop services, remove volumes and `.mina-config` |
| `make logs` | Follow logs |
| `make status` | Container status |
| `make peer-id` | Print this seed's libp2p peer ID |
| `make health` | GraphQL + peer ID + addresses + container summary |

## Verifying the deployment

```bash
make health

docker compose exec mina_seed mina client status

curl -s http://localhost:3085/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{ daemonStatus { peers { peerId } } }"}' | jq .
```

## Clean start

```bash
make clean
docker compose up -d
```

> **Warning**: `make clean` removes `./mina_node/.mina-config`, including your **libp2p key**. Your seed's multiaddr will change after a clean restart. Back up `./mina_node/.mina-config/keys/libp2p-key*` if you've published the multiaddr anywhere.

## Configuration reference

See `example.devnet.env` and `example.mainnet.env`. Key differences between networks:

| Variable | Devnet | Mainnet |
|----------|--------|---------|
| `MINA_NETWORK` | `devnet` | `mainnet` |
| `MINA_PEERLIST_URL` | devnet seeds | mainnet bootnodes |
| `MINA_DAEMON_IMAGE` | `*-devnet` | `*-mainnet` |
