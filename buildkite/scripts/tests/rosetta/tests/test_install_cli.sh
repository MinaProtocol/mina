#!/usr/bin/env bash

# Tests for buildkite/scripts/tests/rosetta/install-cli.sh, against stub curl,
# go, dpkg and sudo. The stub curl writes a tarball with an empty module; the
# stub go "installs" a marker file as the binary.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
SCRIPT="${REPO_ROOT}/buildkite/scripts/tests/rosetta/install-cli.sh"

PASSED=0
FAILED=0
pass () { PASSED=$((PASSED + 1)); }
fail () { echo "  FAIL: $*"; FAILED=$((FAILED + 1)); }
expect () {
  local message="$1"
  shift
  if "$@"; then pass; else fail "$message"; fi
}
not () { ! "$@"; }

WORK=""
setup () {
  WORK="$(mktemp -d)"
  mkdir -p "${WORK}/bin" "${WORK}/storagebox" "${WORK}/install"
  cat > "${WORK}/bin/curl" <<'STUB'
#!/usr/bin/env bash
echo "curl $*" >> "${CALLS}"
[[ -n "${STUB_CURL_FAIL:-}" ]] && exit 35
out=""
while [[ $# -gt 0 ]]; do [[ "$1" == "-o" ]] && out="$2"; shift; done
src="$(mktemp -d)"
mkdir -p "${src}/mesh-cli-0.10.1"
echo "module github.com/coinbase/mesh-cli" > "${src}/mesh-cli-0.10.1/go.mod"
tar -czf "$out" -C "$src" mesh-cli-0.10.1
rm -rf "$src"
STUB
  cat > "${WORK}/bin/go" <<'STUB'
#!/usr/bin/env bash
echo "go $*" >> "${CALLS}"
[[ "$1" == "install" ]] && echo "built-from-source" > "${GOBIN}/rosetta-cli"
exit 0
STUB
  cat > "${WORK}/bin/dpkg" <<'STUB'
#!/usr/bin/env bash
echo amd64
STUB
  cat > "${WORK}/bin/sudo" <<'STUB'
#!/usr/bin/env bash
exec "$@"
STUB
  chmod +x "${WORK}/bin/"*
}
teardown () { rm -rf "$WORK"; }

# run [VAR=value...]: exit code in RC, output in OUT, stub calls in CALLS.
run () {
  export CALLS="${WORK}/calls"
  : > "$CALLS"
  set +e
  OUT="$(env PATH="${WORK}/bin:/usr/bin:/bin" \
    GO="${WORK}/bin/go" \
    CI_CACHE_MOUNT="${WORK}/storagebox" \
    ROSETTA_CLI_INSTALL_PATH="${WORK}/install/rosetta-cli" \
    "$@" "$SCRIPT" 2>&1)"
  RC=$?
  set -e
}

called () { grep -q -- "$1" "$CALLS"; }
installed_is () { [[ -x "${WORK}/install/rosetta-cli" ]] && grep -qx -- "$1" "${WORK}/install/rosetta-cli"; }
CACHED_KEY="v0.10.1-stake-delegation-v1-amd64"
cached () { [[ -f "${WORK}/storagebox/tool-cache/rosetta-cli/${CACHED_KEY}/rosetta-cli" ]]; }

t_builds_from_source_and_stores_in_cache () {
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "must fetch the sources with retries" called "curl .*--retry-all-errors.*mesh-cli/archive/refs/tags/v0.10.1.tar.gz"
  expect "must build" called "go install"
  expect "binary installed" installed_is "built-from-source"
  expect "binary stored in the cache" cached
  expect "no partial file left" not compgen -G "${WORK}/storagebox/tool-cache/rosetta-cli/${CACHED_KEY}/rosetta-cli.new.*"
}

t_second_run_takes_the_cache_and_never_touches_the_network () {
  run
  rm -f "${WORK}/install/rosetta-cli"
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "no download" not called "curl"
  expect "no build" not called "go"
  expect "binary installed from the cache" installed_is "built-from-source"
}

t_cache_hit_from_another_build () {
  mkdir -p "${WORK}/storagebox/tool-cache/rosetta-cli/${CACHED_KEY}"
  echo "from-cache" > "${WORK}/storagebox/tool-cache/rosetta-cli/${CACHED_KEY}/rosetta-cli"
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "no download" not called "curl"
  expect "the cached binary is the one installed" installed_is "from-cache"
}

t_cache_key_follows_version_and_patch_tag () {
  run ROSETTA_CLI_VERSION=v0.10.1 SDK_REPLACEMENT_TAG=other-patch
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "stored under its own key" test -f "${WORK}/storagebox/tool-cache/rosetta-cli/v0.10.1-other-patch-amd64/rosetta-cli"
  expect "default key untouched" not cached
}

t_unmounted_cache_builds_and_does_not_store () {
  run CI_CACHE_MOUNT="${WORK}/absent"
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "binary installed" installed_is "built-from-source"
  expect "nothing stored" not test -e "${WORK}/absent"
  expect "says so" grep -q "not stored" <<< "$OUT"
}

t_cache_write_failure_does_not_fail_the_install () {
  # A file where the cache directory should be defeats mkdir even for root.
  mkdir -p "${WORK}/storagebox/tool-cache"
  : > "${WORK}/storagebox/tool-cache/rosetta-cli"
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "binary installed" installed_is "built-from-source"
  expect "warns" grep -q "WARNING: could not store" <<< "$OUT"
}

t_already_installed_is_a_no_op () {
  printf '#!/bin/sh\necho rosetta-cli v0.10.1\n' > "${WORK}/bin/rosetta-cli"
  chmod +x "${WORK}/bin/rosetta-cli"
  run
  expect "exit $RC: $OUT" test $RC -eq 0
  expect "no download" not called "curl"
  expect "no cache read" not test -e "${WORK}/install/rosetta-cli"
}

t_download_failure_fails () {
  run STUB_CURL_FAIL=1
  expect "must fail" test $RC -ne 0
  expect "nothing installed" not test -e "${WORK}/install/rosetta-cli"
  expect "nothing cached" not cached
}

for t in $(declare -F | awk '$3 ~ /^t_/ {print $3}'); do
  setup
  echo "TEST: $t"
  "$t"
  teardown
done

echo "passed=$PASSED failed=$FAILED"
[[ $FAILED -eq 0 ]]
