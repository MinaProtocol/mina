# Rosetta

Implementation of the [Rosetta API](https://www.rosetta-api.org/) for Coda.

## How to Run

As there is not currently a live network, the best way to run Rosetta is to run it against a sandbox node. Rosetta is best run using the official docker images provided here that run the Coda daemon, an archive node, and the rosetta process for you. See [Reproduce agent and rosetta-cli Validation](#reproduce-agent-and-rosetta-cli-validation) below for details.

## Design Choices

### Network names

Networks supported are `dev`, `debug`, and `testnet`. A sandbox network is a `debug` one. The `dev` net is the one with seed peers always located at `dev.o1test.net` (as soon as we turn it on), and otherwise you are connecting to the `testnet`. Currently, the implementation does not distinguish between these networks, but this will change in the future.

### Operation Statuses

Operations are always `Pending` if retrieved from the mempool. `Success` if they are in a block. A transaction status of `Failed` occurs for transactions within a block whenever certain invariants are not met such as not sending enough to cover the account creation fee. Other reaons include misconfiguring new tokens or snapps. See [this section of the code](https://github.com/CodaProtocol/coda/blob/4ae482b656c743fc4ea824419cebe2f2ff77ef96/src/lib/coda_base/user_command_status.ml#L8) for an exhaustive list.

### Operations Types

See [this section of the code](https://github.com/CodaProtocol/coda/blob/4ae482b656c743fc4ea824419cebe2f2ff77ef96/src/lib/rosetta_lib/operation_types.ml#L4) for an exhaustive list of operation types. Notable balance changing events are fee increases and decreases ("fee_payer_dec", "fee_receiver_inc"), payment increases and decreases ("payment_source_dec", "payment_receiver_inc"), and account creation fee ("account_creation_fee_via_payment", "account_creation_fee_via_fee_payer"), and the block reward or coinbase ("coinbase_inc").

### Account metadata

Accounts in Coda are not uniquely identified by an address alone, you must also couple it with a `token_id`. A `token_id` of 1 denotes the default CODA token. Note that the `token_id` is passed via the metadata field of `account_identifier`.

### Operations for Supported Transactions via Construction

All supported transactions via Construction API are shown as ["living" documentation](https://github.com/CodaProtocol/coda/blob/477bbdcdeeeafbcbaff74b9b1a83feacf104e5c9/src/app/rosetta/test-agent/poke.ml#L89) in our integration testing code.

## Validation

This rosetta implementation has a few different test suites at different layers of the stack.

### Unit Tests

Some of the more interesting endpoints have unit tests asserting their behavior is expected. Additionally, interesting bits of logic have unit test coverage: For example, there are unit tests that validate that different transactions' `to_operations` and `of_operations` functions are self-inverse.

### Curl Tests

Most endpoints have an accompanying shell script in `src/app/rosetta/test-curl/` that can be run to manually hit and inspect those endpoints. To do so while developing locally run `./start.sh CURL`.

### Integration Test Agent

A separate agent binary is optionally run on top of the coda, archive-node, rosetta triplet. This agent manipulates the Coda node through GraphQL and Rosetta to ensure certain invariants.

To test the Data API, for every kind of transaction supported in the Coda protocol, we turn off block production send this transaction via the Coda GraphQL API and then verify that (a) it appears in the mempool with operations we expect, and (b) after turning on block production and producing the next block that the same transaction appears in the block with the operations we expect.

To test the Construction API, for every kind of transaction supported in the Coda protocol, we turn off block production and then run through the standard Construction API flow as documented on the rosetta-api website. Further:

1. We ensure that the unsigned transaction returned from the `/payloads` endpoint parses, and that the signed transaction returned from the `/combine` endpoint parses, and that the operations before payloads and after parsing are consistent.
2. The hash returned by `/hash` is consistent with the hash the coda daemon returns after submitting the transaction to the network.
3. The signature on the signed transactions verifies according to the signer.

Finally we then take the signed transaction submit it to the network and go through the same flow as the Data API checks for this transaction. Ensuring its behavior is the same as if it had gone through the submit path via GraphQL directly.

The signer library used by the test agent can be used as a reference for further signer implementations. An executable interface is also provided via the [`signer.exe` binary](https://github.com/CodaProtocol/coda/blob/3ee8e525662d5243e83ac9d8d89df207bfca9cf6/src/app/rosetta/ocaml-signer/signer.ml).

### Rosetta CLI Validation

The Data API is fully validated using the official `rosetta-cli` against private networks that issue every different type of transaction (running the test-agent suite while `check:data` is run). There are no reconcilliation errors.

The Construction API is _not_ validated using `rosetta-cli` as this would require an implementation of the signer in the rosetta-go-sdk. The test-agent does a thorough job of testing the construction API, however, see the integration-test-agent section above.

### Reproduce agent and rosetta-cli validation

`gcr.io/o1labs-192920/coda-rosetta:debug-v1.1.4` and `rosetta-cli @ v0.5.12`
using this [`rosetta.conf`](https://github.com/CodaProtocol/coda/blob/2b43c8cccfb9eb480122d207c5a3e6e58c4bbba3/src/app/rosetta/rosetta.conf) and the [`bootstrap_balances.json`](https://github.com/CodaProtocol/coda/blob/2b43c8cccfb9eb480122d207c5a3e6e58c4bbba3/src/app/rosetta/bootstrap_balances.json) next to it.

**Create one of each transaction type and exit**

```
$ docker run --publish 3087:3087 --publish 3086:3086 --publish 3085:3085 --name coda-rosetta-test --entrypoint ./docker-test-start.sh -d gcr.io/o1labs-192920/coda-rosetta:debug-v1.1.4

$ docker logs --follow coda-rosetta-test

# Wait for a message that looks like:
#
# {"timestamp":"2020-09-08 15:05:30.648082Z","level":"Info","source":{"module":"Lib__Rosetta","location":"File \"src/app/rosetta/lib/rosetta.ml\", line 107, characters 8-19"},"message":"Rosetta process running on http://localhost:$port","metadata":{"pid":50,"port":3087}}
#
# wait a few more seconds, and then

$ rosetta-cli --configuration-file rosetta.conf check:data
```

**Run a fast sandbox network forever**

```
$ docker run --publish 3087:3087 --publish 3086:3086 --publish 3085:3085 --name coda-rosetta --entrypoint ./docker-demo-start.sh -d gcr.io/o1labs-192920/coda-rosetta:debug-v1.1.4

$ docker logs --follow coda-rosetta-test

# Wait for a message that looks like:
#
# Rosetta process running on http://localhost:3087
#
# wait a few more seconds, and then

$ rosetta-cli --configuration-file rosetta.conf check:data
```

## Future Work and Known Issues

Sorted by priority (highest priority first)

- Untested on a live network
- On a live network, you must _bootstrap your archive node_ if you join the network after the genesis block. Instructions will be provided when the network is online.
- Not fully robust to crashes on adversarial input
- `rosetta.conf` does not properly specify construction scenarios

## Dev locally

(Tested on macOS)

1. Install postgres through homebrew
2. brew services start postgres
3. Run `./make-db.sh` (just once if you want to reuse the same table)
4. Run `./start.sh` to rebuild and rerun the genesis ledger, the archive node, coda daemon running in "demo mode" (producing blocks quickly), and finally the rosetta server.
5. Rerun `./start.sh` whenever you touch any code

Note: Coda is in the `dev` profile, so snarks are turned off and every runs very quickly.

- `./start.sh` runs through an integration test suite and exits 0 on success
- `./start.sh CURL` skips the integration test suite and just produces blocks
- `./start.sh FOREVER` runs the integration test suite and produces blocks forever afterwards

## Model Regen

To regenerate the models:

```
git clone https://github.com/coinbase/rosetta-specifications.git
cd rosetta-specifications
`brew install openapi-generator`
openapi-generator generate -i api.json -g ocaml
mv src/models $CODA/src/lib/rosetta_models
```
