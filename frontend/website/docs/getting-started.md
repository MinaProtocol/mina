# Getting Started

This section will walk you through the requirements needed to run a Coda protocol node on your local machine and connect to the network.

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
You can run `coda -help` to check if the installation succeeded.

### Ubuntu 18.04 / Debian 9

Add the Coda Debian repo and install.

```
echo "deb [trusted=yes] http://packages.o1test.net unstable main" | sudo tee /etc/apt/sources.list.d/coda.list
sudo apt-get update
sudo apt-get install -t unstable coda-testnet-postake-medium-curves=0.0.1-release-beta-43cb0790
sudo apt-mark hold coda-testnet-postake-medium-curves
```

You can run `coda -help` to check if the installation succeeded.


### Windows

Windows is not yet supported. If you have any interest in developing Coda for Windows, please reach out to support@o1labs.org or reach out in the [Discord server](https://bit.ly/CodaDiscord).

### Build from source

If you're running another Linux distro or a different version of macOS, you can [try building Coda from source code](https://github.com/CodaProtocol/coda/blob/master/README-dev.md#building-coda). Please note that other operating systems haven't been tested thoroughly, and may have issues. Feel free to share any logs and get troubleshooting help in the Discord channel.

## Set up port forwarding and any firewalls

If you are running a firewall, you should allow traffic on TCP port 8302 and UDP port 8303. Additionally, unless the `-external-ip YOUR_IP` flag is provided, the daemon will use HTTPS (443) and HTTP (80) to try and determine its own IP address.

You may need to configure your router's port forwarding to allow inbound traffic to the following ports through your **external** IP address.

- `TCP` port `8302`
- `UDP` port `8303`

For walk-through instructions see [this guide](/docs/troubleshooting/#port-forwarding).
## Next

Now that you've installed Coda and configured your network, let's move on to the fun part - [sending a transaction](/docs/my-first-transaction/)!

