#!/usr/bin/env bash
set -euo pipefail

target=$1

id="${MINA_COMMIT_SHA1:-$(git rev-parse --verify HEAD 2>/dev/null || echo "<unknown>")}"
id_short="$(printf "%s" "$id" | cut -c1-8)"

{
    printf 'let commit_id = "%s"\n' "$id"
    printf 'let commit_id_short = "%s"\n' "$id_short"

    printf 'let print_version () = Core_kernel.printf "Commit %%s\\n%%!" commit_id\n'
} > "$1"
