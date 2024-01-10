## Docker Instructions

It is possible to run the Coda daemon inside a Docker container. This allows for resource and dependency isolation, and homogenization of infrastructure. 

The Coda Protocol builds one main Docker Image `codaprotocol/coda-daemon` which contains the Coda Daemon and its dependencies. Image Tags follow the release cadence for the Coda Protocol and the goal is to keep them up to date with [Github Releases](https://github.com/CodaProtocol/coda/releases). 

### Quick Start 

Pull and Run the `coda-daemon` image: 

```
docker run --publish 8302:8302 --publish 8303:8303 codaprotocol/coda-daemon:<version> daemon -peer <testnet>.o1test.net:8303
```

For more details on the `docker run` command, see the [Docker Docs](https://docs.docker.com/engine/reference/run/).

Now, lets break down that command a little bit: 
- `--publish 8302:8302 --publish 8303:8303` By default, the Coda Daemon exposes two ports (8302 TCP, 8303 UDP) used for Network communication
- `daemon` specifies that we should run a mina daemon
- `-peer` specifies an initial seed to query during the peer discovery process, more than one peer may be specified
- `-external-port` specifies a non-default

For more details on the Coda Daemon CLI and other flags it supports, you may execute the `help` command: 

```
docker run codaprotocol/coda-daemon:<version> daemon -help
```

### Running Coda with a Container Orchestrator

Currently, the implementation of the Kademlia DHT in use by the Coda Daemon is a tad tempermental, and requires consistent ports to be set on both the host and container.

There is a bug issue [here](https://github.com/CodaProtocol/coda/issues/2947) that details the problem. In the meantime, it is easiest to avoid any sort of bridge networking and run the Daemon container on the host network, especially if you'd like to use non-default ports. 

Here is a minimal `docker-compose.yml` file that accomplishes this: 

```
version: '3'
services:
  coda:
    network: host
    image: codaprotocol/coda-daemon:<version>
    command: 
      daemon -peer <testnet>.o1test.net:8303 -rest-port 8304 -external-port 10101 -metrics-port 10000 -block-producer-key /root/wallet-keys/my_wallet -unsafe-track-block-producer-key
    environment: 
      MINA_PRIVKEY_PASS: <key-password>
    volumes:
      - ~/wallet-keys:/root/wallet-keys
```

In addition to running the daemon on the host network, it does a few other things: 
- `-rest-port 8304` it enables the Daemon's GraphQL endpoint on `localhost:8304`
- `-external-port 10101` it specifies a non-default external communication (TCP) port (also implicitly sets `10102` as the gossip (UDP) port)
- `-metrics-port 10000` it enables the Daemon's Prometheus metrics endpoint on `localhost:10000`
- `block-producer-key /root/wallet-keys/my_wallet` it loads an arbitrary wallet key file at runtime to act as a Block Producer
- `-unsafe-track-block-producer-key` it tells the daemon to *(insecurely)* strip the password from the wallet key file and load it into the internal wallet store for use with GraphQL 

