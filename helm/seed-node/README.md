## Introduction

This chart bootstraps a Coda protocol Testnet seed node.

## Add Coda Helm chart repository:

 ```console
 helm repo add coda https://coda-charts.storage.googleapis.com
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `seed-node` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`testnetName` | Coda protocol testnet name to deploy to
`seed.discoveryKeyPair` | Key pair used for identifying and connecting to the seed by external clients 

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`seed.active` | Whether to activate client as a Coda protocol seed node | `true`
`seed.fullname` | k8s pod name of seed node to deploy | `seed-node`
`seed.hostPort` | Coda daemon external port | `10001`
`seed.rpcPort` | Coda client peer communication port | `8301`
`seed.discoveryKeyPair` | Key pair used for identifying and connecting to the seed by external clients 
`coda.image` | container image to use for operating the archive node's Coda daemon | `codaprotocol/coda-daemon:0.0.12-beta-develop-589b507`
`coda.seedPeers` | peers to bootstrap the the archive node's Coda daemon

## seed-node launch examples

```console
helm install seed-node \
    --set testnetName=pickles \
    --set seed.discoveryKeyPair=<key-pair>
```
