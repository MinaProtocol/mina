#!/bin/sh
# Find the Debian package files that an image must install.
#
# The Docker build installs the Mina packages from files in the build context,
# not from an apt repository. This script changes a list of "name=version" into
# a list of paths, so that each Dockerfile keeps a readable list of packages and
# only this script knows how a package file is named.
#
# Usage: deb-files.sh <deb-dir> <name=version> [<name=version> ...]
#
#   A specification that starts with "?" is optional: if no file matches, the
#   script writes a note on stderr and continues. Use it for a package that the
#   build gives only in some conditions, such as the storage repair package.
#
# The file name of a Debian package is "<name>_<version>_<arch>.deb". The
# architecture is not known here (it is amd64, arm64 or all), so the script
# matches it with a pattern.
#
# Example:
#   apt-get install $(deb-files.sh /debs "mina-devnet=3.1.0-abc" "?mina-x=3.1.0")

set -eu

if [ "$#" -lt 2 ]; then
    echo "deb-files.sh: usage: deb-files.sh <deb-dir> <name=version> ..." >&2
    exit 1
fi

DEB_DIR="$1"
shift

if [ ! -d "$DEB_DIR" ]; then
    echo "deb-files.sh: '$DEB_DIR' is not a directory." >&2
    exit 1
fi

FILES=""
MISSING=""

for spec in "$@"; do
    optional=0
    case "$spec" in
        \?*) optional=1; spec="${spec#?}" ;;
    esac

    name="${spec%%=*}"
    version="${spec#*=}"

    # An empty name or version means that the caller gave no value for a build
    # argument. Such a package is not requested at all.
    if [ -z "$name" ] || [ -z "$version" ] || [ "$name" = "$spec" ]; then
        if [ "$optional" -eq 1 ]; then
            continue
        fi
        echo "deb-files.sh: '$spec' is not in the form name=version." >&2
        exit 1
    fi

    # The architecture is not known, so match it.
    match=""
    for candidate in "$DEB_DIR/${name}_${version}_"*.deb; do
        if [ -f "$candidate" ]; then
            match="$candidate"
            break
        fi
    done

    if [ -n "$match" ]; then
        FILES="${FILES} ${match}"
    elif [ "$optional" -eq 1 ]; then
        echo "deb-files.sh: optional package ${name}=${version} is not in ${DEB_DIR}, skipping." >&2
    else
        MISSING="${MISSING} ${name}=${version}"
    fi
done

if [ -n "$MISSING" ]; then
    echo "deb-files.sh: these packages are not in ${DEB_DIR}:${MISSING}" >&2
    echo "deb-files.sh: the directory holds:" >&2
    found=0
    for f in "$DEB_DIR"/*.deb; do
        if [ -f "$f" ]; then
            echo "  $(basename "$f")" >&2
            found=1
        fi
    done
    [ "$found" -eq 1 ] || echo "  (no .deb file)" >&2
    exit 1
fi

echo "${FILES# }"
