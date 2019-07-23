# Getting Started

This section will walk you through the requirements needed to run a Coda protocol node on your local machine and connect to the network.

Join the Coda server on [Discord](http://bit.ly/CodaDiscord) to connect with the community, get support, and learn about how you can participate in weekly challenges for Testnet Points.\*

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

### macOS (10.x)

- Run `brew install codaprotocol/coda/coda` -- NOTE: This is a large file (~1 GB), so this step might take some time
- `coda -help` to see if it works
- Set up port forwarding ([see below](/docs/getting-started/#port-forwarding))

### Linux (Ubuntu 18.04 / Debian 9)

- Add the Coda Debian repo and install -- NOTE: This is a large file (~1 GB), so this step might take some time

```
sudo echo "deb [trusted=yes] http://packages.o1test.net unstable main" > /etc/apt/sources.list.d/coda.list
sudo apt-get update
sudo apt-get install -t unstable coda-testnet-postake-medium-curves=0.0.1-release-beta-9fa6e5ec
```

- `coda -help` to see if it works
- Set up port forwarding ([see below](/docs/getting-started/#port-forwarding))


### Windows

Windows is not yet supported. If you have any interest in developing Coda for Windows, please reach out to contact@codaprotocol.org or reach out in the [Discord server](https://bit.ly/CodaDiscord).

### Build from source

If you're running another Linux distro or a different version of macOS, you can [try building Coda from source code](https://github.com/CodaProtocol/coda/blob/master/README-dev.md#building-coda). Please note that other operating systems haven't been tested thoroughly, and may have issues. Feel free to share any logs and get troubleshooting help in the Discord channel.

## Port forwarding

If you're running a Coda node on a home or office machine, you'll have to set up [port forwarding](https://en.wikipedia.org/wiki/Port_forwarding) to make your node visible on the internet to other Coda nodes. Note that when running Coda in the cloud, this is unnecessary -- instead you should configure security groups for your cloud provider.

Follow the steps below to use [MiniUPnP](https://github.com/miniupnp/miniupnp) to forward ports on your router:

1. Run `ifconfig` to get your internal IP address -- you can find this in the output corresponding to the field `en0` on macOS and `wlan0` on a linux system:

        $ ifconfig
        ...
        en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
                ether 8c:85:90:c9:a2:01 
                inet6 fe80::1458:bdd4:e7dc:518e%en0 prefixlen 64 secured scopeid 0x8 
                inet 192.168.101.7 netmask 0xffffff00 broadcast 192.168.101.255
                nd6 options=201<PERFORMNUD,DAD>
                media: autoselect
                status: active
        ...

2. Run the following commands, with the IP address next to the `inet` field in the previous step. Note that you'll have to run it twice for the two ports below:

        $ sudo upnpc -a 192.168.101.7 8302 8302 TCP
        $ sudo upnpc -a 192.168.101.7 8303 8303 UDP

If these commands succeed, you'll see responses indicating that the ports have been successfully redirected:

```
...
InternalIP:Port = 192.168.101.7:8302
external 148.64.99.117:8302 TCP is redirected to internal 192.168.101.7:8302 (duration=0)
...
InternalIP:Port = 192.168.101.7:8303
external 148.64.99.117:8303 UDP is redirected to internal 192.168.101.7:8303 (duration=0)
```

If you are on a shared network (like an office wireless network), you may get the following error if someone else on the same network has already redirected these ports:

```
AddPortMapping(8302, 8302, 192.168.101.7) failed with code 718 (ConflictInMappingEntry)
```

If this happens, you can forward different ports, as long as they are unused by another application. Two things the keep in mind if you forward custom ports:

- The UDP port forwarded has to be the next consecutive port from the TCP mapping.
- When running Coda daemon commands in the next step, you'll need to add the flag `-external-port <TCP PORT>` passing in the TCP port forwarded.

### Manual port forwarding

Depending on your router, you may see one of the following errors:

- `No IGD UPnP Device found on the network!`
- `connect: Connection refused`

If so, find your router model and Google `<model> port forwarding` and follow the instructions to forward the ports from your router to your device running the Coda node. You'll need to open the TCP port 8302, and the UDP port 8303 by default.

## Next

Now that you've installed the Coda binary and configured settings, let's move on to the fun part - [sending a transaction](/docs/my-first-transaction/)!

\*_Testnet Points are designed solely to track contributions to the Testnet and Testnet Points have no cash or other monetary value. Testnet Points are not transferable and are not redeemable or exchangeable for any cryptocurrency or digital assets. We may at any time amend or eliminate Testnet Points._

