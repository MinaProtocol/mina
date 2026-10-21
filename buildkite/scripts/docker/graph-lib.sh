#!/usr/bin/env bash

# Helpers for reading and editing the docker daemon's own data root
# (/var/lib/docker, "the graph") from the CI agent. Source this file.
#
# On the CI agents docker is a DinD sidecar whose graph is a separate volume
# (a 200Gi PVC on generic/integration agents). The agent container cannot see
# it: `df /` on the agent reports the node's filesystem, which can be half
# empty while every `docker load` fails with "no space left on device".
#
# A bind mount source is resolved by the daemon, i.e. inside the sidecar, so a
# container run with `-v /var/lib/docker:...` sees the real graph. The helper
# container is run from an image that is already local (`--pull never`: the
# graph may be too full to pull one), as root, without network, and with a
# NON-recursive bind: a recursive one would copy every running container's
# overlay mount into the helper, and the daemon could then fail to remove those
# containers ("device or resource busy") while the helper runs.

GRAPH_HELPER_MOUNT=/graph

# Prints the first local image whose `sh` has the tools the helpers use.
# DOCKER_GRAPH_HELPER_IMAGE overrides the search. Fails if there is none.
graph_find_helper() {
  if [[ -n "${DOCKER_GRAPH_HELPER_IMAGE:-}" ]]; then
    echo "$DOCKER_GRAPH_HELPER_IMAGE"
    return 0
  fi
  local img
  for img in $(docker image ls --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>'); do
    if docker run --rm --pull never --network none --user 0:0 --entrypoint sh "$img" \
         -c 'for t in df du find stat grep sed sort cat date awk; do command -v $t >/dev/null || exit 1; done' \
         >/dev/null 2>&1; then
      echo "$img"
      return 0
    fi
  done
  return 1
}

# graph_sh <helper-image> <ro|rw> <script> [docker run args...]
# Runs <script> with `sh -c` in a helper container that has the graph at
# $GRAPH_HELPER_MOUNT, also exported to the script as $GRAPH. Extra arguments
# (e.g. `-e VAR=value`) go to `docker run`.
graph_sh() {
  local img="$1" mode="$2" script="$3"
  shift 3
  # CLI 25 renamed bind-nonrecursive=true (deprecated, warns) to
  # bind-recursive=disabled, which older CLIs reject.
  local nonrec="bind-nonrecursive=true"
  [[ "$(docker version -f '{{.Client.Version}}' 2>/dev/null | cut -d. -f1)" -ge 25 ]] 2>/dev/null \
    && nonrec="bind-recursive=disabled"
  local opts="type=bind,source=/var/lib/docker,target=${GRAPH_HELPER_MOUNT},${nonrec}"
  [[ "$mode" == "ro" ]] && opts="${opts},readonly"
  docker run --rm --pull never --network none --user 0:0 --entrypoint sh \
    --mount "$opts" -e GRAPH="$GRAPH_HELPER_MOUNT" "$@" "$img" -c "$script"
}

# graph_usage <helper-image>
# Prints the graph's usage as a percentage, the higher of blocks and inodes
# (either running out fails writes).
graph_usage() {
  graph_sh "$1" ro '
    b=$(df -P "$GRAPH" | awk "NR==2 {sub(/%/, \"\", \$5); print \$5}")
    i=$(df -Pi "$GRAPH" 2>/dev/null | awk "NR==2 {sub(/%/, \"\", \$5); print \$5}")
    case "$i" in ""|*[!0-9]*) i=0 ;; esac
    [ "$b" -ge "$i" ] && echo "$b" || echo "$i"
  '
}
