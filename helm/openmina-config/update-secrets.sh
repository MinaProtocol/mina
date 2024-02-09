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
  prod42-privkey-secret="$(resource key-42)" \
   node1-uptime-key-secret="$(resource uptime-keys/node1)" \
   node2-uptime-key-secret="$(resource uptime-keys/node2)" \
   node3-uptime-key-secret="$(resource uptime-keys/node3)" \
   node4-uptime-key-secret="$(resource uptime-keys/node4)" \
   node5-uptime-key-secret="$(resource uptime-keys/node5)" \
   node6-uptime-key-secret="$(resource uptime-keys/node6)" \
   node7-uptime-key-secret="$(resource uptime-keys/node7)" \
   node8-uptime-key-secret="$(resource uptime-keys/node8)" \
   node9-uptime-key-secret="$(resource uptime-keys/node9)" \
  node10-uptime-key-secret="$(resource uptime-keys/node10)" \
  node11-uptime-key-secret="$(resource uptime-keys/node11)" \
  node12-uptime-key-secret="$(resource uptime-keys/node12)" \
  node13-uptime-key-secret="$(resource uptime-keys/node13)" \
  node14-uptime-key-secret="$(resource uptime-keys/node14)" \
  node15-uptime-key-secret="$(resource uptime-keys/node15)" \
  node16-uptime-key-secret="$(resource uptime-keys/node16)" \
  node17-uptime-key-secret="$(resource uptime-keys/node17)" \
  node18-uptime-key-secret="$(resource uptime-keys/node18)" \
  node19-uptime-key-secret="$(resource uptime-keys/node19)" \
  node20-uptime-key-secret="$(resource uptime-keys/node20)" \
  seed1-uptime-key-secret="$(resource uptime-keys/seed1)" \
  seed2-uptime-key-secret="$(resource uptime-keys/seed2)" \
  snarker001-uptime-key-secret="$(resource uptime-keys/snarker001)"
