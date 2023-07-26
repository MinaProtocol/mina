#!/bin/bash

set -eou pipefail

# Future Improvement: ensure the relative path for the "preprocessor_deps" entry
# correctly lines up with "src/config.mlh"

set +u
if [[ -z "$CI" ]]; then
  MKTEMP_FLAGS="-t "
else
  MKTEMP_FLAGS=""
fi
set -u

tmp=$(mktemp ${MKTEMP_FLAGS}ppx_optcomp_dune_files.XXXX)

# Some directories do not have a dune files: we want to find their closest
# parent dune file instead of reporting an error
find-dune-in-parents() {
  local dir="$1"

  test -e "$dir/dune" && echo "$dir/dune" && return 0
  [ '/' = "$dir" ] && echo "could not find dune file in parents of $dir" && return 1

  find-dune-in-parents "$(dirname "$dir")"
}


# Export the find-dune-in-parents function to be able to call it via xargs.
# See https://stackoverflow.com/questions/11003418/calling-shell-functions-with-xargs
export -f find-dune-in-parents

find "$(pwd)/src/lib" "$(pwd)/src/app" -name '*.ml' -or -name '*.mli' \
  | xargs grep '\[%%import' \
  | cut -d: -f1 \
  | xargs -n 1 dirname \
  | uniq \
  | xargs -I{} bash -c 'find-dune-in-parents "$@"' _ {}\
  | sort \
  > $tmp

bad_files=$(\
  comm -23 \
    <(cat $tmp) \
    <(xargs grep 'preprocessor_deps' <$tmp | cut -d: -f1 | sort))

rm $tmp

if [ -n "$bad_files" ]; then
  echo "ERROR: Some libraries which use ppx_optcomp do not have "preprocessor_deps" entries in their dune files"
  for f in $bad_files; do
    echo "  - $f"
  done
  exit 1
fi
