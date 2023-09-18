#!/usr/bin/env sh

URL=http://1.k8.openmina.com
JSONPATH="{range .items[*]}[{.metadata.name}]($URL:{.metadata.annotations['openmina\.com/testnet\.nodePort']}): {.metadata.annotations['openmina\.com/testnet\.description']}{'\n'}{end}"
kubectl get namespaces -l "openmina.com/kind=testnet" --output=jsonpath="$JSONPATH"
