#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
EXTERNAL_DIR="${REPO_ROOT}/buildkite/src/External"

PRELUDE_VERSION="${PRELUDE_VERSION:-v15.0.0}"
PRELUDE_REPO_URL="${PRELUDE_REPO_URL:-https://github.com/dhall-lang/dhall-lang.git}"
BUILDKITE_RELEASE="${BUILDKITE_RELEASE:-0.0.1}"

TMP_ROOT="${TMPDIR:-/tmp}"

ONLY="all"
KEEP_TMP=0

usage() {
  cat <<'USAGE'
Usage: update_external_deps.sh [options]

Updates buildkite/src/External/{prelude,buildkite} and refreshes dhall hashes.

Options:
  --only <all|prelude|buildkite>  Update a single dependency (default: all)
  --prelude-version <tag>         dhall-lang tag/branch (default: v15.0.0)
  --prelude-repo <name|url>       dhall-lang repo (default: https://github.com/dhall-lang/dhall-lang.git)
  --buildkite-release <version>   S3 release version (default: 0.0.1)
  --tmp-root <path>               Temp directory root (default: /tmp)
  --keep-tmp                      Do not delete temp directories
  -h, --help                      Show this help

Environment variables are also supported:
  PRELUDE_VERSION, PRELUDE_REPO_URL, BUILDKITE_RELEASE, TMPDIR

Notes:
  - If --buildkite-out is not provided, the script will try to download from S3
    using aws-cli and BUILDKITE_RELEASE. Hosted at:
    https://s3.us-west-2.amazonaws.com/dhall.packages.minaprotocol.com/buildkite/releases/${VERSION}
  - To regenerate Buildkite bindings, see buildkite/src/External/README.md.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)
      ONLY="$2"
      shift 2
      ;;
    --prelude-version)
      PRELUDE_VERSION="$2"
      shift 2
      ;;
    --prelude-repo)
      PRELUDE_REPO_URL="$2"
      shift 2
      ;;
    --buildkite-release)
      BUILDKITE_RELEASE="$2"
      shift 2
      ;;
    --tmp-root)
      TMP_ROOT="$2"
      shift 2
      ;;
    --keep-tmp)
      KEEP_TMP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

TMP_DIRS=()

make_tmp_dir() {
  local dir
  dir="$(mktemp -d "${TMP_ROOT%/}/external-deps.XXXXXX")"
  TMP_DIRS+=("$dir")
  echo "$dir"
}

normalize_repo_url() {
  local repo="$1"
  if [[ "${repo}" != *"://"* ]]; then
    repo="https://github.com/${repo}"
  fi
  echo "${repo}"
}

cleanup() {
  if [[ "${KEEP_TMP}" -eq 1 ]]; then
    return
  fi
  for dir in "${TMP_DIRS[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

update_prelude() {
  echo "Updating Prelude (dhall-lang ${PRELUDE_VERSION})"
  local tmp
  tmp="$(make_tmp_dir)"
  local repo_dir="${tmp}/dhall-lang"
  local repo_url
  repo_url="$(normalize_repo_url "${PRELUDE_REPO_URL}")"
  echo "Cloning ${repo_url} into ${repo_dir}"
  git clone --branch "${PRELUDE_VERSION}" --depth 1 \
    "${repo_url}" "${repo_dir}"

  if [[ ! -d "${repo_dir}/Prelude" ]]; then
    echo "Prelude directory not found in ${repo_dir}" >&2
    exit 1
  fi

  echo "Refreshing ${EXTERNAL_DIR}/prelude"
  rm -rf "${EXTERNAL_DIR}/prelude"
  mkdir -p "${EXTERNAL_DIR}/prelude"
  cp -R "${repo_dir}/Prelude/." "${EXTERNAL_DIR}/prelude"
  echo "Freezing ${EXTERNAL_DIR}/Prelude.dhall"
  dhall freeze --inplace "${EXTERNAL_DIR}/Prelude.dhall"
}

resolve_buildkite_src_dir() {
  local out_dir="$1"
  if [[ -d "${out_dir}/top_level" ]]; then
    echo "${out_dir}"
    return 0
  fi
  if [[ -d "${out_dir}/buildkite/top_level" ]]; then
    echo "${out_dir}/buildkite"
    return 0
  fi
  return 1
}

update_buildkite() {
  echo "Updating Buildkite bindings"
  if ! command -v aws >/dev/null 2>&1; then
    echo "aws-cli not available; cannot sync Buildkite bindings from S3." >&2
    exit 1
  fi
  local tmp
  tmp="$(make_tmp_dir)"
  local out_dir="${tmp}/out"
  echo "Syncing Buildkite bindings from S3 (release ${BUILDKITE_RELEASE})"
  aws s3 sync \
    "s3://dhall.packages.minaprotocol.com/buildkite/releases/${BUILDKITE_RELEASE}/" \
    "${out_dir}" \
    --region us-west-2 \
    --quiet

  local src_dir
  if ! src_dir="$(resolve_buildkite_src_dir "${out_dir}")"; then
    echo "Unable to find Buildkite bindings in ${out_dir}" >&2
    echo "Expected to find 'top_level' directory." >&2
    exit 1
  fi

  echo "Refreshing ${EXTERNAL_DIR}/buildkite"
  rm -rf "${EXTERNAL_DIR}/buildkite"
  mkdir -p "${EXTERNAL_DIR}/buildkite"
  cp -R "${src_dir}/." "${EXTERNAL_DIR}/buildkite"
  echo "Freezing ${EXTERNAL_DIR}/Buildkite.dhall"
  dhall freeze --inplace "${EXTERNAL_DIR}/Buildkite.dhall"
}

case "${ONLY}" in
  all)
    update_prelude
    update_buildkite
    ;;
  prelude)
    update_prelude
    ;;
  buildkite)
    update_buildkite
    ;;
  *)
    echo "Unknown --only value: ${ONLY}" >&2
    usage
    exit 1
    ;;
esac
