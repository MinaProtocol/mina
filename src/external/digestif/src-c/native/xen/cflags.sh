#!/bin/sh
export PKG_CONFIG_PATH="$(opam config var lib)/pkgconfig"
flags="$(pkg-config --static mirage-xen-posix --cflags)"
echo "(-std=c99 -I.. $flags)"
