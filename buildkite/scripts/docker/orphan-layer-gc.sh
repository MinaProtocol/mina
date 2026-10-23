#!/usr/bin/env bash

# Reclaim docker graph space held by orphaned layers, with the daemon running.
#
# An interrupted `docker load` -- the job cancelled or timed out, or dockerd
# stopped or killed while it registers the layers -- leaves layers behind that
# no image references. `docker system df` does not count them, and neither
# `docker system prune --all --volumes` nor `docker builder prune --all`
# removes them, so on a persistent graph (the CI agents' DinD volume) they
# accumulate until every job on the agent fails with "no space left on
# device". There is no docker command for this. Two kinds, two remedies:
#
# 1. Layer chains in image/overlay2/layerdb that no image references. `docker
#    load` reuses a layer that already exists (by chain ID) without reading its
#    tar, so loading a stub image (a config whose rootfs is the orphaned chain,
#    and no layer files) and removing it hands the chain back to the daemon,
#    which deletes it like any other unused layer. Layers are reference
#    counted, so a chain that is in fact still in use (e.g. by a load in
#    progress) is unaffected by the stub's removal.
# 2. overlay2 directories nothing references: no layerdb cache-id, no
#    container mount, not named in the BuildKit metadata. These are partially
#    extracted layers that never got a layerdb entry, and the daemon keeps no
#    other record of them, so they are deleted directly.
#
# Both only touch things older than ORPHAN_GC_MIN_AGE_MIN minutes (default
# 120), so nothing a running `docker load` or build is creating is considered.
# Assumes the overlay2 storage driver (the DinD default). DRY_RUN=1 only
# reports. Never fatal. Usage: orphan-layer-gc.sh [helper-image]

set -uo pipefail

# shellcheck source=buildkite/scripts/docker/graph-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/graph-lib.sh"

MIN_AGE_MIN="${ORPHAN_GC_MIN_AGE_MIN:-120}"
DRY_RUN="${DRY_RUN:-0}"

HELPER="${1:-}"
if [[ -z "$HELPER" ]] && ! HELPER=$(graph_find_helper); then
  echo "orphan-layer-gc: no usable local image to inspect the docker graph, skipping"
  exit 0
fi

if [[ "$(docker info -f '{{.Driver}}' 2>/dev/null)" != "overlay2" ]]; then
  echo "orphan-layer-gc: storage driver is not overlay2, skipping"
  exit 0
fi

# --- 1. layer chains no image references

# One line per layerdb entry: <chain-id> <parent chain-id or -> <diff-id> <age in minutes>
chains=$(graph_sh "$HELPER" ro '
  L="$GRAPH/image/overlay2/layerdb/sha256"
  now=$(date +%s)
  for c in $(ls "$L" 2>/dev/null); do
    p=$(cat "$L/$c/parent" 2>/dev/null)
    p=${p#sha256:}
    echo "$c ${p:--} $(cat "$L/$c/diff") $(( (now - $(stat -c %Y "$L/$c")) / 60 ))"
  done')

declare -A parent diff age is_parent is_top
while read -r c p d a; do
  [[ -z "$c" ]] && continue
  parent[$c]=$p
  diff[$c]=$d
  age[$c]=$a
  [[ "$p" != "-" ]] && is_parent[$p]=1
done <<< "$chains"

# The top chain ID of every image: chain(L0) = diff(L0),
# chain(Ln) = sha256(chain(Ln-1) + " " + diff(Ln)).
while read -r layers; do
  top=""
  for d in $layers; do
    if [[ -z "$top" ]]; then
      top=${d#sha256:}
    else
      top=$(printf 'sha256:%s %s' "$top" "$d" | sha256sum | cut -d' ' -f1)
    fi
  done
  [[ -n "$top" ]] && is_top[$top]=1
done < <(docker image ls -aq --no-trunc | sort -u \
           | xargs -r docker image inspect -f '{{range .RootFS.Layers}}{{.}} {{end}}')

arch=$(docker version -f '{{.Server.Arch}}' 2>/dev/null || echo amd64)
released=0
for c in "${!diff[@]}"; do
  # Only leaves: releasing a leaf releases its ancestors that nothing else uses.
  [[ -n "${is_parent[$c]:-}" || -n "${is_top[$c]:-}" ]] && continue
  [[ "${age[$c]}" -lt "$MIN_AGE_MIN" ]] && continue
  diffs=()
  cur=$c
  while [[ -n "${diff[$cur]:-}" ]]; do
    diffs=("${diff[$cur]}" "${diffs[@]}")
    [[ "${parent[$cur]}" == "-" ]] && break
    cur=${parent[$cur]}
  done
  if [[ -z "${diff[$cur]:-}" ]]; then
    echo "orphan-layer-gc: layer chain ${c:0:12} has a missing ancestor, leaving it"
    continue
  fi
  echo "orphan-layer-gc: orphaned layer chain ${c:0:12} (${#diffs[@]} layers)"
  released=$((released + 1))
  [[ "$DRY_RUN" == "1" ]] && continue

  stub=$(mktemp -d)
  tag="orphan-layer-gc:${c:0:12}"
  ids=$(printf '"%s",' "${diffs[@]}")
  files=$(for i in "${!diffs[@]}"; do printf '"l%d/layer.tar",' "$i"; done)
  printf '{"architecture":"%s","os":"linux","config":{},"rootfs":{"type":"layers","diff_ids":[%s]}}' \
    "$arch" "${ids%,}" > "$stub/config.json"
  printf '[{"Config":"config.json","RepoTags":["%s"],"Layers":[%s]}]' \
    "$tag" "${files%,}" > "$stub/manifest.json"
  if tar -C "$stub" -cf - config.json manifest.json | docker load -q >/dev/null; then
    docker rmi "$tag" >/dev/null
  else
    echo "orphan-layer-gc: could not load the stub for ${c:0:12}"
  fi
  rm -rf "$stub"
done
echo "orphan-layer-gc: ${released} orphaned layer chain(s)$([[ "$DRY_RUN" == "1" ]] && echo " found (dry run)" || echo " released")"

# --- 2. overlay2 directories nothing references

mode=rw
[[ "$DRY_RUN" == "1" ]] && mode=ro
graph_sh "$HELPER" "$mode" '
  L="$GRAPH/image/overlay2/layerdb"
  refs=$(mktemp)
  {
    for f in "$L"/sha256/*/cache-id; do [ -f "$f" ] && { cat "$f"; echo; }; done
    for m in "$L"/mounts/*; do
      [ -d "$m" ] || continue
      cat "$m/mount-id" 2>/dev/null; echo
      cat "$m/init-id" 2>/dev/null; echo
    done
    # BuildKit snapshots are overlay2 directories recorded only in its bolt
    # databases; keep anything that looks like an ID in them.
    cat "$GRAPH"/buildkit/*.db 2>/dev/null | grep -aoE "[0-9a-f]{64}"
    cat "$GRAPH"/buildkit/*.db 2>/dev/null | grep -aoE "[0-9a-z]{25}"
  } | sort -u > "$refs"
  n=0
  for d in $(find "$GRAPH/overlay2" -mindepth 1 -maxdepth 1 -type d ! -name l -mmin +"$MIN_AGE_MIN"); do
    id=$(basename "$d")
    grep -qxF "${id%-init}" "$refs" && continue
    echo "orphan-layer-gc: orphaned overlay2 directory $id ($(du -sm "$d" | cut -f1) MB)"
    n=$((n + 1))
    [ "$DRY_RUN" = 1 ] && continue
    [ -f "$d/link" ] && rm -f "$GRAPH/overlay2/l/$(cat "$d/link")"
    rm -rf "$d"
  done
  echo "orphan-layer-gc: $n orphaned overlay2 directory(ies)$([ "$DRY_RUN" = 1 ] && echo " found (dry run)" || echo " removed")"
' -e MIN_AGE_MIN="$MIN_AGE_MIN" -e DRY_RUN="$DRY_RUN"

exit 0
