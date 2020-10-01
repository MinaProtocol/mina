## Introduction

This chart bootstraps a Coda protocol Testnet block producer.

## Add Coda Helm chart repository:

 ```console
 helm repo add coda https://coda-charts.storage.googleapis.com
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `block-producer` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`testnetName` | Coda protocol testnet name to deploy to
`coda.seedPeers` | peers to bootstrap the the archive node's Coda daemon

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`userAgent.image` | Container image to use for a Coda protocol user-agent sidecar
`bots.image` | Container image to use for a Codaprotocol faucet and echo service sidecars
`coda.image` | container image to use for operating the archive node's Coda daemon | `codaprotocol/coda-daemon:0.0.12-beta-new-genesis-01eca9b`
`blockProducerConfigs` | list of Coda protocol block producer config and provisioning settings
`blockProducerConfigs[].name` | Name of block producer configuration and deployment object
`blockProducerConfigs[].class` | Testnet block producer class based on account balance (e.g. fish or whale)
`blockProducerConfigs[].runWithBots` | Whether to run with certain Coda protocol testnet bots
`blockProducerConfigs[].runWithUserAgent` | Whether to run with a user-agent which periodically sends transactions
`blockProducerConfigs[].enableGossipFlooding` | Whether to enable gossip flooding
`blockProducerConfigs[].privateKeySecret` | account wallet private key secret associated with Coda test account/wallet
`blockProducerConfigs[].externalPort` | Port Coda clients use for connecting to the external network
`coda.logLevel` | log level to set for Coda daemon | `TRACE` 
`coda.logReceivedBlocks` | whether the Coda daemon should log received blocks events | `false`
`coda.logSnarkWorkGossip` | whether the Coda daemon should log SNARK work gossip | `false`
`coda.runtimeConfig` | Coda daemon configuration to use at runtime | `undefined`
`coda.privKeyPass` | public-private key-pair associated with Coda daemon account | `see [default] values.yaml`
`userAgent.minFee` | Minimum fee to accept for sending network transactions
`userAgent.maxFee` | Maximum fee to accept for sending network transactions
`userAgent.minTx` | Minimum transaction amount to send by the user-agent
`userAgent.maxTx` | Maxiumum transaction amount to send by the user-agent
`bots.faucet.amount` | Amount to send in response to request for faucet funds 
`bots.faucet.fee` | Fee to charge for sending faucet funds

## block-producer launch examples

```console
helm install block-producer \
    --set testnetName=pickles \
    --set coda.seedPeers=['/dns4/coda-testnet-seed-one.pickles.o1test.net/tcp/10002/p2p/12D3KooWP7fTKbyiUcYJGajQDpCFo2rDexgTHFJTxCH8jvcL1eAH]
```
