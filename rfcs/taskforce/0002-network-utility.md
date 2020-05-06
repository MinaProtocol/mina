# Network Utility Tool

## Goal

When spinning up a network there are a few operations that can and have been automated to decrease iteration speed on testing newer versions of the network.

1. Keyset Generation (Account Creation)
2. Genesis Ledger Creation
3. Distribution of custom network configuration and keys
4. Deployment of infrastructure with updated configuration
5. Monitoring the health of the network and debuging issues / crashes

This document proposes a tool that unifies these processes by collecting tools already written for these purposes and packaging them in a simple CLI and JS API.

# Design

## Existing System

For these processes we mainly use the [testnet-keys.py](https://github.com/CodaProtocol/coda-automation/blob/master/scripts/testnet-keys.py) script in coda-automation.

1. Keypair generation calls `coda advanced-generate keypair` generate new accounts
2. Genesis ledger creation happens using custom logic inside this script
3. Distribution of configuration uses Kubernetes secrets
4. Deployment consists of a variety of terraform configurations targeting Google Kubernetes Engine
5. We have a variety of charts and metrics for monitoring macro network health but debugging specific issues is often manual

### Improvements

While this system is effective, there are a variety of potential improvements to this process.

- Keypair generation depends on the daemon
- Genesis ledger logic could be cleaned up and made more flexible to support a wider variety of configuraitons
- These tools could be packaged together with a JavaScript API for extending functionality
- The internal data structures for storing these keypairs, genesis configuration and distribution are not well defined and could be more robust
- Tools for deployment and monitoring are seperate and these could be packaged in one simple workflow that uses the same underlying functionality

## Proposal

All of these features should be included in a simple command line tool that also exposes a TypeScript API. This service will be written in Reason with TypeScript bindings.

### Keypair Management

Keypairs have a private key and a corresponding public key. For new keypair generation, we can use the new client-sdk which is a much lighter dependency and has a clean JavaScript interface.

However there are also existing keys which we'll need to be able to reference by public key alone since we don't control the private keys. An example of this would be community owned wallets for inclusion in the genesis ledger. Since this distinction can be made at a higher level, we'll keep the definition of a keypair to mean a public key for which we also have th private key.

```
coda-network keypair create
```

This command will generate a new keypair and save it locally.

```
coda-network keypair upload <PUBLIC_KEY>
```

This command will upload a locally stored keypair to an S3 bucket for distribution.

```
coda-network keypair download <PUBLIC_KEY>
```

This will attempt to download a given keypair from S3 if the keypair exists.

### Keyset Management

Keysets are simply a collection of keypairs. We use these for categorizing different groups of keys that will be used in the lifecycle of a network. For each keypair in a keyset, we MAY or MAY NOT have the corresponding private keys. For each keyset, we may want to allocate a different amount of funds to their corresponding accounts in a genesis ledger.

The datastructure for a given keyset is much simpler since it's essentially a list public keys. As such we can simply maintain a simple CSV style document that contains all the public keys included in a given keyset using the name of the keyset for the filename. 

```
coda-network keyset create <NAME>
```

This simply creates a new keyset that keys can be included in.

```
coda-network keyset add <NAME> <PUBLIC_KEY> ...
```

This command would add a public key to a keyset.

```
coda-network keyset remove <NAME> <PUBLIC_KEY> ...
```

This command would remove a public key to a keyset.

```
coda-network keyset [ls|list]
```

This command will show all keysets that are stored locally in addition to the keysets that are available in remote storage.

```
coda-network keyset import <KEYSET_NAME> <CSV_FILENAME>
```

### Runtime Ledger Generation

The code for generating the Runtime Genesis Ledger should be ported over from the [existing code](https://github.com/CodaProtocol/coda-automation/blob/master/scripts/testnet-keys.py#L203) but with the added flexibility of being able to inject any variety of keysets into the ledger with corresponding initial amounts.

```
coda-network genesis create
```

This command will prompt the user for the keysets which should be included in the ledger, their corresponding amounts and delegates. This would then output a `genesis_ledger.json` which contains entries of the following form:

```
[
  {
    "pk": "<PUBLIC_KEY>",
    "sk": "<PRIVATEY_KEY>", // nullable
    "balance": "<AMOUNT>",
    "delegate": "<PUBLIC_KEY>" // nullable
  }
]
```

Additionally we can output an annotated ledger file with additional fields such as `nickname`, `discord_username` etc for use with testnet challenges.

Again this can be uploaded to S3 for sharing.

```
coda-network genesis upload <VERSION>
```

### Configuration Deployment

The configuration deployment will consist of collecting all the "online" keys and the genesis ledger and uploading them to the kubernetes secret service. This tool should expose similar functionality to the existing tool, allowing users to upload keypairs to the kubernetes ConfigMap however not splitting out the task into predefined groups but rather allowing arbitrary keysets to be deployed.

```
coda-network deploy <KEYSET_NAME>
```

This would attempt to find all the keypairs in a given keyset locally or remotely and upload them to the Kubernetes secret service.

### Network Deployment and Monitoring

This tool could optionally wrap the coda-automation tools and provide a simple interface for deploying a full testnet from a single command.

## Command-line Framework

After investigating the current state of commandline infrastructure I've come up with the following three options listed in priority order:

### Cmdliner

This is an OCaml project that a variety of members of our engineering team have experience with. This framework supports a variety of features out of the box that we'd like to have such as:

1. Robust Argument Parsing
2. Subcommands
3. Documentation support
4. Strongly typed with Reason support

Given all these benefits and existing Bucklescript integration, this seems like the best solution to get going quickly and allowing other members of the team to contribute without having to learn a new tool.

**Links**

Original project - [github](https://github.com/dbuenzli/cmdliner), [website](https://erratique.ch/software/cmdliner)
Bucklescript bindings - [github](https://github.com/ELLIOTTCABLE/bs-cmdliner)

### Ink

React based framework for building command-line tools. While this project seems to have a ton of functionality, it seems like it might be a bit overkill for this project. There's no Reason bindings, however they could be ported over reasonably easily from the TypeScript definitions. Overall this seems like a strong contender however is more work than cmdliner and would require everyone to learn a new tool.

**Links**

Ink - [github](https://github.com/vadimdemedes/ink)

### Custom Implementation

This was also a strong option since the amount of functionality we wish to support is well scoped and could be implemented by hand without too much work. The benefits of this approach are dropping a dependency and allowing us to only implement the features that we plan to use. 

Downside of this approach is needing to maintain functionality that is reasonably well supported and maintained by the previously mentioned projects.

## External Users

Ideally this tool should be an easy starting point for users that are trying to run large node operations and particularly staking operations who wish to deploy complex infrastructure.

## Explicitly NOT in scope for this project

- Multi-cloud support
- Local machine multi-node testnets
- Moving away from kubernetes for configuration distribution

## Alternatives Considered

**Clean up existing python script**

Pros:

- Less work
- Most existing network automation is already written in python

Cons:

- Requires lots of rewriting from the ground up in an untyped language
- Less clean integrating with the client-sdk
- Lots of functinality we'd like to add in the future that will further muddy the python code

# Outstanding Questions

- Are there any more usecases this tool should cover or have we over extended the scope of this project.

- ~Carey has played with a couple frameworks for writing CLI tools but they all seem over complicated and unneccissary, should they still be considered?~
  - After talking with people on the team I've settled on cmdliner, see the above section.

# Epic Link

Issue #4722
