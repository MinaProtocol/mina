#!/bin/bash

status=0
rfc_ids=$(ls rfcs/*.md | cut -d/ -f2 | cut -d- -f1 | sort -n)
expected_id=0

error() {
  echo "invalid id \"$1\": $2"
  status=1
}

fatal_error() {
  error "$@"
  exit $status
}

for padded_id in $rfc_ids; do
  if [ "${#padded_id}" -ne 4 ]; then
    error "$padded_id" 'is not 4 characters long'
  fi

  if [ "$padded_id" -eq 0000 ]; then
    id=0
  else
    id="${padded_id#"${padded_id%%[!0]*}"}"
  fi

  if [ "$id" -ne "$expected_id" ]; then
    if [ "$id" -le "$expected_id" ]; then
      error "$padded_id" 'is a duplicate'
    else
      error "$padded_id" "does not follow expected sequence; expected $expected_id"
      expected_id="$id"
    fi
  else
    expected_id=$(($expected_id + 1))
  fi
done

exit $status
