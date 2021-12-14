## Summary

[summary]: #summary

This RFC proposes that we use AWS stack to be the backend of the node status/error system. To be specific by AWS stack, I mean we would use S3 as the storage backend; OpenSearch as the search engine; Kibana as the visualization and charting tool; we could also setup the miniservice that listening on the minaprotocol/node-status on AWS ES2.

## Motivation

[motivation]:#motivation

We need a backend for node staus/error systems. Candidates for the backend include AWS stack and Grafana Loki and LogDNA.

## Implementation

[implementation]:#implementation

The implementation is mainly to setup a miniservice under a domain like https://minaprotocol.com/node-status-service that would validate the report that sends by the users and maybe setup some kind of DOS protection (help would be need to design and implement in this category) and then sends those to the AWS Kenesis stream.

## Other choices

[other-choices]: #other-choices

### Grafana Loki

Grafana Loki functions as basically a log aggregation system for the logs. For log storage, we could choose between different cloud storage backend like S3 or GCS. It uses an agent to send logs to the loki server. This means we need to setup a mini-service similar to the AWS one. They provide a query language called LogQL which is similar to the prometheus query language. Another upside of this choice is that it has good integration with Grafana which is already used and loved by us. One thing to notice is that loki is "label" based, if we want to get the most of it, we need to find a good way to label stuff.

### LogDNA

LogDNA provides both data storage and data visualization and alerting functionality. Besides the usual log collecting agent like Loki, LogDNA also provides the option to sends logs directly to their API which could save us the work to implement a miniservice by ourselves (depending on whether we feel safe to give users the log-uploading keys). The alert service they provide is also handy in node error system.

## Prices

1. S3, $0.023 for 1GB/month, would be a little cheaper if we use more than 50GB
2. OpenSearch, Free usage for the first 12 months for 750 hrs per month
3. Loki, depending on the storage we choose. And we need to run the loki instance somewhere. We could choose to use the grafana cloud. But it seems to have 30 days of log retention. The prices $49/month for 100GB of logs. (I think we already use their service, so the log storage is already paid)
4. LogDNA, $3/GB, logs also have 30 days of retention.
