#!/bin/bash

kubectl get services | awk '{ print $1 }' | while read line; do
  kubectl delete services ${line} &
done

kubectl get deployments | awk '{ print $1 }' | while read line; do
  kubectl delete deployments ${line} &
done
