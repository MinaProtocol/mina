#!/usr/bin/env bash

printf 'Checking if jemalloc is available... ' 1>&2

if pkg-config --exists jemalloc; then
  echo 'Yes, using jemalloc as an allocator' 1>&2
  # Print the linker flag
  printf "jemalloc"
else
  echo 'No, using the default allocator from libc' 1>&2
  printf "c"
fi
