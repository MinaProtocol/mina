[##](##) Replayer component test

This folder holds static data which is used when testing replayer component. Name 'component' is used in context of test since it is not na unit tests but also not interfere with other mina components, so it cannot be called integration test. Basically test production version of replayer against manually prepared data and input config file using command:

```
psql -U postgres -c 'CREATE DATABASE archive'
psql -U postgres archive < ./src/test/archive/sample_db/archive_db.sql
dune exec src/app/replayer/replayer.exe -- --archive-uri postgres://postgres:postgres@localhost:5432/archive --input-file src/test/archive/sample_db/replayer_input_file.json --log-level Trace --log-json  | jq  -R -s 'split("\n") | map(fromjson? // .)'
```
The `--log-json  | jq  -R -s 'split("\n") | map(fromjson? // .)'` portion can be ommited but can be usefull as not all of the logged information is displayed normally.

It expects success

### Regenerate data

`./regenerate.sh` can be used to regenerate the data.
This script should work in the mina nix shell, or a similar environment.
`nix develop mina --command -- ./regenerate.sh`


This bulk of the time this script takes is calling mina-local-network.sh to bootstrap small network and generate archive data.
`DUNE_PROFILE=devnet ./scripts/mina-local-network/mina-local-network.sh -a -r -pu postgres -ppw postgres -zt -vt -lp &`
where:
- `-a` run archive (it will automatically create 'archive' schema)
- `-r` removes any artifacts from previous run to have clear situation
- `-pu -ppw` are database connection parameters
- `-zt` ran zkapp transactions
- `-vt` ran simple value transfer transactions

afterward the blocks are made canonical with `convert_chain_to_canonical.sh`

This is needed because we need to have some canonical blocks in archive database. The more the better. However, with current value of K parameter (responsible for converting pending block into canonical) this process can take a lot of time (> 7hours). Fortunately there are alternative solutions  for this problem.

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

`./src/test/archive/sample_db/convert_chain_to_canonical.sh postgres://postgres:postgres@localhost:5432/archive '3NLbZ28M72eewCxYUCE3CwQo5c7wPzoiGcNC5Bbe8oEnrutXtZt9'`

As a result archive database will now have blocks which are a part of chain from genesis block to target block, converted to canonical. All blocks which are not a part of mentioned chain and have height smaller than target blocks will be orphaned. Rest will be left intact as pending. DO NOT USE on production.

Then the data is dumped into `precomputed_blocks.zip`,`archive_db.sql`, `replayer_input_file.json` and `genesis.json`

### Dependencies

Replayer component tests uses postgres database only. It need to be accessible from host machine


