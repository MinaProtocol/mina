#!/bin/bash

kubectl create -f kube-registry.yaml

kubectl port-forward --namespace kube-system \
$(kubectl get pods -n kube-system | grep kube-registry-v0 | \
awk '{print $1;}') 5000:5000

# Note: maybe on osx?
#ssh -i ~/.docker/machine/machines/default/id_rsa \
#-R 5000:localhost:5000 \
#docker@$(docker-machine ip)

