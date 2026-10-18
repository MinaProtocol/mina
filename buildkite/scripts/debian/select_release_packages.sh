#!/usr/bin/env bash
# Keep only the release packages and their mina dependencies in a folder of
# .deb files, and move everything else out of it.
#
# Usage: select_release_packages.sh <deb-folder> [<excluded-folder>]
#
# Roots: MINA_RELEASE_PACKAGES (comma separated package names), or by default
# every one of the release packages below that is present in the folder. A
# folder that holds one network's build has only that network's roots.
#
# From the roots, every `mina-* (= <version>)` dependency is followed. Each
# (name, version) reached must be in the folder, else the script fails: a
# published package whose dependency is not published cannot be installed.
# Files that are not reached (test tools, legacy packages nothing depends on,
# other architectures) are moved to <excluded-folder> and listed.

set -euo pipefail

DEFAULT_ROOTS=(
  mina-devnet mina-mainnet
  mina-archive-devnet mina-archive-mainnet
  mina-rosetta-devnet mina-rosetta-mainnet
  mina-logproc
)

folder="${1:?usage: $0 <deb-folder> [<excluded-folder>]}"
excluded="${2:-${folder%/}.excluded}"

declare -A file_of=()      # "name=version" -> file
declare -A versions_of=()  # name -> space separated versions
declare -A depends_of=()   # "name=version" -> Depends field

shopt -s nullglob
for f in "${folder}"/*.deb; do
  name="" version="" depends=""
  while IFS= read -r line; do
    case "$line" in
      Package:*) name="${line#Package: }" ;;
      Version:*) version="${line#Version: }" ;;
      Depends:*) depends="${line#Depends: }" ;;
    esac
  done < <(dpkg-deb -f "$f" Package Version Depends)
  if [[ -z "$name" || -z "$version" ]]; then
    echo "❌ ${f}: no Package or Version in the control file" >&2
    exit 1
  fi
  file_of["${name}=${version}"]="$f"
  versions_of["$name"]="${versions_of[$name]:-} ${version}"
  depends_of["${name}=${version}"]="$depends"
done
shopt -u nullglob

roots=()
if [[ -n "${MINA_RELEASE_PACKAGES:-}" ]]; then
  IFS=',' read -ra roots <<< "${MINA_RELEASE_PACKAGES// /}"
  for r in "${roots[@]}"; do
    if [[ -z "${versions_of[$r]:-}" ]]; then
      echo "❌ release package ${r} (MINA_RELEASE_PACKAGES) is not in ${folder}" >&2
      exit 1
    fi
  done
else
  for r in "${DEFAULT_ROOTS[@]}"; do
    [[ -n "${versions_of[$r]:-}" ]] && roots+=("$r")
  done
fi

if [[ ${#roots[@]} -eq 0 ]]; then
  echo "❌ no release package found in ${folder}" >&2
  exit 1
fi

# One Depends entry with an exact version: "mina-foo (= 1.2.3-abc)".
EXACT_DEP_RE='^[[:space:]]*(mina[a-z0-9.+-]*)[[:space:]]*\([[:space:]]*=[[:space:]]*([^[:space:])]+)[[:space:]]*\)'

declare -A keep=()
queue=()
for r in "${roots[@]}"; do
  read -ra vs <<< "${versions_of[$r]}"
  if [[ ${#vs[@]} -ne 1 ]]; then
    echo "❌ ${r} has more than one version in ${folder}: ${vs[*]}" >&2
    exit 1
  fi
  queue+=("${r}=${vs[0]}")
done

missing=0
while [[ ${#queue[@]} -gt 0 ]]; do
  key="${queue[0]}"
  queue=("${queue[@]:1}")
  [[ -n "${keep[$key]:-}" ]] && continue
  if [[ -z "${file_of[$key]:-}" ]]; then
    echo "❌ dependency ${key%%=*} (= ${key#*=}) is not in ${folder}" >&2
    missing=1
    continue
  fi
  keep["$key"]=1
  IFS=',' read -ra deps <<< "${depends_of[$key]}"
  for d in "${deps[@]}"; do
    if [[ "$d" =~ $EXACT_DEP_RE ]]; then
      queue+=("${BASH_REMATCH[1]}=${BASH_REMATCH[2]}")
    fi
  done
done
[[ "$missing" -eq 0 ]] || exit 1

mkdir -p "$excluded"
echo "Release packages in ${folder} (roots: ${roots[*]}):"
for key in "${!file_of[@]}"; do
  if [[ -n "${keep[$key]:-}" ]]; then
    echo "  + $(basename "${file_of[$key]}")"
  else
    mv "${file_of[$key]}" "$excluded/"
    echo "  - $(basename "${file_of[$key]}") (not a release package or dependency)"
  fi
done | sort
