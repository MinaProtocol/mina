# Hard Fork Package Generation

Generating new software packages for hard fork releases on the Mina daemon by bundling artifacts for the new hard fork genesis state.

## Summary

Hard forks of Mina are implemented by restarting a new chain from a genesis state that was captured from the prior chain. In order to facilitate this, we need tooling for migrating the prior chain state and packaging that new genesis state up with the new software release. Such tooling should be usable in the case both where there is a planned hard fork, as well as the case where there is an unplanned emergency hard fork. This RFC proposes process and tooling for generating hard fork software packages under both scenarios (planned and unplanned hard forks).

## Motivation

In order to control the data flow and parallelization of generating the hard fork package, we utilize the Buildkite CI platform, which has great support for specifying arbitrary jobs and dependencies between jobs, and these jobs can be scheduled onto Builkite agents that can have any resources we need available (such as a certain number of CPU cores or a certain amount of RAM).

By setting up the hard fork package generation pipeline to have a simple ledger data input, we can utilize the pipeline for generating hard fork test packages from custom ledgers, and for generating release hard fork packages for both planned and unplanned from historical ledgers.

## Terms

`Network Configuration`: the combination of compile-time mlh configuration and pre-package runtime json configuration that determines the chain id

`Genesis State`: all state related to the genesis of a chain (genesis block, genesis block proof, genesis snarked ledger, genesis staged ledger, genesis epoch ledgers (x2))

## Detailed design

The general process for generating a hard fork package is outlined as follows:

1. Capture the unmigrated genesis state from the prior chain.
2. Migrate the genesis state to the new version of the protocol.
3. Build the new version of the daemon that support the upgraded protocol.
4. Package together the new build with the migrated genesis state and the new network configuration.
5. Test the package.
6. Release the package, announce to the community, and deploy.

The details of step 1 change based on whether or not the hard fork is planned (in which case this step can be automated) or is unplanned (in which case this step is manual). Steps 2-4 can be automated (provided input from step 1). Step 5 can also be automated, but could include manual steps if we wish to make it more robust. Step 6 is manual and must be done in coordination with ecosystem partners. We will not discuss the details of step 6 in the scope of this RFC.

There is a requirement from Mina Foundation that the hard fork package can be prepared in 6 hours or less, so all of these steps need to fit within that timeframe.

<!-- THIS TURNED OUT TO ACTUALLY BE IMPLEMENTED
### Required Updates to the Genesis Ledger Runtime Configuration

Today, the genesis ledger runtime configuration supports specifying genesis ledgers via their contents (list of account states in the ledger). This data can be very slow to load, and even if we have an on-disk ledger to load instead, we need to hash all of the accounts in order to determine what the correct merkle root of the genesis ledger should be. Additionally, even just parsing this amount of JSON adds quite a bit of delay to initializing a daemon.

To better support the workflow of having pre-packaged on-disk ledgers available to load for initial genesis ledger states, we will need to update the runtime configuration to support specifying ledgers via their merkle root instead of their set of accounts. The runtime configuration should continue to support both workflows, as the workflow of specifying specific accounts is very useful for development and testing, it is just undesirable when shipping a hard fork release.

Specifically, we can update the `
-->

### Capturing Genesis State for Planned Hard Forks

Under the current hard fork plan, a soft fork update will be shipped to the prior chain which bakes in shutdown logic at specific slot heights. At some slot height, the prior network will stop accepting transactions, and then at a subsequent slot height after that, the network will shutdown entirely (will stop producing/accepting/broadcasting blocks). At this point in time, we take the strongest chain, and within that chain, take the final block before the slot height we stopped accepting transactions at. This block is where we will dump the genesis state from.

Rather than waiting to dump the genesis block data at the network halt slot, we will proactively dump every candidate hard fork genesis state, and select the correct candidate hard fork genesis state manually once the network halt slot is reached. There will be a special CLI flag that enables dumping the candidate hard fork genesis block states to disk automatically, which will be enabled on some nodes connected to the network. To ensure that we capture this data and do not lose it, a cron job will be executed on the nodes dumping this state which will attempt to upload any dumped candidate hard fork genesis block states to the cloud.

__IMPORTANT NOTE:__ dumping ledgers back to back needs to not break a node (this may require additional work).

### Capturing Genesis State for Unplanned Hard Forks

In the case of an unplanned (emergency) hard fork, we do not have the liberty of allowing the daemon to automatically dump the state that we will start the new chain from. Additionally, the state we want to take could be arbitrarily far back in history (obviously we won't take something that is too far back in history since we don't want to undo much history, but we can't make assumptions about how far back we need to look).

In such a circumstance, we must dump this state from the archive db rather than from an actively running daemon. The replayer tool is capable of materializing staged ledgers, snarked ledgers, and epoch ledgers for arbitrary blocks by replaying transactions from the archive db. It is important that this tool should take at most a couple of hours to execute, as the time spent executing this tool is a further delay in generating a new hard fork package for the emergency release.

### Generating the Hard Fork Package

The hard fork package will be generated in a buildkite pipeline. The buildkite pipeline will accept environment variables providing URLs to download the unmigrated genesis state from. Because different jobs require different parts of the genesis state to run, we will split up the unmigrated genesis state inputs into the following files:

- `block.json` (the full protocol state of the dumped block)
- `staged_ledger.json` (the contents of the staged ledger of the dumped block)
- `next_staking_ledger.json` (the contents of the next staking ledger of the dumped block)
- `staking_ledger.json` (the contents of the staking ledger of the dumped block)

Here is a diagram of the various buildkite jobs required to generate the hard fork package:

![](res/hard-fork-package-generation-buildkite-pipeline.dot.png)

The `build_daemon` job will build the daemon with the correct compile time configuration for mainnet (`mainnet.mlh`). The hard fork specific configuration will be provided via a static runtime configuration that is bundled with the hard fork release.

The `generate_network_config` job will generate the runtime configuration for the hard fork network, embedding the correct ledger hashes and correct fields for `fork_previous_length`, `fork_previous_state_hash` and `fork_previous_global_slot`.

* IMPORTANT: when does the genesis\_timestamp get written in? has is it configured?

The `migrate_*_ledger` jobs will perform any necessary migrations on the input ledgers, and will generate rocksdb ledgers that will be packaged with the hard fork release. These jobs run in parallel.

The `package_deb` and `package_dockerhub` jobs are our standard artifact bundling jobs that we use for releases, with some modifications to pull in the correct data from the hard fork build pipeline. The `package_deb` step will bundle together that artifacts from all the prior steps into a `.deb` package. The `package_dockerhub` installs this `.deb` package onto a Ubuntu docker image.

In the future, we will add additional jobs to the pipeline that will also perform automated tests against the release candidate.

### Testing the Hard Fork Package

In the future, we wish to automate the process of testing a hard fork release candidate. However for the upcoming hard fork, we will instead rely on a manual testing process in order to verify that the hard fork release candidate is of sufficient quality to release. The goal of this testing at this layer is to determine that the new package is configured to the proper genesis state, and that a network can be initialized using the package. We do not perform wider scope functional test suites at this stage, as the version of the software being built when deploying a hard fork will have already been tested thoroughly; we are only interested in testing workflows introduced or affected by the hard fork package generation process.

Ideally, we deploy a very short testnet with community members involved to verify the hard fork package. However, this is not possible to do without modifying the ledger, unless we were to involve the larger Mina staking community. Instead, we will test the hard fork package by initializing seed nodes and checking some very specific criteria. This is considered ok as our goal here is not to test networking, but the initialization states of a daemon when it hits the genesis timestamp, and the state we read from it once it has fully initialized the genesis chain.

The test plan for the seed node would go as follows:

1. Run a seed node with a custom runtime config that sets the genesis timestamp to be 10 minutes in the future.
2. Monitor the seed node logs to ensure that it boots up and begins sleeping until genesis timestamp.
3. Once the seed has passed the genesis timestamp, monitor logs to ensure the node goes through bootstrap only to pass through into participation with the genesis block as its best tip.
4. Run a script against the node that will sample random accounts from each of the genesis ledgers and compare the data served by the daemon against the data in the genesis state we captured from the old chain.

These tests will ensure that the hard fork package is setup properly to initialize the new chain with the correct state.

In order to enable these tests, we will need to ensure we have GraphQL or CLI endpoints available for each of the ledgers (snarked ledger, staged ledger, and the epoch ledgers). Then we will need to write a script that reads the ledger files input to the hard fork package generation timeline and performs the sampling test described in step (4).

<!-- ISSUE: this won't work because we can't modify the ledger for block production
In order to test the hard fork package, Mina ecosystem partners will coordinate with a handful of pre-selected community members in order to launch a very short test network. This group would be determined ahead of time and ready, at the time of the hard fork, to deploy new nodes for the short test network. The Mina ecosystem partners delivering the test build will provide the new package along with a runtime config that sets the genesis timestamp to be earlier than what the new hard fork chain's genesis timestamp. Once the package and test config is delivered to all participants, the testnet will run as follows:

1. All participants will start their daemon's ahead of the genesis timestamp, ensuring their nodes wait for the genesis timestamp.
2. Once the genesis timestamp triggers, nodes are monitored to 
-->

### Package Generation Time Estimates

- `build_daemon` and `package_deb` together take about 11 minutes in CI today
- `package_dockerhub` takes about 4 minutes in CI today
- the `migrate_*_ledger` jobs take 1-2 minutes each (measured against current mainnet ledger size)
<!-- - TODO: consider scan state migration steps -->
 
## Test plan and functional requirements

In order to ensure our hard fork generation tooling is sufficient both in the case of a planned hard fork and an unplanned hard fork, we must perform end-to-end tests for each workflow. Automating these tests will be important in the long term, but it will also be a difficult challenge. As such, we will describe only the testing requirements here, which can be applied to either manual or automated execution of these tests.

* Hard fork initialization
  * When a daemon is configured with a genesis timestamp after the current time, it sleeps until genesis.
  * When a daemon is configured with genesis state ledger hashes only (no accounts in config), it can successfully load those ledger from disk, assuming they have been packaged with the software.
* Planned hard fork
  * Daemons are able to dump ledger data without long async cycles or increased rates of validation timeout errors.
  * Daemons are able to dump ledgers containing up to 1 million accounts (there is currently a bug with this due to RPC size limits)
  * Infrastructure for deploying nodes is guaranteed to dump the required genesis ledger states.
    * Such a test should run a few nodes, and occasionally kill various nodes. We want to ensure this system has high reliability.
  * Buildkite pipeline is able to produce hard fork packages within the allowed time window (6 hours) even for large ledgers.
    * We will use a multiple of the current mainnet ledger size when performing this test to ensure that the system meets requirements for future ledger sizes that we may have to perform unplanned hard forks from.
* Unplanned hard fork
  * The replayer tool is capable of materializing staged ledgers, snarked ledgers, and epoch ledgers from arbitrary blocks.
  * The replayer tool is able to materialize any ledger at an arbitrary block within 4 hours.

## Drawbacks
[drawbacks]: #drawbacks

This approach does not currently include a plan for migrating the scan state data. This means that there will be some transaction history missing from the final blockchain proof of the prior network. It would be an additional and non-trivial engineering project to actually extend this proof retroactively to cover the missing transactions that we are not migrating into the new proof system. This leads to a weakening of Mina's trustlessness, and adds new requirements onto clients that want to truly interact with the Mina protocol's state in a trustless fashion.

## Rationale and alternatives

* ALTERNATIVE TO CLI-FLAG FOR DATA DUMPS: cron job that runs a script against graphql api to find candidates, then dumps via CLI
* ALTERNATIVE TO PRE-DUMPING DATA: keep node alive after the network stop slot, and dump the data at that point
    * this requires putting the node into a new state, and introduces new risk since the node could crash in that state and lose data

## Unresolved questions

* For emergency hard forks, do we need to consider the world in which we only take the snarked ledger an not the staged ledger?
* Is JSON actually the best format for dumping, migrating, and loading ledgers? It's slow to serialize/deserialize, the human readability isn't important for this scope, and it has the potential to introduce data translation errors in ways that other serialization formats don't. Should we just use a `bin_prot` representation instead?
