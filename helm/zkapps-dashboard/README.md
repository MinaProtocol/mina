<a href="https://minaprotocol.com">
	<img width="200" src="https://github.com/MinaProtocol/docs/blob/main/public/static/img/svg/mina-wordmark-redviolet.svg?raw=true&sanitize=true" alt="Mina Logo" />
</a>
<hr/>

<br />

# Mina zkApps Dashboard

<br />

- [Dashboard Architecture](#dashboard-architecture)
- [Helm Chart Installation](#helm-chart-installation)
    - [Optional Configuration](#optional-configuration)
- [Updating zkApp Queries](#updating-zkapps-queries)
- [Connecting to Grafana](#connecting-to-grafana)
- [Future Work](#future-work)

<br />

---

## Dashboard Architecture

<br />

The Mina zkApps dashboad is an auxiliary database that queries a Mina Archive DB on a schedule before saving the returned query results locally.
This Helm chart installs the Mina protocol zkapps dashboard including the following components:

- zkApp dashboard database (Postgresql)
- Persistent storage volumes (PVC)
- Scheduled zkapp archive node queries (Cron Job)
- Kubernetes load balancer

The chart also has a dependency on the Bitnami/postgresql Helm chart. Bitnami postgres configuration parameters are [here](https://github.com/bitnami/charts/tree/main/bitnami/postgresql). A top-level diagram of the zkApps dashboard architecture and the data sources it connects to is shown below:

<br />

<img src="_img/architecture.svg" alt="zkApps dashboard architecture">

## Helm Chart Installation

<br />

This Helm chart can be installed manually using Helm, or bundled as part of a network deployment using Terraform. By default, the chart has password values set to `null`, so both `postgresql.primary.initdb.password` and `postgresql.auth.password` are required values that must be set at the time of deployment. The following command is an example of installing this Helm chart using a local copy of the repository source:

<br />

```console
helm install <deployment name> . -n <kubernetes namespace> \
    --set postgresql.primary.initdb.password=< secret password > \
    --set postgresql.auth.password=< secret password >
```

<br />

<img width="30" src="_img/light_bulb.svg" alt="light bulb">

**NOTE: Ensure that values passed using the `--set` option do not end in a special character. Terminating with a special character will cause errors during yaml parsing**

<br />

### Optional Configuration

<br />

The following table lists the configurable parameters of the `zkapps-dashboard` chart and its default values. These values are set within the `values.yaml` file within the helm chart.

<br />

Parameter | Description | Default
--- | --- | ---
`postgresql.primary.name` | name assigned to backend database used by the zkApps dashboard | `dashboard-db`
`postgresql.primary.service.type` | network connection used to expose the zkApps dashboard | `LoadBalancer`
`postgresql.primary.persistence.enabled` | enable or disable persistent storage | `true`
`postgresql.primary.persistence.size` | storage disk size | `100Gi`
`postgresql.primary.persistence.storageClass` | storage disk type | `ssd-delete`, `local-path`
`postgresql.primary.initdb.user` | default database user | `mina`
`postgresql.primary.initdb.password` | default database password | `null`
`postgresql.primary.initdb.scripts` | script to initialize the zkApp dashboard database table | `zkapp-table.sql : CREATE TABLE zkapps (time timestamp, unique_zkapps INT, total_zkapps INT, successful_txns INT, failed_txns INT, total_txns INT, successful_payments INT, failed_payments INT, total_payments INT, total_acct_updates INT);`
`postgresql.auth.username` | zkApps dashboard database user | `mina`
`postgresql.auth.password` | zkApps dashboard database password | `null`
`postgresql.auth.database` | the database which allows access for the zkApps database user | `dashboard-db`
`postgresql.auth.enablePostgresUser` | enable or disable default postgresql user | `false`
`nodeSelector.preemptible` | enable or disable the use of preemptible servers | `false`
`archive.name` | name of Mina archive node which the zkApps dashboard queries | `archive-1`
`archive.database` | name of the Mina archive node database | `archive`
`archive.auth.username` | username used to authenticate with the Mina archive node | `mina`
`archive.auth.password` | password used to authenticate with the Mina archive node | `zo3moong7moog4Iep7eNgo3iecaesahH`

<br />

## Updating zkApps Queries

<br />

Within this helm package, the `db-cron.yaml` holds the queries that are run. Queries can be added, removed, or updated by editing this file. At a high-level, all queries are done in two parts; the first part is the recursive query of the current chain state shown below:

<br />

```
RECURSIVE_CHAIN="WITH RECURSIVE chain AS (
SELECT id,state_hash,parent_id,parent_hash,creator_id,block_winner_id,snarked_ledger_hash_id,
staking_epoch_data_id,next_epoch_data_id,
min_window_density,total_currency,
ledger_hash,height,global_slot_since_hard_fork,global_slot_since_genesis,
timestamp,chain_status
FROM blocks b WHERE b.id =(select id from blocks where height = (select MAX(height) from blocks) LIMIT 1)
UNION ALL
SELECT b.id,b.state_hash,b.parent_id,b.parent_hash,b.creator_id,b.block_winner_id,b.snarked_ledger_hash_id,
b.staking_epoch_data_id,b.next_epoch_data_id,
b.min_window_density,b.total_currency,
b.ledger_hash,b.height,b.global_slot_since_hard_fork,b.global_slot_since_genesis,
b.timestamp,b.chain_status
FROM blocks b
INNER JOIN chain
ON b.id = chain.parent_id AND (chain.id <> 1 OR b.id = 1)
)";
```

<br />

<img width="30" src="_img/light_bulb.svg" alt="light bulb">

**Note that all queries run by the zkApps dashboard have a dependency on this recursive chain result that is returned. If the chain query returns bad data, or an incorrect value due to missing blocks within the Mina Archive DB, this will also be seen in query results.**

<br />

The second part is a query of the recursive chain that was previous returned. An example query excerpted from `db-cron.yaml` is shown below:

<br />

```
TOTAL_PAYMENTS_QUERY="select count(*) from chain b left join blocks_user_commands bc on b.id = bc.block_id where bc.user_command_id is not null ;";
```

<br />

Again note that the above `TOTAL_PAYMENTS_QUERY` references table data coming from the recursive chain query. If data for an intended query is not existing in the recursive query, or if the Mina Archive database schema is changed, the root recursive chain query used here may also need to be updated.

<br />

## Connecting to Grafana

<br />

The final destination of zkApp query data is typically a [Mina zkApp Metrics](https://o1testnet.grafana.net/d/W9_ZpVoVk/zkapp-metrics?orgId=1&var-testnet=zkapps-berkeley-v2) Grafana dashboard. Once the `zkapps-dashboard` Helm chart has been installed to Kubernetes, it must be added as a "datasource" within Grafana before it can be queried and displayed within the dashboard. [Instructions for adding a new postgresql database to Grafana can be found here](https://grafana.com/docs/grafana/latest/datasources/postgres/). Note that Admin permissions are required to modify Grafana data sources. 

When adding the new postgres datasource, as long as "zkapps" is included within the source name, it will be detected and become available as a dropdown choice within the existing [Mina zkApps Metrics](https://o1testnet.grafana.net/d/W9_ZpVoVk/zkapp-metrics?orgId=1&var-testnet=zkapps-berkeley-v2) dashboard. The recommended convention for naming zkApps dashboard datasources is: `<zkapps>-<network name here>`. For example: `zkapps-mainnet` or `zkapps-berkeley`.

<br />

## Future Work

<br />

The current iteration of the zkApps dashboard employs basic password security. It is possible to enable SSL encryption, certificate authentication, or further security as part of future work.

<br />
