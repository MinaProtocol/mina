# Database



Database is a custom-built lightweight Rust-based key-value store in the form of a single append-only file. Storage data is now saved into the file system, which grants us more control and oversight for C++, increasing the node’s security. The new database follows the same API as the previous `rocksdb` package, making it a drop-in replacement. 

The database is a single append-only file, where each entry (key-value) are preceded by a header. Each entry in the Database has the following structure:

![image](https://github.com/openmina/mina/assets/60480123/1fb6b589-656d-4f00-ae8f-364bf8df63c2)


We are using compression on both keys and values with the library `zstd`. This provides the following advantages:



* **Space Efficiency**: Compression significantly reduces the amount of storage space required for our data.
* **Improved I/O Efficiency**: Data compression improves I/O efficiency by reducing the amount of data that needs to be read from or written to disk. Since disk I/O tends to be one of the slowest operations in a database system, anything that reduces I/O can have a significant impact on performance.
* **Cache Utilization**: By compressing data, more of it can fit into the database's cache. This increases cache hit rates, meaning that the database can often serve data from fast memory, leading to better performance.
* **Reduced Latency**: With smaller data sizes due to compression, the time taken for disk reads and writes is lowered. 

The compression makes the biggest difference on the transition frontier:



* With RocksDB, the frontier takes **245 MB** on disk.
* With our Rust implementation, takes **140 MB**.

Although we’ve replaced the storage, we still use the same format (`binprot`) for encoding the Merkle tree as well as the accounts. To validate data integrity, we use `crc32`.

The design of the Rust-based storage is based on information by performance-related data. This includes a redesign and improvement upon the implementation of the on-disk ledger (and possibly other similar data stores) used by the Mina node software. 

This employs techniques such as removing wasteful copying, delaying the application of actions until commit, optimizing space usage, and more. 


# How to run Mina with the new storage implementation and Docker

These instructions for connecting to berkeleynet.

Add this to a `.mina-env` file:

```bash
export MINA_PRIVKEY_PASS=""
export MINA_LIBP2P_PASS=""
PEER_LIST_URL=https://storage.googleapis.com/seed-lists/berkeley_seeds.txt
```

Create the `.mina-config` and `keys` directories:

```bash
mkdir .mina-config
mkdir keys
chmod 700 keys
```

Produce a libp2p keypair:

```bash
docker run -it --rm \
  --mount "type=bind,source=$(pwd)/keys,dst=/keys" \
  openmina/mina:rust-ondiskdb \
  libp2p generate-keypair --privkey-path /keys/p2pkey
```

And finally launch the daemon:

```bash
docker run --name mina -d \
  -p 8302:8302 --restart=always \
  --mount "type=bind,source=$(pwd)/.mina-env,dst=/entrypoint.d/mina-env,readonly" \
  --mount "type=bind,source=$(pwd)/keys,dst=/keys,readonly" \
  --mount "type=bind,source=$(pwd)/.mina-config,dst=/root/.mina-config" \
  openmina/mina:rust-ondiskdb \
  daemon --libp2p-keypair /keys/p2pkey --config-file /var/lib/coda/berkeley.json
```

For more information see [here](https://docs.minaprotocol.com/node-operators/connecting-to-the-network#docker)

# How to build Mina from scratch with the new storage implementation

## Install System Packages

### Debian/Ubuntu
1. Install packages from package manager:
    ```bash
    apt -y update && \
      apt -y upgrade && \
      apt -y install \
        apt-transport-https \
        ca-certificates \
        pkg-config \
        build-essential \
        curl \
        git \
        dnsutils \
        dumb-init \
        gettext \
        gnupg2 \
        unzip \
        bubblewrap \
        jq \
        libgmp10 \
        libgomp1 \
        libssl1.1 \
        libpq-dev \
        libffi-dev \
        libgmp-dev \
        libssl-dev \
        libbz2-dev \
        zlib1g-dev \
        m4 \
        libsodium-dev \
        libjemalloc-dev \
        procps \
        python3 \
        tzdata
    ```

## Install Other Prerequisites

1. Install **go**: https://go.dev/doc/install (version must be 1.18)

    Go is needed [libp2p_helper](https://github.com/MinaProtocol/mina/blob/2c63bd39c97441e8a188e762175953c2164f6500/src/app/libp2p_helper/README.md)
    which is a separate process that mina uses for p2p communication.

1. Install **capnproto**:

    ```bash
    curl -sSL https://capnproto.org/capnproto-c++-0.10.2.tar.gz | tar -zxf - \
      && cd capnproto-c++-0.10.2 \
      && ./configure \
      && make -j6 check \
      && make install \
      && cd .. \
      && rm -rf capnproto-c++-0.10.2
    ```

1. Install **opam**:

    ```bash
    sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)
    ```

1. Install **Rust**:

    ```bash
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    ```

## Clone And Build Mina

1. Get **mina** source code:

    ```bash
    git clone https://github.com/openmina/mina
    git checkout ledger-ondisk
    cd mina
    ```

1. Init submodules:

    ```bash
    git submodule update --init --recursive \
      && git config --local --add submodule.recurse true
    ```

1. Prepare **opam** and pin external packages:
    ```bash
    opam init --disable-sandboxing \
      && opam switch create . \
      && eval $(opam config env) \
      && opam switch import -y opam.export \
      && ./scripts/pin-external-packages.sh
    ```

1. Set `$DUNE_PROFILE`:

    Based on the `DUNE_PROFILE` env variable, different constants are used
    for mina daemon. It can be set to the filename from one of the files in
    [./src/config](https://github.com/MinaProtocol/mina/blob/2c63bd39c97441e8a188e762175953c2164f6500/src/config) directory:

    ```bash
    $ ls src/config/ | grep mlh
    debug.mlh
    dev.mlh
    devnet.mlh
    mainnet.mlh
    ...
    ```

    To configure built executable with **mainnet** constants defined in
    [mainnet.mlh](https://github.com/MinaProtocol/mina/blob/2c63bd39c97441e8a188e762175953c2164f6500/src/config/mainnet.mlh)
    ```bash
    export DUNE_PROFILE=mainnet
    ```

    To configure built executable with **devnet** constants defined in
    [devnet.mlh](https://github.com/MinaProtocol/mina/blob/2c63bd39c97441e8a188e762175953c2164f6500/src/config/devnet.mlh)
    ```bash
    export DUNE_PROFILE=devnet
    ```

    To let the system know the location of the new storage library:
    ```bash
    export LD_LIBRARY_PATH=$(pwd)/_build/default/src/lib/keyvaluedb_rust
    ```

1. Build packages:

    ```bash
    make libp2p_helper \
      # build daemon binaries.
      && make build_all_sigs \
      # build archive node binaries.
      && make build_archive_all_sigs
    ```

    Above will produce 2 types of binaries:
    - `*_testnet_signatures.exe`
    - `*_mainnet_signatures.exe`

    On testnet and on mainnet, signatures are generated slightly differently,
    so that signatures created for **testnet** network, will be invalid for
    **mainnet** and vise-versa.

    That's why we have 2 types of binaries. One for mainnet and one
    for testnet. That means that you need to run specific binary,
    based on which network you are going to connect to.

    Those binaries can be found in: `_build/default/src/app/cli/src/`

## Use Mina Daemon

Before you run mina daemon or archive node, you need to prepare genesis
ledger configuration.

In [./genesis_ledgers/](https://github.com/MinaProtocol/mina/blob/2c63bd39c97441e8a188e762175953c2164f6500/genesis_ledgers/)
directory, there are multiple configuration options.

If you plan to connect daemon to the **Devnet**:
```bash
cp ./genesis_ledgers/devnet.json ~/.mina-config/daemon.json
```

If you plan to connect daemon to the **Mainnet**:
```bash
cp ./genesis_ledgers/mainnet.json ~/.mina-config/daemon.json
```

This file along other configurations, contains accounts which are
available at the genesis block and their balances. You can modify
that file to create a custom chain/network and fill your test accounts
with as much tokens as you need. You can use [mina-sandbox](https://github.com/name-placeholder/mina-sandbox)
for conveniently deploy/run custom chain/network locally.

### Set Initial Peers

You need to set initial peer(s) in order for the daemon to do further
peer discovery and join that network. There are 2 arguments that you
can use:

1. `--peer-list-url <url>` - where `<url>` is the link to the file, which
   contains a list of initial peers.

   Devnet: https://storage.googleapis.com/seed-lists/devnet_seeds.txt

   Mainnet: https://storage.googleapis.com/seed-lists/mainnet_seeds.txt

1. `--peer <multiaddr>` - where `<multiaddr>` is the address or the list
   of addresses to use as initial peers for the node.

   Example: `/ip4/127.0.0.1/tcp/8302/p2p/12D3KooWFpqySZDHx7k5FMjdwmrU3TLhDbdADECCautBcEGtG4fr`

   More on [MultiAddr format](https://multiformats.io/multiaddr/)

### Run Mina Node

**Devnet**:
```bash
./_build/default/src/app/cli/src/mina_testnet_signatures.exe daemon \
  --peer-list-url https://storage.googleapis.com/seed-lists/devnet_seeds.txt
```

**Mainnet:**
```bash
./_build/default/src/app/cli/src/mina_mainnet_signatures.exe daemon \
  --peer-list-url https://storage.googleapis.com/seed-lists/mainnet_seeds.txt
```

### Run Mina Block Producer

For Block Producer, we need to pass keys for the block producing account
in the Mina blockchain. In the examples we will assume keys are stored
in: `~/.mina-config/keys`.

If you have just private key and not the files, you can generate those
files using command:
```bash
CODA_PRIVKEY=<privkey> \
MINA_PRIVKEY_PASS= \
mina advanced wrap-key --privkey-path ~/.mina-config/keys
```
Replace `<privkey>` with your private key. If your private key is encrypted
with a passcode, fill `MINA_PRIVKEY_PASS` as well, otherwise leave it empty.

**Devnet**:
```bash
./_build/default/src/app/cli/src/mina_testnet_signatures.exe daemon \
  --peer-list-url https://storage.googleapis.com/seed-lists/devnet_seeds.txt \
  --block-producer-key ~/.mina-config/keys
```

**Mainnet:**
```bash
./_build/default/src/app/cli/src/mina_mainnet_signatures.exe daemon \
  --peer-list-url https://storage.googleapis.com/seed-lists/mainnet_seeds.txt \
  --block-producer-key ~/.mina-config/keys
```

---
If you are using hardware wallet (like [Ledger](https://www.ledger.com/)),
for now you can't use it directly for running a block producer.
Instead, for security:

- Create another wallet, as a **hot wallet**.
- Delegate to it from **hardware wallet** account.
- Run block producer with that **hot wallet**.

This way, in the worst case, if the keys get leaked somehow, you will
only lose rewards left in the **hot wallet**, but the deposit will stay
safely in the **hardware wallet**.

### Run Mina Node on Berkeley QANet (develop)

[This branch](https://github.com/MinaProtocol/mina/pull/11831) must be used as the base and the node has to be built with `DUNE_PROFILE=devnet`.

Also a libp2p key is required, which can be generated with this command:

```bash
./_build/default/src/app/cli/src/mina.exe libp2p generate-keypair -privkey-path path/to/libp2pkey
```

Once built with `make build_all_sigs`, it can be launched with this command:

```bash
MINA_LIBP2P_PASS=some-password
./_build/default/src/app/cli/src/mina_testnet_signatures.exe daemon \
  --peer-list-url https://storage.googleapis.com/seed-lists/berkeley_seeds.txt \
  --config-file genesis_ledgers/berkeley.json \
   --libp2p-keypair path/to/libp2pkey
```

## Run tests:
```bash
cargo test --release
```

## Documentation:

```bash
cargo doc --open
```

