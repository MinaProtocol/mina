<a href="https://minaprotocol.com">
	<img width="200" src="https://github.com/MinaProtocol/docs/blob/main/public/static/img/svg/mina-wordmark-redviolet.svg?raw=true&sanitize=true" alt="Mina Logo" />
</a>
<hr/>

<br />

# CI Metrics Dashboard (PoC)

<br />

- [CI Metrics Dashboard (PoC)](#ci-metrics-dashboard-poc)
  - [Dashboard Architecture](#dashboard-architecture)
    - [Database bootstrap](#database-bootstrap)
    - [Retrievers](#retrievers)
      - [Important assumptions to consider before adding a retriever](#important-assumptions-to-consider-before-adding-a-retriever)
    - [Metrics sources](#metrics-sources)
  - [Helm Chart Installation](#helm-chart-installation)
  - [Proposed retriever development workflow](#proposed-retriever-development-workflow)
- [Future (ongoing) Work](#future-ongoing-work)

<br />

---

## Dashboard Architecture

<br />

<img width="500" src="_img/ci-metrics-cronjob-architecture.svg" alt="light bulb">

The CI Metrics dashboard PoC Chart essentially deploys an auxiliary database, consequently populated by a collection of `retrievers` containers periodically executed by a Kubernetes CronJob. The database serves as a "data source" to Grafana.

Overall, the Chart deploys the following Kubernetes workloads:
- An InfluxDB from a [dependency Chart](https://github.com/bitnami/charts/tree/main/bitnami/influxdb). This deploy a StatefulSet and other resources. Refer to the repository for the configuration parameters.
- A CronJob with as many initContainers as configured `.Values.retrievers`. Retrievers will dump metrics to files at `$OUTPUTDIR/` which is passed as an environment variable to each container running a retriever. Later, a `db-pusher` container will scrape all `/$OUTPUTDIR/*.dat` files and dump it in the database.
- **IMPORTANT:** by convention these **metric value files** follow this schema:
  - `METRIC_NAME.dat`: file name is the metric name.
  - `METRIC_NAME.dat` contains `METRIC_VALUE_AS_FLOAT`

### Database bootstrap
`.Values.influxdb` is used to configure the data base at boot time. Values for this section can be checked at the [dependency Chart](https://github.com/bitnami/charts/tree/main/bitnami/influxdb).

Relevant for the vanilla implementation are the `.Values.influxdb.auth.admin` values, which contain authorization information as well as the definition of an InfluxDB `bucket`, akin to a database name to which events (i.e., metric values at sample time) will be stored.

### Retrievers
Retrievers are a collection of Python scripts, each with a `requirements.txt` file and a main Python `*.py` script file. The schema of a `retriever` in a `values.yaml` is the following:

```yaml
#####################################
# Proposed YAML schema for retrievers
#####################################
retrievers:
- name: "myRetriever" # must be unique among retrievers
  image: # retriever container image
    name: "python"
    tag: "latest"
  env: # to be inserted into .spec.container.*.env
    - name: MY_EXAMPLE_ENV
      value: MY_EXAMPLE_VALUE
  script: # python script to be executed by the retriever
    name: "example.py"
    secret: # Automatically created Secret with script.name contents
      name: "my-retriever-script"
    mountPath: "/mnt/my-scripts" # mountPath inside retriever container
```

#### Important assumptions to consider before adding a retriever
- Script `SCRIPT_NAME` and `requirements.txt` file for retriever `RETRIEVER_NAME` should be placed under `files/$RETRIEVER_NAME` directory. Mandatory files:
  - `files/$RETRIEVER_NAME/requirements.txt`: details Python dependencies modules and versions.
  - `files/$RETRIEVER_NAME/$SCRIPT_NAME`: a Python script following `*.py` naming convention.
- Each `retriever` container will have the following entrypoint:
  ```bash
    pip install -r files/$RETRIEVER_NAME/requirements.txt;
    /usr/local/bin/python files/$RETRIEVER_NAME/$SCRIPT_NAME;
  ```
- The following are env variables defined for all containers in the `ci-cron.yaml` Pod:
  - `OUTPUTDIR`: Path to retriever directory to dump metrics.
  - Each `retriever` will write metric files (`*.dat`) to the path pointed by such env variable.
  - Internally, the path is different for each retriever, and is suffixed by its name `{{ .Values.outputEnv.value }}/$RETRIEVER_NAME`. This prevents overwriting data, but also forces retriever names to be unique.
- For metrics to be scrapped they must follow the convened schema, that is:
  - Filename should be: `$METRIC_NAME.dat`
  - Contents of file should be `$METRIC_VALUE_AS_FLOAT`
  - We expect to have one of such files per metric to scrape and dump in the data base.

### Metrics sources
You can leverage the `.Values.sources` to create Kubernetes Secrets holding API tokens and other auxiliary info, such as `apiUrl`. Helm creates a Secret for each entry with the following schema:
  ```yaml
  sources:
  - name: "sourceName"
    apiUrl: "https://my-api-endpoint.info/v1"
    token: # 'token' is the key used in secretName to refer to secretValue
      secretName: "my-token-secret-name"
      secretValue: "my-plain-super-secret-token"
  ```
This is not mandatory, but provides a standard way of injecting these particular data to the retrievers,


## Helm Chart Installation
This Helm chart will trigger any source GraphQL APIs if input with the proposed schema. A valid token should be added in `values.yaml` or a secret with it should be created before-hand.

```console
helm install <deployment name> . -n <kubernetes namespace>
```

## Proposed retriever development workflow
To start development of retrievers simply:

1. Write the Python script under `files/$RETRIEVER_NAME/`
2. Write the corresponding `files/$RETRIEVER_NAME/requirements.txt` file with Python dependencies.
3. Fill a `values.yaml` file equivalent at the one shown at the [beginning of this document](#dashboard-architecture)

# Future (ongoing) Work
- Secure Secrets Operations best practices need to be implemented in order to make the injection of TOKENS a secured procedure.