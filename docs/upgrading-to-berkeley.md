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
mina-verify-packaged-fork-config fork_config.json /tmp/mina-verification
```

Many of the script inputs are environment variables that default to the locations used by the debs. If you are building from source, inspect the script, determine what you need to change, and then run it.
