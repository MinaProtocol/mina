#!/bin/bash

set -eox pipefail

./buildkite/scripts/cache/manager.sh read --root ${CACHED_BUILDKITE_BUILD_ID} debians/${CODENAME}/mina-daemon* ./

./buildkite/scripts/cache/manager.sh read hardfork/ledgers/*.tar.gz hardfork_ledgers/
./buildkite/scripts/cache/manager.sh read hardfork/new_config.json .

MINA_DEB_FILE=$(ls mina-daemon*.deb | head -n 1)

./scripts/hardfork/convert-debian-to-hf.sh -d "$MINA_DEB_FILE" -c "./new_config.json" -l "./hardfork_ledgers/"

./buildkite/scripts/cache/manager.sh write ./mina-daemon-*.deb debians/${CODENAME}/