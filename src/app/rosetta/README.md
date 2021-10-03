# Rosetta

Implementation of the [Rosetta API](https://www.rosetta-api.org/) for Mina.

## Changelog

2021/09/12:

- Construction API ready to ship on rosetta-v2

2021/09/02:

- Build off of the rosetta-v2 branch so that compatible does not break in parrallel to this document
- All docker build instructions and docker image references have been updated accordingly

2021/08/31:

- Add init-db.sh and download-missing-blocks.sh to the normal daemon startup procedure to restore historical block data from O(1) Labs backups (See the Database Bootstrap section for more information about the implementation)
- Include rosetta-cli, mina-missing-blocks-auditor, and other rosetta/archive tooling in every container
- Include rosetta.conf and rosetta-dev.conf for the two major networks (mainnet and devnet respectively)
- Default to storing postgresql data and .mina-config in /data/, and the tools now wait to initialize those until runtime instead of during docker build
- Convert docker-devnet-start.sh into a special case / configuration of docker-start.sh based on the environment variables `MINA_NETWORK=devnet2` and `MINA_SUFFIX=-dev`

2021/08/24:

- Update docker image links and outdated coda references
- Support mainnet configuration with docker-start.sh and move devnet setup to docker-devnet-start.sh
- Include mainnet mina binaries AND devnet mina binaries (as mina-dev and rosetta-dev)
- Include the mina-rosetta-test-agent for running our internal test suite

2021/08/13:

- Updated Rosetta spec to v1.4.9
- Preliminary testing on the `devnet2` network
- Updated dockerfile split into stages
- New documentation for the start scripts
- Fixes:
  - When internal commands create new accounts, use a new operation `Account_creation_fee_via_fee_receiver`,
     so that the computed balance matches the live balance
  - Handle duplicate transaction hashes for internal commands where the command types differ,
     by prepending the type and `:` to the actual hash
  - Valid balance queries for blocks containing user commands, where the fee payer, source, or
     receiver balance id is NULL

2020/11/30:

- Upgrades from Rosetta spec 1.4.4 to 1.4.7

2020/9/14:

- Upgrades from Rosetta spec v1.4.2 to v1.4.4
- Handles case where there are multiple blocks at the same height
- "Failed transactions" decode into operations and reconcile properly

## How to build your own docker image

Checkout the "rosetta-v2" branch of the mina repository, ensure your Docker configuration has a large amount of RAM (at least 12GB, recommended 16GB) and then run the following:

`cat dockerfiles/stages/1-build-deps dockerfiles/stages/2-toolchain dockerfiles/stages/3-opam-deps dockerfiles/stages/4-builder dockerfiles/stages/5-prod-ubuntu | docker build -t mina-rosetta:v2 --build-arg "deb_codename=stretch" --build-arg "MINA_BRANCH=rosetta-v2" -`

This creates an image (mina-rosetta:v2) based on the most up-to-date changes that support rosetta. This image
can be used as a drop-in replacement for `gcr.io/o1labs-192920/mina-rosetta:v2` in any of the below commands for testing.

## How to Run

The container includes 4 scripts in /rosetta which run a different set of services connected to a particular network
- `docker-standalone-start.sh` is the most straightforward, it starts only the mina-rosetta API endpoint and any flags passed into the script go to mina-rosetta. Use this for the "offline" part of the Construction API.
- `docker-demo-start.sh` launches a mina node with a very simple 1-address genesis ledger as a sandbox for developing and playing around in. This script starts the full suite of tools (a mina node, mina-archive, a postgresql DB, and mina-rosetta), but for a demo network with all operations occuring inside this container and no external network activity.
- `docker-test-start.sh` launches the same demo network as in demo-start.sh but also launches the mina-rosetta-test-agent to run a suite of tests against the rosetta API.
- The default, `docker-start.sh`, which connects the mina node to our [Mainnet](https://docs.minaprotocol.com/en/using-mina/connecting) network and initializes the archive database from publicly-availible nightly O(1) Labs backups. As with `docker-demo-start.sh`, this script runs a mina node, mina-archive, a postgresql DB, and mina-rosetta. The script also periodically checks for blocks that may be missing between the nightly backup and the tip of the chain and will fill in those gaps by walking back the linked list of blocks in the canonical chain and importing them one at a time. Take a look at the [source](https://github.com/MinaProtocol/mina/blob/rosetta-v2/src/app/rosetta/docker-start.sh) for more information about what you can configure and how.
- Finally, the previous default, `docker-devnet-start.sh`, which connects the mina node to our [Devnet](https://docs.minaprotocol.com/en/advanced/connecting-devnet) network with the archive database initalized in a similar way to docker-start.sh. As with `docker-demo-start.sh`, this script runs a mina node, mina-archive, a postgresql DB, and mina-rosetta. `docker-devnet-start.sh` is now just a special case of `docker-start.sh` so inspect the source there for more detailed configuration.

For example, to run the `docker-devnet-start.sh` and connect to the live devnet:

```
docker run -it --rm --name rosetta --entrypoint=./docker-devnet-start.sh -p 10101:10101 -p 3085:3085 -p 3086:3086 -p 3087:3087 gcr.io/o1labs-192920/mina-rosetta:v2
```

Note: It will take 20min-1hr for your node to sync

* Port 10101 is the default P2P port and must be exposed to the open internet
* The GraphQL API runs on port 3085 (accessible via `localhost:3085/graphql`)
* PostgreSQL runs on port 3086
* Rosetta runs on port 3087

Examples queries via Rosetta:

* `curl --data '{ metadata: {} }' 'localhost:3087/network/list'`
* `curl --data '{ network_identifier: { blockchain: "mina", network: "devnet" }, metadata: {} }' 'localhost:3087/network/status'`

Any queries that rely on historical data will fail until the archive database is populated. This happens automatically with the relevant entrypoints.

## Design Choices

### Database Bootstrap Scripts

#### init-db.sh

As Mina does not store or broadcast historical blocks beyond the "transition frontier" (approximately 290 blocks), Rosetta requires logic to fetch historical data from a trusted archive node database. `docker-start.sh` and the `init-db.sh` script that it calls set up a fresh database when the node is first launched (located in /data/postgresql by default) and then restores the latest O(1) Labs nightly backup into that new database. If this data is persisted across reboots/deployments then the `init-db.sh` script will short-circuit and refuse to restore from the database backup.

#### download-missing-blocks.sh

In all cases, `download-missing-blocks.sh` will check the database every 5 minutes for any gaps / missing blocks until the first missing block is encountered. Once this happens, `mina-missing-blocks-auditor` will return the state hash and block height for whichever blocks are missing, and the script will download them one at a time from O(1) Labs json block backups until the missing blocks auditor reaches the genesis block.

If the data in postgresql is really stale (>24 hours), it would likely be better/quicker to delete the /data/ directory and force `init-db.sh` to restore from a complete database backup instead of relying on the individual block restore mechanism to download hundreds of blocks.

### Network names

Networks supported are `rosetta-demo`, `devnet`, and `mainnet`. Currently, the rosetta implementation does not distinguish between these networks, but this will change in the future. The default entrypoint script, `docker-start.sh` runs a mina daemon connected to the Mina [Mainnet](https://docs.minaprotocol.com/en/using-mina/connecting) network with an empty archive node and the rosetta api. To connect to our [Devnet](https://docs.minaprotocol.com/en/advanced/connecting-devnet) network, the `docker-devnet-start.sh` entrypoint is provided and it functions identically to `docker-start.sh` except for Devnet. Additionally, there is a built-in entrypoint script for `rosetta-demo` called `docker-demo-start.sh` which runs a sandboxed node with a simple genesis ledger with one keypair, attaches it to an archive-node and postgres database, and launches the rosetta-api so you can make queries against it.

### Operation Statuses

Operations are always `Pending` if retrieved from the mempool. `Success` if they are in a block and fully applied. A transaction status of `Failed` occurs for transactions within a block whenever certain invariants are not met such as not sending enough to cover the account creation fee. Other reaons include misconfiguring new tokens or snapps. See [this section of the code](https://github.com/MinaProtocol/mina/blob/4ae482b656c743fc4ea824419cebe2f2ff77ef96/src/lib/coda_base/user_command_status.ml#L8) for an exhaustive list.

### Operations Types

See [this section of the code](https://github.com/MinaProtocol/mina/blob/4ae482b656c743fc4ea824419cebe2f2ff77ef96/src/lib/rosetta_lib/operation_types.ml#L4) for an exhaustive list of operation types. Notable balance changing events are fee increases and decreases ("fee_payer_dec", "fee_receiver_inc"), payment increases and decreases ("payment_source_dec", "payment_receiver_inc"), and account creation fee ("account_creation_fee_via_payment", "account_creation_fee_via_fee_payer"), and the block reward or coinbase ("coinbase_inc").

### Account metadata

Accounts in Mina are not uniquely identified by an address alone, you must also couple it with a `token_id`. A `token_id` of 1 denotes the default MINA token. Note that the `token_id` is passed via the metadata field of `account_identifier`.

### Operations for Supported Transactions via Construction

The following supported transactions on devnet and mainnet for the Construction API are the `payment` and `delegation` ones within the ["living" documentation](https://github.com/MinaProtocol/mina/blob/477bbdcdeeeafbcbaff74b9b1a83feacf104e5c9/src/app/rosetta/test-agent/poke.ml#L89) in our integration testing code. The other transaction types are disabled on the live networks.

## Future Work and Known Issues

- On a live network, in order to work with historical data, you must _sync your archive node_ if you join the network after the genesis block. Some Rosetta endpoints depend on this functionality. Instructions to be provided.
- On devnet and mainnet there are still a handful of edge cases preventing full reconcilliation that are being worked through
- There are several references to "coda" instead of the new name "mina"
- Not fully robust to crashes on adversarial input

---

# Details you probably don't need to dig into

## Validation

This rosetta implementation has a few different test suites at different layers of the stack.

### Unit Tests

Some of the more interesting endpoints have unit tests asserting their behavior is expected. Additionally, interesting bits of logic have unit test coverage: For example, there are unit tests that validate that different transactions' `to_operations` and `of_operations` functions are self-inverse.

### Curl Tests

Most endpoints have an accompanying shell script in `src/app/rosetta/test-curl/` that can be run to manually hit and inspect those endpoints. To do so while developing locally run `./start.sh CURL`.

### Integration Test Agent

A separate agent binary is optionally run on top of the mina, archive-node, rosetta triplet. This agent manipulates the Mina node through GraphQL and Rosetta to ensure certain invariants.

To test the Data API, for every kind of transaction supported in the Mina protocol, we turn off block production send this transaction via the Mina GraphQL API and then verify that (a) it appears in the mempool with operations we expect, and (b) after turning on block production and producing the next block that the same transaction appears in the block with the operations we expect.

To test the Construction API, for every kind of transaction supported in the Mina protocol, we turn off block production and then run through the standard Construction API flow as documented on the rosetta-api website. Further:

1. We ensure that the unsigned transaction returned from the `/payloads` endpoint parses, and that the signed transaction returned from the `/combine` endpoint parses, and that the operations before payloads and after parsing are consistent.
2. The hash returned by `/hash` is consistent with the hash the mina daemon returns after submitting the transaction to the network.
3. The signature on the signed transactions verifies according to the signer.

Finally we then take the signed transaction submit it to the network and go through the same flow as the Data API checks for this transaction. Ensuring its behavior is the same as if it had gone through the submit path via GraphQL directly.

The signer library used by the test agent can be used as a reference for further signer implementations. An executable interface is also provided via the [`signer.exe` binary](https://github.com/MinaProtocol/mina/blob/3ee8e525662d5243e83ac9d8d89df207bfca9cf6/src/app/rosetta/ocaml-signer/signer.ml).

### Rosetta CLI Validation

The Data API is fully validated using the official `rosetta-cli` against private networks that issue every different type of transaction (running the test-agent suite while `check:data` is run). There are no reconcilliation errors. We are in the middle of verifying reconcilliation errors against devnet.

The Construction API is _not_ validated using `rosetta-cli` as this would require an implementation of the signer in the rosetta-go-sdk. The test-agent does a thorough job of testing the construction API, however, see the integration-test-agent section above.

### Reproduce agent and rosetta-cli validation

`gcr.io/o1labs-192920/mina-rosetta:v2` and `rosetta-cli @ v0.5.12`
using this [`rosetta.conf`](https://github.com/MinaProtocol/mina/blob/2b43c8cccfb9eb480122d207c5a3e6e58c4bbba3/src/app/rosetta/rosetta.conf) and the [`bootstrap_balances.json`](https://github.com/MinaProtocol/mina/blob/2b43c8cccfb9eb480122d207c5a3e6e58c4bbba3/src/app/rosetta/bootstrap_balances.json) next to it.

**Create one of each transaction type using the test-agent and exit**

```
$ docker run --rm --publish 3087:3087 --publish 3086:3086 --publish 3085:3085 --name mina-rosetta-test --entrypoint ./docker-test-start.sh -d gcr.io/o1labs-192920/mina-rosetta:v2

$ docker logs --follow mina-rosetta-test
```

**Run a fast sandbox network forever and test with rosetta-cli**

```
$ docker run --rm --publish 3087:3087 --publish 3086:3086 --publish 3085:3085 --name mina-rosetta-demo --entrypoint ./docker-demo-start.sh -d gcr.io/o1labs-192920/mina-rosetta:v2

$ docker logs --follow mina-rosetta-demo

# Wait for a message that looks like:
#
# Rosetta process running on http://localhost:3087
#
# wait a few more seconds, and then

$ rosetta-cli --configuration-file rosetta.conf check:data
```

## Dev locally

(Tested on macOS)

1. Install postgres through homebrew
2. brew services start postgres
3. Run `./make-db.sh` (just once if you want to reuse the same table)
4. Run `./start.sh` to rebuild and rerun the genesis ledger, the archive node, mina daemon running in "demo mode" (producing blocks quickly), and finally the rosetta server.
5. Rerun `./start.sh` whenever you touch any code

Note: Mina is in the `dev` profile, so snarks are turned off and every runs very quickly.

- `./start.sh` runs through an integration test suite and exits 0 on success
- `./start.sh CURL` skips the integration test suite and just produces blocks
- `./start.sh FOREVER` runs the integration test suite and produces blocks forever afterwards

## Model Regeneration

To regenerate the models:

Install openapi-generator, instructions [here](https://openapi-generator.tech/docs/installation/),
then
```
git clone https://github.com/coinbase/rosetta-specifications.git
cd rosetta-specifications
openapi-generator generate -i api.json -g ocaml
cp -p src/models/* $MINA/src/lib/rosetta_models/
```
In the generated files, the type `deriving` clauses will need to have `eq` added manually.
Any record types with a field named `_type` will need annotate that field with `[@key "type"]`.
In `lib/network.ml`, update the two instances of the version number.
