# Lucy

## Overview

![Mina and Lucy](https://user-images.githubusercontent.com/3465290/213062809-f4bb13a7-9620-464d-9f8a-708126d37393.png)
| :--: | 
*My dearest Mina, we have told all our secrets to each other since we were children; we have slept together and eaten together, and laughed and cried together; and now, though I have spoken, I would like to speak more.* ~excerpt from *Dracula*, by Bram Stoker; Chapter V: LETTER, LUCY WESTENRA TO MINA MURRAY


**Lucy** is the name of Mina Protocol's fully end-to-end integration testing framework, developed in-house by O(1) Labs.  This piece of software is a standalone testing tool, and was previously known as simply "the integration testing framework" and sometimes as "the test executive".

#### Elevator Pitch

Lucy was created to tackle is the problem of testing a Mina blockchain in a realistic way.  Mina Protocol, like all blockchains, operates upon a decentralized, distributed network of peer nodes, who all work together using cryptography and peer-to-peer communication to come to a consensus on chain state.  Testing a blockchain in a fully integrated manner therefore requires creating a test network of nodes, which interact with each other in the same way that they would in a real network.  Creating mocked peers with hardcoded responses is not sufficient for an integration test.  Simply spinning up a single node on one's local machine to create, in effect, a single peer network is a handy expedient for many development purposes, but is far from sufficient for true integration testing purposes, because so much of a distributed computing network (such as a blockchain) consists in the interactions and consensus between multiple nodes.

Given this, the solution, therefore, is quite clear: we must spin up from scratch an entire decentralized network of nodes, and then run tests against this network.  In concept this is quite simple, but of course in implementation it is ambitious.

#### Name

![we are all good christian victorian women here](https://user-images.githubusercontent.com/3465290/213062888-6fd82ec4-7e96-4b5a-bbc4-926f8b9cde79.png)
|:--:|
*Leave these others and come to me. My arms are hungry for you. Come, and we can rest together. Come, my husband, come!* ~excerpt from *Dracula*, by Bram Stoker; Chapter XVI: DR SEWARD’S DIARY *(continued)*

Lucy is of course named after the character Lucy Westerna from Bram Stoker's Dracula.  Lucy is Mina Harker née Murray's ["best friend"](https://www.youtube.com/watch?v=VbbRQj8Oi2k), who sapphically and figuratively [tests Mina's virtues](https://archiveofourown.org/tags/Mina%20Murray%20Harker*s*Lucy%20Westenra/works) (and the virtues of the other characters in the novel but no one cares about them), so naturally we thought this would be an appropriate name for an integration testing framework which tests the Mina Protocol.

#### Structure (super high level)

There are a number of moving parts to Lucy, and these parts are subject to change as it is being actively developed and extended.  However in it's current state, Lucy tests Mina Protocol by creating a whole entire Mina testnet from scratch with a specified number of nodes of various types, creating a new blockchain from genesis, and then monitoring and interacting with this testnet in accordance to test logic as determined in pre-written tests.  These tests are written in a Lucy-specific OCaml DSL.  If the testnet seems healthy and behaves as one expects in response to the interactions, then the test passes; if not then it fails.  Then the testnet is destroyed-- although if one wants, one can prevent the destruction of the testnet with a flag, and then manually interact with the nodes on the testnet.

**Broadly speaking, Lucy has 2 parts.**  
1. the testnet itself, consisting of a number of nodes all running the Mina daemon.  
2. the test_executive, which creates the testnet according to it's own configurations, orchestrates the testnet, tracks the state of the testnet, runs test logic against the testnet, and eventually is responsible for tearing down the testnet as well.

The exact size and composition of testnets spun up by Lucy are custom configured and specified by the test_executive.  Also specified by the test executive is the exact version/release of the Mina daemon that the testnet nodes are running.  A Lucy testnet is of course going to be much smaller compared to mainnet, or the official public devnets created by O(1) Labs and Mina Foundation.  Also unrealistic, at least at the current moment, is the fact that all the testnet nodes are going to be on the same machine which means that network latency is never going to be a real issue.  However asides from scale and a few caveats such as latency, there is no qualitative or behavioral differences between a Lucy testnet and mainnet or public devnets (assuming that the same version of the Mina daemon is being run).  A Lucy testnet maintains an accounts ledger, produces blocks, has consensus, distributes block rewards to block producers, maintains a blockchain, can carry out transactions, produces snarks, can run zkapps, can run SnarkyJS and implement smart contracts, and so on.  Whatever smart contract features you'd expect from the Berkeley Devnet, such as rollups, receiving off chain computation, zk cypto, will all work on a Lucy testnet (provided the testnet is using correct version/release of the Mina daemon).  The testnet can be specified with archive nodes and snark worker nodes, as well as the usual block producers and seeds.  Developers can manually interact with Lucy testnets, such as connecting other nodes to the testnet, or manually sending transactions and running smart contracts and what not (the workflow for this particular usecase is a bit roundabout at the current moment, but we plan to improve this).

#### Tests

The usecase which Lucy has been designed around (thus far) is the usecase of running automated *tests*.  There are a number of pre-written tests which are compiled into the test_executive (such as the payments_test, zkapps_test, chain_reliability_test, etc).  Those who are familiar with OCaml can learn the DSL and modify or extend these tests, and/or write new tests.

Lucy is set up such that the test to be run is selected at the invocation of Lucy, in the terminal command to run Lucy.  A single invocation of Lucy runs exactly 1 test and creates exactly 1 testnet, which is usually torn down at the end of the test.

Each test consists of the following two elements:
- a testnet spec which tells Lucy how many nodes of each node type to spin up in the testnet and what sort of balances the initial genesis accounts have.  For example, a typical testnet might look something like: 1 seed node, 6 block producers, 1 archive node, and 2 snark workers; Account A has 1000 tokens, Account B has 4000 tokens, and so on.  Of course it's more complicated than this, but that's the general idea.
- a sequence of test logic and Mina interactions to be run against the testnet.  For example, waiting for blocks to be produced, sending transactions, waiting for transactions to reach consensus, running snarkyjs, removing nodes from the network and checking network connectivity, and so on.  

#### Infrastructure (super high level)

The 2 aforementioned parts (the test_executive, and the testnet) are typically run on different infrastructure.

At the current moment, the testnet can only be run on Google Cloud, using their Google Kubernetes Engine.

The test_executive is run either on a developer's own laptop/desktop, or from our Continuous Integration system (BuildKite).  The machine running the test executive does not need much computing power, only an internet connection and the right credentials to access Google Cloud.

Eventually, we would like the testnet to be able to run within virtual machines on the local computer.  Doing so would require the user to have a beefy enough computer to run all the virtual machines each with a full mina node running inside it, however there are certainly many users who would desire this usecase.


## Architecture

![edit this picture at: https://drive.google.com/file/d/1fN03qmTzpjibgu6TY4DGxJF9__P8xyK3/view?usp=sharing](https://user-images.githubusercontent.com/3465290/217935205-11dc0828-bfde-4207-978f-ec7f930d579b.png)
|:--:|
*Lucy General Architecture*

Any Lucy test first creates a whole new testnet from scratch, and then runs test logic using that testnet in order to confirm and measure the performance of connectivity, functionality, or correct interactions between nodes.  The testnet is destroyed after the test is complete (unless the user wishes it not to be destroyed).

- control flow / data flow:
    - The test is kicked off by running the test_executive process.  You can run it on your local machine, it also is frequently run on CI. In arguments to the command line to run the test_executive, you must specify which test to run, and the infrastructure engine to be used.  (As noted elsewhere, the only infrastructure engine available at the moment is the local engine)
    - Each test has an OCaml data structure which defines specifications of the testnet to be spun up.  This data structure will stipulate things such as the number of staking block producer nodes in the testnet, the number of archive nodes, the number of snark workers, the balances of the accounts in the genesis ledger, and other variables.  Then Lucy will use the given infrastructure engine (as specified in the original terminal command) to spin up a testnet as specified.  The infrastructure level details are abstracted within the infrastructure engine
    - Once the testnet is fully established, the test_executive process can interact with nodes on the network and wait for various events to take place. The test_executive is able to send graphql queries to any of the nodes on the network, or further control the network through the use of the infrastructure engine (such as by stopping or starting nodes).
	- The infrastructure engine streams logs from the individual nodes in the testnet network back to the test_executive.  The test_executive will parse the logs to look for "structured log events".  Lucy maintains internal data structures representing the network state, which are updated based on the structured event logs which it receives.
    - Wait conditions are the bread and butter of how tests are constructed in the test_executive.  A wait_condition, simply put, waits for a certain condition to be satisfied on the testnet or on the blockchain.  A wait condition can be predicated on either the network state, or directly based on the streams of structured log events.

- infrastructure engines: the writing of the test itself is abstracted away from the infrastructure that the test is running on.  You must pass in an initial argument specifying what infrastructure is to be used. The only implemented option is "local"
    - local engine: uses docker swarm for spinning up network.
    - GCP cloud engine: retired.
    - AWS cloud engine: not implemented.  Sure would be nice to have.


## Using Lucy

### Prerequisites Softwares

Make sure you have the following critical tools installed on the machine which you will run Lucy's test_executive upon:

- docker (https://docs.docker.com/get-docker/)
 
### `mina-test-executive` command line breakdown

If you were to run Lucy's test executive directly in the terminal, the command line would look something like this:

```
mina-test-executive local $TEST_NAME --mina-image $MINA_IMAGE --archive-image $ARCHIVE_IMAGE --debug | tee test.log | mina-logproc -i inline -f '!(.level in ["Spam", "Debug"])'
```

Running it directly in the terminal is not the most recommended method, but it is technologically speaking the simplest method (even if not practically the most streamlined) and all the other methods are based on it eventually, and so before moving on, it's worth breaking down the command line arguments and options for `mina-test-executive`.

- `local` : the first argument specifies if you'd like to run the testnet locally in docker.  only the `local` option works at the moment
- `$TEST_NAME`: the second argument is the name of the pre-written test which you wish to run.
	+ In the current state of development, the following pre-written tests are available on all major branches: `peers-reliability`, `chain-reliability`, `payments`, `delegation`, `archive-node`, `gossip-consis`, `medium-bootstrap`, `block-prod-prio`
	+ The following pre-written tests are available only on versions of Lucy based off the `develop` branch: `zkapps`, `zkapps-timing`, `snarkyjs`
	+ The following pre-written tests are available only on version of Lucy based off the `compatible` branch: `archive-node` (the test logic for the archive-node test was rolled into other tests in develop based branches)
- `--mina-image $MINA_IMAGE`: this must be a url to a docker image which is the mina-daemon.  This is required.  Go to the [mina-daemon dockerhub page](https://hub.docker.com/r/minaprotocol/mina-daemon/tags) or the [mina-daemon GCR page](https://console.cloud.google.com/gcr/images/o1labs-192920/global/mina-daemon) and pick a suitable, preferably recent, image to run the tests with.  When choosing an image, keep in mind the following tips.  1. Usually, you should choose the most recent image from the branch one is currently working on.  2. Generally use "-devnet" images instead of "-mainnet" images for testing, although it usually won't make a difference.  Also, please keep in mind that changes to Lucy itself do not make it into the daemon image, ie they are compiled separately and built into separate images.  This means that if you make changes to Lucy in a branch, the changes will not be reflected in the latest mina image off of the same branch.
- `--archive-image $ARCHIVE_IMAGE`: this must be a url to a docker image which is the mina-archive.  These can be found in the [mina-archive dockerhub page](https://hub.docker.com/r/minaprotocol/mina-archive/tags) or in the [mina-archive GCR page](https://console.cloud.google.com/gcr/images/o1labs-192920/global/mina-archive).  An archive-image is required even if you're not using archive nodes, in which case any image will do.
- `--debug`: if this flag is not present, then Lucy will automatically destroy the testnet.  If it is present, it will wait for your to manually prompt it before destroying the testnet.
- `mina-logproc` is simply an auxiliary program that makes the large quantity of log output from the Lucy test_executive be prettier and more human readable.  It can also filter log lines based on the severity level, usually we filter out `Debug` and `Spam` logs (those log levels are very verbose and are intended for debugging test framework internals).  In the idiomatic command line expression, the bit with `tee test.log` is used to store the raw output into the file `test.log` so that it can be saved and later inspected.

### Running the Lucy test_executive from your local machine

There are several ways to run Lucy: 
1. Running the mina-test-executive package directly from command line.  (not particularly recommended but it'll be fine)
2. Running from the pre-built debian package.  (most recommended method)
3. compiling from source code, then running what you compiled.  (if you want to modify or extend existing tests, or write new tests, then you will need to do this)

We will go over each method in turn.

#### Installing the mina-test-executive package and running directly in command line

The first and most basic way is to use the debian/ubuntu `apt` package manager to download the test_executive, and then run it in the command line directly.  This method isn't recommended for most people-- if you're "most people" then skip ahead to the section [Run Lucy in dockerized form](README.md#run-lucy-in-dockerized-form)

First you must download and install the debian package `mina-test-executive` and you can do that by running the following commands:

```
echo "deb [trusted=yes] http://packages.o1test.net $(lsb_release -cs) stable" > /etc/apt/sources.list.d/o1.list \
  && apt-get update --yes \
  && apt-get install --yes --allow-downgrades "mina-test-executive"
```

This will put the `mina-test-executive` executable binary in your terminal path.

Once you've configured test executive, the idiomatic command to run Lucy is as follows:

```
export $TEST_NAME=<test>
export $MINA_IMAGE="<url to mina daemon image>"
export $ARCHIVE_IMAGE="<url to mina archiver image>"

mina-test-executive local $TEST_NAME --mina-image $MINA_IMAGE --archive-image $ARCHIVE_IMAGE --debug | tee test.log | mina-logproc -i inline -f '!(.level in ["Spam", "Debug"])'
```

If you prefer, it is also idiomatic to just manually edit and execute the `mina-test-executive` line instead of exporting the env vars.

#### Compile Lucy from source

If you wish to modify or extend existing tests, and/or write a whole new test, or modify the Lucy test executive itself, you will need to compile the Lucy test_executive from source.  Lucy is a complex piece of software written in OCaml, it's not some simple python or bash script.  

Lucy is in the same git repository as the rest of the Mina Daemon at https://github.com/MinaProtocol/mina.  Lucy and Mina need to live together because other than being [goth sapphic girlfriends](https://64.media.tumblr.com/3ad7878b174be3b61c2e1ab1cf8a91aa/tumblr_n1osgph7yb1t5no8yo2_500.gifv), Lucy and Mina also share a number of OCaml libraries.

I will assume the user who wishes to compile Lucy is familiar with not just OCaml but also with the normal compilation process of mina.  Compiling the test executive is not that different.

```
make build

dune build src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe
```

Once you've compiled the test executive executable binary, you can run the binary the same way as detailed in the section [Installing the mina-test-executive package and running directly in command-line](README.md#installing-the-mina-test-executive-package-and-running-directly-in-command-line).  The only difference is that you will have to provide the path to the binary instead of just typing `mina-test-executive`, because of course you won't have the debian package `mina-test-executive`.  The compiled executable will be at:

```
./_build/default/src/app/test_executive/test_executive.exe
```

Optionally, you can set the following aliases in one's .bashrc or .bash_aliases (protip: aliases don't work if set in .profile):

```
alias test_executive=./_build/default/src/app/test_executive/test_executive.exe
alias logproc=./_build/default/src/app/logproc/logproc.exe
```


### Notes on Docker namespace name
- Running the integration test will of course create a testnet on docker swarm.  In order to differentiate different test runs, a unique testnet namespace is constructed for each testnet.  The namespace is constructed from appending together the first 5 chars of the local system username of the person running the test, the short 7 char git hash, the test name, and part of the timestamp.
- the namespace format is: `it-{username}-{gitHash}-{testname}`.  for example: `it-adalo-3a9f8ce-payments`; user is adalovelace, git commit 3a9f8ce, running payments integration test

## Relevant Source Code Directories

### Lucy general purpose directories

- `src/app/test_executive/` — The pre-written Lucy tests live here, along with the file `test_executive.ml` which is the entrypoint for executing them.
- `src/lib/integration_test_lib/` — Contains the core logic for integration test framework. This is where you will find the implementation of the Lucy OCaml DSL, the event router, the network state data structure, and wait conditions. This library also contains the definition of the interfaces for execution engines and test definitions.

## Writing Tests

- To write a new Lucy integration test, create a new file in `src/app/test_executive/` and by convention name it something like `*_test.ml`.  (Feel free to check out other tests in that directory for examples.)
- The new test must implement the `Test` interface found in `integration_test_lib/intf.ml` .  The two most important things to implement are the `config` struct and the `run` function.
    - `config` .  Most integration tests will use all the default values of `config` except for the number of block producers, the mina balance of each block producer, and the timing details of each block producer.  The integration test framework will create the testnet based on the highish level specifications laid out in this struct.
    - the `run` function contains all the test logic.  this function receives as an argument a struct `t` of type *dsl*, and a `network` struct of type *network*, both of which have their uses within the test.  There are a number of things that can be done in this function
        - **Interacting with nodes**.  Within `integration_test_lib/intf.ml` is a `Node` module which contains a number of function signatures which are implemented by all existing infrastructure engines.  These functions allow the integration test to interact with nodes in the testnet.
            - Puppeteer.  The `start` and `stop` functions use puppeteer to start and stop nodes, so that integration tests can test network resiliency.  (note: nodes will already by started at the beginning of tests, you do NOT need to manually start them)
            - Graphql.  functions like `get_peer_id` and `send_payment` will, under the hood, send a graphql query or mutation request to a specified node.  The test that one is writing may require one to write additional graphql client functions integration test side.  The new function must be defined in the `Node` module of intf.ml, and then implemented for each infrastructure engine.  For the docker engine, graphql interactions are implemented in `integration_test_docker_engine/docker_network.ml`
        - **Waiting for conditions**.  the `wait_for` function can be used to wait for a number of different conditions, such as but not limited to:
            - initialization (the `run` function typically begins by waiting for all the block producers nodes in the testnet to initialize)
            - block produced
            - payment included in blockchain frontier
        - **Checking network state**.  The integration test framework keeps a special struct representing network state, which can be obtained by calling `network_state t`.  The members of this struct contain useful information, for example `(network_state t).blocks_generated` is simply an integer that represents the number of blocks generated.
            - Note that each call to `network_state t` returns a fresh and full struct whose value is computed eagerly, it is NOT lazy and does NOT return a pointer.  For example, if one calls `let ns = network_state t in ...`  , the value of `ns` is guaranteed to remain the same for the rest of the program (unless explicitly reassigned) EVEN if the actual network state changes in the meantime.  To obtain a fresh network state, one must make another explicit call to `network_state t`.


## Debugging Tests

<!-- - how to process test executive logs
    - logproc examples -->
- make sure to use the `--debug` flag so that the testnet doesn't automatically self-teardown after the test run
- if you suspect there may be infrastructure failures, or failures of the testnet to initialize
    - check the testnet status on the docker console.  if there are errors about not enough CPU or something like that, then this is a problem of your machine not having enough resources, or there being too much resource contention
- how to find node logs
    - In the docker swarm, find your test run's namespace, then particular node log by:
    `docker logs ....`
- how to correlate expected structured events with logs.
    - structured log events are not an integration test construct, they are defined in various places around the protocol code.  For example, the  `Rejecting_command_for_reason` structured event is defined in `network_pool/transaction_pool.ml`.
    - The structured log events that matter to the integration test are in `src/lib/integration_test_lib/event_type.ml`.  The events integration-test-side will trigger based on logic defined in each event type's `parse` function, which parses messages from the logs, often trying to match for exact strings
- Please bear in mind that test executive run the image that you link in your argument, it does NOT run whatever code you have locally.  Only that which relates to the test executive is run from local.  If you make a change in the protocol code, first this needs to be pushed to CI, where CI will bake a fresh image, and that image can be obtained to run on one's nodes.

## Exit codes

- Exit code `4` will be returned if not all pods were assigned to nodes and ready in time.
- Exit code `5` will be returned if some pods could not be found.
- Exit code `6` will be returned if Subscriptions, Topics, or Log sinks could not be created
- Exit code `7` will be returned if the capacity check reports that the integration test cluster is out of capacity and no further tests can be run.  (deprecated given that we've changed how capacity is handled, replaced by exit code 14)
- Exit code `20` will be returned if any testnet nodes hard timed-out on initialization

![totally heterosexual and entirely becoming of good christian victorian woman behavior](https://user-images.githubusercontent.com/3465290/213062986-35ab48cc-d57f-4348-bda2-a8a504944cb5.png)
|---|
*...and so, as you love me, and he loves me, and I love you with all the moods and tenses of the verb... Goodbye, my dearest Lucy, and all blessings on you.<br/>Yours,<br/>Mina Harker* <br/>~excerpt from *Dracula*, by Bram Stoker; Chapter XII: LETTER, MINA HARKER TO LUCY WESTENRA *(Unopened by her)*
