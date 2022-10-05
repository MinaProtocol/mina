#!/bin/bash

set -e

namespace=$1
logproc=$2
log=$3

[ -n "$namespace" ] || (echo 'Missing argument 1, namespace' && exit 1)
[ -n "$logproc" ] || (echo 'Missing argument 2, logproc' && exit 1)
[ -n "$log" ] || (echo 'Missing argument 3, log directory' && exit 1)

get_logs() {
  namespace=$1
  logproc=$2
  log=$3
  pod=$4
  file=$log/$pod.log
  lines=$(kubectl logs $pod -n $namespace 2>/dev/null)
  result=$?
  if [ $result == 1 ]; then
    lines=$(kubectl logs $pod -n $namespace -c coda)
  fi
  echo "$lines" | grep '^{' | $logproc -f ".level == \"Fatal\""
  #echo "$lines" > $file # | grep '^{' | $logproc -f ".level == \"Fatal\"" > $file
  if [ ! -s $file ]; then
    rm $file
  fi
}
export -f get_logs

kubectl -n $namespace get pods \
  | grep -v NAME \
  | cut -d' ' -f1 \
  | parallel -j 1 get_logs $namespace $logproc $log '{}'
