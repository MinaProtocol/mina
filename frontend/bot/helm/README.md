## Introduction

This chart bootstraps O(1) Lab's Coda protocol bot for providing various services to deployed testnets.

## Add Coda Helm chart repository:

 ```console
 helm repo add coda <insert-repository-url>
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `o1-bot` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`bot.name` | name of bot to deploy
`bot.image` | container image representing bot function/role
`bot.role` | role/function of bot to deploy
`bot.testnet` | coda protocol testnet to deploy to

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`bot.command` | override command to run on bot startup | `[]`
`bot.args` | arguments to pass to startup override command | `[]`
`bot.resources` | bot resource specification/mapping | `see default Values.yaml`
`bot.optionalEnv` | optional environment variable configuration settings | `[]`
`bot.volumes` | k8s volume objects to launch bot with | `[]`
`bot.volumeMounts` | bot pod volume mount path settings | `[]`

## buildkite-exporter launch examples

```console
helm install faucet ...
```
