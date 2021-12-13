## Summary

[summary]: #summary

This RFC proposes that we use AWS stack to be the backend of the node status/error system. To be specific by AWS stack, I mean we would use S3 as the storage backend; OpenSearch as the search engine; Kibana as the visualization and charting tool; we could also setup the miniservice that listening on the minaprotocol/node-status on AWS ES2.

## Motivation

[motivation]:#motivation

We need a backend for node staus/error systems. Candidates for the backend include AWS stack and Grafana Loki and LogDNA.

The motivation for choosing AWS stack as a whole is that
1. The AWS stack is a mature solution for logging storage and search and analysis
2. The integration of different parts are easy to implement and maintein

## Other choices

## Implementation

[implementation]:#implementation

The implementation is mainly to setup a miniservice under a domain like https://minaprotocol.com/node-status-service that would validate the report that sends by the users and maybe setup some kind of dos protection (I need help in this category) and then sends those to the AWS Kenesis stream.

[other-choices]: #other-choices

### Grafana Loki

Grafana Loki functions as basically a datastore for the logs. It uses an agent to send logs to the loki server. This means we need to setup a mini-service similar to the AWS one. They provide a query language called LogQL which is similar to the prometheus query language. Another upside of this choice is that it has good integration with Grafana which is already used and loved by us.

### LogDNA

LogDNA provides both data storage and data visualization and alerting functionality. Besides the usual log collecting agent like Loki, LogDNA also provides the option to sends logs directly to their API which could save us the work to implement a miniservice by ourselves. The alert service they provide is also handy in node error system.
