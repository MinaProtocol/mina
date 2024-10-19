#!/bin/bash

HEAD=$1
BASE=$2

set -eou pipefail

git log  --format=%B --merges --first-parent "${BASE}".."${HEAD}" | tr "\n" ';' | sed -r 's/Merge pull request #(\S*)[^;]*;;/PR #\1: /g' | tr ';' "\n"