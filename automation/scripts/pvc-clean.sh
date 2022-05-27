#!/bin/bash

for disk in $(gcloud compute disks list | awk 'NR>1 {print $1}'); do
  zone=$(gcloud compute disks list | grep $disk | awk '{print $2}')
  in_use=$(gcloud compute disks describe $disk --zone $zone | grep users)
  if [ -z "$in_use" ]; then
    echo "disk:" $disk "is not in use"
    #gcloud compute disks delete $disk --zone $zone -q
  fi
done