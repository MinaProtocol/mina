#!/usr/bin/env bash
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
printf '{"go.mod":"%s","go.sum":"%s","vendorSha256":"%s"}' \
"$(sha256sum src/app/libp2p_helper/src/go.mod | cut -d\  -f1)" \
"$(sha256sum src/app/libp2p_helper/src/go.sum | cut -d\  -f1)" \
"$1" \
| tee nix/libp2p_helper.json
