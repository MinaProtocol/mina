# Rosetta

Implementation of the [Rosetta API](https://docs.cloud.coinbase.com/rosetta/docs/welcome) for Mina.

## How to build your Docker image

Checkout the branch of the Mina repository matching the network you wish to use,
ensure your Docker configuration has a large amount of RAM (at least 12GB,
recommended 16GB) and then run the following:

```bash
cat dockerfiles/Dockerfile-mina-rosetta \
    | docker build -t mina-rosetta:v2.0.0 \
        --build-arg "network=berkeley" \
        --build-arg "image=debian:bullseye" \
        --build-arg "deb_codename=bullseye" \
        --build-arg "deb_release=berkeley" \
        --build-arg "deb_version=2.0.0berkeley-rc1-1551e2f" -
```

This creates an image (`mina-rosetta:v2.0.0`) based on Debian Bullseye that
includes the Mina daemon along with the Mina archive node, PostgreSQL, and Mina
Rosetta node. Each build argument is configurable and defines the following:

* `image`: base image used to build this image
* `deb_version`: Debian package version of the artifacts to install
* `deb_release`: Debian package repository
* `deb_codename`: Debian repository codename
* `network`: network version of the artifacts to install

To build an image with just the minimal requirements to run a Rosetta node (e.g. when connecting to an existing Mina node and archive DB) you can run the same
command but use `dockerfiles/Dockerfile-mina-daemon` instead.

Alternatively, you could use an official image that is built in exactly this way by buildkite CI/CD.

## How to run

### All-in-one container

The container includes 4 scripts in `/etc/mina/rosetta` that run a different set of services connected to a particular network

* `docker-standalone-start.sh` is the most straightforward, it starts only the
  Rosetta API endpoint and any flags passed into the script go to
  `mina-rosetta`. Use this to connect to an existing Mina node and archive.
* `docker-demo-start.sh` launches a Mina node with a very simple 1-address
  genesis ledger as a sandbox for developing and playing around. This script
  starts a full suite of tools (a Mina node, Mina archive, a PostgreSQL DB,
  and Rosetta node), but for a demo network with all operations occurring inside
  this container and no external network activity.
* The default, `docker-start.sh` connects the Mina node to our
  [Mainnet](https://docs.minaprotocol.com/node-operators/connecting-to-the-network)
  network and initializes the archive database from publicly available nightly
  O(1) Labs backups. As with `docker-demo-start.sh`, this script runs a Mina
  node, a Mina archive, a PostgreSQL DB, and Rosetta. The script also
  periodically checks for blocks that may be missing between the nightly backup
  and the tip of the chain and will fill in those gaps by walking back the
  linked list of blocks in the canonical chain and importing them one at a time.
  This can also be used to connect to other networks and has several
  configuration parameters. Take a look at the [source](https://github.com/MinaProtocol/mina/blob/src/app/rosetta/scripts/docker-start.sh)
  for more information about what you can configure and how.
* `docker-devnet-start.sh` connects the Mina node to our
  [Devnet](https://docs.minaprotocol.com/node-operators/connecting-to-devnet)
  network with the archive database initialized similarly to `docker-start.sh`.
  As with `docker-demo-start.sh`, this script runs a Mina node, a Mina archive, a
  PostgreSQL DB, and a Rosetta node. `docker-devnet-start.sh` is now just a
  special case of `docker-start.sh` so inspect the source there for more
  detailed configuration.
* Finally, the `docker-berkeley-start.sh` is the same as
  `docker-devnet-start.sh` but for the Berkeley network.

For example, to run the `docker-start.sh` and connect to a network:

```bash
docker run -it --rm --name rosetta \
    --entrypoint=./docker-start.sh \
    -p 10101:10101 -p 3081:3081 -p 3085:3085 -p 3086:3086 -p 3087:3087 \
    <DOCKER_IMAGE>
```

* Port 10101 is the default P2P port and must be exposed to the open internet
* The daemon listens to client requests on port 3081
* The GraphQL API runs on port 3085 (accessible via `localhost:3085/graphql`)
* Archive node runs on port 3086
* Rosetta runs on port 3087
* `<DOCKER_IMAGE>` should be the name of an image compatible with the
  network you wish to connect to.

Note: this image does not define a volume for DB data. If you want to persist it, please create a volume mapping pointing to the DB directory of the container (default: `/data/postgresql`).

### Standalone container

If you want to run the Rosetta server in a standalone container, you can do so by running the following command:

```bash
docker run -it --rm --name rosetta \
    -p 3087:3087 \
    --entrypoint=/etc/mina/rosetta/docker-start.sh \
    --graphql-uri http://<MINA_NODE_IP>:<MINA_NODE_PORT>/graphql \
    --archive-uri postgres://<POSTGRES_USER>:<POSTGRES_PWD>@<POSTGRES_HOST>:<POSTGRES_PORT>/<POSTGRES_DB> \
    <DOCKER_IMAGE>
```

* `--graphql-uri` is the address of the Mina node's GraphQL API
* `--archive-uri` is the address of the PostgreSQL database
* `<DOCKER_IMAGE>` should be the name of an image compatible with the
  network you wish to connect to. For standalone use, you can use the same
  image as the one used for the all-in-one use or the same image as the one
  used for the Mina node.

#### Using Docker Compose

If you want to run the Rosetta server in a standalone container using Docker Compose, you can look at the `docker-compose.yml` file [here](docker-compose/docker-compose.yml) for an example.

## Example queries via Rosetta

* `curl --data '{ metadata: {} }' 'localhost:3087/network/list'`
* `curl --data '{ network_identifier: { blockchain: "mina", network: "devnet" }, metadata: {} }' 'localhost:3087/network/status'`

Any queries that rely on historical data will fail until the archive database is populated. This happens automatically with the relevant entrypoints.

### Running natively

When `src/app/rosetta` is compiled it's also possible to run Rosetta natively,
without using the Docker image. This is more convenient in some cases, for
instance when testing development changes to the Rosetta server.

For instructions on how to set up a daemon, see the `README-dev.md` file and
follow the instructions in there. Additionally, Rosetta also relies on the
archive to store the history of the blockchain (which the daemon does not
remember for long due to its concise nature). See `src/app/archive/README.md`
for more information on how to run it. Rosetta does not use the archive
directly, though, but rather it connects to its database and queries it
directly.

Once this is done, the Rosetta server can be launched with the following
command:

```bash
$ MINA_ROSETTA_MAX_DB_POOL_SIZE=64 _build/default/src/app/rosetta/rosetta.exe \
    --port 3087 \
    --graphql-uri http://localhost:3085/graphql \
    --archive-uri postgres://pguser:pguser@localhost:5432/archive_berkeley
```

The `--graphql-uri` parameter gives the address at which Rosetta can connect to
the daemon's GraphQL service. It should point to the address where the Mina
daemon is running.

The `--archive-uri` parameter describes the connection to the database we
have just set up. It has the following form:

```text
postgres://{POSTGRES_USER}:{POSTGRES_USER}@{POSTGRES_HOST}:{POSTGRES_PORT}/{POSTGRES_DB}
```

`POSTGRES_USER` and `POSTGRES_DB` should be identical to those given in the
previous step. `POSTGRES_HOST` will usually be just `localhost` and
`POSTGRES_PORT`, unless specifically set up otherwise is `5432`.

## Design Choices

### Database Bootstrap Scripts

#### init-db.sh

As Mina does not store or broadcast historical blocks beyond the "transition frontier" (approximately 290 blocks), Rosetta requires logic to fetch historical data from a trusted archive node database. `docker-start.sh` and the `init-db.sh` script that it calls set up a fresh database when the node is first launched (located in `/data/postgresql` by default) and then restores the latest O(1) Labs nightly backup into that new database. If this data is persisted across reboots/deployments then the `init-db.sh` script will short-circuit and refuse to restore from the database backup.

#### download-missing-blocks.sh

In all cases, `download-missing-blocks.sh` will check the database every 5 minutes for any gaps / missing blocks until the first missing block is encountered. Once this happens, `mina-missing-blocks-auditor` will return the state hash and block height for whichever blocks are missing, and the script will download them one at a time from O(1) Labs JSON block backups until the missing blocks auditor reaches the genesis block.

If the data in PostgreSQL is really stale (>24 hours), it would likely be better/quicker to delete the `/data/` directory and force `init-db.sh` to restore from a complete database backup instead of relying on the individual block restore mechanism to download hundreds of blocks.

### Operation Statuses

Operations are always `Pending` if retrieved from the mempool. `Success` if they are in a block and fully applied. A transaction status of `Failed` occurs for transactions within a block whenever certain invariants are not met such as not sending enough to cover the account creation fee. Other reasons include misconfiguring new tokens or zkapps. See [this section of the code](https://github.com/MinaProtocol/mina/blob/03e11970387b05dd970c6ab0d1a0b01f18e3a8db/src/lib/coda_base/user_command_status.ml#L8-L21) for an exhaustive list.

### Operations Types

See [this section of the code](https://github.com/MinaProtocol/mina/blob/03e11970387b05dd970c6ab0d1a0b01f18e3a8db/src/lib/rosetta_lib/operation_types.ml#L4-L13) for an exhaustive list of operation types.

### Account metadata

Accounts in Mina are not uniquely identified by an address alone, you must also couple it with a `token_id`. A `token_id` of `wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf` denotes the default MINA token. Note that the `token_id` is passed via the metadata field of `account_identifier`.

### Operations for Supported Transactions via Construction

The following supported transactions for the Construction API are `payment` and `delegation`.

## Future Work and Known Issues

* Not fully robust to crashes on adversarial input.

---

## Details you probably don't need to dig into

### Validation

This Rosetta implementation has a few different test suites at different layers of the stack.

#### Unit Tests

Some of the more interesting endpoints have unit tests asserting their behavior is expected. Additionally, interesting bits of logic have unit test coverage: For example, there are unit tests that validate that different transactions' `to_operations` and `of_operations` functions are self-inverse.

#### Curl Tests

Most endpoints have an accompanying shell script in `src/app/rosetta/test-curl/` that can be run to manually hit and inspect those endpoints. To do so while developing locally run `./start.sh CURL`.

#### Integration Test Agent

A separate agent binary is optionally run on top of the Mina, Archive,
Rosetta triplet. This agent manipulates the Mina node through GraphQL and Rosetta to ensure certain invariants.

To test the Data API, for every kind of transaction supported in the Mina protocol, we turn off block production send this transaction via the Mina GraphQL API and then verify that (a) it appears in the mempool with operations we expect, and (b) after turning on block production and producing the next block that the same transaction appears in the block with the operations we expect.

To test the Construction API, for every kind of transaction supported in the Mina protocol, we turn off block production and then run through the standard Construction API flow as documented on the `rosetta-api` website. Further:

1. We ensure that the unsigned transaction returned from the `/payloads` endpoint parses, and that the signed transaction returned from the `/combine` endpoint parses, and that the operations before payloads and after parsing are consistent.
2. The hash returned by `/hash` is consistent with the hash the Mina daemon returns after submitting the transaction to the network.
3. The signature on the signed transactions is verified according to the signer.

Finally, we then take the signed transaction submit it to the network and go through the same flow as the Data API checks for this transaction. Ensuring its behavior is the same as if it had gone through the submit path via GraphQL directly.

The signer library used by the test agent can be used as a reference for further signer implementations. An executable interface is also provided via the [`signer.exe` binary](https://github.com/MinaProtocol/mina/blob/src/app/rosetta/ocaml-signer/signer.ml).

#### Rosetta CLI Validation

The Data API is fully validated using the official `rosetta-cli`
against private networks that issue every different type of
transaction. For instructions on how to run these tests manually,
see [README.md](rosetta-cli-config/README.md).

##### Run a fast sandbox network forever and test with rosetta-cli

```bash
$ docker run -d --rm \
    --publish 3087:3087 \
    --publish 3086:3086 \
    --publish 3085:3085 \
    --name mina-rosetta-demo \
    --entrypoint ./docker-demo-start.sh \
    <DOCKER_IMAGE>

$ docker logs --follow mina-rosetta-demo

# Wait for a message that looks like:
#
# Rosetta process running on http://localhost:3087
#
# wait a few more seconds, and then

$ rosetta-cli --configuration-file rosetta.conf check:data
```

### Model Regeneration

To regenerate the models:

Install openapi-generator, instructions [here](https://openapi-generator.tech/docs/installation/),
then

```bash
git clone https://github.com/coinbase/rosetta-specifications.git
cd rosetta-specifications
openapi-generator generate -i api.json -g ocaml -o out
cp -p out/src/models/* out/src/support/enums.ml $MINA/src/lib/rosetta_models/
```

In the generated files, the type `deriving` clauses will need to have `eq` added manually.
Any record types with a field named `_type` will need to annotate that field with `[@key "type"]`.
In `lib/network.ml`, update the two instances of the version number.
Check the diff after regeneration and be sure to add `[@default None]` and `[@default []]` to all relevant fields of the models
