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
- A PostgreSQL from a [dependency Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql). This deploy a StatefulSet and other resources. Refer to the repository for the configuration parameters.
- A CronJob with as many initContainers as configured `.Values.retrievers`. Such retrievers will dump metrics to files, each one mapped to a column in the database. Later, a `db-pusher` container will pickup such files from a shared mount point in the Pod and dump it in the database.

### Database bootstrap
`.Values.postgresql.primary.initdb.scripts` is run at startup. It is used to create the main table for the dashboard and define its columns.

Currently, `db-pusher` is expecting a set of predefined `*.dat` files to be located in the `.Values.outputEnv.value` mount path of the CronJob Pod (each retriever is provided with this path via `{{ .Values.outputEnv.name | upper }}` (e.g., `$OUTPUTDIR`) environment variable). 

Bootstrap the database and ensure the files dumped by `retrievers` are persisted by performing the following:

- Append a column to the table representing the value of a retriever. This is done in `.Values.postgresql.primary.initdb.scripts` at `values.yaml`; for example:
  ```yaml
  # rest of structure is omitted for brevity
  postgresql:
    primary:
      initdb:
        scripts:
          example-table.sql: CREATE TABLE example (time timestamp, values_from_retriever_1 INT, values_from_retriever_2 REAL, values_from_retriever_n REAL);
  ```
  This will create a table called `example` at startup with four columns of a specific type.
- As `retrievers` dump metrics to `$OUTPUTDIR`, save those in a variable and add it the collection to be inserted into the database at `templates/ci-cron.yaml`, specifically at `.spec.jobTemplate.spec.template.spec.containers.0.command`. For example
  ```bash
  # Other entries omitted for brevity
  # ...
  values_from_retriever_n=`cat /mnt/output/retriever-n/value-from-retriever-n.dat`;
  echo "Metrics produced by retriever-n: $values_from_retriever_n";

  echo "#####################";
  echo "Pushing to Database";
  echo "#####################";
  psql $PREVIOUSLY_CONFIGURED_CONNECTION -c "INSERT INTO public.example VALUES (current_timestamp, $values_from_retriever_1, $values_from_retriever_2, $values_from_retriever_n)";
  '
  ```

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