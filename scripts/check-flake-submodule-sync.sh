#!/usr/bin/env bash
#
# Verify that the revs pinned in flake.lock for the rust and snarky
# flake inputs match the SHAs of their corresponding git submodules.
# Fails if they drift, so a submodule bump that forgets to update the
# flake input is caught before it can hide a build divergence between
# `nix build` and `dune build`.

set -euo pipefail

# Map of submodule path -> flake input name. Keep in sync with flake.nix.
SUBMODULES=(
  "src/lib/snarky:snarky"
  "src/lib/crypto/proof-systems:proof-systems"
  "src/lib/crypto/kimchi_bindings/stubs/kimchi-stubs-vendors:kimchi-stubs-vendors"
)

cd "$(git rev-parse --show-toplevel)"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 2
fi

failed=0
for entry in "${SUBMODULES[@]}"; do
  path="${entry%%:*}"
  input="${entry##*:}"

  submodule_sha="$(git ls-tree HEAD "$path" | awk '{print $3}')"
  if [[ -z "$submodule_sha" ]]; then
    echo "error: no submodule entry for $path in HEAD" >&2
    failed=1
    continue
  fi

  flake_rev="$(jq -r --arg name "$input" '.nodes[$name].locked.rev // empty' flake.lock)"
  if [[ -z "$flake_rev" ]]; then
    echo "error: no flake.lock entry for input '$input'" >&2
    failed=1
    continue
  fi

  if [[ "$submodule_sha" != "$flake_rev" ]]; then
    echo "drift: $path / flake input '$input'" >&2
    echo "  git submodule SHA: $submodule_sha" >&2
    echo "  flake.lock rev:    $flake_rev" >&2
    failed=1
  fi
done

if (( failed != 0 )); then
  echo >&2
  echo "To fix: update the corresponding URL in flake.nix and run" >&2
  echo "  nix flake update <input> [<input>...]" >&2
  exit 1
fi

echo "flake inputs are in sync with git submodules."
