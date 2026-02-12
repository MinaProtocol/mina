# Mina Local Network Manager

A script to spin up a local Mina blockchain network for development and testing.

## Quick Start

### Prerequisites
- Mina repository checked out
- Python 3 and `jq` installed
- PostgreSQL (optional, for archive node)

### Installation

1. Install Python dependencies:
   ```shell
   pip3 install -r ./scripts/mina-local-network/requirements.txt
   ```

2. Build Mina executables (using Nix):
   ```shell
   nix develop mina
   MINA_COMMIT_SHA1=$(git rev-parse HEAD) \
   DUNE_PROFILE="devnet" \
     dune build \
       src/app/cli/src/mina.exe \
       src/app/archive/archive.exe \
       src/app/logproc/logproc.exe
   ```

### Basic Usage

Run a local network with default settings:
```shell
./scripts/mina-local-network/mina-local-network.sh
```

Run with custom configuration:
```shell
./scripts/mina-local-network/mina-local-network.sh \
  -w 2 \          # 2 whale nodes
  -f 1 \          # 1 fish node
  -n 1 \          # 1 non-block-producing node
  -ll Trace \     # Console log level
  -fll Trace \    # File log level
  -vt \           # Enable value transfer transactions
  -ti 10          # Transaction interval (seconds)
```

View all options:
```shell
./scripts/mina-local-network/mina-local-network.sh -h
```

## Advanced Features and Examples

### New Seed Node Configuration

The `--seed` parameter now supports two modes:

1. **Spawn seed locally** (default):
   ```shell
   ./scripts/mina-local-network/mina-local-network.sh --seed "spawn:3000"
   ```

2. **Connect to external seed**:
   ```shell
   ./scripts/mina-local-network/mina-local-network.sh --seed "at:/ip4/127.0.0.1/tcp/3002/p2p/12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr"
   ```

### Partial Network Spawning

You can now spawn networks without certain components:

**Disable archive node** (default):
```shell
./scripts/mina-local-network/mina-local-network.sh -ap ""
```

**Disable snark coordinator**:
```shell
./scripts/mina-local-network/mina-local-network.sh -swp ""
```

**Network without seed** (connect to external seed):
```shell
./scripts/mina-local-network/mina-local-network.sh --seed "at:SEED_PEER_ID"
```

### Config Inheritance Modes

The `--config` parameter supports three modes:

1. **`reset`** - Generate new config, keypairs, and ledgers:
   ```shell
   ./scripts/mina-local-network/mina-local-network.sh -c reset
   ```

2. **`inherit`** - Reuse config from previous network:
   ```shell
   ./scripts/mina-local-network/mina-local-network.sh -c inherit
   ```

### Hardfork Testing

Support for hardfork testing with new parameters:

```shell
./scripts/mina-local-network/mina-local-network.sh \
  --hardfork-handling "some_value" \
  -hfd 100  # hardfork-genesis-slot-delta
```

### Demo Mode

Run a single pre-bootstrapped node for demonstrations:

```shell
./scripts/mina-local-network/mina-local-network.sh -d
```

### ITN Keys Support

Use ITN keys for node authentication:

```shell
./scripts/mina-local-network/mina-local-network.sh --itn-keys "keys.json"
```

### Log Redirection

Redirect node logs to files instead of console:

```shell
./scripts/mina-local-network/mina-local-network.sh --redirect-logs
```

### Genesis Timestamp Control

Control genesis timestamp with flexible options:

```shell
# Fixed timestamp
./scripts/mina-local-network/mina-local-network.sh -u "fixed:2024-01-01T00:00:00+00:00"

# Delay from current time
./scripts/mina-local-network/mina-local-network.sh -u "delay_sec:60"  # 60 seconds from now

# No update (default)
./scripts/mina-local-network/mina-local-network.sh -u "no"
```

### Slot Time Override

Override block production slot time:

```shell
./scripts/mina-local-network/mina-local-network.sh -st 5000  # 5 seconds
```

### Transaction and Chain End Slots

Control when transactions and block production stop:

```shell
./scripts/mina-local-network/mina-local-network.sh \
  -ste 1000  # Stop transactions after slot 1000
  -sce 2000  # Stop chain after slot 2000
```

## SnarkyJS and zkApps

- Now, if you’d like to work with `zkApps` using `SnarkyJS` locally, you need to update the `SnarkyJS` reference for your `zkApp` project (e.g. created using [zkApp-CLI](https://github.com/o1-labs/zkapp-cli) like this: `zk project foo`).

  - Suppose you’ve created `zkApp` at following path:
    - `~/projcts/zkapps/foo`
  - Go to `zkApp` project root (☝️).
  - Remove old `SnarkyJS` Node Module:
    - `rm -rf node_modules/snarkyjs`
  - Install its fresh version (built from sources as described above) instead:

    ```shell
    npm i ${HOME}/<path_to_Mina_repo>/src/lib/snarkyjs
    ```

  - Note: you can also refer to [this repo](https://github.com/o1-labs/e2e-zkapp/) in order to get environment setting up scripts.

## Lightweight Network (Fast Mode)

For faster testing with reduced resource usage, use the `lightnet` build profile:

1. Build with the `lightnet` profile:
   ```shell
   MINA_COMMIT_SHA1=$(git rev-parse HEAD) \
   DUNE_PROFILE="lightnet" \
     dune build \
       src/app/cli/src/mina.exe \
       src/app/archive/archive.exe \
       src/app/logproc/logproc.exe
   ```

2. Run the network (proof level is automatically set to `none` in lightnet):
   ```shell
   ./scripts/mina-local-network/mina-local-network.sh
   ```

**Lightnet Configuration:**
- Block window duration: 20 seconds (vs 180 seconds in devnet/mainnet)
- k (finality): 30 blocks
- Proof level: none (dummy proofs)
- Slots per epoch: 720

**Important Notes:**
- **Always test with `devnet` or `mainnet` profiles for production validation**
- Lightnet uses dummy proofs - not suitable for security testing
- May be unstable under heavy transaction load

## Common Use Cases

### Development Network
```shell
./scripts/mina-local-network/mina-local-network.sh \
  -w 2 -f 1 -n 1 \
  -vt -ti 30 \
  -ll Info -fll Debug \
  --redirect-logs
```

### Testing Network (Fast)
```shell
./scripts/mina-local-network/mina-local-network.sh \
  -w 1 -f 1 \
  -st 2000 \  # 2 second slots
  -c reset \
  -ll Trace
```

### Network with Archive Node
```shell
# First, ensure PostgreSQL is running
./scripts/mina-local-network/mina-local-network.sh \
  -ap 3086 \  # Archive server port
  -w 2 -f 1 \
  -vt
```

### Hardfork Test Network
```shell
./scripts/mina-local-network/mina-local-network.sh \
  -w 3 -f 2 \
  --hardfork-handling "test_value" \
  -hfd 150 \
  -c reset
```

## Important Notes

### Network Configuration
- **Always run at least 2 block producers** (`-w 2`) to prevent network halting
- Default work directory: `${HOME}/.mina-network`
- Account private key passphrase: `naughty blue worm`
- Seed peer ID is stored at `${ROOT}/seed_peer_id.txt`

### Archive Node (PostgreSQL)
- Required for archive node functionality (`-ap` flag)
- Ensure PostgreSQL is running and accessible
- Database schema is automatically created when not inheriting config

### GraphQL Endpoints
- Available at `http://localhost:{port}/graphql`
- Ports follow pattern: base_port + 1 (e.g., seed:3001, fish:5001, etc.)
- Specific ports shown in script output

### Port Allocation
- Seed: `SEED_START_PORT` + [0-5] (client, rest, external, metrics, libp2p-metrics, itn-graphql)
- Whales: `WHALE_START_PORT` + i*6 + [0-5]
- Fish: `FISH_START_PORT` + i*6 + [0-5]
- Nodes: `NODE_START_PORT` + i*6 + [0-5]
- Snark Coordinator: `SNARK_COORDINATOR_PORT` + [0-5]

### Account Management

**Get encoded private key:**
```shell
mina.exe advanced dump-keypair \
  --privkey-path ~/.mina-network/offline_whale_keys/offline_whale_account_1
```

**Import and unlock account for transactions:**
```shell
mina.exe accounts import \
  --privkey-path ~/.mina-network/offline_whale_keys/offline_whale_account_1 \
  --rest-server 4006

mina.exe accounts unlock \
  --public-key "B62q..." \
  --rest-server 4006
```

## Troubleshooting

### Common Issues

1. **"Failed to generate daemon keypair"** - Check file permissions in `${ROOT}` directory
2. **PostgreSQL connection errors** - Verify PostgreSQL is running and credentials are correct
3. **Network not syncing** - Ensure at least 2 block producers are running
4. **Port conflicts** - Use different start ports or stop existing processes

### Debugging Tips

- Use `-ll Trace` for detailed console logs
- Enable `--redirect-logs` to capture logs to files
- Check `${ROOT}/nodes/` directory for individual node logs
- Use `mina client status -daemon-port PORT` to check node status

### Cleaning Up

To completely reset the network:
```shell
rm -rf ~/.mina-network
```

Or use a custom root directory:
```shell
./scripts/mina-local-network/mina-local-network.sh -r /tmp/test-network -c reset
```
