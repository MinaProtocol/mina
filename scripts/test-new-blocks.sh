#!/bin/bash


SLOT_DURATION=$(coda client status -json | jq .consensus_configuration.slot_duration)

SLOT_DURATION_S=$(($SLOT_DURATION / 1000))

START_BLOCK=$(coda client status -json | jq .blockchain_length)