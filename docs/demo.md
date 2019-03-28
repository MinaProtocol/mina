# Tutorial: Coda Quickstart

## Introduction

Hello! We'll walk you through a short demo to get a local testnet running using Coda.

Specifically, you'll download a docker image, run it, then play around with the command line interface to create a wallet and send/receive payments.

## Helpful links

- [Docs](https://codaprotocol.com/code.html)
- [Support Channel](https://discord.gg/Ur3tEAu)

## Prerequisites

While you don't need to be a seasoned OCaml hacker to follow this guide, you should have a background or familiarity with common development patterns. If you know how to use the terminal, install a docker image, read developer documentation, and have access to a Linux-based operating system, you should be able to follow this guide.

## Demo

At a high level, you'll follow these steps:

1. [Verify your system](#verify-your-system)
2. [Run the docker image](#download-the-docker-image)
3. [Interact with the network](#interact-with-the-network)

We'll walk through them one by one.

### Verify your operating system

**Software**: You need to be running **a Debian 9 or Ubuntu 18 distribution**, either natively or in a VM. These are the only operating systems we have tested against. If you don't have this running locally, there are instructions in the [appendix](#appendix) to set up a Google Compute instance.

**Hardware**: We'll be running three nodes on your machine, including a node that is performing intensive zk-SNARK proving work. Therefore, we recommend the following system requirements: 12GB ram (you may be able to get away with less), 4 cores.

### Download the docker image

First, you'll need to install Docker 18.06 on your machine. You can do so by following the instructions here: [Mac](https://docs.docker.com/docker-for-mac/install/), [Ubuntu](https://docs.docker.com/install/linux/docker-ce/ubuntu/), [Windows](https://docs.docker.com/docker-for-windows/install/).

**WARNING**: Most of these commands won't work as shown unless you [manage Docker as a non-root user](https://docs.docker.com/install/linux/linux-postinstall/). You can either follow the linked instructions OR run the following commands as root.

Now, create a directory where you can work, and run the docker image:

```
$ docker run -d --name coda codaprotocol/coda:demo
```

Now, connect to the docker process with the following command:
```
$ docker exec -it coda /bin/bash
```

### Interact with the network

At a high level, here's what just happened: you started three Coda nodes, all of which are running locally on your machine over your localhost network.

There are a few ways you can interact with this network right away:
- [Check the network status](#check-the-network-status)
- [Create a wallet](#create-a-wallet)
- [Send payments](#send-payments)
- [Check account balances](#check-account-balances)
- [Add additional nodes to the network](#add-additional-nodes-to-the-network)

We'll show some code snippets for each of these actions below.

#### Check the network status

We use this general command to check the network's status (from the view of a particular node):

```
$ coda client status
```

**Since you're running three nodes, the command above will fail.** You have to specify the port that your nodes are running on. The following commands should work -- *and* give a consistent view of the network:

```
$ coda client status -daemon-port 8301
$ coda client status -daemon-port 8401
$ coda client status -daemon-port 8501

```

If you just want to have a running status page of the entire network, try running this:

```
$ watch coda client status -daemon-port 8301

```

#### Create a wallet

A wallet in Coda is just a [public/private key pair](https://en.wikipedia.org/wiki/Public-key_cryptography). The public key corresponds to your publicly available address, and the private key is like a password, required to authorize sending funds from that address.

First, create a directory for your wallet:

```
$ mkdir wallet
```

The following command will generate a public/private keypair and prompt you for a password to encrypt the private key file:

```
$ coda client generate-keypair -privkey-path ./wallet/key
```

That creates an encrypted private key file at `./wallet/key` and a corresponding public key file at `./wallet/key.pub`. To check your public key, you can run

```
$ cat ./wallet/key.pub
```

#### Send payments

For ease of setup and experimentation, we've already given you a well-funded account, which you can use to send payments to new accounts. Here's how you can send a payment from this account:

```
$ coda client send-txn -amount <AMOUNT> -privkey-path ./funded-wallet/key -receiver <RECEIVER_ADDRESS>
```

Replacing the `<AMOUNT>` argument with an integer value and the `<RECEIVER_ADDRESS>` with the public key of the account you're sending money to. It will prompt you for the private key password but it is blank.

#### Check account balances

Naturally, you might be interested in seeing how and when the network processes your payments. You can do that by either inquiring for a specific address or all account balances. Here are the commands to do so:

**Checking account balance**
```
$ coda client get-balance -address <PUBLIC_KEY>
```

**Checking everyone's account balances**
```
$ coda client get-public-keys -with-balances
```

#### Add additional nodes to the network

To spin up additional nodes, you'll need to point them to existing, running nodes. You can see how we spin up the nodes used in your network by reading through `./scripts/cluster.sh`, and if you want to spin up new nodes, you can follow the patterns there.

Then, you can check whether this node is up and running with the following status command:

```
$ coda client status -daemon-port <PORT>
```


## Appendix

This will show you how to get up and running with an appropriate Linux distribution on Google Cloud. We'll cover a few steps: 1) getting the instance set up, 2) interacting with the machine on the command line.

#### Setting up the instance

To get the instance set up, follow [these instructions](https://cloud.google.com/compute/docs/quickstart-linux), with the following changes:

- **Choose `Ubuntu 18.04 LTS` as the OS.**
- **Instead of 1 vCPU, choose to have 4 vCPUs**
- **If you're on the west coast, instead of choosing us-east1 choose a west coast region**
- **Change the amount of ram to 12GB**

#### Interacting with the CLI

To interact with the CLI, go to the compute engine -> VM instances page.

Then, select the VM, start the VM, and click the SSH button to open up a terminal window.

