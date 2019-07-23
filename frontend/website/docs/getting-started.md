# Getting Started

This section will walk you through the requirements needed to run a Coda protocol node on your local machine and connect to the network.

!!! note
    Last updated for release v0.0.1

## Requirements

**Software**: macOS (10.x+) or Linux (currently supports Debian 9 and Ubuntu 18.04 LTS)

**Hardware**: Sending and receiving coda does not require any special hardware, but participating as a node operator currently requires:

- at least a 4-core processor
- at least 8 GB of RAM

GPU's aren't currently required, but may be required for node operators when the protoctol is upgraded.

**Network**: At least 1 Mbps connection

## Installation

The newest binary releases can be found below. Instructions are provided for macOS and Linux below:

### macOS

- Run `brew install codaprotocol/coda/coda` -- NOTE: This is a large file (~1 GB), so this step might take some time
- `coda -help` to see if it works
- Set up port forwarding ([see here](/docs/troubleshooting/#port-forwarding))

### Ubuntu 18.04 / Debian 9

- Add the Coda Debian repo and install -- NOTE: This is a large file (~1 GB), so this step might take some time

```
sudo echo "deb [trusted=yes] http://packages.o1test.net unstable main" > /etc/apt/sources.list.d/coda.list
sudo apt-get update
sudo apt-get install -t unstable coda-testnet-postake-medium-curves=0.0.1-release-beta-9fa6e5ec
```

- `coda -help` to see if it works
- Set up port forwarding ([see here](/docs/troubleshooting/#port-forwarding))


### Windows

Windows is not yet supported. If you have any interest in developing Coda for Windows, please reach out to contact@codaprotocol.org or reach out in the [Discord server](https://discord.gg/ShKhA7J).

### Build from source

If you're running another Linux distro or a different version of macOS, you can [try building Coda from source code](https://github.com/CodaProtocol/coda/blob/master/README-dev.md#building-coda). Please note that other operating systems haven't been tested thoroughly, and may have issues. Feel free to share any logs and get troubleshooting help in the Discord channel.

## Next

Now that you've installed the Coda binary and configured settings, let's move on to the fun part - [sending a transaction](/docs/my-first-transaction/)!
