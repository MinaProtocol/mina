#!/bin/bash

set -e

trap 'kill $(jobs -p)' EXIT

cp /app/lib/mnt_cycle_search_testbridge/search.py /app-lib/ecfactory/ecfactory/mnt_cycles/search.py

cd /app-lib/ecfactory

/bin/bash -c "source ~/.profile && nix-shell /app/sage.nix --command 'sage ecfactory/mnt_cycles/search.py'" < /dev/stdin

