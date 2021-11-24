## Introduction

This chart bootstraps a Mina protocol Testnet Generic Node.

## Add Mina Helm chart repository:

 ```console
 helm repo add mina https://coda-charts.storage.googleapis.com
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `generic-node` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`testnetName` | Mina protocol testnet name to deploy to
`generic.discoveryKeyPair` | Key pair used for identifying and connecting to the seed by external clients 

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`generic.active` | Whether to activate client as a Mina protocol generic node | `true`
`generic.fullname` | k8s pod name of generic node to deploy | `generic-node`
`generic.hostPort` | Mina client external port | `10001`
`generic.p2p` | Mina client peer communication port | `10909`
`generic.graphql` | Mina Client graphql communication port | `3085`
`generic.postgresPort` | Postgres database port | `5432`
`generic.discoveryKeyPair` | Key pair used for identifying and connecting to the seed by external clients 
`mina.image` | container image to use for operating the archive node's Mina daemon | `minaprotocol/mina-daemon1.2.1alpha1-1f98b8b-devnet`
`mina.runtimeConfig` | Mina daemon configuration to use at runtime | `undefined`

### Generic-node launch examples

```console
helm install generic-node
```