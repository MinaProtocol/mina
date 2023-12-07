#!/usr/bin/env python3

import influxdb_client, os, time
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS

# InfluxDB credentials and details
token = os.environ.get('INFLUXDB_TOKEN', '')
org = "o1-labs"
url = os.environ.get('INFLUXDB_URL', 'http://34.118.176.35:8086')
bucket = os.environ.get('INFLUXDB_BUCKET', "dashboard-db")

files = os.environ.get('outputdir','/mnt/output')
filesSuffix = os.environ.get('INFLUXDB_FILES_SUFFIX', '.dat')

write_client = influxdb_client.InfluxDBClient(url=url, token=token, org=org)
write_api = write_client.write_api(write_options=SYNCHRONOUS)
query_api = write_client.query_api()

points = []
for folder in os.listdir(files):
  print(f"\nPushing retriever: {folder}")
  folderPath = os.path.join(files, folder)
  if os.path.isdir(folderPath):
    for file in os.listdir(folderPath):
      if file.endswith(filesSuffix):
        metricName = os.path.splitext(file)[0]
        print(f"\t-Metric: {metricName}")
        with open(f"{folderPath}/{file}", 'r') as data_file:
          data = data_file.read().strip()
          points.append(
            Point("measurementFile")
            .tag(key="metric", value=metricName)
            .tag(key="retriever", value=folder)
            .field("data", data)
          )
write_api.write(bucket=bucket, org=org, record=points)

print(f"\nRetrieving recent written data:")
print(f"==================================")
query = f"""from(bucket: "{bucket}")
 |> range(start: -10m)
 |> filter(fn: (r) => r._measurement == "measurementFile")"""
tables = query_api.query(query, org=org)

for table in tables:
  for record in table.records:
    print(record)
