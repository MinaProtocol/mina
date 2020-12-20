#!/bin/sh

## Install libs needed by OPAM packages.

ZARITH=
CTYPES=
ASYNC_SSL=
POSTGRESQL=
POSTGRESQL_C=

UNAME=$( command -v uname)

case $( "${UNAME}" | tr '[:upper:]' '[:lower:]') in
    linux*)
        printf 'linux\n'
        ZARITH=libgmp3-dev
        CTYPES=libffi-dev
        ASYNC_SSL=libssl-dev
        POSTGRESQL_C=libpq-dev
        ;;
    darwin*)
        printf 'darwin\n'
        export HOMEBREW_NO_AUTO_UPDATE=1
        brew update-reset
        ZARITH=gmp
        CTYPES=libffi
        ASYNC_SSL=openssl@1.1
        POSTGRESQL=postgresql
        POSTGRESQL_C=libpq
        ;;
    # msys*|cygwin*|mingw*)
    #   # or possible 'bash on windows'
    #   printf 'windows\n'
    #   ;;
    # nt|win*)
    #   printf 'windows\n'
    #   ;;
    *)
        printf 'unknown os\n'
        ;;
esac

## FIXME: also support homebrew for MacOS
sudo apt-get update
sudo apt-get install --yes \
     pkg-config  \
     ZARITH \
     CTYPES \
     ASYNC_SSL \
     POSTGRESQL_C


# OPAM:
# * build-essential
# * autoconf
# * m4
# * unzip
# * bubblewrap
# * patchelf?

# For bazel:
# * git
# * curl
# * gnupg
