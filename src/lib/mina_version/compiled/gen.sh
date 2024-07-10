#!/usr/bin/env bash
set -euo pipefail

# we are nested 6 directories deep (_build/<context>/src/lib/mina_version/normal)
if [ -z ${MINA_COMMIT_SHA1+x} ]; then
  root="${MINA_ROOT-$(git rev-parse --show-toplevel || echo ../../../../../..)}"
  pushd "$root" > /dev/null
  id="${MINA_COMMIT_SHA1-$(git rev-parse --verify HEAD || echo "<unknown>")}"
  popd > /dev/null
else
  id="${MINA_COMMIT_SHA1}"
fi

id_short="$(printf "%s" "$id" | cut -c1-8)"

{
    printf 'let commit_id = "%s"\n' "$id"
    printf 'let commit_id_short = "%s"\n' "$id_short"

    printf 'let print_version () = Core_kernel.printf "Commit %%s\\n%%!" commit_id\n'
} > "$1"
