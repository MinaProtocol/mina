#!/bin/bash

i=1
status=0

error() {
  echo "Error [$i]: $1"
  status=1
}

while read line; do
  if [[ $line =~ ^\ *$ ]] || [[ $line =~ ^\# ]]; then
    continue
  fi

  if [[ $line =~ ^[^\#]*\# ]]; then
    error 'invalid comment ("#" must appear at the beginning of a line)'
  fi

  target=$(echo $line | cut -d' ' -f1)
  mentions=$(echo $line | cut -d' ' -f2-)

  if [[ $target =~ \* ]]; then
    error 'wildcard targets are not allowed (for now)'
  fi

  if ! [[ -e ${target#/} ]]; then
    error "target $target does not exist"
  fi

  for mention in $mentions; do
    if ! [[ $mention =~ ^@ ]]; then
      error "invalid mention format ($mention)"
    fi
  done

  i=$(( i + 1 ))
done < CODEOWNERS

exit $status
