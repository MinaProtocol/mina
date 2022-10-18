# Rosetta

Implementation of the [Rosetta API](https://www.rosetta-api.org/) for Mina.

## Changelog

2022/04/20: Add `MINA_ROSETTA_TERMINATE_ON_SERVER_ERROR` environment
  variable.  If that variable is set to any value, the process will
  terminate with exit code 1 if the server encounters an internal
  error.

2022/03/24:

- Fix: When a transaction is received in the same block that a transaction is
  sent, the nonce returned by the account-balance lookup returns an older nonce.
  There was also another edge case that hasn't occurred yet where nonces could
  be off-by-one, this is also now fixed.
- Release of rosetta-v18-beta2 with above changes

2022/03/18:

- Ensured memo is returned in user commands from /block endpoint
- Release of rosetta-v18 with above changes

2022/02/18:

- Added nonces to the balance table with all relevant schema migration changes and archive node changes to support it

2022/02/11:

- Replaced "Pending" status with null as demanded by the specification:
https://www.rosetta-api.org/docs/models/Operation.html

2022/02/09:

- Refactor docker build instructions to use a generic dockerfile that works across debian/ubuntu

2022/02/03:

- Removed the current test-agent, in part because it relies
   on the ability to enable and disable staking via GrapQL.
   That feature of the daemon had been deprecated, and has been
   removed. A new test-agent may appear in the future.
- Update for release/1.3.0 as opposed to purpose-built rosetta branches

2022/01/18:

- /network/list uses `MINA_ROSETTA_NETWORK`
- Include unsigned transaction in `hex_bytes` instead
- Under-the-hood improvements to the signature representation to prevent
  future regressions at the type-system level
- Release of rosetta-v16 with above changes

2022/01/13:

- Construction APIs use a new encoding scheme
- /network/list and /network/options also work offline
- Release of rosetta-v15 with above changes

2022/01/05:

- Deterministic responses to block and account balance queries so that
   they see same block at tip
- Optional `MINA_ROSETTA_MAX_HEIGHT_DELTA` environment variable to adjust
   the visible height of the tip
- Release of rosetta-v14 with above changes

2021/12/22:

- Attempts to fix missing pubkey SQL error
- Release of rosetta-v13 with all of the above (and below)

2021/12/15:

- Mainnet check:data succeeds with 99% reconciliation
- Ubuntu 20.04 support
- Release of rosetta-v12 with all of the above (and below)

2021/12/08:

- Uses the migrated archive node and changes around some queries
- Release of rosetta-v11 with all of the above (and below)

2021/11/19:

- Uses the archive node as a backup for checking for duplicates
- Release of rosetta-v10 with all of the above (and below)

2021/11/06:

- Properly throws duplicate transaction errors instead of bad nonce errors when
  duplicate transactions occur.
- Release of rosetta-v9 with all of the above (and below)

2021/11/06:

- Rebase off of a combination of stable daemon changes that are pending for next
  public release while removing unstable recent Rosetta changes that are still
  in testing.
- Release of rosetta-v8 with all of the above (and below)

2021/11/02:

- Adds explicit transaction submit errors for all known invalid transaction
  cases. Note: Fallback errors go through via GraphQL errors as before.

2021/10/27:

- Adds memo to construction in the same way as `valid_until`. To use a memo, add the `memo` field to the metadata next to `valid_until` and give it a string, like `"memo": "hello"`. The string must be small -- it is limited to less than 32 bytes.
- Adds valid_until and memo to the metadata of the `/construction/parse` response
- Release of rosetta-v6 with all of the above
- Make all lists in requests omittable
- Release of rosetta-v7 with all of the above

2021/10/26:

- Fix /account/balance returns an Account-not-found error instead of a Chain-info-missing error when an account is missing.
- Fix max_fee is now properly optional in the /construction/preprocess request.
- Release of rosetta-v5 with all of the above

2021/10/21:

- New Construction API features
  - Populate account_creation_fee in /construction/metadata response iff the receiver account does not exist in the ledger at the time this endpoint is called. Account_creation_fee is omitted from the JSON if the account does exist. If the account does not exist, then it is present and set to the account_creation_fee value (which is currently hardcoded to 1.0 MINA)
  - Suggested_fee in the metadata response now dynamically adjusts based on recent activity. The algorithm for predicting fee is: Take all the user-generated transactions from the most recent five blocks and then find the median and interquartile range for the fee amounts. The suggested fee is `median + (interquartile-range/2)`
  - Transactions can be set to expire using the newly exposed `valid_until` field. This is set during the /construction/preprocess step. Valid_until is a unsigned-32bit integer represented as a string in JSON. Example: `{ valid_until : "200000" }`. The unit for valid_until is a "global slot". To set a transaction's expiry date to 3 hours from the current time, you would take the current time, add 3 hours, subtract the genesis timestamp, and then divide the result by 3 to get the slot.
    Example:
      I want to expire a transaction in a few hours at UTC time x=1634767563.
      Genesis time is: 2021-03-17 00:00:00.000000Z or g=1615939200

      We can do 'x-g / 180' to get the slot number to give to valid_until.
      In this case, "104602" -- so we send `{ valid_until : "104602" }`
- New daemon stability fixes from 1.2.1 release (and new --stop-time flag to the daemon to configure the auto-shutdown behavior)
- Add rosetta-999.conf for testing 99.9% reconciliation on mainnet
- Update rosetta-dev.conf to use 99.9% reconciliation end condition
- Release of rosetta-v4 with all of the above

2021/10/15:

- Use a more liberal postgres configuration
- Set default transaction isolation to Repeatable Read
- Include new archive node changes for account creation fee edge case
- Allow for configuring the DUMP_TIME to import archive dumps not made automatically at midnight

2021/10/12:

- Adjust API to remove empty array responses
- Rename send/recieve operations to fee_payment
- Fix archive node bug for account creation fees
- Release rosetta-v3

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

Checkout the "release/1.3.0" branch of the mina repository, ensure your Docker configuration has a large amount of RAM (at least 12GB, recommended 16GB) and then run the following:

`cat dockerfiles/stages/1-build-deps dockerfiles/stages/2-opam-deps dockerfiles/stages/3-builder dockerfiles/stages/4-production | docker build -t mina-rosetta-ubuntu:v1.3.0 --build-arg "MINA_BRANCH=release/1.3.0" -`

This creates an image (mina-rosetta-ubuntu:v1.3.0) based on Ubuntu 20.04 and includes the most recent release of the mina daemon along with mina-archive and mina-rosetta.

Alternatively, you could use the official image `minaprotocol/mina-rosetta-ubuntu:1.3.0beta1-087f715-stretch` which is built in exactly this way by buildkite CI/CD.

## How to Run

The container includes 4 scripts in /rosetta which run a different set of services connected to a particular network
- `docker-standalone-start.sh` is the most straightforward, it starts only the mina-rosetta API endpoint and any flags passed into the script go to mina-rosetta. Use this for the "offline" part of the Construction API.
- `docker-demo-start.sh` launches a mina node with a very simple 1-address genesis ledger as a sandbox for developing and playing around in. This script starts the full suite of tools (a mina node, mina-archive, a postgresql DB, and mina-rosetta), but for a demo network with all operations occuring inside this container and no external network activity.
- `docker-test-start.sh` launches the same demo network as in demo-start.sh but also launches the mina-rosetta-test-agent to run a suite of tests against the rosetta API.
- The default, `docker-start.sh`, which connects the mina node to our [Mainnet](https://docs.minaprotocol.com/en/node-operators/connecting) network and initializes the archive database from publicly-availible nightly O(1) Labs backups. As with `docker-demo-start.sh`, this script runs a mina node, mina-archive, a postgresql DB, and mina-rosetta. The script also periodically checks for blocks that may be missing between the nightly backup and the tip of the chain and will fill in those gaps by walking back the linked list of blocks in the canonical chain and importing them one at a time. Take a look at the [source](https://github.com/MinaProtocol/mina/blob/rosetta-v16/src/app/rosetta/docker-start.sh) for more information about what you can configure and how.
- Finally, the previous default, `docker-devnet-start.sh`, which connects the mina node to our [Devnet](https://docs.minaprotocol.com/en/node-operators/connecting-devnet) network with the archive database initalized in a similar way to docker-start.sh. As with `docker-demo-start.sh`, this script runs a mina node, mina-archive, a postgresql DB, and mina-rosetta. `docker-devnet-start.sh` is now just a special case of `docker-start.sh` so inspect the source there for more detailed configuration.

For example, to run the `docker-devnet-start.sh` and connect to the live devnet:

```
docker run -it --rm --name rosetta --entrypoint=./docker-devnet-start.sh -p 10101:10101 -p 3085:3085 -p 3086:3086 -p 3087:3087 minaprotocol/mina-rosetta-ubuntu:v1.3.0
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

### Running natively

When `src/app/rosetta` is compiled it's also possible to run Rosetta natively,
without using the docker image. This is more convenient in some cases, for
instance when testing development changes to the Rosetta server.

In order to work, Rosetta needs a PostgreSQL database containing an archive
data collected from a Mina daemon. It also requires a connection to the Mina
daemon itself in order to fetch some data directly from it.

It might be convenient to set up the database inside a docker container anyway,
for instance like so:

```shell
$ docker run -d --name pg-mina-archive -p 5432:5432 -e POSTGRES_PASSWORD='*******' -e POSTGRES_HOST_AUTH_METHOD=trust -e POSTGRES_DB=mina_archive -e POSTGRES_USER=pguser postgres:14.5
```

The `POSTGRES_HOST_AUTH_METHOD=trust` instructs the database not to require
password for authentication. This is fine in development environments, but
highly discouraged in production. Note that, whether you want to set auth
method to `trust` or not, `POSTGRES_PASSWORD` is still required and must be
set.

Of course, it is also possible to set up the database natively, in which case
the settings above should be replicated.

For instructions on how to set up a daemon, see the `README-dev.md` file and
follow instructions in there. 

Once this is done, the Rosetta server can be launched with the following
command:

```shell
$ MINA_ROSETTA_MAX_DB_POOL_SIZE=64 _build/default/src/app/rosetta/rosetta.exe --port 3087 --graphql-uri http://localhost:3085/graphql --archive-uri postgres://pguser:pguser@localhost:5432/archive_berkeley
```

The `--graphql-uri` parameter gives address at which Rosetta can connect to
the daemon's GraphQL service. It should point to the address where the Mina
daemon is running.

The `--archive-uri` parameter describes the connection to the database we
have just set up. It has the following form:

```
postgres://{POSTGRES_USER}:{POSTGRES_USER}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}
```

`POSTGRES_USER` and `POSTGRES_DB` should be identical to those given in the
previous step. `POSTGRES_HOST` will usually be just `localhost` and
`POSTGRES_PORT`, unless specifically set up otherwise is `5432`.

## Design Choices

### Database Bootstrap Scripts

#### init-db.sh

As Mina does not store or broadcast historical blocks beyond the "transition frontier" (approximately 290 blocks), Rosetta requires logic to fetch historical data from a trusted archive node database. `docker-start.sh` and the `init-db.sh` script that it calls set up a fresh database when the node is first launched (located in /data/postgresql by default) and then restores the latest O(1) Labs nightly backup into that new database. If this data is persisted across reboots/deployments then the `init-db.sh` script will short-circuit and refuse to restore from the database backup.

#### download-missing-blocks.sh

In all cases, `download-missing-blocks.sh` will check the database every 5 minutes for any gaps / missing blocks until the first missing block is encountered. Once this happens, `mina-missing-blocks-auditor` will return the state hash and block height for whichever blocks are missing, and the script will download them one at a time from O(1) Labs json block backups until the missing blocks auditor reaches the genesis block.

If the data in postgresql is really stale (>24 hours), it would likely be better/quicker to delete the /data/ directory and force `init-db.sh` to restore from a complete database backup instead of relying on the individual block restore mechanism to download hundreds of blocks.

### Network names

Networks supported are `rosetta-demo`, `devnet`, and `mainnet`. Currently, the rosetta implementation does not distinguish between these networks, but this will change in the future. The default entrypoint script, `docker-start.sh` runs a mina daemon connected to the Mina [Mainnet](https://docs.minaprotocol.com/en/node-operators/connecting) network with an empty archive node and the rosetta api. To connect to our [Devnet](https://docs.minaprotocol.com/en/node-operators/connecting-devnet) network, the `docker-devnet-start.sh` entrypoint is provided and it functions identically to `docker-start.sh` except for Devnet. Additionally, there is a built-in entrypoint script for `rosetta-demo` called `docker-demo-start.sh` which runs a sandboxed node with a simple genesis ledger with one keypair, attaches it to an archive-node and postgres database, and launches the rosetta-api so you can make queries against it.

### Operation Statuses

Operations are always `Pending` if retrieved from the mempool. `Success` if they are in a block and fully applied. A transaction status of `Failed` occurs for transactions within a block whenever certain invariants are not met such as not sending enough to cover the account creation fee. Other reaons include misconfiguring new tokens or zkapps. See [this section of the code](https://github.com/MinaProtocol/mina/blob/4ae482b656c743fc4ea824419cebe2f2ff77ef96/src/lib/coda_base/user_command_status.ml#L8) for an exhaustive list.

### Operations Types

See [this section of the code](https://github.com/MinaProtocol/mina/blob/4ae482b656c743fc4ea824419cebe2f2ff77ef96/src/lib/rosetta_lib/operation_types.ml#L4) for an exhaustive list of operation types. Notable balance changing events are fee increases and decreases ("fee_payer_dec", "fee_receiver_inc"), payment increases and decreases ("payment_source_dec", "payment_receiver_inc"), and account creation fee ("account_creation_fee_via_payment", "account_creation_fee_via_fee_payer"), and the block reward or coinbase ("coinbase_inc").

### Account metadata

Accounts in Mina are not uniquely identified by an address alone, you must also couple it with a `token_id`. A `token_id` of 1 denotes the default MINA token. Note that the `token_id` is passed via the metadata field of `account_identifier`.

### Operations for Supported Transactions via Construction

The following supported transactions on devnet and mainnet for the Construction API are `payment` and `delegation`. The other transaction types are disabled on the live networks.

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

The Data API is fully validated using the official `rosetta-cli` against private networks that issue every different type of transaction. There are no reconcilliation errors. We are in the middle of verifying reconcilliation errors against devnet.

The Construction API is _not_ validated using `rosetta-cli` as this would require an implementation of the signer in the rosetta-go-sdk.

### Reproduce agent and rosetta-cli validation

`minaprotocol/mina-rosetta-ubuntu:v1.3.0` and `rosetta-cli @ v0.5.12`
using this [`rosetta.conf`](https://github.com/MinaProtocol/mina/blob/2b43c8cccfb9eb480122d207c5a3e6e58c4bbba3/src/app/rosetta/rosetta.conf) and the [`bootstrap_balances.json`](https://github.com/MinaProtocol/mina/blob/2b43c8cccfb9eb480122d207c5a3e6e58c4bbba3/src/app/rosetta/bootstrap_balances.json) next to it.

**Create one of each transaction type using the test-agent and exit**

```
$ docker run --rm --publish 3087:3087 --publish 3086:3086 --publish 3085:3085 --name mina-rosetta-test --entrypoint ./docker-test-start.sh -d minaprotocol/mina-rosetta:v16

$ docker logs --follow mina-rosetta-test
```

**Run a fast sandbox network forever and test with rosetta-cli**

```
$ docker run --rm --publish 3087:3087 --publish 3086:3086 --publish 3085:3085 --name mina-rosetta-demo --entrypoint ./docker-demo-start.sh -d minaprotocol/mina-rosetta-ubuntu:v1.3.0

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
openapi-generator generate -i api.json -g ocaml -o out
cp -p out/src/models/* out/src/support/enums.ml $MINA/src/lib/rosetta_models/
```
In the generated files, the type `deriving` clauses will need to have `eq` added manually.
Any record types with a field named `_type` will need annotate that field with `[@key "type"]`.
In `lib/network.ml`, update the two instances of the version number.
Check the diff after regeneration and be sure to add `[@default None]` and `[@default []]` to all relevant fields of the models
