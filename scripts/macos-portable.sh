#!/bin/bash

# Create a portable Coda build by rewriting the dynamic library loading to look
# in the current working directory.

set -eou pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <path-to-coda.exe> <path-to-kademlia-binary> <outdir>"
  exit 1
fi

LOCAL_CODA_EXE="$(basename "$1")"
LOCAL_KADEMLIA="$(basename "$2")"
DIST_DIR="$3"

mkdir -p "$DIST_DIR"

cp "$1" "$DIST_DIR/$LOCAL_CODA_EXE"
cp "$2" "$DIST_DIR/$LOCAL_KADEMLIA"
chmod +w "$DIST_DIR/$LOCAL_KADEMLIA"

pushd "$DIST_DIR"

# Set of libraries and binaries we've already rewritten the tables
SEEN=("")

# `containsElement e array` returns 0 iff e is in the array
# from https://stackoverflow.com/questions/3685970/check-if-a-bash-array-contains-a-value
containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

# Rewrite the libraries' and binaries' dylib names
fixup() {
  local BIN="$1"

  local LIBS=$(otool -l "$BIN" | grep -E '\s+name' | grep -E '/local' | awk '{print $2}')

  echo "$LIBS" | while read lib; do
    local LOCAL_LIB="$(basename $lib)"
    if ! containsElement "$LOCAL_LIB" "${SEEN[@]}"; then
      cp -n "$lib" "$LOCAL_LIB" \
        && echo "Moving and rewriting $lib" \
        || echo "Already copied $lib" # no clobber in case we've already moved this lib
      chmod +w "$LOCAL_LIB"
      install_name_tool -change "$lib" "@executable_path/$(basename $lib)" "$BIN" || exit 1
      # Add to our seen set, by adding to the array and then filtering dupes
      SEEN+=("$BIN")
      SEEN=($(for v in "${SEEN[@]}"; do echo "$v";done | sort | uniq | xargs))
      # Recursively call for this lib
      fixup "$LOCAL_LIB"
    fi
  done
}

# Start with coda.exe
fixup "$LOCAL_CODA_EXE"

# Fixup kademlia
K_LIBS=$(otool -l kademlia | grep -E '\s+name' | grep '/nix' | grep -v '\-osx\-' | awk '{print $2}')
echo "$K_LIBS" | while read lib; do
  # we already have all the libs from coda.exe thankfully
  install_name_tool -change "$lib" "@executable_path/$(basename $lib)" "$LOCAL_KADEMLIA"
done

