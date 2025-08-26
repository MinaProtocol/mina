# Internal details on Berkeley migration

To perform the upgrade from 1.5 to 2.0, first connect a node to the 1.5 network.
When it has synchronized, the `fork_config` GraphQL endpoint produces the protocol
state needed to start the new chain:

```sh
curl --location "http://localhost:3085/graphql" \
 --header "Content-Type: application/json" \
 --data "{\"query\":\"query MyQuery {\n  fork_config\n}\n\",\"variables\":{}}" | jq '.data.fork_config' > fork_config.json
 ```

 You may now shut down the node. ⚠️ **⚠️ Back up the config directory.⚠️** ⚠️ `mv ~/.mina-config ~/mina-1-final-config`. This is your last chance to save or archive the transition frontier as it existed at the end of the chain.

## Manual upgrade

If you installed mina from a package, skip to the [next section](#verifying-packaged-configuration). This section is if you build from source.

 Now that you have moved the old config directory, build or install Mina 2.0. Use `mina-create-genesis` (or, `dune exec --profile=mainnet src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe`) to bundle the ledgers and kickstart the new config. The 1.5 ledger format is slightly different than the 2.0 format which now includes a version number. A simple sed command corrects for this difference. This step will take some time, as it must hash the exported ledgers.


```sh
sed -i -e 's/"set_verification_key": "signature"/"set_verification_key": {"auth": "signature", "txn_version": "1"}/' fork_config.json

mkdir -p ~/.mina-config/genesis
mina-create-genesis --config-file fork_config.json --genesis-dir ~/.mina-config/genesis --hash-output-file ~/.mina-config/genesis_hashes.json
```

Next, drop the accounts from the fork config to form the start of the new config:

```sh
jq --slurpfile hashes ~/.mina-config/genesis_hashes.json 'del(.ledger) | del(.epoch_data.staking.accounts) | del(.epoch_data.next.accounts) * $hashes[0]' fork_config.json > ~/.mina-config/daemon.json
```

Finally, edit the `daemon.json` to also include the correct genesis timestamp. You will need to consult the release documentation for this value.

As an optional check, you can use `ldb` to compare the generated key-value databases to those archived on the web. The `ldb` tool is part of rocksdb, packaged as:

- Nix: `rocksdb.tools` (eg run this inside `nix-shell -p rocksdb.tools`)
- Debian/Ubuntu/Fedora: `rocksdb-tools`
- homebrew: `rocksdb`
- Arch Linux: `rocksdb-ldb` (AUR)

```sh
workdir=$(mktemp -d)
ldb_cmd=$(command -v rocksdb-ldb || command -v rocksdb_ldb || command -v ldb)
error=0
for file in ~/.mina-config/genesis/*.tar.gz; do
    tarname=${$(basename "$file")%.tar.gz}
    tardir="$workdir/verify-ledgers/$tarname"
    mkdir -p "$tardir/{web,generated}"
    tar -xzf "$file" -C "$tardir/generated"
    curl "https://s3-us-west-2.amazonaws.com/snark-keys.o1test.net/$tarname.tar.gz" | tar -xz -C "$tardir/web"
    $ldb_cmd --hex --db="$tardir/web" scan > $workdir/web.scan
    $ldb_cmd --hex --db="$tardir/generated" scan > $workdir/generated.scan

    if ! cmp $workdir/generated.scan $workdir/web.scan; then
        echo "Error: kvdb contents mismatch for $tarname"
        error=1
    fi
done
```

## Verifying packaged configuration


A script is installed (from `./scripts/mina-verify-packaged-fork-config`) that automates this process. If you want to verify that an installed Mina package was generated from the same configuration as the one exported earlier, it is as easy as:

```
mina-verify-packaged-fork-config (mainnet|devnet) fork_config.json /tmp/mina-verification
```

Many of the script inputs are environment variables that default to the locations used by the debs. If you are building from source, inspect the script, determine what you need to change, and then run it.

Here are some general instructions that should help you get most of the way there.

### Package Verification

#### Environment Setup
1. **Use a Debian Environment:** 
    - It is recommended to perform package verification in a Debian environment because macOS Intel emulation doesn’t support the required AVX instructions for libp2p.

2. **Environment Preparation:**
    - **Install mina-create-legacy-genesis**
      ```bash
      echo "deb [trusted=yes] http://packages.o1test.net bullseye stable" > /etc/apt/sources.list.d/o1.list
      apt-get update
      apt-get install mina-create-legacy-genesis=1.4.1-97f7d8c

    - **Direct Installation Script:**
    - ***NOTE this currently needs to be run as root***
        ``` bash
        #!/bin/bash
        export CONFIG_JSON_GZ_URL="https://storage.googleapis.com/tmp-hardfork-testing/fork-config-3NLRTfY4kZyJtvaP4dFenDcxfoMfT3uEpkWS913KkeXLtziyVd15.json.gz"
        export GENESIS_TIMESTAMP="2024-06-05T00:00:00Z"
        export NETWORK_NAME="mainnet"
        mkdir -p genesis_ledgers
        cp /var/lib/coda/config_93e02797.json genesis_ledgers/mainnet.json
        curl https://storage.googleapis.com/tmp-hardfork-testing/fork-config-3NLRTfY4kZyJtvaP4dFenDcxfoMfT3uEpkWS913KkeXLtziyVd15.json.gz > config.json.gz && gunzip config.json.gz && mina-verify-packaged-fork-config mainnet config.json /workdir/verification 
        ```

- **Prepare Environment Variables:** Set up the necessary environment variables manually to match the expected configuration for verification.
- **Create `genesis_ledgers` Directory:** Temporarily, create a new directory named `genesis_ledgers` in the working directory and place the daemon config for the required chain, typically `mainnet.json` there. Alternatively, make sure that `genesis_ledgers/mainnet.json` is present. The script assumes that it is running in a directory where this is present.


3. **Set Environment Variables:**
    - **GSUTIL Path:**
        ```bash
        export GSUTIL=/usr/bin/gsutil
        ```
    - **Download Block Data:**
        - Example command to download the block data:
            ```bash
            gsutil cp gs://mina_network_block_data/mainnet-<some-version>.json ./block_data.json
            export PRECOMPUTED_FORK_BLOCK=./block_data.json
            ```
    - **Verify Additional Variables:**
        - Confirm the following variables are properly set:
            ```bash
            CONFIG_JSON_GZ_URL=<url to fork config zip> ex: "https://storage.googleapis.com/fork-config-dryrun.json.gz"
            GENESIS_TIMESTAMP=<same ts as your genesis config> ex: "2024-05-03T00:00:00Z"
            NETWORK_NAME=<this should match the intended network> ex: mainnet
            PRECOMPUTED_BLOCK_GS_PREFIX=<url to the network block data> ex: "gs://mina_network_block_data/mainnet"
            ```

#### Verification Process
1. **Run the Verification Command:**
    - If the fork config is not already on your machine, you can download it with a command similiar to:
        ```bash
        curl https://storage.googleapis.com/fork-config-dryrun.json.gz > config.json.gz && gunzip config.json.gz && mina-verify-packaged-fork-config mainnet config.json /workdir/verification gs://mina_network_block_data/mainnet-pre-hf-dry-run-2
        ```
    - If the fork config is already available locally, use:
        ```bash
        mina-verify-packaged-fork-config mainnet fork-config-dryrun.json /tmp/mina-verification
        ```
