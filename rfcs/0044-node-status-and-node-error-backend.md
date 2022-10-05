## Summary

[summary]: #summary

This RFC proposes that we use Google Cloud Logging service to be the backend of the node status/error system. The logs would be stored in the gcloud buckets; and we could use the Log Explorer to search around logs. Metrics can also be created against the logs. For visualization and graphing, we would use Kibana.

## Motivation

[motivation]:#motivation

We need a backend for node staus/error systems. Candidates for the backend include GCloud Logging, AWS stack and Grafana Loki and LogDNA.

## Implementation

[implementation]:#implementation

### Google Cloud Logging

Google Cloud Loggind provides storage and data searching/visualization of logs. It provides a handy command line sdk tool. But unfortunately there's no official support for ocaml binding. The architecture of the Google Cloud Logging is depicted as following: 

![](res/gcloud_logging.png)

For the frontend, each nodes would have 2 command line options to allow them to sed node status/error reports to any specific url: `--node-status-url URL` and `--node-error-url URL`. By default users would send their reports to our backend. They could change the destination by providing their own destination `URL` to the command options. Those setting could also be changed in the daemon.json file for the corresponding field.

We would setup micro-services under the corresponding subdomain: https://node-status-report.minaprotocol.com and https://node-error-report.minaprotocol.com. The micro-service would be implemented using `Google Functions`. It already has the environment setup for us which is very convenient. Here's the pseudo-code that demonstrates how it would work:
```js
exports.nodeStatus = (req, res) => {
  if (req.body.payload.version != 1) {
      res.status(400);
      res.render('error', {error: "Version Mismatch"});
  } else if (Buffer.byteLength(req.body, 'utf8') > 1000000) {
      res.status(413);
      res.render('error', {error: "Payload Too Large"})
  } else {
      console.log(req.body);
      res.end();
  }
};
```

We would setup an alert that tells us if user's input is over the designated limit (~1mb). This way we could tune the upper bound of the message size later.

For storage of the logs, we can setup customized buckets that can be configured to have 3650 days of log retentions.

For visualization and plotting, logs can be passed to the elastic cloud on GCP through Pub/Sub message sharing. We decided to hold the elastic stack by ourselves on our k8s clusters.

Most of the setup would be capture in a terraform modules, except the management of secret and service accounts since it's not safe to expose those in terraform states.

In summary, we need to setup a micro-service for each corresponding system and we also need to setup separate log buckets and log sinks for them.

## Other choices

[other-choices]: #other-choices

### AWS Stack

The AWS stack provides the log storage and data searching/visualization.

![](res/aws_stack.png)

Like the diagram shown above, we would setup a public Kenesis firehose data stream where the mina client can push to. And this Kenesis data stream would be connected to the S3 bucket, the OpenSearch and Kibana. (Splunk and Redshift are potential  tools that we could utilize but we would not use them in this project.)

We would directly push the status/error reports to AWS Kenesis firehose data stream. There would be no server maintained by us at the backend. When writing this RFC, the frontend of the node status collection service has already been merged (https://github.com/MinaProtocol/mina/blob/compatible/src/lib/node_status_service/node_status_service.ml). In the current implementation we send the report to the url that provided by users through `--node-status-url`. In the new design, what we would do is to let the mina client by default send the report directly to our Kenesis data stream with the help of ocaml-aws library. The user still have the option to send their reports elsewhere through the `--node-status-url`.

In summary, For the AWS stack we need to setup
1 Kenesis firehose data stream to receive the logs, and
1 S3 storage bucket to store the logs, and
1 OpenSearch service that provides the search ability for the logs, and
1 Kibana service that provides the visualization for the data
The communication between different components are through Kenesis data stream, what we need to do is to setup things correctly.

The same setup also applies to the node error system backend.

### Grafana Loki

Grafana Loki functions as basically a log aggregation system for the logs. For log storage, we could choose between different cloud storage backend like S3 or GCS. It uses an agent to send logs to the loki server. This means we need to setup a micro-service that listening on https://node-status.minaprotocol.com and redirect the data to Loki. They provide a query language called LogQL which is similar to the prometheus query language. Another upside of this choice is that it has good integration with Grafana which is already used and loved by us. One thing to notice is that loki is "label" based, if we want to get the most of it, we need to find a good way to label stuff.

### LogDNA

LogDNA provides both data storage and data visualization and alerting functionality. Besides the usual log collecting agent like Loki, LogDNA also provides the option to sends logs directly to their API which could save us the work to implement a micro-service by ourselves (depending on whether we feel safe to give users the log-uploading keys). The alert service they provide is also handy in node error system.

## Prices

0. Elastic Cloud on GCP for 0.0001/Count
1. S3, $0.023 for 1GB/month, would be a little cheaper if we use more than 50GB
2. OpenSearch, Free usage for the first 12 months for 750 hrs per month
3. Loki, depending on the storage we choose. And we need to run the loki instance somewhere. We could choose to use the grafana cloud. But it seems to have 30 days of log retention. The prices $49/month for 100GB of logs. (I think we already use their service, so the log storage is already paid)
4. LogDNA, $3/GB, logs also have 30 days of retention.

## Rationale Behind the choices

### Rationale Behind the micro-service
I personally think that the best option is to setup a micro-service that handles the traffic to our selected backend. The reasons are the following:
1. This decouples the choice of the backend from the mina client. If we ever want to make any change to the backend, we won't need to update the client code.
2. Hiding the choice of backend would also prevent us from exposing any credential files/configs to the users. This is safer.
3. Having a micro-service sitting in the middle would gives us the room to add DOS protection in the future if that's ever needed.
4. Having a micro-service would make the entire thing more decentralized in the sense that @Jason Borseth has talked about. It means that the mina client would always push the reports to any URL they specified (by default to us). This is more uniform than having the mina client to push to a certain backend in the default case or push to a URL if they choose not to send the report to us.
5. The current implementation would just be simple bash script that redirects the reports to the GCloud Logging API, so it's really easy to implement. If we ever need to do any DOS protection, we could switch to a python script or any other languages that have GCloud SDK. This gives us a lot of flexibility for changes and upgrades.
6. Since the traffic on node error/status service won't be high in the recent future, we won't need to worry about the scalability of this micro-service for now. If it ever becomes a problem, we can change this design then. For now, this design should be enough.

### Rationale Behind the Google Cloud Logging
The reason that we choose Google Cloud Logging fo our backend is that
0. Google Cloud Logging meets the requirements of both node status/error system.

1. We have most of service held by Google Cloud Platform. It's already familiar for most of the engineers. This is the main reason that we choose it over AWS stack 

2. For LogDNA, it has a 30 days log retention limit which clearly doesn't suit our needs. Plus, LogDNA is much expensive than the other 2.

3. For Grafana Loki, it features a "label"-indexed log compression system. This would shine if the log that it process has a certain amount of static labels. For our system, this is not the case. Plus that, none of us are familiar with Loki. And finally Grafana's cloud system also has a 30 days' limit on log retention. This limitation implies that if we want to use Loki then we have to set up our own Loki service which adds some more additional maintenance complexity.

## The decision to make our Kibana ingress private
We choose Kibana as our tool to visualize and search through the reports. And we decide to make the Kibana ingress private. The reason is that the reports that users send us contains stack traces that might contains sensitive information that could expose vulnerability to malicious users. So we decided not to make those reports public. But we would create some grafana charts that highlights the stats we collected from those reports.
