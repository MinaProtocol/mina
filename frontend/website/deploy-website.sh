#!/bin/bash

set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <staging | prod>"
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

# Keep all top-level except fonts.css
rm lib/website/fonts.css

read -p "To $1, did you deploy to CDN first? And are you sure? This can break the live site: [y/N]" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi


if [[ "$1" == "staging" ]]; then
  TARGET=coda-staging-84430
elif [[ "$1" == "prod" ]]; then
  TARGET=coda-203520
else
  echo "Target must be one of: staging, prod"
  exit 1
fi

echo "*** Deploying to $1"

./node_modules/firebase-tools/lib/bin/firebase.js --project $TARGET deploy

