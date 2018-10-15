# Coda

Coda is a new cryptocurrency protocol with a lightweight, constant sized blockchain.

* [Coda Protocol Website](https://codaprotocol.com/)
* [Coda Protocol Roadmap](https://github.com/orgs/CodaProtocol/projects/1)

Please see our [developer README](README-dev.md) if you are interested in building coda from source code.

FIXME: Add some user documentation here.

# Getting started

# Downloading coda packages

```
curl
dpkg -i
coda daemon ...
coda client ...
```

# Running coda container

```
docker run ...
```

# Network considerations

Coda needs open communication for our Gossip protcol and DHT neighbor discovery to communicate.

Be sure to open the necessary ports on iptables, security groups, or NAT forwarding rules to permit this traffic.

Default ports are: TCP 8302 for Gossip and UDP 8303 for DHT peer exchange.

The [miniupnp project](http://miniupnp.free.fr/) has some simple utilities to make this easier to setup.


# License

This repository is distributed under the terms of the Apache 2.0 license,
available in the LICENSE fail and online at
https://www.apache.org/licenses/LICENSE-2.0. Commits older than 2018-10-03 do
not have a LICENSE file or this notice, but are distributed under the same terms.
