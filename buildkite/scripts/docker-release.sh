set -eo pipefail
set +x

docker_env=${1:-DOCKER_DEPLOY_ENV}

source $docker_env

service=${2:-CODA_SERVICE}
extra_args=${3:-""}

echo "--- Build/Release docker artifact for ${service}"
scripts/release-docker.sh --service "${service}" --version "${CODA_VERSION}" --extra-args "$extra_args"