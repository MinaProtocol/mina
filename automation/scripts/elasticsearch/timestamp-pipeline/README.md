# Why?

This is an ingest pipeline for Coda daemon logs. Elasticsearch expects a timestamp to be in the @timestamp field, and by default FileBeat saves the index-time of the logs in that field. FileBeat needs to be configured to use this ingest pipeline when forwarding logs to Elasticsearch. 

# How? 

To upload this pipeline, run the `upload-pipeline.sh` script. It needs to be uploaded @ creation time of the elasticsearch instance. 

# Docs and Things



## Configuring Filebeat

- https://www.elastic.co/guide/en/beats/filebeat/master/configuring-ingest-node.html


## Ingest Pipeline Links
- https://www.elastic.co/guide/en/elasticsearch/reference/current/pipeline.html
- https://www.elastic.co/guide/en/elasticsearch/reference/master/date-processor.html
- https://www.elastic.co/guide/en/elasticsearch/reference/master/put-pipeline-api.html
- https://www.elastic.co/guide/en/elasticsearch/reference/master/ingest.html
- https://discuss.elastic.co/t/get-timestamp-from-log-lines/117816