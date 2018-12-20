#!/bin/bash
echo "$1" | jq '.timestamp'

format() {
  echo "$(echo "$1" | jq -r "\"[\(.timestamp)]\(.level[0]):\(.path[0])$ \(.message)\"")"
}

while read line
do
  format "$line"
done < "${1:-/dev/stdin}"
