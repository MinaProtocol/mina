#!/bin/bash

# xcode technique to rewrite dynamic lib links
# tweaks kademlia binaries built with nix to work with os installed libs

check_file() {
  mybin="$1"
  if [ ! -f ${mybin} ]; then
    echo "ERROR: ${mybin} missing"
    exit 1
  fi
}

# Allow for specific target
TARGET=${1:-kademlia}

# check for xcode tools
for mybin in /usr/bin/install_name_tool /usr/bin/otool
do
  check_file $mybin
done

BUILD_DIR_NAME=package

# Swap nix libs for brew libs (ugly hack)
rewrite_lib() {
  TARGET="$1"
  LIB_NAME="$2"
  NEW_PATH="$3"
  # build env may not have these libs
  #check_file ${NEW_PATH}
  OLD_PATH=$(/usr/bin/otool -X -L ${TARGET} | grep "${LIB_NAME}" | grep '/nix'  | awk '{print $1}')
  echo "Updating ${TARGET} - rewriting ${OLD_PATH} to ${NEW_PATH}"
  /usr/bin/install_name_tool -change "$OLD_PATH" "$NEW_PATH" "${TARGET}"
}

# rewrite the libs
rewrite_lib $TARGET 'libgmp' "/usr/local/opt/gmp/lib/libgmp.10.dylib"
rewrite_lib $TARGET 'libffi' "/usr/local/opt/libffi/lib/libffi.6.dylib"
rewrite_lib $TARGET 'libSystem' "/usr/lib/libSystem.B.dylib"
rewrite_lib $TARGET 'libiconv' "/usr/lib/libiconv.dylib"