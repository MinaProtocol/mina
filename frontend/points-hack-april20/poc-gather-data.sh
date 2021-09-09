#!/bin/bash

BUCKET=gs://points-data-hack-april20

for metric in $(gsutil ls "$BUCKET/32qa"); do
  gsutil cp $metric out/$(basename $metric)
done

