#!/usr/bin/env bash
set -u
# Set the prefix to the node name (like "seed" or "block-producer")
# And set count as the number of keys of this type to generate (e.g. "./keygen.sh seed 6" produces 6 keys, "seed-1" through "seed-6")
PREFIX=$1
COUNT=$2

for i in $(seq 1 ${COUNT}); do

        NODE="${PREFIX}-${i}"

        export MINA_PRIVKEY_PASS=$(pwgen --no-vowels --secure --ambiguous 64 1)
        export MINA_LIBP2P_PASS=$(pwgen --no-vowels --secure --ambiguous 64 1)

        KEY="${NODE}-key"
        PUB="${NODE}-key.pub"
        LIBP2P="${NODE}-libp2p"
        PEERID="${NODE}-libp2p.peerid"
        YAML="${NODE}.yaml"

        echo "Generating keys for ${NODE}"
        mina advanced generate-keypair --privkey-path ${KEY} 2> /dev/null
        mina advanced generate-libp2p-keypair --privkey-path ${LIBP2P} 2> /dev/null

        echo "Generating Secret yaml ${YAML}"
        kubectl create secret generic --dry-run=client -o yaml "${NODE}" \
                --from-literal=libp2p-password=${MINA_LIBP2P_PASS} \
                --from-literal=key-password=${MINA_PRIVKEY_PASS} \
                --from-file ${KEY} \
                --from-file ${PUB} \
                --from-file ${LIBP2P} \
                --from-file ${PEERID} \
                > ${YAML}
        echo "---" >> ${YAML}

        rm ${KEY} ${PUB} ${LIBP2P} ${PEERID}
done

echo "All keys generated successfully!"
echo "Combining yaml files into one keys.yaml and cleaning up"
cat ${PREFIX}-*.yaml > keys.yaml
rm -rf ${PREFIX}-*.yaml
