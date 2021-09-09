## Introduction

This chart bootstraps a Mina protocol Testnet snark-coordinator and associated workers.

## Add Mina Helm chart repository:

 ```console
 helm repo add mina https://coda-charts.storage.googleapis.com
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `snark-worker` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`testnetName` | Mina protocol testnet name to deploy to
`coordinator.publicKey` | Mina account/wallet public key to use for registering for SNARK work payments
`coda.seedPeers` | peers to bootstrap the the archive node's Mina daemon

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`coordinator.active` | Whether to activate testnet client as a SNARK coordinator | `true`
`coordinator.fullname` | k8s pod name of snark coordinator to deploy | `see [default] values.yaml`
`coordinator.snarkFee` | Fee to charge for processing SNARK work | `0.025`
`coordinator.workSelectionAlgorithm` | SNARK work selection and assignment algorithm | `seq`
`coordinator.hostPort` | Mina client external port | `10001`
`coordinator.rpcPort` | Mina client peer communication port | `8301`
`worker.active` | Whether to activate testnet client with SNARK workers | `true`
`worker.fullname` | k8s pod name of snark worker to deploy | `see [default] values.yaml`
`worker.numReplicas` | Number of SNARK workers to provision and manage by coordinator | `1`
`worker.remoteCoordinatorHost` | Host address to access a remote coordinator | `see [default] values.yaml`
`worker.remoteCoordinatorPort` | Host port to access a remote coordinator | `8301`
`coda.image` | container image to use for operating the archive node's Mina daemon | `codaprotocol/coda-daemon:0.0.12-beta-develop-589b507`
`coda.genesis` | Mina genesis constants | `see [defaults] values.yaml`
`coda.runtimeConfig` | Mina daemon configuration to use at runtime | `undefined`

## snark-worker launch examples

```console
helm install snark-worker \
    --set testnetName=pickles \
    --set coordinator.publicKey="<public-key>" \
    --set coda.seedPeers=['/dns4/coda-testnet-seed-one.pickles.o1test.net/tcp/10002/p2p/12D3KooWP7fTKbyiUcYJGajQDpCFo2rDexgTHFJTxCH8jvcL1eAH]
```
