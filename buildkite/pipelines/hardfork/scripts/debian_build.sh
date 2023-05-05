#!/bin/bash
# this script updates the Mina src and builds required Mina .deb packages
# final .deb packages are published to AWS S3 after the build completes

##########################################################
# Updating Mina src with hard fork configs
##########################################################

set -euo pipefail

echo "--- Cloning Mina repository"
git clone https://github.com/MinaProtocol/mina.git 

# prevent git -diff from failing the build after hard fork configs are modified
sed -i '/echo "--- Git diff after build is complete:"/d' ./mina/buildkite/scripts/build-artifact.sh
sed -i '/git diff --exit-code/d' ./mina/buildkite/scripts/build-artifact.sh

echo "--- Importing hard fork configuration"

echo "[%%define fork_previous_length 3757]" > ./mina/fork_3757.mlh
echo "[%%define fork_previous_state_hash "3NKR3QYJ7qwxiGgX39umahgdT8BH5yXBQwQtpYZdvodCXcsndK7f"]" >> ./mina/fork_3757.mlh
echo "[%%define fork_previous_global_slot 12796]" >> ./mina/fork_3757.mlh

# cat ./mina/fork_3757.mlh

echo "[%%import "/src/config/fork_3757.mlh"]" >> ./mina/src/config/mainnet.mlh # mainnet config
echo "[%%import "/src/config/fork_3757.mlh"]" >> ./mina/src/config/testnet_postake_medium_curves.mlh # devnet config

# tail ./mina/src/config/mainnet.mlh
# tail ./mina/src/config/testnet_postake_medium_curves.mlh

##########################################################
# Running commands within Mina toolchain container
##########################################################

# https://buildkite.com/o-1-labs-2/mainnet-hardfork-stage-1-fork/builds/184#0187a015-e275-46ef-801a-63195a8a3953
# working example: https://github.com/MinaProtocol/mina-deployments/blob/484f1241dbb96950b74fac726308ec5d40ba34c9/.buildkite/scripts/debian_build.sh

docker run --mount type=bind,source="$(pwd)"/mina,target=/home/opam/mina \
--rm -it --env AWS_ACCESS_KEY_ID --env AWS_SECRET_ACCESS_KEY \
--entrypoint bash gcr.io/o1labs-192920/mina-toolchain@sha256:1e2feaebd47c330e990fe3c4e0681d16ad42bfa642937c4c5142793da06c890b -c \
'
set -euo pipefail

export DUNE_PROFILE="devnet"
export BUILDKITE_BRANCH="fix/nonce-test-flake"

cd ../
sudo chown -R $(whoami) ./mina
cd ./mina

##########################################################
# Building and publishing Mina .deb packages
##########################################################

echo "--- Updating OPAM dependencies"
bash ./scripts/pin-external-packages.sh
eval $(opam env)

bash ./buildkite/scripts/build-artifact.sh

echo
echo "--- Mina package build complete!"
echo
echo "The following packages have been built and uploaded to AWS:"
echo

ls -lh _build/
'
