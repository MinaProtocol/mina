#!/bin/bash
set -e

generate_workspace() {
  rm -f $1
  echo "(lang dune 1.6)" >> $1
  echo $2 >> $1
}

generate_workspace "dune-workspace" "(context default)"

for profile_config in $(ls src/config/*.mlh); do
  profile=$(basename ${profile_config%.mlh})
  generate_workspace "dune-workspace.$profile" "
(context
  (opam
    (switch coda)
    (name $profile)
    (profile $profile)))"
done
