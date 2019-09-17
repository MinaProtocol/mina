# Getting Started

This section will walk you through the requirements needed to run a Coda protocol node on your local machine and connect to the network.

Join the Coda server on [Discord](http://bit.ly/CodaDiscord) to connect with the community, get support, and learn about how you can participate in weekly challenges for [Testnet Points](/docs#testnet-points)[\*](#disclaimer). Check out the [Testnet Leaderboard](http://bit.ly/TestnetBetaLeaderboard) to see who is winning this week's challenges.

!!! note
    This documentation is for the **beta** release. The commands and APIs may change before the initial release. Last updated for `v0.0.1-beta.1`.

## Requirements

**Software**: macOS or Linux (currently supports Debian 9 and Ubuntu 18.04 LTS)

**Hardware**: Sending and receiving coda does not require any special hardware, but participating as a node operator currently requires:

- at least a 4-core processor
- at least 8 GB of RAM

GPUs aren't currently required, but may be required for node operators when the protoctol is upgraded.

**Network**: At least 1 Mbps connection

## Installation

The newest binary releases can be found below. Instructions are provided for macOS and Linux below:

!!! note
    This is a large download, around 1GB, so the install might take some time.

### macOS

Install using [brew](https://brew.sh).
```
brew install codaprotocol/coda/coda
``` 
You can run `coda -help` to see if the works

### Ubuntu 18.04 / Debian 9

Add the Coda Debian repo and install.

```
echo "deb [trusted=yes] http://packages.o1test.net unstable main" | sudo tee /etc/apt/sources.list.d/coda.list
sudo apt-get update
sudo apt-get install -t unstable coda-testnet-postake-medium-curves=0.0.1-release-beta-43cb0790
```

You can `coda -help` to see if it works.


### Windows

Windows is not yet supported. If you have any interest in developing Coda for Windows, please reach out to support@o1labs.org or reach out in the [Discord server](https://bit.ly/CodaDiscord).

### Build from source

If you're running another Linux distro or a different version of macOS, you can [try building Coda from source code](https://github.com/CodaProtocol/coda/blob/master/README-dev.md#building-coda). Please note that other operating systems haven't been tested thoroughly, and may have issues. Feel free to share any logs and get troubleshooting help in the Discord channel.

## Set up port forwarding

You must allow inbound traffic to the following ports through your **external** IP address.

- `TCP` port `8302`
- `UDP` port `8303`

For walk-through instructions see [this guide](/docs/troubleshooting/#port-forwarding).
## Next

Now that you've installed Coda and configured your network, let's move on to the fun part - [sending a transaction](/docs/my-first-transaction/)!

<span id="disclaimer">
\*_Testnet Points are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points._
</span>

