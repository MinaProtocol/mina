## Summary

[summary]: #summary

This RFC proposes that we use AWS stack to be the backend of the node status/error system. To be specific by AWS stack, I mean we would use S3 as the storage backend; OpenSearch as the search engine; Kibana as the visualization and charting tool.

## Motivation

[motivation]:#motivation

We need a backend for node staus/error systems. Candidates for the backend include AWS stack and Grafana Loki and LogDNA.

## Implementation

[implementation]:#implementation

![](res/aws_stack.png)

Like the diagram shown above, We would setup a public Kenesis firehose data stream where the mina client can push to. And this Kenesis data stream would be connected to the S3 bucket, the OpenSearch and Kibana. We just won't use the Splunk and Redshift.

We would directly push the status/error reports to AWS Kenesis firehose data stream. There would be no server maintained by us at the backend. When writing this RFC, the frontend of the node status collection service has already been merged (https://github.com/MinaProtocol/mina/blob/compatible/src/lib/node_status_service/node_status_service.ml). In the current implementation we send the report to the url that provided by users through `--node-status-url`. In the new design, what we would do is to let the mina client by default send the report directly to our Kenesis data stream with the help of ocaml-aws library. The user still have the option to send their reports elsewhere through the `--node-status-url`.

In summary, For the AWS stack we need to setup
1 Kenesis firehose data stream to receive the logs, and
1 S3 storage bucket to store the logs, and
1 OpenSearch service that provides the search ability for the logs, and
1 Kibana service that provides the visualization for the data
The communication between different components are through Kenesis data stream, what we need to do is to setup things correctly.

The same setup also applies to the node error system backend.

## Other choices

[other-choices]: #other-choices

### Grafana Loki

Grafana Loki functions as basically a log aggregation system for the logs. For log storage, we could choose between different cloud storage backend like S3 or GCS. It uses an agent to send logs to the loki server. This means we need to setup a micro-service that listening on https://node-status.minaprotocol.com and redirect the data to Loki. They provide a query language called LogQL which is similar to the prometheus query language. Another upside of this choice is that it has good integration with Grafana which is already used and loved by us. One thing to notice is that loki is "label" based, if we want to get the most of it, we need to find a good way to label stuff.

### LogDNA

LogDNA provides both data storage and data visualization and alerting functionality. Besides the usual log collecting agent like Loki, LogDNA also provides the option to sends logs directly to their API which could save us the work to implement a micro-service by ourselves (depending on whether we feel safe to give users the log-uploading keys). The alert service they provide is also handy in node error system.

### Google Cloud Logging

Google Cloud Loggind provides storage and data searching/visualization of logs. It provides a handy command line sdk tool. There's also various libraries for mainstream languages. Since we are already using gcloud logging for our nodes, the integrated `Logs explorer` would be familiar for most of our engineers. It also provides some log-based metrics and alerts. By default the user defined log bucket has a 30-day log retention, but it's configurable. Comparible to the AWS stack, the architecture is a little different. There's no `Kenesis data stream`-equivalent part for gcloud logging. The logs go directly to the Google Cloud Logging API, as illustrated in the following diagram:
![](res/gcloud_logging.png)

To send logs to Cloud Logging API, we have 2 options:
1. Call the RESTful API directly from node.
2. Set up a mini-service under the subdomain https://node-status-report.minaprotocol.com (https://node-error-report.minaprotocol.com for node error report system). The mini-service would just consists of a simple bash/python script that redirects the report to Google Cloud Logging API. This would requires a bit setup but this gives us the flexibility of changing the backend at any time without modify the client.

## Prices

1. S3, $0.023 for 1GB/month, would be a little cheaper if we use more than 50GB
2. OpenSearch, Free usage for the first 12 months for 750 hrs per month
3. Loki, depending on the storage we choose. And we need to run the loki instance somewhere. We could choose to use the grafana cloud. But it seems to have 30 days of log retention. The prices $49/month for 100GB of logs. (I think we already use their service, so the log storage is already paid)
4. LogDNA, $3/GB, logs also have 30 days of retention.

## Rationale Behind our choices

The reason that we choose AWS stack for our backend is that
0. The requirements for the node status collection and node error collection system is that we need a backend that provides the storage of data and an easy way to search and visualize the data. AWS stack fulfills these requirements.

1. AWS stack is robust and easy to use. It has built-in DOS protection. And we have team members who has used the AWS stack before and this means that some of the team members are already familiar with it. And it seems to be the cheapest choice for us.

2. For LogDNA, it has a 30 days log retention limit which clearly doesn't suit our needs. Plus, LogDNA is much expensive than the other 2.

3. For Grafana Loki, it features a "label"-indexed log compression system. This would shine if the log that it process has a certain amount of static labels. For our system, this is not the case. Plus that, none of us are familiar with Loki. And finally Grafana's cloud system also has a 30 days' limit on log retention. This limitation implies that if we want to use Loki then we have to set up our own Loki service which adds some more additional maintenance complexity.

To summary, AWS stack has the functionality of the other two choices and it's the easiest one to maintain and to setup. Plus it's the cheapest.
