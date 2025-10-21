#!/usr/bin/env bash

printf 'Checking if jemalloc is available... ' 1>&2
if [ -z "${CC-}" ]; then
  if command -v gcc >/dev/null 2>&1; then
    CC=gcc
  else
    CC=clang
  fi
fi

# Try to link against jemalloc
if echo 'int main(){}' | "$CC" -x c - -ljemalloc -o /dev/null >/dev/null 2>&1; then
  echo 'Yes, using jemalloc as an allocator' 1>&2
  printf jemalloc
else
  echo 'No, using the default allocator from libc' 1>&2
  printf c
fi
