# Faucet Service

The faucet service is a simple Discord bot that listens for requests for `CODA` in a Discord channel and issues transactions to a local Coda Daemon. It is currently best to run this against a mina daemon running on a host machine, as opposed to against a Daemon in a docker container. 

## Usage

First you'll need to have a `coda` daemon running on your machine. See the docs [here](https://docs.minaprotocol.com/en/getting-started) for instructions on getting a node, then run the following command:

```
$ mina daemon -rest-port 49370 -peer beta.o1test.net:8303
```

This process must be running for this service to work. Open a new terminal session before you continue.

The service requires Python 3.7 to be installed on your system, and uses pip as the package manager. To make things easy, a docker-compose environment has been provided that allows you to start the service simply. First, copy the example and update your environment variables:

```
cp docker-compose.yml.example docker-compose.yml
```

```
environment:
    DISCORD_API_KEY: <API_KEY>
    DAEMON_HOSTNAME: localhost
    DAEMON_PORT: 8304
    FAUCET_PUBLIC_KEY: <PUBLIC_KEY> 
```

```
docker-compose up
```

**NOTE:** Host networking is enabled in the example docker-compose file, meaning that host ports will be shared with the container and the daemon can be accessed on `localhost`.
