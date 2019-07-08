# Getting Started

Last updated for release v0.0.1

### Requirements

**Software**: macOS (10.x.x+) or Linux (currently supports Debian 9 and Ubuntu)

**Hardware**: Sending and receiving coda does not require any special hardware, but [some requirements](link to earn coda) exist for generating zk-SNARKs

### Installation

The newest binary releases can be found here<TODO LINK>. With the exception of the .exe and .dmg files, they are archives of the latest executable binaries for each release. Although most of this will be extract and go, instructions are provided for macOS and Linux below:

**macOS**

1. Download [coda.zip](todo)
2. Unzip anywhere, `cd` to navigate to the Coda directory
3. Run `brew install miniupnpc` to install [MiniUPnP client](https://github.com/miniupnp/miniupnp)
4. Set up port forwarding (see below)
5. `./coda -help` to see if it works

**Linux (Ubuntu / Debian)**

1. Download [coda.deb](todo)
2. Run `apt-get install miniupnpc` to install [MiniUPnP client](https://github.com/miniupnp/miniupnp)
3. Set up port forwarding (see below)
4. Double click
5. `coda -help` to see if it works


**Windows**

Windows is not yet supported - we have grant funding <insert link> for adding Windows support.

To build from source code, please follow [the instructions in the Coda protocol repo](https://github.com/CodaProtocol/coda/blob/master/README-dev.md#building-coda)

## Port forwarding

If you're running a Coda node on a home or office machine, you'll have to manually set up [port forwarding](https://en.wikipedia.org/wiki/Port_forwarding) to make the node visible on the internet to the other Coda nodes.

Run the following commands to use MiniUPnP to reconfigure ports on your IP address:

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
    $ upnpc -a 192.168.101.7 8301 8301 TCP
    $ upnpc -a 192.168.101.7 8302 8302 TCP
    $ upnpc -a 192.168.101.7 8303 8303 TCP
    $ upnpc -a 192.168.101.7 8304 8304 TCP

If these commands succeed, you will have successfully forwarded ports `8301-8304`. Otherwise, you may see the following error message:

    No IGD UPnP Device found on the network !

If so, [find your router model](https://portforward.com/router.htm) and follow the instructions to forward `8301-8304` TCP ports from your router to your device running the Coda node.