#!/bin/bash
set -e

rm -f $1
echo "(lang dune 1.6)" >> $1
echo "(context default)" >> $1
for profile_config in $(ls src/config/*.mlh); do
  profile=$(basename ${profile_config%.mlh})
  echo "
(context
  (opam
    (switch coda)
    (name $profile)
    (profile $profile)))" >> $1
done
