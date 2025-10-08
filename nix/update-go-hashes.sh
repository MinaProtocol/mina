#!/usr/bin/env bash

NAME="$1"
VENDOR_HASH="$2"

if [[ "$NAME" == "" ]] || [[ "$VENDOR_HASH" == "" ]]; then
    echo "Usage: $0 <name> <vendor hash>"
    exit 1
fi

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
printf '{"go.mod":"%s","go.sum":"%s","vendorSha256":"%s"}' \
"$(sha256sum "src/app/$NAME/src/go.mod" | cut -d\  -f1)" \
"$(sha256sum "src/app/$NAME/src/go.sum" | cut -d\  -f1)" \
"$VENDOR_HASH" | tee "nix/go-hashes/$NAME.json"
