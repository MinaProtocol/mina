## Introduction

This chart bootstraps a Mina protocol Testnet block producer.

## Add Mina Helm chart repository:

 ```console
 helm repo add mina https://coda-charts.storage.googleapis.com
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `block-producer` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`testnetName` | Mina protocol testnet name to deploy to
`coda.seedPeers` | peers to bootstrap the the archive node's Mina daemon

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`userAgent.image` | Container image to use for a Mina protocol user-agent sidecar | ""
`bots.image` | Container image to use for a Mina protocol faucet and echo service sidecars | ""
`coda.image` | container image to use for operating the archive node's Mina daemon | `codaprotocol/coda-daemon:0.0.12-beta-new-genesis-01eca9b`
`blockProducerConfigs` | list of Mina protocol block producer config and provisioning settings | `see [default] values.yaml`
`blockProducerConfigs[].name` | Name of block producer configuration and deployment object | `<item-data>`
`blockProducerConfigs[].class` | Testnet block producer class based on account balance (e.g. fish or whale) | `<item-data>`
`blockProducerConfigs[].runWithBots` | Whether to run with certain Mina protocol testnet bots | `<item-data>`
`blockProducerConfigs[].runWithUserAgent` | Whether to run with a user-agent which periodically sends transactions | `<item-data>`
`blockProducerConfigs[].enableGossipFlooding` | Whether to enable gossip flooding | `<item-data>`
`blockProducerConfigs[].privateKeySecret` | account wallet private key secret associated with Mina test account/wallet | `<item-data>`
`blockProducerConfigs[].externalPort` | Port Mina clients use for connecting to the external network | `<item-data>`
`coda.logLevel` | log level to set for Mina daemon | `TRACE` 
`coda.logSnarkWorkGossip` | whether the Mina daemon should log SNARK work gossip | `false`
`coda.runtimeConfig` | Mina daemon configuration to use at runtime | `undefined`
`coda.privKeyPass` | public-private key-pair associated with Mina daemon account | `see [default] values.yaml`
`userAgent.minFee` | Minimum fee to accept for sending network transactions | ""
`userAgent.maxFee` | Maximum fee to accept for sending network transactions | ""
`userAgent.minTx` | Minimum transaction amount to send by the user-agent | ""
`userAgent.maxTx` | Maxiumum transaction amount to send by the user-agent | ""
`bots.faucet.amount` | Amount to send in response to request for faucet funds | "10000000000"
`bots.faucet.fee` | Fee to charge for sending faucet funds | "100000000"

## block-producer launch examples

```console
helm install block-producer \
    --set testnetName=pickles \
    --set coda.seedPeers=['/dns4/coda-testnet-seed-one.pickles.o1test.net/tcp/10002/p2p/12D3KooWP7fTKbyiUcYJGajQDpCFo2rDexgTHFJTxCH8jvcL1eAH]
```
