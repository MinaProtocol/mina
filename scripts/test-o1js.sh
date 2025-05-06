#!/usr/bin/env bash
set -Eu

gh workflow run checks.yml -R o1-labs/o1js -F mina_commit="$(git rev-parse HEAD)" --ref brian/mina-test
# TODO remove --ref once merged and
# Same from RUN_ID command

RUN_ID=$(gh run list \
      -R o1-labs/o1js \
      --workflow=checks.yml \
      --branch=brian/mina-test \
      --event workflow_dispatch \
      --limit 1 \
      --json databaseId \
      -q '.[0].databaseId'
    )

gh run watch -R o1-labs/o1js "$RUN_ID" --exit-status
