## Introduction

This chart bootstraps a Coda protocol archive node and associated Postgres database.

## Add Coda Helm chart repository:

 ```console
 helm repo add coda <insert-repository-url>
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `archive-node` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`testnetName` | Coda protocol testnet name
`coda.seedPeers` | peers to bootstrap the the archive node's Coda daemon 
`archive.nodeName` | name identifier of archive node pod

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`archive.image` | container image to use for operating an archive node | `codaprotocol/coda-archive:0.0.12-beta-fix-archive-debs-62bae52`
`archive.postgresHost` | Postgres database host to store archival data | `see [default] values.yaml`
`archive.postgresPort` | Postgres database port | `5432`
`archive.postgresDB` | Postgres database to store archival data | `archive`
`archive.postgresUri` | port on which to listen for data collection requests | `see [default] values.yaml`
`archive.remoteSchemaFile` | archive database schema during initialization | `see [default] values.yaml`
`archive.hostPort` | Kubernetes node port to expose | `10909`
`archive.optionalEnv` | optional environment variable configuration settings | `[]`
`postgres.postgresqlUsername` | Postgress database access username (if set) | `postgres`
`postgres.postgresPassword` | Postgres database access password (if set) | `foobar`
`coda.image` | container image to use for operating the archive node's Coda daemon | `codaprotocol/coda-daemon:0.0.14-rosetta-scaffold-inversion-489d898`
`coda.logLevel` | log level to set for Coda daemon | `TRACE` 
`coda.logReceivedBlocks` | whether the Coda daemon should log received blocks events | `false`
`coda.logSnarkWorkGossip` | whether the Coda daemon should log SNARK work gossip | `false`
`coda.runtimeConfig` | Coda daemon configuration to use at runtime | `undefined`
`coda.privKeyPass` | public-private key-pair associated with Coda daemon account | `see [default] values.yaml`

## archive-node launch examples

```console
helm install archive-node \
    --set testnetName=pickles \
    --set coda.seedPeers=['/dns4/coda-testnet-seed-one.pickles.o1test.net/tcp/10002/p2p/12D3KooWP7fTKbyiUcYJGajQDpCFo2rDexgTHFJTxCH8jvcL1eAH]
```
