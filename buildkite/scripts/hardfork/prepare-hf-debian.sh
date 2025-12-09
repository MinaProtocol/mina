#!/bin/bash

set -eox pipefail


## Check if CACHED_BUILDKITE_BUILD_ID is defined
if [ "${CACHED_BUILDKITE_BUILD_ID+x}" ]; then
	ROOT_ARG="--root ${CACHED_BUILDKITE_BUILD_ID}"
else
	ROOT_ARG=""
fi

./buildkite/scripts/cache/manager.sh read ${ROOT_ARG} debians/${CODENAME}/mina-${NETWORK_NAME}* ./

./buildkite/scripts/cache/manager.sh read hardfork/ledgers/*.tar.gz ./hardfork_ledgers/
./buildkite/scripts/cache/manager.sh read hardfork/new_config.json .

MINA_DEB_FILE=$(ls mina-${NETWORK_NAME}_*.deb | head -n 1)

ls -al

./scripts/hardfork/convert-debian-to-hf.sh -d "$MINA_DEB_FILE" -c "./new_config.json" -l "./hardfork_ledgers/"

./buildkite/scripts/cache/manager.sh write ./mina-${NETWORK_NAME}-hardfork_*.deb debians/${CODENAME}/
./buildkite/scripts/cache/manager.sh write ./mina-zkapp*.deb debians/${CODENAME}/