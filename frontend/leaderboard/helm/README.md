## Introduction

This chart bootstraps a Mina Protocol Testnet leaderboard service

## Add Mina Helm chart repository:

 ```console
 helm repo add mina https://coda-charts.storage.googleapis.com
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `leaderboard` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`postgresql.postgresHost` | Mina protocol Postgres SQL archive host address
`postgresql.postgresPort` | Mina protocol Postgres SQL archive listening port
`volume.secretName` | Leaderboard credentials information | `none`

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`leaderboard.name` | Mina protocol leaderboard service/cron job name | `leaderboard-cron`
`leaderboard.containerName` | name of container to provision for leaderboard job | `leaderboard`
`leaderboard.image` | Mina protocol leaderboard container image | `gcr.io/o1labs-192920/leaderboard`
`leaderboard.schedule` | frequency with which to execute leaderboard operations | `@hourly`
`postgresql.postgresqlUsername` | Mina protocol Postgres SQL archive username | `none`
`postgresql.postgresqlPassword` | Mina protocol Postgres SQL archive password | `none`

## leaderboard launch examples

```console
helm install leaderboard
```
