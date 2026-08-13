#!/usr/bin/env bash

# Test published Mina Debian packages and Docker images across distribution codenames.
#
# For each package it starts a clean container of the matching base image, adds the
# apt repository, installs the package at an exact version and runs a check that
# suits that package. For each Docker image it pulls the image and runs the same
# check inside it.
#
# The check is chosen by package kind, not by name alone, because the artifacts do
# not all provide the same binaries:
#
#   daemon      /usr/local/bin/mina, plus config_<hash>.json matching the binary
#   archive     mina-archive
#   rosetta     mina-rosetta and mina-ocaml-signer (the deb ships no mina binary;
#               the docker image does, and is then checked for it too)
#   logproc     mina-logproc
#   payload     a runtime-only package: /usr/lib/mina/<runtime>/mina, no mina on PATH
#   dispatcher  /usr/local/bin/mina is the automode dispatcher, which needs
#               MINA_HARDFORK_STATE_DIR before it will run
#   config      configuration only, no binaries
#
# Applying the daemon check to a payload or rosetta package produces a failure that
# says nothing about the package. This script avoids that class of false result.
#
# Usage:
#   ./scripts/verify/test-release.sh --packages mina-devnet=3.5.0-x,mina-logproc=3.5.0-x
#   ./scripts/verify/test-release.sh --list --channel alpha
#   ./scripts/verify/test-release.sh --automode mina-devnet-automode=4.0.0-x

set -eo pipefail

REPO=packages.o1test.net
CHANNEL=alpha
DOCKER_REPO=minaprotocol
DOCKER_SUFFIX="-devnet"
CODENAMES="bullseye,focal,noble,jammy,bookworm"
ARCH=amd64
JOBS=4
PACKAGES=""
IMAGES=""
AUTOMODE=""
OUTDIR=""
SIGNED=0
LIST_ONLY=0

function usage() {
  if [[ -n "$1" ]]; then echo "ERROR: $1"; echo; fi
  echo "Usage: $0 [options]"
  echo
  echo "  -p, --packages    Comma list of debian packages as name=version, or a bare"
  echo "                    name to test whatever the channel currently offers"
  echo "  -i, --images      Comma list of docker images as name=version"
  echo "  -a, --automode    Automode metapackage as name=version. Installs it with no"
  echo "                    version pin and checks both runtimes, the genesis config"
  echo "                    and the dispatcher. This is the operator-facing test."
  echo "  -m, --codenames   Comma list of codenames (default: $CODENAMES)"
  echo "  -c, --channel     Debian channel/component (default: $CHANNEL)"
  echo "  -r, --repo        Debian repository host (default: $REPO)"
  echo "      --docker-repo Docker registry namespace (default: $DOCKER_REPO)"
  echo "      --suffix      Docker tag suffix after the codename (default: $DOCKER_SUFFIX)"
  echo "      --arch        Architecture (default: $ARCH)"
  echo "  -j, --jobs        Containers to run at once (default: $JOBS)"
  echo "  -o, --output      Directory for logs (default: a mktemp directory)"
  echo "  -s, --signed      Use the repository signing key instead of [trusted=yes]"
  echo "  -l, --list        Only list what the channel holds, then exit"
  echo "  -h, --help        This message"
  echo
  echo "Exit code is 1 if any case fails. Cases that cannot apply are reported as SKIP"
  echo "and do not fail the run."
  echo
  echo "Examples:"
  echo "  $0 --list --channel alpha --codenames bullseye"
  echo "  $0 --packages mina-devnet=3.5.0-devnet-stop-slot-98e7835 \\"
  echo "     --images mina-daemon=3.5.0-devnet-stop-slot-98e7835 \\"
  echo "     --automode mina-devnet-automode=4.0.0-devnet-ca2ccb1"
  exit 1
}

while [[ "$#" -gt 0 ]]; do case $1 in
  -p|--packages) PACKAGES="$2"; shift;;
  -i|--images) IMAGES="$2"; shift;;
  -a|--automode) AUTOMODE="$2"; shift;;
  -m|--codenames) CODENAMES="$2"; shift;;
  -c|--channel) CHANNEL="$2"; shift;;
  -r|--repo) REPO="$2"; shift;;
  --docker-repo) DOCKER_REPO="$2"; shift;;
  --suffix) DOCKER_SUFFIX="$2"; shift;;
  --arch) ARCH="$2"; shift;;
  -j|--jobs) JOBS="$2"; shift;;
  -o|--output) OUTDIR="$2"; shift;;
  -s|--signed) SIGNED=1;;
  -l|--list) LIST_ONLY=1;;
  -h|--help) usage "";;
  *) usage "Unknown parameter: $1";;
esac; shift; done

if ! command -v docker > /dev/null; then usage "docker is required but not installed"; fi

if [[ -z "$OUTDIR" ]]; then OUTDIR=$(mktemp -d "${TMPDIR:-/tmp}/mina-test-release.XXXXXX"); fi
mkdir -p "$OUTDIR/logs"
RESULTS="$OUTDIR/results.tsv"
: > "$RESULTS"

# Base image for a codename. Debian and Ubuntu codenames are not interchangeable.
function base_image() {
  case "$1" in
    bullseye|bookworm) echo "debian:$1" ;;
    focal|noble|jammy) echo "ubuntu:$1" ;;
    *) echo "" ;;
  esac
}

# Package kind, which decides the check. Order matters: the automode and postfork
# packages own the dispatcher, so they must be matched before the generic daemon rule.
function package_kind() {
  case "$1" in
    *-automode|*-postfork-*)  echo "dispatcher" ;;
    *-prefork-*)              echo "payload" ;;
    *-config)                 echo "config" ;;
    mina-archive*)            echo "archive" ;;
    mina-rosetta*)            echo "rosetta" ;;
    mina-logproc)             echo "logproc" ;;
    mina-daemon)              echo "daemon" ;;
    mina-*)                   echo "daemon" ;;
    *)                        echo "unknown" ;;
  esac
}

# Runtime libraries a package needs but does not declare in its control file.
#
# The rosetta deb is built with the shared dependencies alone, so its Depends
# names none of jemalloc, libpq or libffi, although both binaries it ships link
# against all three:
#
#   ldd mina-rosetta -> libjemalloc.so.2, libpq.so.5, libffi.so.7
#
# In a clean container the binary therefore stops at the first of them:
#
#   error while loading shared libraries: libjemalloc.so.2
#
# That is a known packaging defect and it is not fixed yet. Installing the
# libraries before the package keeps this test on the question it can answer,
# which is whether the published binary itself runs. The docker image ships them
# already, which is why the same check passes there.
#
# libffi comes in under two names, as in the daemon dependencies in
# scripts/debian/builder-helpers.sh: libffi7 on bullseye and focal, libffi8 on
# the newer codenames. It is usually pulled in anyway by wget or gnupg, but that
# is a side effect of another package and not something to depend on.
#
# Remove the rosetta entry when the deb declares these libraries itself.
function extra_deps() {
  local kind="$1" codename="$2" ffi

  case "$codename" in
    bullseye|focal) ffi=libffi7 ;;
    *)              ffi=libffi8 ;;
  esac

  case "$kind" in
    rosetta) echo "libjemalloc2 libpq5 $ffi" ;;
    *)       echo "" ;;
  esac
}

# A spec is "name=version" or a bare "name". A bare name means "whatever the
# channel offers right now", which is what a recurring schedule wants: it never
# needs editing after a release, and it tests what a user would actually get.
function spec_version() {
  case "$1" in
    *=*) echo "${1#*=}" ;;
    *)   echo "any" ;;
  esac
}

function record() {
  # status <tab> area <tab> codename <tab> target <tab> detail
  printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" >> "$RESULTS"
}

# ---------------------------------------------------------------------------
# The in-container checker. It is written once and mounted read-only into every
# container, so the same logic runs for debians and for docker images.
# ---------------------------------------------------------------------------

CHECKER="$OUTDIR/container-check.sh"
cat > "$CHECKER" <<'CHECKER_EOF'
#!/usr/bin/env bash
# Args: <kind> <context: deb|docker> [package] [strict_runtimes: yes|no]
#
# strict_runtimes applies to the dispatcher kind only. The automode metapackage
# pulls in both runtimes, so it is checked with "yes" and must have both. A bare
# postfork package ships the post-fork runtime alone and relies on the metapackage
# to bring the pre-fork one, so it is checked with "no": a missing pre-fork runtime
# is then reported as a warning about the installation, not a fault in the package.
set -uo pipefail

KIND="$1"
CONTEXT="$2"
PKG="${3:-}"
STRICT_RUNTIMES="${4:-no}"
rc=0

function fail() { echo "CHECK-FAIL: $*"; rc=1; }
function ok()   { echo "CHECK-OK: $*"; }

function binary_runs() {
  local bin="$1"
  if ! command -v "$bin" > /dev/null 2>&1 && [[ ! -x "$bin" ]]; then
    fail "$bin is not installed"
    return 1
  fi
  if ! "$bin" --version > /tmp/ver.out 2>&1; then
    fail "$bin --version exited non-zero: $(head -1 /tmp/ver.out)"
    return 1
  fi
  ok "$bin --version -> $(head -1 /tmp/ver.out)"
  return 0
}

# The daemon auto-loads /var/lib/coda/config_<hash>.json, where <hash> is the short
# commit of the daemon that should read it. A mismatch means the package pair was
# built against a different commit than the one installed.
function config_matches() {
  local commit="$1"
  local cfg
  cfg=$(ls /var/lib/coda/config_*.json 2>/dev/null | head -1)
  if [[ -z "$cfg" ]]; then
    echo "CHECK-INFO: no genesis config shipped, skipping config match"
    return 0
  fi
  local hash
  hash=$(basename "$cfg" | sed 's/config_\(.*\)\.json/\1/')
  if [[ "${commit:0:${#hash}}" == "$hash" ]]; then
    ok "genesis config $(basename "$cfg") matches commit ${commit:0:8}"
  else
    fail "genesis config $(basename "$cfg") does not match commit ${commit:0:8}"
  fi
}

function commit_of() {
  "$1" --version 2>&1 | grep -oE '[a-f0-9]{40}' | head -1
}

case "$KIND" in
  daemon)
    binary_runs mina && config_matches "$(commit_of mina)"
    ;;

  archive)
    binary_runs mina-archive
    ;;

  rosetta)
    binary_runs mina-rosetta
    binary_runs mina-ocaml-signer
    # The deb ships no mina or mina-archive. The docker image does. Check them only
    # where they exist, so the deb is not failed for something it never shipped.
    if [[ "$CONTEXT" == "docker" ]]; then
      binary_runs mina
      binary_runs mina-archive
    else
      for extra in mina mina-archive; do
        if command -v "$extra" > /dev/null 2>&1; then
          echo "CHECK-INFO: $extra present in the deb (not required)"
        fi
      done
    fi
    ;;

  logproc)
    if ! command -v mina-logproc > /dev/null 2>&1; then
      fail "mina-logproc is not installed"
    else
      ok "mina-logproc is installed at $(command -v mina-logproc)"
    fi
    ;;

  payload)
    # A runtime-only package. It must not put mina on PATH; it must ship a runtime.
    found=0
    for rt in /usr/lib/mina/*/; do
      [[ -x "${rt}mina" ]] || continue
      found=1
      if v=$("${rt}mina" --version 2>&1); then
        ok "runtime $(basename "$rt") -> $(echo "$v" | head -1)"
      else
        fail "runtime $(basename "$rt") mina --version failed"
      fi
    done
    [[ "$found" == 1 ]] || fail "no runtime found under /usr/lib/mina/"
    if command -v mina > /dev/null 2>&1; then
      echo "CHECK-INFO: mina is on PATH; this package usually provides none"
    fi
    ;;

  dispatcher)
    [[ -x /usr/local/bin/mina ]] || fail "/usr/local/bin/mina is missing"

    # Inventory the runtimes first. What the dispatcher can do depends on which of
    # them are installed, so the checks below have to know before they judge.
    pre=""; post=""
    for rt in /usr/lib/mina/*/; do
      [[ -x "${rt}mina" ]] || continue
      c=$(commit_of "${rt}mina")
      if [[ -z "$c" ]]; then
        fail "runtime $(basename "$rt") reports no commit"
      else
        ok "runtime $(basename "$rt") = ${c:0:8}"
      fi
      case "$(basename "$rt")" in
        berkeley) pre="$c" ;;
        *) post="$c" ;;
      esac
    done

    if [[ "$STRICT_RUNTIMES" == "yes" ]]; then
      [[ -n "$pre" ]]  || fail "no pre-fork (berkeley) runtime installed"
      [[ -n "$post" ]] || fail "no post-fork runtime installed"
      # Two identical runtimes mean the wrong deb pair was installed and the
      # hardfork cannot happen, even though every other check would pass.
      if [[ -n "$pre" && "$pre" == "$post" ]]; then
        fail "both runtimes report the same commit ${pre:0:8}; the deb pair is wrong"
      fi
    else
      [[ -n "$post" ]] || fail "no post-fork runtime installed"
      if [[ -z "$pre" ]]; then
        echo "CHECK-WARN: no pre-fork runtime installed, so the dispatcher cannot select one; install the automode metapackage for a working mina"
      fi
    fi

    # The dispatcher documents --version as a pass-through to the runtime, but it
    # stops at its environment guard first. Report the bare call, then require the
    # supported call to work whenever the runtime it would select is present.
    if [[ -x /usr/local/bin/mina ]]; then
      if ! mina --version > /tmp/bare.out 2>&1; then
        echo "CHECK-WARN: mina --version fails without MINA_HARDFORK_STATE_DIR: $(head -1 /tmp/bare.out)"
      else
        ok "mina --version works without MINA_HARDFORK_STATE_DIR"
      fi

      if [[ -n "$pre" ]]; then
        export MINA_HARDFORK_STATE_DIR="${MINA_HARDFORK_STATE_DIR:-/root/.mina-config}"
        binary_runs mina
      fi
    fi

    # The genesis config the post-fork package ships belongs to the pre-fork
    # runtime, because that is the one that runs first. Check it only when that
    # runtime is actually installed, or the comparison has nothing to compare to.
    if [[ -n "$pre" ]]; then
      config_matches "$pre"
    fi
    ;;

  config)
    if ls /var/lib/coda/*.json > /dev/null 2>&1 || ls /etc/mina* > /dev/null 2>&1; then
      ok "configuration files present"
    else
      fail "package $PKG shipped no configuration"
    fi
    ;;

  *)
    echo "CHECK-INFO: no check defined for kind '$KIND', install-only"
    ;;
esac

exit $rc
CHECKER_EOF
chmod +x "$CHECKER"

# ---------------------------------------------------------------------------
# Debian setup, run inside the container before the checker.
# ---------------------------------------------------------------------------

SETUP="$OUTDIR/container-setup.sh"
cat > "$SETUP" <<'SETUP_EOF'
#!/usr/bin/env bash
# Args: <package> <version> <repo> <codename> <channel> <signed> [extra deps]
#
# extra_deps is a space separated list of distribution packages to install first.
# It carries the runtime libraries that a mina package needs but does not declare.
# See extra_deps() in the calling script for why each one is there.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC

PACKAGE="$1"; VERSION="$2"; REPO="$3"; CODENAME="$4"; CHANNEL="$5"; SIGNED="$6"
EXTRA_DEPS="${7:-}"

apt-get update -qq
apt-get install -y -qq ca-certificates wget gnupg > /dev/null

if [[ "$SIGNED" == "1" ]]; then
  wget -q "https://${REPO}/repo-signing-key.gpg" -O /etc/apt/trusted.gpg.d/minaprotocol.gpg
  echo "deb https://${REPO} ${CODENAME} ${CHANNEL}" > /etc/apt/sources.list.d/mina.list
else
  echo "deb [trusted=yes] https://${REPO} ${CODENAME} ${CHANNEL}" > /etc/apt/sources.list.d/mina.list
fi
apt-get update -qq

# Undeclared runtime libraries, installed before the package so that the check
# reports on the mina binary and not on a dependency the control file omits.
if [[ -n "$EXTRA_DEPS" ]]; then
  echo "PREREQ: apt-get install ${EXTRA_DEPS}"
  # shellcheck disable=SC2086
  apt-get install -y -qq $EXTRA_DEPS > /dev/null
fi

# "any" installs whatever the channel currently offers, which is exactly what a
# user gets from "apt-get install <package>". A recurring job should use it, so
# the schedule does not carry version numbers that go stale after each release.
if [[ "$VERSION" == "any" ]]; then
  echo "INSTALL: apt-get install ${PACKAGE} (channel candidate)"
  apt-get install -y "${PACKAGE}"
else
  echo "INSTALL: apt-get install ${PACKAGE}=${VERSION}"
  apt-get install -y --allow-downgrades "${PACKAGE}=${VERSION}"
fi

# Record what was really installed, so a run that pinned nothing still says
# exactly which version it tested.
echo "INSTALLED-VERSION: $(dpkg-query -W -f='${Version}' "$PACKAGE" 2>/dev/null || echo unknown)"
echo "INSTALL-OK"
SETUP_EOF
chmod +x "$SETUP"

# ---------------------------------------------------------------------------
# List mode
# ---------------------------------------------------------------------------

if [[ "$LIST_ONLY" == 1 ]]; then
  IFS=',' read -ra CN_LIST <<< "$CODENAMES"
  for cn in "${CN_LIST[@]}"; do
    echo "=== $cn / $CHANNEL / $ARCH"
    curl -sL "https://${REPO}/dists/${cn}/${CHANNEL}/binary-${ARCH}/Packages.gz" \
      | gunzip 2>/dev/null \
      | awk '/^Package: /{p=$2} /^Version: /{printf "  %-32s %s\n", p, $2}' \
      | sort -u
  done
  exit 0
fi

if [[ -z "$PACKAGES" && -z "$IMAGES" && -z "$AUTOMODE" ]]; then
  usage "Nothing to test. Pass --packages, --images or --automode."
fi

# ---------------------------------------------------------------------------
# Case runners. Each writes one line to the results file.
# ---------------------------------------------------------------------------

function run_deb_case() {
  local cn="$1" pkg="$2" ver="$3"
  local img kind log extra note
  img=$(base_image "$cn")
  kind=$(package_kind "$pkg")
  extra=$(extra_deps "$kind" "$cn")
  log="$OUTDIR/logs/deb__${cn}__${pkg}.log"

  # Say in the report which libraries the test had to add, so a pass here is not
  # read as "the package declares everything it needs".
  note="kind=$kind"
  if [[ -n "$extra" ]]; then note="$note, prereq=${extra// /+}"; fi

  if [[ -z "$img" ]]; then
    record "SKIP" "debian" "$cn" "$pkg" "unknown codename"
    return 0
  fi

  if docker run --rm --platform "linux/$ARCH" \
      -v "$SETUP:/mina/setup.sh:ro" -v "$CHECKER:/mina/check.sh:ro" \
      "$img" \
      bash -c "bash /mina/setup.sh '$pkg' '$ver' '$REPO' '$cn' '$CHANNEL' '$SIGNED' '$extra' && bash /mina/check.sh '$kind' deb '$pkg' no" \
      > "$log" 2>&1; then
    local warn installed
    warn=$(grep -c "CHECK-WARN" "$log" || true)
    installed=$(grep -m1 'INSTALLED-VERSION:' "$log" | cut -d' ' -f2- || true)
    if [[ "$warn" -gt 0 ]]; then
      record "WARN" "debian" "$cn" "$pkg" "${installed:-?} :: $(grep -m1 'CHECK-WARN' "$log" | cut -c13-)"
    else
      record "PASS" "debian" "$cn" "$pkg" "${installed:-?} ($note)"
    fi
  else
    local reason
    if grep -q "unmet dependencies" "$log"; then
      reason=$(grep -A2 "unmet dependencies" "$log" | tail -1 | sed 's/^ *//')
      record "FAIL" "debian" "$cn" "$pkg" "install: $reason"
    elif grep -q "CHECK-FAIL" "$log"; then
      record "FAIL" "debian" "$cn" "$pkg" "$(grep -m1 'CHECK-FAIL' "$log" | cut -c13-)"
    else
      record "FAIL" "debian" "$cn" "$pkg" "see $(basename "$log")"
    fi
  fi
}

function run_docker_case() {
  local cn="$1" image="$2" ver="$3"
  local tag kind log
  tag="${DOCKER_REPO}/${image}:${ver}-${cn}${DOCKER_SUFFIX}"
  case "$image" in
    mina-daemon*)  kind="daemon" ;;
    mina-archive*) kind="archive" ;;
    mina-rosetta*) kind="rosetta" ;;
    *)             kind=$(package_kind "$image") ;;
  esac
  log="$OUTDIR/logs/docker__${cn}__${image}.log"

  if ! docker manifest inspect "$tag" > /dev/null 2>&1; then
    record "FAIL" "docker" "$cn" "$image" "tag does not exist: $tag"
    return 0
  fi

  if docker run --rm --platform "linux/$ARCH" --entrypoint bash \
      -v "$CHECKER:/mina/check.sh:ro" "$tag" /mina/check.sh "$kind" docker "$image" \
      > "$log" 2>&1; then
    record "PASS" "docker" "$cn" "$image" "kind=$kind"
  else
    record "FAIL" "docker" "$cn" "$image" "$(grep -m1 'CHECK-FAIL' "$log" | cut -c13- || echo "see $(basename "$log")")"
  fi
}

# The operator-facing test: install the metapackage with no version pin. If the
# channel holds a higher version of a strictly pinned dependency, this fails even
# though every individual package is sound.
function run_automode_case() {
  local cn="$1" pkg="$2" ver="$3"
  local img log
  img=$(base_image "$cn")
  log="$OUTDIR/logs/automode__${cn}.log"

  if docker run --rm --platform "linux/$ARCH" \
      -v "$SETUP:/mina/setup.sh:ro" -v "$CHECKER:/mina/check.sh:ro" \
      "$img" \
      bash -c "bash /mina/setup.sh '$pkg' '$ver' '$REPO' '$cn' '$CHANNEL' '$SIGNED' && bash /mina/check.sh dispatcher deb '$pkg' yes" \
      > "$log" 2>&1; then
    local warn
    warn=$(grep -c "CHECK-WARN" "$log" || true)
    if [[ "$warn" -gt 0 ]]; then
      record "WARN" "automode" "$cn" "$pkg" "$(grep -m1 'CHECK-WARN' "$log" | cut -c13-)"
    else
      record "PASS" "automode" "$cn" "$pkg" "unpinned install and both runtimes"
    fi
  else
    if grep -q "unmet dependencies" "$log"; then
      record "FAIL" "automode" "$cn" "$pkg" "unpinned install failed: $(grep -A2 'unmet dependencies' "$log" | tail -1 | sed 's/^ *//')"
    else
      record "FAIL" "automode" "$cn" "$pkg" "$(grep -m1 'CHECK-FAIL' "$log" | cut -c13- || echo "see $(basename "$log")")"
    fi
  fi
}

export -f run_deb_case run_docker_case run_automode_case base_image package_kind extra_deps record
export OUTDIR RESULTS SETUP CHECKER REPO CHANNEL ARCH SIGNED DOCKER_REPO DOCKER_SUFFIX

# ---------------------------------------------------------------------------
# Build the work list and run it
# ---------------------------------------------------------------------------

WORK="$OUTDIR/work.txt"
: > "$WORK"

IFS=',' read -ra CN_LIST <<< "$CODENAMES"

if [[ -n "$PACKAGES" ]]; then
  IFS=',' read -ra PKG_LIST <<< "$PACKAGES"
  for cn in "${CN_LIST[@]}"; do
    for spec in "${PKG_LIST[@]}"; do
      printf 'run_deb_case %s %s %s\n' "$cn" "${spec%%=*}" "$(spec_version "$spec")" >> "$WORK"
    done
  done
fi

if [[ -n "$IMAGES" ]]; then
  IFS=',' read -ra IMG_LIST <<< "$IMAGES"
  for cn in "${CN_LIST[@]}"; do
    for spec in "${IMG_LIST[@]}"; do
      if [[ "$spec" != *=* ]]; then
        usage "Docker image '$spec' needs an explicit version; a tag has no channel to resolve against."
      fi
      printf 'run_docker_case %s %s %s\n' "$cn" "${spec%%=*}" "${spec#*=}" >> "$WORK"
    done
  done
fi

if [[ -n "$AUTOMODE" ]]; then
  for cn in "${CN_LIST[@]}"; do
    printf 'run_automode_case %s %s %s\n' "$cn" "${AUTOMODE%%=*}" "$(spec_version "$AUTOMODE")" >> "$WORK"
  done
fi

TOTAL=$(wc -l < "$WORK")
echo "Running $TOTAL cases, $JOBS at a time. Logs: $OUTDIR/logs"
echo

# shellcheck disable=SC2016
xargs -a "$WORK" -P "$JOBS" -n 4 bash -c '"$0" "$1" "$2" "$3"' || true

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo
echo "===================================================================="
printf '%-9s %-9s %-10s %-28s %s\n' "STATUS" "AREA" "CODENAME" "TARGET" "DETAIL"
echo "--------------------------------------------------------------------"
sort -k2,2 -k4,4 -k3,3 "$RESULTS" | while IFS=$'\t' read -r st area cn target detail; do
  printf '%-9s %-9s %-10s %-28s %s\n' "$st" "$area" "$cn" "$target" "$detail"
done
echo "--------------------------------------------------------------------"

PASS=$(grep -c '^PASS' "$RESULTS" || true)
WARN=$(grep -c '^WARN' "$RESULTS" || true)
FAILED=$(grep -c '^FAIL' "$RESULTS" || true)
SKIPPED=$(grep -c '^SKIP' "$RESULTS" || true)

echo "PASS $PASS   WARN $WARN   FAIL $FAILED   SKIP $SKIPPED   (of $TOTAL)"
echo "Results: $RESULTS"
echo "Logs:    $OUTDIR/logs"

if [[ "$FAILED" -gt 0 ]]; then
  echo
  echo "Failures:"
  grep '^FAIL' "$RESULTS" | while IFS=$'\t' read -r _ area cn target detail; do
    echo "  $area $cn $target: $detail"
  done
  exit 1
fi

exit 0
