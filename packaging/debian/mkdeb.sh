#!/usr/bin/env bash
# Builds one .deb from files that a dune rule has already built.
#
# Usage:
#   mkdeb.sh --output <file.deb> --package <name> --version <version>
#            --architecture <arch> --description <text>
#            [--depends <extra Depends>] [--replaces <pkgs>] [--breaks <pkgs>]
#            [--githash <hash>] [--buildurl <url>]
#            <source>:<destination> ... [--into <directory> <source> ...]
#
# <source>:<destination> installs <source> at <destination>. After
# --into <directory>, a <source> on its own is installed in <directory> under
# its own name. An ELF file or a script starting with #! is installed with
# mode 0755, and anything else with 0644, whatever the mode of <source>.
#
# --architecture is what the package must be built for, normally dune's
# %{architecture}: the target of the compiler that built the binaries. Every
# ELF file in the package is checked against it, so a binary built for a
# different architecture fails the build instead of being packaged. A package
# of --architecture all may hold no ELF file at all.
#
# The shared libraries the binaries need are found by dpkg-shlibdeps, from the
# libraries installed where the build runs. So a package built on bookworm
# depends on bookworm's library packages, and one built on jammy on jammy's.
# --depends adds dependencies that are not shared libraries.
#
# Codename is the VERSION_CODENAME of /etc/os-release, which is where the
# library dependencies come from.
#
# Files are owned by root and dated 1970-01-01, so the same inputs give the
# same package.

set -euo pipefail

output="" package="" version="" architecture="" description=""
depends="" replaces="" breaks="" githash="" buildurl="" into=""
installs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) output="$2"; shift 2 ;;
    --package) package="$2"; shift 2 ;;
    --version) version="$2"; shift 2 ;;
    --architecture) architecture="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    --depends) depends="$2"; shift 2 ;;
    --replaces) replaces="$2"; shift 2 ;;
    --breaks) breaks="$2"; shift 2 ;;
    --githash) githash="$2"; shift 2 ;;
    --buildurl) buildurl="$2"; shift 2 ;;
    --into) into="$2"; shift 2 ;;
    --*) echo "mkdeb: unknown option $1" >&2; exit 2 ;;
    *:*) installs+=("$1"); shift ;;
    *)
      if [[ -z "$into" ]]; then
        echo "mkdeb: $1 has no destination; give <source>:<destination> or --into" >&2
        exit 2
      fi
      installs+=("$1:${into%/}/$(basename "$1")"); shift ;;
  esac
done

for v in output package version architecture description; do
  if [[ -z "${!v}" ]]; then
    echo "mkdeb: --${v} is required" >&2
    exit 2
  fi
done

# The ELF machine names readelf prints for each Debian architecture.
case "$architecture" in
  amd64) elf_machine="Advanced Micro Devices X86-64" ;;
  arm64) elf_machine="AArch64" ;;
  all) elf_machine="" ;;
  *) echo "mkdeb: no Debian package architecture for '${architecture}'" >&2; exit 1 ;;
esac

# shellcheck disable=SC1091
codename=$(. /etc/os-release && echo "${VERSION_CODENAME:?}")

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
root="${work}/debian/${package}"
mkdir -p "${root}/DEBIAN"
chmod 0755 "$root"

elfs=()
for entry in "${installs[@]}"; do
  src="${entry%%:*}"
  dest="${entry#*:}"
  magic=$(head -c 4 "$src" | tr -d '\0')
  mode=0644
  if [[ "$magic" == $'\x7fELF' || "$magic" == '#!'* ]]; then
    mode=0755
  fi
  install -D -m "$mode" "$src" "${root}${dest}"
  if [[ "$magic" == $'\x7fELF' ]]; then
    machine=$(readelf -h "$src" | sed -n 's/^ *Machine: *//p')
    if [[ -z "$elf_machine" || "$machine" != "$elf_machine" ]]; then
      echo "mkdeb: ${src} is built for '${machine}', not ${architecture}" >&2
      exit 1
    fi
    elfs+=("${root}${dest}")
  fi
done

shlib_depends=""
if [[ ${#elfs[@]} -gt 0 ]]; then
  : > "${work}/debian/control"
  shlib_depends=$(cd "$work" && dpkg-shlibdeps -O "${elfs[@]/#${work}\//}" \
    | sed -n 's/^shlibs:Depends=//p')
fi
all_depends="${shlib_depends}${depends:+${shlib_depends:+, }${depends}}"

installed_size=$(du -sk --exclude=DEBIAN "$root" | cut -f1)

{
  echo "Package: ${package}"
  echo "Version: ${version}"
  echo "License: Apache-2.0"
  echo "Origin: MinaProtocol"
  echo "Label: MinaProtocol"
  echo "Vendor: O(1)Labs"
  echo "Codename: ${codename}"
  echo "Architecture: ${architecture}"
  echo "Maintainer: O(1)Labs <build@o1labs.org>"
  echo "Installed-Size: ${installed_size}"
  if [[ -n "$all_depends" ]]; then
    echo "Depends: ${all_depends}"
  fi
  if [[ -n "$replaces" ]]; then
    echo "Replaces: ${replaces}"
  fi
  if [[ -n "$breaks" ]]; then
    echo "Breaks: ${breaks}"
  fi
  echo "Section: base"
  echo "Priority: optional"
  echo "Homepage: https://minaprotocol.com/"
  echo "Description: ${description}"
  if [[ -n "$githash" ]]; then
    echo " Built from ${githash}${buildurl:+ by ${buildurl}}"
  fi
} > "${root}/DEBIAN/control"

find "$root" -exec touch -h -d @0 {} +
SOURCE_DATE_EPOCH=0 dpkg-deb --root-owner-group -Zgzip --build "$root" "$output" >/dev/null
