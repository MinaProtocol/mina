#!/bin/bash

# Future Improvement: ensure the relative path for the "preprocessor_deps" entry
# correctly lines up with "src/config.mlh"

tmp=$(mktemp /tmp/ppx_optcomp_dune_files.XXXXXX)

find src/lib src/app -name '*.ml' -or -name '*.mli' \
  | xargs grep '\[%%import' \
  | cut -d: -f1 \
  | xargs -n 1 dirname \
  | uniq \
  | xargs -i echo '{}/dune' \
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
