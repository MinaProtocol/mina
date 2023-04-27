#!/bin/bash
set -u
# Set the prefix to the node name (like "seed" or "block-producer")
# And set count as the number of keys of this type to generate (e.g. "./keygen.sh seed 6" produces 6 keys, "seed-1" through "seed-6")
PREFIX=$1
COUNT=$2

for i in $(seq 1 ${COUNT}); do

        NODE="${PREFIX}-${i}"
        PASS="${NODE}-password.txt"

        mkdir "./${NODE}"

        export MINA_PRIVKEY_PASS=$(pwgen --no-vowels --secure --ambiguous 64 1)
        echo "${MINA_PRIVKEY_PASS}" > "${NODE}/${PASS}"

        KEY="${NODE}-key"
        PUB="${NODE}-key.pub"
        ZIP="${NODE}.zip"

        echo "Generating key for ${NODE}"
        mina advanced generate-keypair --privkey-path "${NODE}/${KEY}" # 2> /dev/null

        echo "Copying public key for use in ledgers:"
        cp "${NODE}/${PUB}" .

        echo "Generating zip file ${ZIP}"
        zip -r "${ZIP}" "${NODE}"

        echo "Cleaning up ${NODE} directory"
        rm -rf ${NODE}
done

echo "All keys generated successfully!"
echo "Combining .pub files into one ${PREFIX}-keys.txt and cleaning up"
cat ${PREFIX}-*.pub > ${PREFIX}-keys.txt
rm -rf ${PREFIX}-*.pub
