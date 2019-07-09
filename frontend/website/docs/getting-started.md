# Getting Started

This section will walk you through the requirements needed to run a Coda protocol node on your local machine and connect to the network.

!!! note
    Last updated for release v0.0.1

### Requirements

**Software**: macOS (10.x.x and above) or Linux (currently supports Debian 9 and Ubuntu)

**Hardware**: Sending and receiving coda does not require any special hardware, but [some requirements]() exist for generating zk-SNARKs

### Installation

The newest binary releases can be found [here](). With the exception of the .exe and .dmg files, they are archives of the latest executable binaries for each release. Instructions are provided for macOS and Linux below:

**macOS**

1. Download [coda.zip]()
2. Unzip anywhere, `cd` to navigate to the Coda directory
3. Run `brew install miniupnpc` to install [MiniUPnP client](https://github.com/miniupnp/miniupnp)
4. Set up port forwarding (see below)
5. `./coda -help` to see if it works

**Linux (Ubuntu / Debian)**

1. Download [coda.deb]()
2. Run `apt-get install miniupnpc` to install [MiniUPnP client](https://github.com/miniupnp/miniupnp)
3. Set up port forwarding (see below)
4. Double click
5. `coda -help` to see if it works


**Windows**

Windows is not yet supported - there is [grant funding available]() for adding Windows support.

To build from source code, please follow [the instructions in the Coda protocol repo](https://github.com/CodaProtocol/coda/blob/master/README-dev.md#building-coda)

## Port forwarding

If you're running a Coda node on a home or office machine, you'll have to manually set up [port forwarding](https://en.wikipedia.org/wiki/Port_forwarding) to make your node visible on the internet to other Coda nodes.

Run the following commands to use MiniUPnP to reconfigure ports on your IP address:

1. First run `ifconfig` to get your external IP address - you can find this in the output corresponding to the field `en0`:


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

2. Then run `upnpc -a <IP address> <internal port> <external port> TCP`, with the IP address from from the previous step. Note that you'll have to run it four times, one for each port that needs to be forwarded:

        $ upnpc -a 192.168.101.7 8301 8301 TCP
        $ upnpc -a 192.168.101.7 8302 8302 TCP
        $ upnpc -a 192.168.101.7 8303 8303 TCP
        $ upnpc -a 192.168.101.7 8304 8304 TCP



If these commands succeed, you will have successfully forwarded ports `8301-8304`. Otherwise, you may see the following error message:

    No IGD UPnP Device found on the network !

If so, [find your router model](https://portforward.com/router.htm) and follow the instructions to forward TCP ports `8301-8304` from your router to your device running the Coda node.

Now that you've installed the Coda binary and configured settings, let's move on to the fun part - [sending a transaction](/my-first-transaction)!