## Replayer component test

This folder holds static data which is used when testing replayer component. Name 'component' is used in context of test since it is not na unit tests but also not interfere with other mina components, so it cannot be called integration test. Basically test production version of replayer against manually prepared data and input config file using command:

```
mina-replayer --archive-uri {connection_string} --input-file input.json 
```

It expects success

### Regenerate data

Data generation is still manual process. Mina local network script (./script/mina-local-network/mina-local-network.sh) can be used to bootstrap small network and generate archive data. For example below command is usually used:

```
./scripts/mina-local-network/mina-local-network.sh -a -r -pu postgres -ppw postgres -zt -vt
```

where:
- `-a` run archive (it will automatically create 'archive' schema)
- `-r` removes any artifacts from previous run to have clear situation
- `-pu -ppw` are database connection parameters
- `-zt` ran zkapp transactions
- `-vt` ran simple value transfer transactions

> :warning: Prior to mina-local-network run you need to build mina, archive, zkapp_transaction, logproc apps

It is important to mention that properly generated archive data should have at least 10 canonical blocks as we run replayer tests only on canonical blocks.

After we are satisfied with data generation process. We can dump archive data and prepare input replayer file from genesis_ledger.json file from our local network

#### Full script

Disclaimer: I'm a nix user and has already setup nix on my machine 

```
nix develop mina

dune build src/app/cli/src/mina.exe src/app/archive/archive.exe src/app/zkapp_test_transaction/zkapp_test_transaction.exe src/app/logproc/logproc.exe

./scripts/mina-local-network/mina-local-network.sh -a -r -pu postgres -ppw postgres -zt -vt

# archive_db.sql
pg_dump -U postgres -d archive > archive_db.sql

# input file 
cp ~/.mina-network/mina-local-network-2-1-1/genesis_ledger.json
cat genesis_ledger.json | jq '.ledger.accounts' > _tmp.json
echo '{ "genesis_ledger": { "accounts": '$(cat _tmp.json)' } }' | jq > input.json
            

```

#### Alternatives

As mentioned in previous section we need to have some canonical blocks in archive database. The more the better. However, with current value of K parameter (responsible for converting pending block into canonical) this process can take a lot of time (> 7hours). Fortunately there are alternative solutions  for this problem.

a) We can alter input config and use `target_epoch_ledgers_state_hash` property in replayer input file to inform replayer that we want to replay also pending blocks. Example:

```
{ 
    "target_epoch_ledgers_state_hash": "3NLbZ28M72eewCxYUCE3CwQo5c7wPzoiGcNC5Bbe8oEnrutXtZt9",
    "genesis_ledger": {
    "name": "release",
    "num_accounts": 250,
    "accounts": [
     {
      "pk": "B62qkamwHMkTvY3t9wu4Aw4LJTDJY4m6Sk48pJ2kSMtV1fxKP2SSzWq",
   .....
     
```

b) Convert pending chain to canonical blocks using helper script:

`./src/app/replayer/test/convert_chain_to_canonical.sh postgres://postgres:postgres@localhost:5432/archive '3NLbZ28M72eewCxYUCE3CwQo5c7wPzoiGcNC5Bbe8oEnrutXtZt9'`

As a result archive database will now have blocks which are a part of chain from genesis block to target block converted to canonical. All blocks which are not a part of mentioned chain and have height smaller than target blocks will be orphaned. Rest will be left intact as pending. DO NOT USE on production.

### Dependencies

Replayer component tests uses postgres database only. It need to be accessible from host machine



## Archive automode component test

`sample_mesa_hf_db` also drives a second component test, which exercises the
archive's automatic hard fork hand-over rather than the replayer:

```
./buildkite/scripts/archive-automode-test.sh --pg {connection_string}
```

The database is useful here because it crosses a fork. It holds berkeley blocks
up to height 1761 and mesa blocks from 1749, with the fork block at height 1748,
slot 3059, and the post-fork genesis at 1749, slot 3120.

The test rebuilds the pre-fork archive out of it (`prefork-state.sql` removes
the new era and sets the post-fork genesis aside), runs
`src/app/archive/upgrade_to_mesa.sql`, starts the archive, and sends the fork
configuration over the archive RPC with `mina advanced send-hardfork-config`.

It then checks two things in order, and the distinction between them is the
point of the test.

The archive **accepts the configuration as soon as it arrives**: it writes a
`hardfork_state` row with stage `announced`, which it keeps across restarts.
Accepting the announcement and acting on it are separate, though. While no
post-fork genesis block is present the archive must **change no block**, because
the fork block is so far attested only by that one message and nothing has
corroborated it.

Once the genesis block is put back -- its parent hash is the fork block's, so
the chain itself now confirms what the daemon said -- the repair runs and the
stage becomes `finalized`. The stranded band must then heal: every block up to
the fork canonical, the blocks off that chain orphaned, and the post-fork
genesis left alone.

### Confirmations

The archive requires blocks above the fork block before it settles, 20 by
default. This network cannot supply that many: `stop-slot-config.json` puts
`slot_tx_end` and `slot_chain_end` 20 slots apart, and that window produced 14
blocks. The test therefore passes `--hardfork-confirmations 10`, which the
fixture clears with room to spare.
