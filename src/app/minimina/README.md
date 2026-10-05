# MiniMina

MiniMina is a command line tool for spinning up Mina networks locally on a user's computer. It supports both Docker Compose and native process deployment modes, enabling integration tests of the Mina protocol outside of GCP. For design details, see the [RFC](docs/rfc/README.md).

## Prerequisites

- **Docker** - required for Docker mode. See [docker install](https://docs.docker.com/engine/install/).
- **Rust & Cargo** - required for building from source. See [Rust install](https://www.rust-lang.org/tools/install).

## Building

```bash
cd src/app/minimina
cargo build --release
cp target/release/minimina ~/.local/bin
```

Assuming `~/.local/bin` is on your `$PATH`, `minimina` will be available from the command line.

### Installing from Deb Package

```bash
echo "deb [trusted=yes] http://packages.o1test.net ubuntu stable" | sudo tee /etc/apt/sources.list.d/mina.list
sudo apt-get update
sudo apt-get install -y minimina
```

> The `stable` repository contains the release version, while `unstable` mirrors the current state of the main branch.

## Testing

```bash
cargo test
```

## Usage

```bash
minimina --help
minimina network --help
minimina node --help
```

---

## Default Network

Create a local blockchain network with default settings:

```bash
minimina network create
```

### Network Lifecycle

```bash
minimina network start
minimina network stop
minimina network delete
```

### Query Network

```bash
minimina network info
minimina network status
```

### Directory Structure

The default network is stored at `~/.minimina/default/` (override with `$MINIMINA_HOME`):

```
~/.minimina/default/
├── docker-compose.yaml
├── network.json
├── services.json
├── genesis_ledger.json
├── create_schema.sql
├── zkapp_tables.sql
├── libp2p-keypairs/    (12 files)
└── network-keypairs/   (12 files)
```

### Default Nodes

| Node | Role | GraphQL |
|------|------|---------|
| `mina-seed-1` | Seed | localhost:3101 |
| `mina-bp-1` | Block producer | localhost:4001 |
| `mina-bp-2` | Block producer | localhost:4006 |
| `mina-snark-worker-1` | SNARK worker | - |
| `mina-snark-coordinator` | SNARK coordinator | localhost:7001 |
| `mina-archive` | Archive node | localhost:5006 |

### Node Operations

**Logs:**
```bash
minimina node logs -n <node-name>                 # JSON logs
minimina node logs -n <node-name> --raw            # raw logs
```

**Start/Stop individual nodes:**
```bash
minimina node stop -n <node-name>
minimina node start -n <node-name>
minimina node start -n <node-name> --fresh-state
minimina node start -n <node-name> --import-accounts
minimina node start -n <node-name> --graphql-filtered-logs
```

**Dump data:**
```bash
minimina node dump-precomputed-blocks -n <node-name>
minimina node dump-archive-data -n <node-name>
minimina node run-replayer -n <node-name>
```

---

## Custom Networks (Lucy-Generated Genesis & Topology)

Pre-configured test networks are available in `./tests/data/`:

**Large network:**
```bash
minimina network create \
  -g ./tests/data/large_network/genesis_ledger.json \
  -t ./tests/data/large_network/topology.json \
  -n large-network
```

**Small network:**
```bash
minimina network create \
  -g ./tests/data/small_network/genesis_ledger.json \
  -t ./tests/data/small_network/topology.json \
  -n small-network
```

Manage custom networks with the same commands, using `-n <name>`:
```bash
minimina network start -n large-network
minimina network status -n large-network
minimina network stop -n large-network
minimina network delete -n large-network
```

---

## Network with Uptime-Service-Backend

Test data is in `tests/data/uptime_service_network`.

1. Populate `app_config.json` and `minasheets.json` with AWS S3 and Google Sheets credentials
2. Rename `uptime_service_config_test` to `uptime_service_config`
3. Create and start:

```bash
minimina network create \
  -n uptime \
  -t tests/data/uptime_service_network/topology.json \
  -g tests/data/uptime_service_network/genesis_ledger.json

minimina network start -n uptime
```

---

## Architecture

MiniMina supports two deployment modes:

- **Docker mode** (`src/docker/`): Uses Docker Compose to manage containerized Mina nodes
- **Native mode** (`src/native/`): Spawns Mina processes directly on the host machine

### Integration with Lucy

MiniMina is designed to work with [Lucy](../test_executive/README.md) (the Mina integration test executive). Lucy generates network topology and genesis files, then uses MiniMina to create and manage the test network:

1. Lucy generates topology and genesis files
2. Lucy calls `minimina network create` with those files
3. MiniMina returns GraphQL endpoints and log paths
4. Lucy executes integration tests via GraphQL
5. Lucy can start/stop individual nodes during tests
6. Lucy calls `minimina network delete` to tear down

## License

This project is licensed under the [MIT License](LICENSE).
