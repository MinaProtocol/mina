#!/bin/bash

set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <version eg. v1>"
  exit 1
fi


rm -rf lib/cdn
mkdir -p lib/cdn

echo "*** Building"

npm run build && node lib/js/src/Render.js prod

cp site/fonts.css lib/cdn/
cp -r site/static lib/cdn/

cd lib/cdn

read -p "Are you sure? This cost \$\$ and can break the live site: [y/N]" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

BUCKET="s3://website-codaprotocol/$1"

echo "*** Deploying to $BUCKET"

aws s3 sync . "$BUCKET"

