#!/bin/bash

set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <staging | prod | ci>"
  exit 1
fi


rm -rf lib/website
mkdir -p lib/website

echo "*** Building"

npm run build && node lib/js/src/Render.js prod

# first copy the full site
cp -r site/* lib/website

# static main.bc.js and verifier_main.bc.js
rm -rf lib/website/static
mkdir -p lib/website/static
cp site/static/main.bc.js lib/website/static
cp site/static/verifier_main.bc.js lib/website/static

CI=no
if [[ "$1" == "staging" ]]; then
  TARGET=coda-staging-84430
elif [[ "$1" == "ci" ]]; then
  TARGET=coda-staging-84430
  CI=yes
elif [[ "$1" == "prod" ]]; then
  TARGET=coda-203520
else
  echo "Target must be one of: staging, prod, ci"
  exit 1
fi

if [[ "$CI" != "yes" ]]; then
  read -p "To $1, did you deploy to CDN first? And are you sure? This can break the live site: [y/N]" -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

echo "*** Deploying to $1"

if [[ "$CI" == "yes" ]]; then
  if [[ -z "$FIREBASE_TOKEN" || "$FIREBASE_TOKEN" == "" ]]; then
    echo "Skipping deployment as you don't have the creds to see our token!"
  else
    ./node_modules/firebase-tools/lib/bin/firebase.js --token "$FIREBASE_TOKEN" --project $TARGET deploy
  fi
else
  ./node_modules/firebase-tools/lib/bin/firebase.js --project $TARGET deploy
fi

