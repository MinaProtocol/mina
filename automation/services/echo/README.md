# Echo Service

This is a simple node service that listens for transactions to a specific address and then simply sends a payment back to the sender with the amount of `amount - fee`. The fee can be configured but by default is set to `5`.

## Usage

First you'll need to have a `mina` daemon running on your machine. See the docs [here](https://docs.minaprotocol.com/en/getting-started/) for instructions on getting a node, then run the following command:

```
$ mina daemon -rest-port 49370 -peer beta.o1test.net:8303
```

This process must be running for this service to work. Open a new terminal session before you continue.

The service requires [node](https://nodejs.org) to be installed on your system, and uses [yarn](https://yarnpkg.com) as the package manager. Here's how you run the echo service:

```
$ yarn
$ yarn start
```

Look at the logs for the address on which the service is listening. By default the client will query the node for existing wallets. If none exist it will create a new wallet. You can also manually set the public key by setting the`PUBLIC_KEY` environment variable. *NOTE: This is an advanced configuration, you must have the private keys for the address loaded into the node or else the service will not be able to send payments*

When you send a payment to the service, it will send back a payment with the amount equal to `initial_amount - fee` which can be configured via the `FEE` environment variable, however is set to `5` by default.

By default, the client tries to connect to the daemon at `localhost:49370` however this can be configured via the `CODA_HOST` and `CODA_PORT` environment variables. 
