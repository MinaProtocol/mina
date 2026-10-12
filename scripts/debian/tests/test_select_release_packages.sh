#!/usr/bin/env bash
# Tests for buildkite/scripts/debian/select_release_packages.sh.
#
# A fixture .deb is a text file holding its control fields; a dpkg-deb stub on
# PATH prints them, so the tests need no dpkg.

set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")/../../.." && pwd)/buildkite/scripts/debian/select_release_packages.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/bin"
cat > "$WORK/bin/dpkg-deb" <<'EOF'
#!/usr/bin/env bash
# dpkg-deb -f <file> <fields...>
cat "$2"
EOF
chmod +x "$WORK/bin/dpkg-deb"
export PATH="$WORK/bin:$PATH"

PASS=0
FAIL=0
FAILURES=()

pass() { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); FAILURES+=("${CURRENT}: $1"); echo "  FAIL: $1"; }

V=4.0.1-abc1234
LEGACY=3.5.0-stop-1111111

# deb <folder> <name> <version> <arch> [<depends>]
deb() {
  local dir="$1" name="$2" version="$3" arch="$4" depends="${5:-}"
  mkdir -p "$dir"
  {
    echo "Package: ${name}"
    echo "Version: ${version}"
    echo "Architecture: ${arch}"
    [[ -n "$depends" ]] && echo "Depends: ${depends}"
  } > "${dir}/${name}_${version}_${arch}.deb"
}

# A mainnet build as the package job leaves it, plus the legacy cache.
mainnet_folder() {
  local d="$1"
  deb "$d" mina-mainnet "$V" amd64 "mina-mainnet-generic (=$V), mina-mainnet-config (=$V)"
  deb "$d" mina-mainnet-generic "$V" amd64 "mina-generic (=$V), mina-mainnet-profile (=$V)"
  deb "$d" mina-mainnet-config "$V" all
  deb "$d" mina-mainnet-profile "$V" amd64
  deb "$d" mina-generic "$V" amd64 "libssl3, libgmp10, mina-logproc"
  deb "$d" mina-logproc "$V" amd64 "libssl3"
  deb "$d" mina-archive-mainnet "$V" amd64 "mina-archive-generic (=$V), mina-mainnet-profile (=$V)"
  deb "$d" mina-archive-generic "$V" amd64 "libpq-dev, curl"
  deb "$d" mina-rosetta-mainnet "$V" amd64 "mina-rosetta-generic (=$V), mina-mainnet-profile (=$V)"
  deb "$d" mina-rosetta-generic "$V" amd64
  # not release packages
  deb "$d" mina-mainnet-automode "$V" amd64 "mina-mainnet-prefork-mesa (=$LEGACY)"
  deb "$d" mina-mainnet-prefork-mesa "$LEGACY" amd64
  deb "$d" mina-test-suite "$V" amd64
  deb "$d" mina-daemon-recovery-storage-toolbox 3.3.0-x arm64
}

kept() { (cd "$1" && ls ./*.deb 2>/dev/null | sed 's|^\./||' | sort); }

expect_kept() {
  local dir="$1"; shift
  local want got
  want="$(printf '%s\n' "$@" | sort)"
  got="$(kept "$dir")"
  [[ "$want" == "$got" ]] && pass || fail "kept files differ:
want:
${want}
got:
${got}"
}

run() { CURRENT="$1"; echo "TEST: $1"; "$1"; }

test_default_roots_keep_the_dependency_closure() {
  local d="$WORK/t1/bookworm"
  mainnet_folder "$d"
  "$SCRIPT" "$d" > "$WORK/t1.log" 2>&1 || { fail "exit $?: $(cat "$WORK/t1.log")"; return; }
  expect_kept "$d" \
    "mina-mainnet_${V}_amd64.deb" "mina-mainnet-generic_${V}_amd64.deb" \
    "mina-mainnet-config_${V}_all.deb" "mina-mainnet-profile_${V}_amd64.deb" \
    "mina-generic_${V}_amd64.deb" "mina-logproc_${V}_amd64.deb" \
    "mina-archive-mainnet_${V}_amd64.deb" "mina-archive-generic_${V}_amd64.deb" \
    "mina-rosetta-mainnet_${V}_amd64.deb" "mina-rosetta-generic_${V}_amd64.deb"
  [[ -f "$WORK/t1/bookworm.excluded/mina-test-suite_${V}_amd64.deb" ]] && pass \
    || fail "excluded file not moved to the excluded folder"
}

# A legacy package stays only when a release package depends on it.
test_legacy_kept_only_when_depended_on() {
  local d="$WORK/t2/bookworm"
  mainnet_folder "$d"
  MINA_RELEASE_PACKAGES="mina-mainnet,mina-mainnet-automode" "$SCRIPT" "$d" > "$WORK/t2.log" 2>&1 \
    || { fail "exit $?: $(cat "$WORK/t2.log")"; return; }
  kept "$d" | grep -qx "mina-mainnet-prefork-mesa_${LEGACY}_amd64.deb" && pass \
    || fail "prefork the automode package depends on was dropped"
  kept "$d" | grep -q "mina-archive-mainnet" && fail "archive kept although not a root" || pass
}

# A dependency that is not in the folder makes the publish fail.
test_missing_dependency_fails() {
  local d="$WORK/t3/bookworm"
  mainnet_folder "$d"
  rm "$d/mina-mainnet-profile_${V}_amd64.deb"
  if "$SCRIPT" "$d" > "$WORK/t3.log" 2>&1; then
    fail "succeeded with a missing dependency"
  else
    grep -q "mina-mainnet-profile" "$WORK/t3.log" && pass || fail "error does not name the dependency"
  fi
}

test_unknown_requested_package_fails() {
  local d="$WORK/t4/bookworm"
  mainnet_folder "$d"
  if MINA_RELEASE_PACKAGES="mina-devnet" "$SCRIPT" "$d" > "$WORK/t4.log" 2>&1; then
    fail "succeeded with a requested package that is not in the folder"
  else
    pass
  fi
}

test_two_versions_of_a_root_fail() {
  local d="$WORK/t5/bookworm"
  mainnet_folder "$d"
  deb "$d" mina-mainnet 4.0.1-ffff000 amd64 "mina-mainnet-generic (=$V)"
  if "$SCRIPT" "$d" > "$WORK/t5.log" 2>&1; then
    fail "succeeded with two versions of mina-mainnet"
  else
    pass
  fi
}

run test_default_roots_keep_the_dependency_closure
run test_legacy_kept_only_when_depended_on
run test_missing_dependency_fails
run test_unknown_requested_package_fails
run test_two_versions_of_a_root_fail

echo
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -ne 0 ]]; then
  printf '  - %s\n' "${FAILURES[@]}"
  exit 1
fi
