#!/usr/bin/env bash
# Mock Debian repository for the release-manager test suite.
#
# The suite used to read and write two live S3 buckets,
# test.packages.o1test.net and signed.tests.packages.o1test.net. That coupled
# every run to an AWS account, to a real GPG private key, and to fixture
# packages that somebody had to upload by hand and nobody could delete. It also
# made the tests fail for reasons that had nothing to do with the release
# manager: the repository was served over HTTPS, so a base image without a
# trust store failed with "Certificate verification failed" instead of saying
# what was really wrong.
#
# This script replaces both buckets with a throwaway MinIO container:
#
#   - MinIO speaks the S3 API, so deb-s3 drives it unchanged. Our deb-s3 fork
#     already accepts --endpoint and --force-path-style; the release scripts
#     pass them when DEB_S3_ENDPOINT is set (scripts/debian/deb-s3-common.sh).
#   - The repository is served over plain HTTP on a private docker network, so
#     apt needs no ca-certificates and no TLS at all.
#   - The signing key is generated per run, so no production private key is
#     needed to test the signed code path.
#   - Fixture packages are built here with dpkg-deb. They are about 1 KB each
#     instead of 260 MB, and they still exercise the real check scripts: the
#     stub mina binary reports a commit hash and the package ships a matching
#     /var/lib/coda/config_<hash>.json, which is exactly what
#     scripts/verify/check-daemon.sh compares.
#
# Everything created here is removed by mock_repo_stop.
#
# This file is sourced by lib.sh, so it deliberately sets no shell options: it
# would be setting them on the caller. The suites run under `set -eo pipefail`,
# which applies to the functions here as well.

MOCK_REPO_CONTAINER="mina-release-mock-repo-$$"
MOCK_REPO_NETWORK="mina-release-mock-net-$$"
# quay.io, not Docker Hub: MinIO no longer publishes a publicly pullable
# minio/minio there, so an agent without Docker Hub credentials fails with
# "pull access denied ... may require 'docker login'". The tag is pinned so
# that a MinIO release cannot change the tests underneath us.
MOCK_REPO_IMAGE="${MOCK_REPO_IMAGE:-quay.io/minio/minio:RELEASE.2025-02-28T09-55-16Z}"
MOCK_REPO_ACCESS_KEY="minioadmin"
MOCK_REPO_SECRET_KEY="minioadmin"

# Buckets that stand in for the two retired S3 buckets.
MOCK_REPO_BUCKET="test-packages"
MOCK_REPO_SIGNED_BUCKET="signed-test-packages"

# Commit hash baked into the stub daemon. check-daemon.sh takes the first 8
# characters of the binary's hash and compares them with the hash in the
# genesis config filename, so the two must agree.
MOCK_REPO_COMMIT="918b8c0a"

###############################################################################
# Internals
###############################################################################

_mock_repo_aws() {
    aws --endpoint-url "${MOCK_REPO_ENDPOINT}" "$@"
}

_mock_repo_deb_s3() {
    deb-s3 "$1" \
        --endpoint="${MOCK_REPO_ENDPOINT}" \
        --force-path-style \
        --s3-region="${MOCK_REPO_REGION}" \
        "${@:2}"
}

# Open a bucket for anonymous reads. apt fetches the indexes and the .deb files
# with no credentials, exactly as it does against the public repositories.
_mock_repo_make_public_bucket() {
    local __bucket=$1

    _mock_repo_aws s3 mb "s3://${__bucket}" > /dev/null
    _mock_repo_aws s3api put-bucket-policy --bucket "${__bucket}" --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [{
            \"Effect\": \"Allow\",
            \"Principal\": \"*\",
            \"Action\": [\"s3:GetObject\"],
            \"Resource\": [\"arn:aws:s3:::${__bucket}/*\"]
        }]
    }"
}

# Build one fixture .deb. A daemon package also gets the stub binary and the
# matching genesis config, so that check-daemon.sh runs its real comparison
# instead of being skipped.
#
# Usage: _mock_repo_build_deb <name> <version> <arch> <output-dir>
_mock_repo_build_deb() {
    local __name=$1
    local __version=$2
    local __arch=$3
    local __out_dir=$4

    local __root="${__out_dir}/${__name}_${__version}_${__arch}"
    rm -rf "${__root}"
    mkdir -p "${__root}/DEBIAN" "${__root}/usr/local/bin"

    cat > "${__root}/DEBIAN/control" <<EOF
Package: ${__name}
Version: ${__version}
Section: utils
Priority: optional
Architecture: ${__arch}
Maintainer: O(1) Labs <build@o1labs.org>
Description: Synthetic ${__name} fixture for the release-manager test suite
 Built by buildkite/scripts/tests/release-manager/mock-repo.sh. It carries no
 Mina code: it exists so that the release manager has a package to publish,
 promote, reversion and verify.
EOF

    case "${__name}" in
        mina-logproc)
            # check-logproc.sh runs nothing, so a marker file is enough.
            printf '#!/bin/sh\necho "mina-logproc fixture"\n' \
                > "${__root}/usr/local/bin/mina-logproc"
            chmod 755 "${__root}/usr/local/bin/mina-logproc"
            ;;
        mina-archive*)
            printf '#!/bin/sh\necho "Commit %s"\n' "${MOCK_REPO_COMMIT}" \
                > "${__root}/usr/local/bin/mina-archive"
            chmod 755 "${__root}/usr/local/bin/mina-archive"
            ;;
        *)
            # Daemon-shaped package: stub binary plus matching genesis config.
            cat > "${__root}/usr/local/bin/mina" <<EOF
#!/bin/sh
case "\$1" in
  --version) echo "Commit ${MOCK_REPO_COMMIT} on branch master" ;;
  --help)    echo "Usage: mina [COMMAND]" ;;
  *)         echo "Usage: mina [COMMAND]"; exit 1 ;;
esac
EOF
            chmod 755 "${__root}/usr/local/bin/mina"
            mkdir -p "${__root}/var/lib/coda"
            echo '{"ledger":{"name":"devnet"}}' \
                > "${__root}/var/lib/coda/config_${MOCK_REPO_COMMIT}.json"
            ;;
    esac

    dpkg-deb --build "${__root}" "${__root}.deb" > /dev/null
    rm -rf "${__root}"
    echo "${__root}.deb"
}

# Generate the throwaway repository signing key and publish its public half at
# the path setup.sh expects.
_mock_repo_create_signing_key() {
    export GNUPGHOME="${MOCK_REPO_WORK_DIR}/gnupg"
    mkdir -p "${GNUPGHOME}"
    chmod 700 "${GNUPGHOME}"

    gpg --batch --gen-key > /dev/null 2>&1 <<'EOF'
%no-protection
Key-Type: RSA
Key-Length: 3072
Name-Real: Mina Release Manager Test Key
Name-Email: release-manager-tests@o1labs.invalid
Expire-Date: 0
%commit
EOF

    MOCK_REPO_SIGN_KEY=$(gpg --list-keys --with-colons | awk -F: '/^fpr:/{print $10; exit}')

    gpg --export "${MOCK_REPO_SIGN_KEY}" > "${MOCK_REPO_WORK_DIR}/repo-signing-key.gpg"
    _mock_repo_aws s3 cp \
        "${MOCK_REPO_WORK_DIR}/repo-signing-key.gpg" \
        "s3://${MOCK_REPO_SIGNED_BUCKET}/repo-signing-key.gpg" > /dev/null
}

###############################################################################
# Public interface
###############################################################################

# Start the mock repository and seed it. Exports everything the suite needs.
#
# Usage: mock_repo_start <codename> <unsigned-arch> <signed-arch> <ci-component>
mock_repo_start() {
    local __codename=$1
    local __arch=$2
    local __signed_arch=$3
    local __component=$4

    MOCK_REPO_REGION="${TEST_REGION:-us-west-2}"
    MOCK_REPO_WORK_DIR=$(mktemp -d -t mock-repo.XXXXXX)

    echo "[mock-repo] starting MinIO container ${MOCK_REPO_CONTAINER}"
    docker network create "${MOCK_REPO_NETWORK}" > /dev/null

    # Publish on an ephemeral loopback port so that parallel agents on the same
    # host never collide; docker picks the number and we read it back.
    docker run -d \
        --name "${MOCK_REPO_CONTAINER}" \
        --network "${MOCK_REPO_NETWORK}" \
        -p 127.0.0.1::9000 \
        -e "MINIO_ROOT_USER=${MOCK_REPO_ACCESS_KEY}" \
        -e "MINIO_ROOT_PASSWORD=${MOCK_REPO_SECRET_KEY}" \
        "${MOCK_REPO_IMAGE}" server /data > /dev/null

    local __host_port
    __host_port=$(docker port "${MOCK_REPO_CONTAINER}" 9000/tcp | head -1 | sed 's/.*://')

    # Two views of the same server. The test scripts run on the agent and reach
    # it through the published port; the verification containers are siblings on
    # the docker network and reach it by container name.
    MOCK_REPO_ENDPOINT="http://127.0.0.1:${__host_port}"
    # Read by lib.sh to build the repository URLs.
    # shellcheck disable=SC2034
    MOCK_REPO_INTERNAL_ENDPOINT="http://${MOCK_REPO_CONTAINER}:9000"

    local __waited=0
    until curl -sf "${MOCK_REPO_ENDPOINT}/minio/health/live" > /dev/null; do
        if [[ ${__waited} -ge 60 ]]; then
            echo "[mock-repo] MinIO did not become healthy within 60s" >&2
            docker logs "${MOCK_REPO_CONTAINER}" >&2 || true
            return 1
        fi
        sleep 1
        __waited=$((__waited + 1))
    done
    echo "[mock-repo] MinIO healthy at ${MOCK_REPO_ENDPOINT}"

    # MinIO checks signatures, so credentials must be set even though the read
    # side is anonymous.
    export AWS_ACCESS_KEY_ID="${MOCK_REPO_ACCESS_KEY}"
    export AWS_SECRET_ACCESS_KEY="${MOCK_REPO_SECRET_KEY}"
    export AWS_DEFAULT_REGION="${MOCK_REPO_REGION}"
    unset AWS_SESSION_TOKEN AWS_PROFILE || true

    _mock_repo_make_public_bucket "${MOCK_REPO_BUCKET}"
    _mock_repo_make_public_bucket "${MOCK_REPO_SIGNED_BUCKET}"

    _mock_repo_create_signing_key
    echo "[mock-repo] signing key ${MOCK_REPO_SIGN_KEY}"

    # Seed the CI component, which is the source channel every promote test
    # reads from. Versions match what the tests ask for.
    local __deb
    __deb=$(_mock_repo_build_deb "mina-devnet" "3.3.0-alpha1-compatible-918b8c0" "${__arch}" "${MOCK_REPO_WORK_DIR}")
    _mock_repo_deb_s3 upload --bucket="${MOCK_REPO_BUCKET}" --codename="${__codename}" \
        --component="${__component}" --arch="${__arch}" --preserve-versions "${__deb}" > /dev/null

    __deb=$(_mock_repo_build_deb "mina-logproc" "3.3.0-beta1-dkijania-berkeley-automode-05a597d" "${__arch}" "${MOCK_REPO_WORK_DIR}")
    _mock_repo_deb_s3 upload --bucket="${MOCK_REPO_BUCKET}" --codename="${__codename}" \
        --component="${__component}" --arch="${__arch}" --preserve-versions "${__deb}" > /dev/null

    # The signed repository gets its own source package, signed with the
    # throwaway key so that apt can check the InRelease signature.
    __deb=$(_mock_repo_build_deb "mina-archive-devnet" "3.3.0-8c0c2e6" "${__signed_arch}" "${MOCK_REPO_WORK_DIR}")
    _mock_repo_deb_s3 upload --bucket="${MOCK_REPO_SIGNED_BUCKET}" --codename="${__codename}" \
        --component="${__component}" --arch="${__signed_arch}" --preserve-versions \
        --sign="${MOCK_REPO_SIGN_KEY}" "${__deb}" > /dev/null

    echo "[mock-repo] seeded ${__codename}/${__component}"

    # Point the release scripts and the verification containers at the mock.
    export DEB_S3_ENDPOINT="${MOCK_REPO_ENDPOINT}"
    export DEB_S3_REGION="${MOCK_REPO_REGION}"
    export MINA_VERIFY_DOCKER_NETWORK="${MOCK_REPO_NETWORK}"
}

# Remove everything mock_repo_start created. Safe to call more than once.
mock_repo_stop() {
    if [[ -n "${MOCK_REPO_CONTAINER:-}" ]]; then
        docker rm -f "${MOCK_REPO_CONTAINER}" > /dev/null 2>&1 || true
    fi
    if [[ -n "${MOCK_REPO_NETWORK:-}" ]]; then
        docker network rm "${MOCK_REPO_NETWORK}" > /dev/null 2>&1 || true
    fi
    if [[ -n "${MOCK_REPO_WORK_DIR:-}" && -d "${MOCK_REPO_WORK_DIR}" ]]; then
        # gpg-agent holds the socket in GNUPGHOME open; ask it to go away first.
        gpgconf --homedir "${MOCK_REPO_WORK_DIR}/gnupg" --kill all > /dev/null 2>&1 || true
        rm -rf "${MOCK_REPO_WORK_DIR}"
    fi
}
