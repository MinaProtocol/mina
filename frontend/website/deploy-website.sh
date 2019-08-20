#!/bin/bash

set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <staging | prod | ci>"
  exit 1
fi

if [ -f ".bsb.lock" ]; then
  echo ".bsb.lock file exists, this usually means you're running 'yarn dev'."
  echo "It's dangerous to deploy while running a dev server."
  echo "If you're VERY sure, you can delete .bsb.lock and rerun the deploy."
  exit 1
fi

rm -rf deploy
mkdir -p deploy

echo "*** Building"

yarn clean && yarn build $1
yarn graphql-docs


# Deploy cdn if prod
# ==================

if [[ "$1" == "prod" ]]; then
  echo "Deploying to prod involves refreshing cdn assets."
  read -p "This costs \$\$, are you sure? [y/N]" -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Canceled deployment"
    exit 1
  fi
  BUCKET="s3://website-codaprotocol/website"
  echo "*** Deploying to $BUCKET"
  mkdir -p deploy/cdn
  cp -r site/static deploy/cdn/static
  pushd deploy/cdn > /dev/null
  aws s3 sync . "$BUCKET"
  popd > /dev/null
fi

# Deploy firebase
# ===============

# first copy the full site
cp -r site deploy/website


CI=no
if [[ "$1" == "staging" ]]; then
  TARGET=proof-of-steak-7ab54
elif [[ "$1" == "ci" ]]; then
  TARGET=coda-staging-84430
  CI=yes
elif [[ "$1" == "prod" ]]; then
  TARGET=coda-203520

  # remove cdn assets and move
  # main.bc.js and verifier_main.bc.js to static
  rm -rf deploy/website/static
  mkdir -p deploy/website/static
  cp static/main.bc.js deploy/website/static
  cp static/verifier_main.bc.js deploy/website/static
else
  echo "Target must be one of: staging, prod, ci"
  exit 1
fi

if [[ "$CI" = "no" ]]; then
  read -p "You are deploying to $1 ($TARGET). ARE YOU SURE? [y/N]" -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Canceled deployment"
    exit 1
  fi
fi

echo "*** Deploying to $1"

if [[ "$CI" == "yes" ]]; then
  if [[ -z "$FIREBASE_TOKEN" || "$FIREBASE_TOKEN" == "" ]]; then
    echo "Skipping deployment as you don't have the creds to see our token!"
  else
    npx firebase-tools --token "$FIREBASE_TOKEN" --project $TARGET deploy
  fi
else
  npx firebase-tools --project $TARGET deploy
fi

