#!/bin/bash
set -u

# This script depends on the mina daemon package, zip, and pwgen
#   to generate unique passwords for each key, and output a zip file containing:
#   the password along with the public and private keypairs
# For convenience, the script finally zips together all of the individual zip files,
#   plus a txt file containing just the public keys
# Set the prefix to the node name (like "community", "seed" or "block-producer")
#   and set count as the number of keys of this type to generate (e.g. "./generate-community-keys.sh bp 5" produces 3 keys, "bp-1" through "bp-5")
PREFIX=$1
COUNT=$2

mkdir "${PREFIX}"
cd "${PREFIX}"

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

echo "Combining .pub files into one ${PREFIX}-keys.txt and cleaning up"
cat ${PREFIX}-*.pub > ${PREFIX}-keys.txt
cp ${PREFIX}-keys.txt ../
rm -rf ${PREFIX}-*.pub

cd ..
echo "All keys generated successfully! Combining into one zip file"
zip -r "${PREFIX}.zip" "${PREFIX}"

rm -rf "${PREFIX}"
