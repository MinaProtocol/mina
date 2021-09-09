#!/bin/bash
set -euo pipefail

# Needed to check variables
set +u

cd frontend/wallet

BUCKET=wallet.o1test.net
VERSION=$(cat package.json | jq -r .version)
NAME=$(cat package.json | jq -r .build.productName)

# check for AWS Creds
if [ -z "$AWS_ACCESS_KEY_ID" ]; then
  echo "WARNING: AWS_ACCESS_KEY_ID not set, publish commands not run"
  exit 0
else
  aws s3 cp "dist/$NAME-$VERSION.dmg" s3://$BUCKET/branch/$CIRCLE_BRANCH/wallet.dmg
fi
