#!/bin/bash
set -euo pipefail

################################################################################
# Mock of `deb-toolkit build` (MinaProtocol/deb-toolkit) for the Debian builder
# tests.
#
# The tests check what scripts/debian/builder-helpers.sh gives to deb-toolkit:
# the files of each package and its control fields. They do not check what
# deb-toolkit does with them. deb-toolkit has its own tests for the control
# format and the package build, and the "Debian: Build" CI jobs run the real
# tool. With this mock, the tests do not need deb-toolkit, fakeroot or dpkg-deb.
#
# The mock:
#   - accepts only the options of `deb-toolkit build` (an unknown option is an
#     error, as in deb-toolkit),
#   - writes each control option as "Field: value" into
#     <build-dir>/DEBIAN/control, in the order of the options. This is NOT the
#     control format of deb-toolkit: values are not split or joined again,
#   - writes an empty <output-dir>/<package>_<version>_<architecture>.deb, the
#     file name that deb-toolkit gives.
#
# MOCK_DEB_TOOLKIT_FAIL=1 makes the mock fail, to test the error path.
################################################################################

if [[ "${1:-}" != "build" ]]; then
  echo "mock deb-toolkit: only the 'build' command is supported, got '${1:-}'" >&2
  exit 2
fi
shift

if [[ -n "${MOCK_DEB_TOOLKIT_FAIL:-}" ]]; then
  echo "mock deb-toolkit: fails because MOCK_DEB_TOOLKIT_FAIL is set" >&2
  exit 1
fi

# The options of `deb-toolkit build` that take a value, other than
# --build-dir and --output-dir.
CONTROL_OPTIONS=(
  package-name version architecture codename suite vendor origin label authors
  maintainer description section priority homepage installed-size source
  license githash buildurl depends pre-depends recommended-depends
  suggested-depends conflicts replaces breaks provides defaults-file
)

is_control_option() {
  local known
  for known in "${CONTROL_OPTIONS[@]}"; do
    [[ "$known" == "$1" ]] && return 0
  done
  return 1
}

build_dir=""
output_dir=""
package="" version="" architecture=""
control=()

while [[ $# -gt 0 ]]; do
  option="${1#--}"
  if [[ "$1" != --* ]]; then
    echo "mock deb-toolkit: unexpected argument '$1'" >&2
    exit 2
  fi
  if [[ $# -lt 2 ]]; then
    echo "mock deb-toolkit: option --${option} has no value" >&2
    exit 2
  fi
  value="$2"
  shift 2

  case "$option" in
    build-dir) build_dir="$value"; continue ;;
    output-dir) output_dir="$value"; continue ;;
  esac
  if ! is_control_option "$option"; then
    echo "mock deb-toolkit: unknown option --${option}" >&2
    exit 2
  fi

  case "$option" in
    package-name) field="Package"; package="$value" ;;
    suggested-depends) field="Suggests" ;;
    recommended-depends) field="Recommends" ;;
    *)
      # depends -> Depends, pre-depends -> Pre-Depends
      field=""
      IFS='-' read -ra parts <<< "$option"
      for part in "${parts[@]}"; do
        field="${field:+${field}-}${part^}"
      done
      ;;
  esac
  case "$option" in
    version) version="$value" ;;
    architecture) architecture="$value" ;;
  esac
  control+=("${field}: ${value}")
done

for required in build-dir:build_dir output-dir:output_dir \
  package-name:package version:version architecture:architecture; do
  variable="${required#*:}"
  if [[ -z "${!variable}" ]]; then
    echo "mock deb-toolkit: --${required%%:*} is required" >&2
    exit 2
  fi
done
if [[ ! -d "$build_dir" ]]; then
  echo "mock deb-toolkit: build directory does not exist: ${build_dir}" >&2
  exit 1
fi

mkdir -p "${build_dir}/DEBIAN" "$output_dir"
printf '%s\n' "${control[@]}" > "${build_dir}/DEBIAN/control"
: > "${output_dir}/${package}_${version}_${architecture}.deb"
