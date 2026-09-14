# Mina SNARK Worker Docker Compose

Run a Mina SNARK coordinator together with a SNARK worker. The coordinator is a Mina daemon configured to advertise SNARK work and collect fees; the worker is an internal process that produces proofs and submits them to the coordinator.

## Services

| Service | Description | Default Port |
|---------|-------------|--------------|
| `generate_wallet_key` | One-shot: generates the SNARK fee account keypair | - |
| `mina_snark_coordinator` | Mina daemon with `--run-snark-coordinator` and `--snark-worker-fee` | 3085 (GraphQL), 8302 (P2P) |
| `mina_snark_worker` | `mina internal snark-worker` connected to the coordinator on port 8301 | - |

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

2. Edit `.env` — at minimum set `MINA_PRIVKEY_PASS`, `MINA_LIBP2P_PASS`, and review `MINA_SNARK_FEE` (in MINA, not nanomina).

3. Start services:

```bash
docker compose up -d
```

4. Check logs:

```bash
docker compose logs -f
docker compose logs -f mina_snark_coordinator
docker compose logs -f mina_snark_worker
```

## Scaling workers

To run multiple workers against the same coordinator, duplicate the `mina_snark_worker` service in `docker-compose.yml` with a different name:

```yaml
  mina_snark_worker_2:
    image: '${MINA_DAEMON_IMAGE}'
    restart: always
    entrypoint: []
    command: >
      bash -c '
        mina internal snark-worker \
             --daemon-address mina_snark_coordinator:${MINA_DAEMON_CLIENT_PORT} \
             --proof-level ${MINA_PROOF_LEVEL}
      '
    depends_on:
      mina_snark_coordinator:
        condition: service_healthy
```

## Data persistence

| Path | Contents |
|------|----------|
| `./mina_node/.mina-config` | Coordinator daemon config, fee account key, peers |

## Make targets

| Command | Description |
|---------|-------------|
| `make devnet` | Copy devnet env and start services |
| `make mainnet` | Copy mainnet env and start services |
| `make stop` | Stop services |
| `make clean` | Stop services, remove volumes, print host-side cleanup instructions for `./mina_node` (root-owned) |
| `make logs` | Follow logs |
| `make status` | Container status |
| `make health` | GraphQL + coordinator client status + container summary |

## Verifying the deployment

```bash
make health

docker compose exec mina_snark_coordinator mina client status

# Pending SNARK work
curl -s http://localhost:3085/graphql -H 'Content-Type: application/json' \
  -d '{"query":"{ snarkPool { workIds fee } }"}' | jq .
```

## Clean start

```bash
make clean
docker compose up -d
```

> **Warning**: `make clean` removes `./mina_node/.mina-config`, which contains your **SNARK fee account key**. Back up `./mina_node/.mina-config/keys/` before running it.

## Configuration reference

See `example.devnet.env` and `example.mainnet.env`. Key tunables:

| Variable | Description |
|----------|-------------|
| `MINA_SNARK_FEE` | Per-proof fee in MINA. Lower = more competitive but smaller revenue. |
| `MINA_WORK_SELECTION` | `rand` (default) or `seq`. `rand` randomizes work selection across coordinators. |
| `MINA_PROOF_LEVEL` | `full` for production. `check` / `none` are for testing only. |

| Variable | Devnet | Mainnet |
|----------|--------|---------|
| `MINA_NETWORK` | `devnet` | `mainnet` |
| `MINA_PEERLIST_URL` | devnet seeds | mainnet bootnodes |
| `MINA_DAEMON_IMAGE` | `*-devnet` | `*-mainnet` |
