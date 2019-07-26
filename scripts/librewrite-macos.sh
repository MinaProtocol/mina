#!/bin/bash

# xcode technique to rewrite dynamic lib links
# tweaks kademlia binaries built with nix to work with os installed libs

BUILD_DIR_NAME=package

relib() {
  NAME="$1"
  REWRITE_PATH="$2"
  OLD_PATH=$(otool -l ${BUILD_DIR_NAME}/kademlia | grep -E '\s+name' | grep '/nix' | grep "$NAME" |  awk '{print $2}')

  install_name_tool -change "$OLD_PATH" "$REWRITE_PATH" "${BUILD_DIR_NAME}/kademlia"
}

relib 'libgmp' "/usr/local/opt/gmp/lib/libgmp.10.dylib"
relib 'libffi' "/usr/local/opt/libffi/lib/libffi.6.dylib"
relib 'libSystem' "/usr/lib/libSystem.B.dylib"
relib 'libiconv' "/usr/lib/libiconv.dylib"