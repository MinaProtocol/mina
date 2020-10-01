## Introduction

This chart bootstraps a Buildkite GraphQL API metrics exporter providing job and agent statistics to a Prometheus compatible endpoint.

## Add Coda Helm chart repository:

 ```console
 helm repo add coda <insert-repository-url>
 helm repo update
 ```

## Configuration

The following table lists the configurable parameters of the `buildkite-exporter` chart and its default values.

### Required Settings

Parameter | Description
--- | ---
`exporter.buildkiteApiKey` | Buildkite GraphQL API access key

### Optional Settings

Parameter | Description | Default
--- | --- | ---
`exporter.pipeline` | Buildkite pipeline to scrape and export | `coda`
`exporter.image` | Buildkite exporter container image to deploy | `codaprotocol/buildkite-exporter:0.1.0`
`exporter.listeningPort` | port on which to listen for data collection requests | `8000`
`exporter.optionalEnv` | optional environment variable configuration settings | `[]`

## buildkite-exporter launch examples

```console
helm install buildkite-exporter \
    --set exporter.buildkiteApiKey=<api-key> \
    --set exporter.optionalEnv=[{'name': 'BUILDKITE_BRANCH', 'value': 'release'}]
```
