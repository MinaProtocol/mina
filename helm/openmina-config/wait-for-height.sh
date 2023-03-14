#!/usr/bin/env sh

set -xe

MINA_RESOURCE=$1
TARGET_HEIGHT=$2

# 120 times, 10s pause = 20min, should be enough to get to height 10
for _ in $(seq 120); do
    HEIGHT=$(kubectl exec ${MINA_RESOURCE} -c mina -- mina client status | grep "Block height" | cut -d ":" -f 2)
    if [ -n "${HEIGHT}" ]; then
        if [ "${HEIGHT}" -ge "${TARGET_HEIGHT}" ]; then
            echo "node1 reached height ${TARGET_HEIGHT}"
            exit
        else
            echo "node1 still at height ${HEIGHT}"
        fi
    fi
    sleep 10
done
