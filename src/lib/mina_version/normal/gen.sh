#!/usr/bin/env bash
set -euo pipefail

branch="${MINA_BRANCH-$(git rev-parse --verify --abbrev-ref HEAD || echo "<unknown>")}"

# we are nested 6 directories deep (_build/<context>/src/lib/mina_version/normal)
root="${MINA_ROOT-$(git rev-parse --show-toplevel || echo ../../../../../..)}"

pushd "$root" > /dev/null
  id="${MINA_COMMIT_SHA1-$(git rev-parse --verify HEAD || echo "<unknown>")}"
  commit_id_short="$(printf "%s" "$id" | cut -c1-8)"
  if [[ -e .git ]] && ! git diff --quiet; then id="[DIRTY]$id"; fi
  commit_date="${MINA_COMMIT_DATE-$(git show HEAD -s --format="%cI" || echo "<unknown>")}"

  mina_submodule=$(git submodule status | grep "mina" || true)
  base_dir=
  if [[ -n "$mina_submodule" ]]; then
    base_dir=src/mina/
  fi
  CARGO_LOCK="${base_dir}src/lib/crypto/kimchi_bindings/stubs/Cargo.lock"
  PAT='git\+https://github\.com/o1-labs/proof-systems\.git\?rev=[a-f0-9]*'

  marlin_commit_id="${MARLIN_COMMIT_ID-$(grep -m 1 -oE "$PAT" "$CARGO_LOCK" | grep -oE '[^=]*$')}"
  marlin_commit_id_short="$(printf '%s' "$marlin_commit_id" | cut -c1-8)"
popd > /dev/null

{
    printf 'let commit_id = "%s"\n' "$id"
    printf 'let commit_id_short = "%s"\n' "$commit_id_short"
    printf 'let branch = "%s"\n' "$branch"
    printf 'let commit_date = "%s"\n' "$commit_date"

    printf 'let marlin_commit_id = "%s"\n' "$marlin_commit_id"
    printf 'let marlin_commit_id_short = "%s"\n' "$marlin_commit_id_short"

    printf 'let print_version () = Core_kernel.printf "Commit %%s on branch %%s\\n%%!" commit_id branch\n'
} > "$1"
