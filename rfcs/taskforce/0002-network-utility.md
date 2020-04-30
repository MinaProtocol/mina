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

For new keypair generation, we can use the new client-sdk which is a much lighter dependency and has a clean JavaScript interface.

```
type keypair = {
  publicKey: string,
  privateKey: option(string)
}
```

However there are also existing keys which we'll need to be able to reference by public key alone since we don't control the private keys. These include community owned wallets for inclusion in the genesis ledger.The basic type of a keypair consists of the following:

### Keyset Management

Keysets are simply a collection of keypairs. We use these for categorizing different groups of keys that will be used in the lifecycle of a network. For each keypair in a keyset, we MAY or MAY NOT have the corresponding private keys. For each keyset, we may want to allocate a different amount of funds to their corresponding accounts in a genesis ledger.

```
type keysetMember = | Owned(keypair) | Unowned(publicKey)
```

Where it's implied that `type publicKey = string`.

### Runtime Ledger Generation

The code for generating the Runtime Genesis Ledger should be ported over from the [existing code](https://github.com/CodaProtocol/coda-automation/blob/master/scripts/testnet-keys.py#L203) but with the added flexibility of being able to inject any variety of keysets into the ledger with corresponding initial amounts.

### Configuration Deployment

The configuration deployment should be updated to take advantage of the kubernetes JavaScript client API. This tool should expose similar functionality to the existing tool, allowing users to upload keypairs to the kubernetes ConfigMap however not splitting out the task into predefined groups but rather allowing arbitrary keysets to be deployed.

### Network Deployment and Monitoring

This tool could optionally wrap the coda-automation tools and provide a simple interface for deploying a full testnet from a single command.

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

# Outstanding Questions

- Are there any more usecases this tool should cover or have we over extended the scope of this project.

- Carey has played with a couple frameworks for writing CLI tools but they all seem over complicated and unneccissary, should they still be considered?

# Epic Link

Issue #4722
