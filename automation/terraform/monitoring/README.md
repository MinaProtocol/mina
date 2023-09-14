<p><img src="https://storage.googleapis.com/coda-charts/Mina_Icon_Secondary_RGB_Black.png" alt="Mina logo" title="mina" align="left" height="60" /></p>

# Testnet Monitoring & Alerting :fire_engine: Guide

**Table of Contents**
- [Updating Testnet Alerts](#update-testnet-alerts)
    - [Developing alert expressions](#developling)
    - [Testing](#testing)
    - [Deployment](#deployment)
- [Alert Status](#alert-status)
    - [GrafanaCloud Config](#grafancloud-config)
    - [Alertmanager UI](#alertmanager-ui)
    - [PagerDuty](#pagerduty)
- [HowTo](#howto)
    - [Silence Alerts](#silence-alerts)
    - [Update Alert Receivers](#update-alert-receivers)
    - [View Alert Metrics](#view-alert-metrics)

## Updating Testnet Alerts

#### Developing alert expressions

You can develop alert expressions for devising metric and alerting conditions and rules. Use the Prometheus domain-specific [query language](https://prometheus.io/docs/prometheus/latest/querying/basics/) ([examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)) and follow the alert rules specification [format](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/).

To enable variability when defining these rules, implement each rule set or group by using the *terraform* [template_file](https://registry.terraform.io/providers/hashicorp/template/latest/docs/data-sources/file) and `(${ ... })` templating mechanisms for including variable substitution where appropriate. (**Note:** Variable substitutions are *optional* and provided as defaults. You can completely define alert rules according to a custom specification).

You must edit the `testnet-alert-rules.yml.tpl` file when you add rules to be applied to all testnets. A standard set of such testnet alert rules based on templates is defined in the [testnet-alert-rules.yml.tpl](https://github.com/MinaProtocol/mina/blob/develop/automation/terraform/modules/testnet-alerts/templates/testnet-alert-rules.yml.tpl#L6) file. 

Generally, when adding or updating alerts:
1. Consult [Grafanacloud's Prometheus Explorer](https://o1testnet.grafana.net/explore?orgId=1&left=%5B%22now-1h%22,%22now%22,%22grafanacloud-o1testnet-prom%22,%7B%7D%5D) to ensure the metric to alert on is collected by infrastructure's Prometheus instances. If missing, reach out on the Mina Protocol Discord in the [#reliability-engineering](https://discord.com/channels/484437221055922177/610580493859160072) channel for help on getting the alert added.
1. Apply alerting changes to *testnet-alert-rules.yml.tpl* based on the Prometheus query language and alerting rules config.

#### Testing

Testing of testnet alerts involves leveraging Grafana's [cortex-tools](https://github.com/grafana/cortex-tools), a toolset developed and maintained by the Grafana community for managing Prometheus/Alertmanager alerting configurations. Specifically, the testing process makes use of `lint` and `check` for ensuring alerting rules defined in *testnet-alert-rules.yml* are syntactically correct and also meet best practices and standards for maintaining consistency in how rules are expressed and formatted. Both operations can be executed automatically in CI or manually within a developer's local environment.

**Note:** You must run all manual steps from the [automation monitoring](https://github.com/MinaProtocol/mina/tree/develop/automation/terraform/monitoring) directory within the *mina* repo. A copy of the rendered rules configuration will be placed in this directory for reference when testing locally.

##### Linting

[lints](https://github.com/grafana/cortex-tools#rules-lint) a testnet alert rules file. The linter verifies YAML and PromQL expression formatting within the rule file but does not verify correctness.

###### automation

Executed by CI's *Lint/TestnetAlerts* [job](https://github.com/MinaProtocol/mina/blob/develop/buildkite/src/Jobs/Lint/TestnetAlerts.dhall) when a change is detected to the testnet-alerts template file.

###### manual steps

```
    terraform apply -target module.o1testnet_alerts.null_resource.alert_rules_lint
``` 

##### Check alerts against recommended [best practices](https://prometheus.io/docs/practices/rules/)

###### automation

Executed by CI's *Lint/TestnetAlerts* [job](https://github.com/MinaProtocol/mina/blob/develop/buildkite/src/Jobs/Lint/TestnetAlerts.dhall) when a change is detected to the testnet-alerts template file.

###### manual steps

```
    terraform apply -target module.o1testnet_alerts.null_resource.alert_rules_check
```

#### Deployment

Deploying testnet alert rules entails syncing the rendered configuration in source with the Prometheus instance rules config found [here](https://o1testnet.grafana.net/a/grafana-alerting-ui-app/?tab=rules&rulessource=grafanacloud-o1testnet-prom). Appropriate AWS access is necessary for authenticating with Grafanacloud and must be similar to, if not the same, as those used for deploying testnets.

###### automation

Executed by CI's *Release/TestnetAlerts* [job](https://github.com/MinaProtocol/mina/blob/develop/buildkite/src/Jobs/Release/TestnetAlerts.dhall) when a change is detected to the testnet-alerts template file and linting/checking of alerts has succeeded.

###### manual steps

```
    terraform apply -target module.o1testnet_alerts.docker_container.sync_alert_rules
```

**Note:** Operation will sync provisioned alerts with an exact match of alert file state (e.g. alerts removed from the alert file will be unprovisioned on Grafanacloud)

**Warning:** Unfortunately, Terraform silences errors that cortext-tool is producing, for example when syncing rules. To debug sync rules, follow these steps:
    - Obtain secrets (id,address,key) from AWS secret manager 
    - Run the previous terraform command once again
    - Run the following command in automation/terraform/monitoring folder: 

```
    ~/.local/bin/cortextool rules sync --rule-files alert_rules.yml --id ... --address ... --key ... 
```

## Alert Status

#### GrafanaCloud Config

To view the current testnet alerting rules config or verify that changes were applied correctly following a deployment, visit this Grafanacloud rules config [site](https://o1testnet.grafana.net/alerting/list?search=datasource:grafanacloud-o1testnet-prom).

**Note:** Ensure the datasource is set to `grafanacloud-o1testnet-prom` to access the appropriate ruleset. 

#### Alertmanager UI

You can also view alerting rule violations in the Grafanacloud Alertmanager [UI](https://alertmanager-us-central1.grafana.net/alertmanager/#/alerts). This site provides an overview of all violating rule conditions in addition to rules that have been silenced.

#### PagerDuty

PagerDuty is O(1) Lab's primary alert receiver and is configured with a single [service](https://o1labs.pagerduty.com/service-directory/PY2JUNP) for monitoring Mina testnet deployments. This service receives alert notifications requiring attention from the development team to assist in repairing issues and restoring network health.

For more information, reach out to [#reliability-engineering](https://discord.com/channels/484437221055922177/610580493859160072) on Mina's Discord channel with questions etc.

## HowTo

#### Silence Alerts

* Alertmanager alert silencing: You create new alert silences using either the [Alertmanager](https://alertmanager-us-central1.grafana.net/alertmanager/#/silences/new) or the [Grafanacloud](https://o1testnet.grafana.net/a/grafana-alerting-ui-app/?tab=silences&alertmanager=grafanacloud-o1testnet-alertmanager) UI.
* PagerDuty alert suppression: See the PagerDuty [Event Management](https://support.pagerduty.com/docs/event-management#suppressing-alerts) guide.

##### Creating new silences

When creating new alert silences (from the preceding links or otherwise), you'll likely want to make use of the Alertmanager `Matchers` construct that basically consists of a set of key-value pairs used to target the alert to silence. For example, to silence the "LowFillRate" alert currently firing for testnet *devnet*:
 Create a new silence with individual `Matchers` for the alert name and testnet like the following:

###### Matchers example

| Name | Value|
| ------------- | ------------- |
| testnet  | devnet  | 
| alertname  | LowFillRate  |

![Grafanacloud New Silence](https://storage.googleapis.com/shared-artifacts/grafanacloud-new-silence-example.png)

Note the `Start`, `Duration`, and `End` inputs in the UI. Typically, only the duration of a silence is updated although Alertmanager supports the specification of start and end times based on internet timing standards [RFC3339](https://xml2rfc.tools.ietf.org/public/rfc/html/rfc3339.html#anchor14).

**Be sure to set the *Creator* and *Comments* field accordingly to provide insight into the reasoning for the silence and guidelines for following up.**

#### Update Alert Receivers

Alert receivers are reporting endpoints for messaging alert rules that are in violation, like *PagerDuty* pages, *incident* emails, SMS messages, or Discord notifications. You can find a list of available receivers and their associated configuration documentation in the [Prometheus Alertmanager configuration](https://prometheus.io/docs/alerting/latest/configuration/) documentation. 

Configure all receivers in an *Alertmanager* service receivers config to set a series of alerting routes based on `match` and `match_re` (regular expression) qualifiers that are applied to incoming rule violations received by the service. Both PagerDuty and Discord webhook receivers are set up to receive these rule violations and forward them to their appropriate destinations and are configured in the [testnet-alert-receivers.yml.tpl](https://github.com/MinaProtocol/mina/blob/develop/automation/terraform/modules/testnet-alerts/templates/testnet-alert-receivers.yml.tpl) file.

Updates to testnet alert receivers typically involve 1 or more of the following tasks:
* modify which testnets trigger Pagerduty incidents when alert rule violations occur
* modify which testnets are included within the monitoring and alerting system (e.g. to exclude testnets launched by CI)
* update the Testnet PagerDuty service integration key
* update the Discord webhook integration key

##### Modify testnets which alert to PagerDuty

The list of testnets that trigger PagerDuty incidents when rule violations occur is controlled by a single regular expression defined in the [o1-testnet-alerts](https://github.com/MinaProtocol/mina/blob/develop/automation/terraform/monitoring/o1-testnet-alerts.tf#L17) Terraform module config. 

You can modify this value to any regex for capturing testnets by name, although the value is generally a relatively simple expression (e.g. `"mainnet|qanet|release-net"`) considering the critical nature of the setting and allowing easy identification of which testnets the developers will be paged about.

##### Modify monitored testnets

Like the list of testnets that trigger PagerDuty incidents, the list of testnets monitored is also controlled by a single regular expression defined in the [o1-testnet-alerts](https://github.com/MinaProtocol/mina/blob/develop/automation/terraform/monitoring/o1-testnet-alerts.tf#L15) terraform module config. This setting must always be a superset of the testnets alerting to PagerDuty since it manages all testnets to be included in the monitoring and alerting pipeline and both operationally and technically must be as expressive as visibility calls for.

##### Update Pagerduty Testnet Service Integration Key 

For assistance, reach out to the [#reliability-engineering](https://discord.com/channels/484437221055922177/610580493859160072) channel in Mina Protocol Discord.

##### Update Discord webhook integration key 

For assistance, reach out to the [#reliability-engineering](https://discord.com/channels/484437221055922177/610580493859160072) channel in Mina Protocol Discord.

#### Deploy Alert Receiver Updates

To view the current alerting receiver configuration or verify changes following a deployment, visit O(1) Lab's Grafanacloud alertmanager receiver [configuration](https://o1testnet.grafana.net/a/grafana-alerting-ui-app/?tab=config&alertmanager=grafanacloud-o1testnet-alertmanager).

##### Steps

On the command line, run the following command from the [automation monitoring](https://github.com/MinaProtocol/mina/tree/develop/automation/terraform/monitoring) directory:

```
    terraform apply -target module.o1testnet_alerts.docker_container.update_alert_receivers
``` 

#### View Alert Metrics

When responding to a PagerDuty incident, you'll likely want to check the Alert's *Annotations:Source* for visualizing the metrics series responsible for the firing alert. This information is contained within each incident page under the `ALERTS : CUSTOM DETAILS` section in the form of a URL which links to Grafancloud's Prometheus explorer.

![PagerDuty Incident Annotations](https://storage.googleapis.com/shared-artifacts/pagerduty-incident-annotations.png)

From here, it's possible to explore the values of the offending metric (along with others) over time for investigating incidents.

![PagerDuty Incident Metric Explorer](https://storage.googleapis.com/shared-artifacts/grafanacloud-incident-metric-explorer.png)
