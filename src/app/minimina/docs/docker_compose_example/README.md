# Mina Local Network Setup with Docker Compose

This guide will help you set up a local Mina network with 1 seed node, 2 block producers, 1 snark coordinator with 1 snark worker and archive service.

Note that the guide is compatible with following docker images:
 - Mina daemon: `gcr.io/o1labs-192920/mina-daemon:2.0.0rampup3-bfd1009-buster-berkeley`
 - Mina archive: `gcr.io/o1labs-192920/mina-archive:2.0.0rampup3-bfd1009-buster`

## Prerequisites

- Ensure Docker is installed on your machine.

## Step-by-step Guide

1. **Create Required Directories**

Create necessary directories for your local Mina network:

```bash
mkdir -p ~/.minimina/default
```

2. **Generate Key Pairs for Block Producers**

We need to generate key pairs for our block producers `mina-bp-1` and `mina-bp-2` making sure that folder containing keys have appopriate file permissions. Keys for the seed node and snark coordinator will be hardcoded inside our docker-compose.

Use the [generate_keys.sh](generate_keys.sh) helper script to produce necessary key pairs using the Docker image:

```bash
$ ./docs/docker_compose_example/generate_keys.sh
----------------
mina-bp-1 keys: 

Using password from environment variable MINA_PRIVKEY_PASS
Keypair generated
Public key: B62qmA6aWP4TLDG7TPqRoTm9yJNbqe46ZZftVYtRdSdRrh2BuccDm81
Raw public key: 50A63B492627EB9A66E3AC2268AF7F649793F63E474E0E51D5722D79D13D4591

libp2p keypair:
CAESQFWdTju2nlLVu1exgaKYMwDmWxKfDmk/jeWGKTTNQZw+vBcBuN9Dlxul0maxgBD85Mp4rYPuKmGNbXXTXk8+GWg=,CAESILwXAbjfQ5cbpdJmsYAQ/OTKeK2D7iphjW11015PPhlo,12D3KooWNUbARSnVbRyaNTuQYVuPZnCTx2A591h3AP1YUXkAc5JP

----------------
mina-bp-2 keys: 

Using password from environment variable MINA_PRIVKEY_PASS
Keypair generated
Public key: B62qqD5HUTos1Ezui8Z6YuGxAjm6WY94wqmgfYfpwGz7z8jBuwyAUvJ
Raw public key: C987E064EC8B1297351D95DECE263D678D71AB10DC3D6F7D4AACCBA259BCCC80

libp2p keypair:
CAESQCkVLr2hqOCCfY8qg68Q4CsdbbWwLFXDtJl9E/6Rdh4WXQ29UTGubEeNUf0erg6Pl47oi8oXqHHZv5QIqzkuVWE=,CAESIF0NvVExrmxHjVH9Hq4Oj5eO6IvKF6hx2b+UCKs5LlVh,12D3KooWG5cEeAm2JgaNdv8mZ4ivyLfpAdF4PHh7RarfRnZHNMqi
```

3. **Generate Genesis Ledger File**

Generate genesis ledger file ensuring that generated keys for block producers will have funds to be able to produce blocks.

Use the [generate_ledger.sh](generate_ledger.sh) helper script to produce `genesis_ledger.json` file in `~/.minimina/default` directory:

```bash
$ ./docs/docker_compose_example/generate_ledger.sh
Generated genesis ledger file in /home/piotr/.minimina/default/genesis_ledger.json including keys:
Key 1: B62qmA6aWP4TLDG7TPqRoTm9yJNbqe46ZZftVYtRdSdRrh2BuccDm81
Key 2: B62qqD5HUTos1Ezui8Z6YuGxAjm6WY94wqmgfYfpwGz7z8jBuwyAUvJ
```

4. **Docker Compose Configuration**

Copy [docker-compose-example.yaml](docker-compose-example.yaml) to `~/.minimina/default/docker-compose.yaml`.

```bash
cp docs/docker_compose_example/docker-compose-example.yaml ~/.minimina/default/docker-compose.yaml
```

5. **Configure Postres Database for Archive Node**

In order to configure database for Archive Node we need to start postgres database first.

```bash
cd ~/.minimina/default
docker compose create
docker compose start postgres
```

Now, let's create database:

```bash
docker exec -it postgres createdb -U postgres archive
```

And load the mina archive and zkapps schemas into the archive database:

```bash
curl -Ls https://raw.githubusercontent.com/MinaProtocol/mina/rampup/src/app/archive/create_schema.sql | docker exec -i postgres psql -U postgres -d archive

curl -Ls https://raw.githubusercontent.com/MinaProtocol/mina/rampup/src/app/archive/zkapp_tables.sql | docker exec -i postgres psql -U postgres -d archive
```

6. **Start the Network**

Once everything is configured, spin up the local network.

```bash
cd ~/.minimina/default
docker compose up
```

And that's it! Your local Mina network should now be running. Monitor the logs to ensure all services are operating without errors.

> ⚠️ Depending on your Docker version, you might need to use `docker-compose up` and `docker-compose down` instead.

7. **Monitor and manage the network**

- To check running processes:

```bash
docker ps
```

- To view the logs of a specific Mina daemon (for example, mina-bp-1):

```bash
docker logs mina-bp-1 -f
```

- To check the status of a particular daemon (consult the `docker-compose.yaml` file to determine the client port for a specific daemon):

```bash
docker run \
--network host \
--rm \
--entrypoint mina \
gcr.io/o1labs-192920/mina-daemon:2.0.0rampup3-bfd1009-buster-berkeley \
client status -daemon-port 4000
```

- To stop and start particular daemon

```bash
docker stop mina-bp-2
docker start mina-bp-2
```

8. **Stop the network**

If you wish to stop the network, simply run:

```bash
cd ~/.minimina/default
docker compose down --volumes
```
