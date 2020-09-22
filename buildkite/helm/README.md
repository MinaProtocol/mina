## Introduction

This chart bootstraps a Buildkite GraphQL API metrics exporter providing job and agent statistics to a Prometheus compatible endpoint.

## Add Buildkite Exporter Helm chart repository:

 ```console
 helm repo add buildkite <insert>
 helm repo update
 ```

## Installing the Chart

In order for the chart to configure the Buildkite exporter properly during the installation process, you must provide some minimal configuration which can't rely on defaults:

To install the chart with the release name `bk-exporter`:

```console
helm install --name bk-exporter --namespace buildkite codaprotocol/buildkite-exporter \
    --set exporter.buildkiteApiKey="BUILDKITE_API_KEY"
```

## Configuration

The following table lists the configurable parameters of the `buildkite-exporter` chart and their default values.

Parameter | Description | Default
--- | --- | ---
`replicaCount` | Replicas count | 1

## buildkite-exporter launch examples


## Uninstalling the Chart

To uninstall/delete the `bk-exporter` release:

```console
helm delete bk-exporter
```
