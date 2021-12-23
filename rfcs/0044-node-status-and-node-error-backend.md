## Summary

[summary]: #summary

This RFC proposes that we use AWS stack to be the backend of the node status/error system. To be specific by AWS stack, I mean we would use S3 as the storage backend; OpenSearch as the search engine; Kibana as the visualization and charting tool; we could also setup the miniservice that listening on the minaprotocol/node-status on AWS ES2.

## Motivation

[motivation]:#motivation

We need a backend for node staus/error systems. Candidates for the backend include AWS stack and Grafana Loki and LogDNA.

## Implementation

[implementation]:#implementation

Users would send their node status report to https://node-status.minaprotocol.com. Then a bash script would redirect the user input to AWS Kenesis firehose by using the AWS cli tool. And this script would be put in an AWS EC2 container to make the configuration minimal.

For the AWS stack we need to setup
1 Kenesis firehose data stream to receive the logs, and
1 S3 storage bucket to store the logs, and
1 OpenSearch service that provides the search ability for the logs, and
1 Kibana service that provides the visualization for the data

The same setup also applies to the node error system backend.

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

## Rationale Behind our choices

The reason that we choose AWS stack for our backend is that
0. The requirements for the node status collection and node error collection system is that we need a backend that provides the storage of data and an easy way to search and visualize the data. AWS stack fulfills these requirements.

1. AWS stack is robust and easy to use. It has built-in DOS protection. And we have team members who has used the AWS stack before and this means that some of the team members are already familiar with it. And it seems to be the cheapest choice for us.

2. For LogDNA, it has a 30 days log retention limit which clearly doesn't suit our needs. Plus, LogDNA is much expensive than the other 2.

3. For Grafana Loki, it features a "label"-indexed log compression system. This would shine if the log that it process has a certain amount of static labels. For our system, this is not the case. Plus that, none of us are familiar with Loki. And finally Grafana's cloud system also has a 30 days' limit on log retention. This limitation implies that if we want to use Loki then we have to set up our own Loki service which adds some more additional maintenance complexity.

To summary, AWS stack has the functionality of the other two choices and it's the easiest one to maintain and to setup. Plus it's the cheapest.
