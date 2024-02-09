#!/usr/bin/env sh

set -e

. "$(dirname "$0")/common.sh"

NAMESPACE="${NAMESPACE:-testnet-testworld-2}"

"$(dirname "$0")/create-secrets.sh" -d --namespace="$NAMESPACE" \
  seed1-libp2p-secret="$(resource seed1)" \
  seed2-libp2p-secret="$(resource seed2)" \
  prod1-privkey-secret="$(resource key-01)" \
  prod2-privkey-secret="$(resource key-02)" \
  prod3-privkey-secret="$(resource key-03)" \
  prod4-privkey-secret="$(resource key-04)" \
  prod5-privkey-secret="$(resource key-05)" \
  prod6-privkey-secret="$(resource key-06)" \
  prod7-privkey-secret="$(resource key-07)" \
  prod8-privkey-secret="$(resource key-08)" \
  prod9-privkey-secret="$(resource key-09)" \
  prod10-privkey-secret="$(resource key-10)" \
  prod11-privkey-secret="$(resource key-11)" \
  prod12-privkey-secret="$(resource key-12)" \
  prod13-privkey-secret="$(resource key-13)" \
  prod14-privkey-secret="$(resource key-14)" \
  prod15-privkey-secret="$(resource key-15)" \
  prod16-privkey-secret="$(resource key-16)" \
  prod17-privkey-secret="$(resource key-17)" \
  prod18-privkey-secret="$(resource key-18)" \
  prod19-privkey-secret="$(resource key-19)" \
  prod20-privkey-secret="$(resource key-20)" \
  prod21-privkey-secret="$(resource key-21)" \
  prod22-privkey-secret="$(resource key-22)" \
  prod23-privkey-secret="$(resource key-23)" \
  prod24-privkey-secret="$(resource key-24)" \
  prod25-privkey-secret="$(resource key-25)" \
  prod26-privkey-secret="$(resource key-26)" \
  prod27-privkey-secret="$(resource key-27)" \
  prod28-privkey-secret="$(resource key-28)" \
  prod29-privkey-secret="$(resource key-29)" \
  prod30-privkey-secret="$(resource key-30)" \
  prod31-privkey-secret="$(resource key-31)" \
  prod32-privkey-secret="$(resource key-32)" \
  prod33-privkey-secret="$(resource key-33)" \
  prod34-privkey-secret="$(resource key-34)" \
  prod35-privkey-secret="$(resource key-35)" \
  prod36-privkey-secret="$(resource key-36)" \
  prod37-privkey-secret="$(resource key-37)" \
  prod38-privkey-secret="$(resource key-38)" \
  prod39-privkey-secret="$(resource key-39)" \
  prod40-privkey-secret="$(resource key-40)" \
  prod41-privkey-secret="$(resource key-41)" \
  prod42-privkey-secret="$(resource key-42)"
