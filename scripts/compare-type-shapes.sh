#!/bin/bash

# compare-type-shapes.sh -- compare bin_prot type shapes between this checkout
# and a baseline (e.g. a develop worktree), for serialization-compatibility
# gating (RFC 0047). Wraps `mina internal dump-type-shapes`, which prints one
# line per versioned type registered via ppx_version:
#   <module path>, <shape digest>, <canonical shape sexp>, <type declaration>
#
# Usage:
#   ./scripts/compare-type-shapes.sh BASELINE [OUT_DIR]
#
#   BASELINE   Either a git worktree/checkout of the baseline branch (the
#              mina.exe target is built there with dune, using that tree's
#              own _build), or a pre-generated dump file produced by
#              `mina internal dump-type-shapes`.
#   OUT_DIR    Where to write dump files and the diff (default: a mktemp dir).
#
# When the baseline branch needs a different toolchain/opam switch than the
# current branch (e.g. core v0.14 vs v0.16), build the baseline dump inside
# the baseline's own dev environment first and pass the resulting file:
#   (cd /path/to/develop-worktree \
#     && dune build src/app/cli/src/mina.exe \
#     && ./_build/default/src/app/cli/src/mina.exe internal dump-type-shapes \
#        > /tmp/develop-shapes.txt)
#   ./scripts/compare-type-shapes.sh /tmp/develop-shapes.txt
#
# Exits 0 if all shape digests are identical, 1 on any difference (with a
# report of added/removed/changed types), 2 on usage/build errors.
#
# Related CI tooling (not reusable locally): scripts/version-linter.py and
# buildkite/scripts/dump-mina-type-shapes.sh, which compare dumps uploaded
# to gs://mina-type-shapes per commit.

set -euo pipefail

usage() {
  echo "Usage: $0 BASELINE [OUT_DIR]" >&2
  echo "  BASELINE: baseline worktree directory or pre-generated dump file" >&2
  exit 2
}

[[ $# -ge 1 && $# -le 2 ]] || usage

BASELINE=$1
OUT_DIR=${2:-$(mktemp -d /tmp/compare-type-shapes.XXXXXX)}
MINA_EXE_TARGET="src/app/cli/src/mina.exe"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

mkdir -p "$OUT_DIR"

# Build mina.exe in the given tree and dump sorted type shapes to stdout.
dump_shapes() {
  local tree=$1
  (
    cd "$tree"
    ulimit -s 65532 2>/dev/null || true
    ulimit -n 10240 2>/dev/null || true
    dune build "$MINA_EXE_TARGET" 1>&2
    "./_build/default/$MINA_EXE_TARGET" internal dump-type-shapes
  ) | sort
}

echo "--- Dumping type shapes for current branch ($REPO_ROOT)"
CURRENT_DUMP="$OUT_DIR/current-shapes.txt"
dump_shapes "$REPO_ROOT" > "$CURRENT_DUMP"

BASELINE_DUMP="$OUT_DIR/baseline-shapes.txt"
if [[ -f "$BASELINE" ]]; then
  echo "--- Using pre-generated baseline dump: $BASELINE"
  sort "$BASELINE" > "$BASELINE_DUMP"
elif [[ -d "$BASELINE" ]]; then
  echo "--- Dumping type shapes for baseline worktree: $BASELINE"
  dump_shapes "$BASELINE" > "$BASELINE_DUMP"
else
  echo "error: baseline '$BASELINE' is neither a file nor a directory" >&2
  usage
fi

for dump in "$CURRENT_DUMP" "$BASELINE_DUMP"; do
  if [[ ! -s "$dump" ]]; then
    echo "error: empty shape dump: $dump" >&2
    exit 2
  fi
done

# Reduce each dump to "path, digest" for the comparison; paths and digests
# never contain commas (the shape sexp in later fields may). Re-sort on the
# path field so join/comm below see strict key ordering.
cut -d',' -f1,2 "$BASELINE_DUMP" | sort -t',' -k1,1 > "$OUT_DIR/baseline-digests.txt"
cut -d',' -f1,2 "$CURRENT_DUMP" | sort -t',' -k1,1 > "$OUT_DIR/current-digests.txt"

echo "--- Comparing shape digests"
if diff -u "$OUT_DIR/baseline-digests.txt" "$OUT_DIR/current-digests.txt" \
     > "$OUT_DIR/digests.diff"; then
  echo "OK: $(wc -l < "$CURRENT_DUMP") type shapes identical to baseline"
  exit 0
fi

# Build a readable report: types whose digest changed, and types present in
# only one of the two dumps.
cut -d',' -f1 "$OUT_DIR/baseline-digests.txt" > "$OUT_DIR/baseline-paths.txt"
cut -d',' -f1 "$OUT_DIR/current-digests.txt" > "$OUT_DIR/current-paths.txt"

echo
echo "=== TYPE SHAPE DIFFERENCES DETECTED ==="

echo
echo "--- Types with changed shape digests:"
join -t',' "$OUT_DIR/baseline-digests.txt" "$OUT_DIR/current-digests.txt" \
  | awk -F',' '$2 != $3 { printf "  %s\n    baseline:%s\n    current: %s\n", $1, $2, $3 }'

echo
echo "--- Types only in baseline (removed on current branch):"
comm -23 "$OUT_DIR/baseline-paths.txt" "$OUT_DIR/current-paths.txt" \
  | sed 's/^/  /'

echo
echo "--- Types only on current branch (added):"
comm -13 "$OUT_DIR/baseline-paths.txt" "$OUT_DIR/current-paths.txt" \
  | sed 's/^/  /'

echo
echo "Full dumps and raw diff kept in: $OUT_DIR"
echo "  baseline: $BASELINE_DUMP"
echo "  current:  $CURRENT_DUMP"
echo "  diff:     $OUT_DIR/digests.diff"
exit 1
