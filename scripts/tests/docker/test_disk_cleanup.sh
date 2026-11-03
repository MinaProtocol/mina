#!/bin/bash
set -euo pipefail

################################################################################
# Test suite for buildkite/scripts/docker/disk-cleanup.sh and
# orphan-layer-gc.sh (and load_from_cache.sh's part in the LRU eviction)
#
# Usage:
#   bash scripts/tests/docker/test_disk_cleanup.sh
#
# Needs a local docker that can run privileged containers, and ~8G of disk.
# Takes a few minutes. Not run in CI (CI agents cannot run privileged DinD of
# their own); run it by hand when changing these scripts.
#
# The tests are black box against a CI-shaped daemon: a docker:27.1.2-dind
# sidecar (the CI version) whose graph is a 5G ext4 filesystem, so thresholds
# are reachable, driven from this host over TCP the way the agent drives its
# sidecar. Leaks are made the way they happen in CI: dockerd is killed while a
# `docker load` registers its layers, then restarted on the same graph (a pod
# restart).
################################################################################

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRIPTS="$REPO_ROOT/buildkite/scripts/docker"
DIND_IMAGE=docker:27.1.2-dind
CLI_IMAGE=docker:27.1.2-cli
BASE_IMAGE=debian:bookworm-slim
NAME="test-disk-cleanup-$$"
PORT=$((23000 + $$ % 1000))
WORK="$(mktemp -d)"

################################################################################
# Test framework
################################################################################

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=()
CURRENT_TEST=""

start_test() {
    CURRENT_TEST="$1"
    TESTS_RUN=$((TESTS_RUN + 1))
    echo "--- $CURRENT_TEST"
}

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "    PASS"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILURES+=("$CURRENT_TEST: $1")
    echo "    FAIL: $1"
}

################################################################################
# CI-shaped sidecar
################################################################################

host() { env -u DOCKER_HOST docker "$@"; }
export DOCKER_HOST="tcp://127.0.0.1:$PORT"

cleanup() {
    host rm -f "$NAME" "$NAME-client" >/dev/null 2>&1 || true
    rm -rf "$WORK"
}
trap cleanup EXIT

wait_daemon() {
    for _ in $(seq 60); do docker info >/dev/null 2>&1 && return 0; sleep 1; done
    echo "sidecar did not start"; host logs "$NAME" | tail -5; exit 1
}

start_sidecar() {
    truncate -s 5G "$WORK/graph.ext4"
    host run --rm -v "$WORK:/w" "$BASE_IMAGE" mkfs.ext4 -q -F /w/graph.ext4
    # /var/run is cleared on start, like the fresh emptyDir of a new CI pod.
    host run -d --privileged --name "$NAME" -p "127.0.0.1:$PORT:2375" -v "$WORK:/w" \
        -e DOCKER_TLS_CERTDIR= --entrypoint sh "$DIND_IMAGE" -c \
        'mount -o loop /w/graph.ext4 /var/lib/docker && rm -rf /var/run/docker.pid /var/run/docker && exec dockerd --host=tcp://0.0.0.0:2375 --host=unix:///var/run/docker.sock' \
        >/dev/null
    wait_daemon
}

# A ~1.5G image tar on the host, made in the sidecar.
make_leak_tar() {
    local d
    d="$(mktemp -d -p "$WORK")"
    printf 'FROM %s\nRUN head -c 500000000 /dev/urandom > /a\nRUN head -c 500000000 /dev/urandom > /b\nRUN head -c 500000000 /dev/urandom > /c\n' \
        "$BASE_IMAGE" > "$d/Dockerfile"
    docker build -q -t leak:1 "$d" >/dev/null
    docker save leak:1 -o "$WORK/leak.tar"
    docker rmi leak:1 >/dev/null
    docker builder prune --all -f >/dev/null
}

# Kill dockerd <seconds> into a `docker load` run from a client in the
# sidecar's network namespace, then restart the sidecar on the same graph.
kill_mid_load() {
    host run -d --name "$NAME-client" --network "container:$NAME" -v "$WORK:/w" "$CLI_IMAGE" \
        docker -H tcp://localhost:2375 load -i /w/leak.tar >/dev/null
    sleep "$1"
    host kill -s KILL "$NAME" >/dev/null
    host rm -f "$NAME-client" >/dev/null 2>&1 || true
    host start "$NAME" >/dev/null
    wait_daemon
    docker rmi leak:1 >/dev/null 2>&1 || true
}

# shellcheck source=buildkite/scripts/docker/graph-lib.sh
source "$SCRIPTS/graph-lib.sh"

graph_mb() {
    graph_sh "$BASE_IMAGE" ro 'du -sm "$GRAPH" | cut -f1' 2>/dev/null
}

image_runs() { docker run --rm "$1" true >/dev/null 2>&1; }

################################################################################
# Tests
################################################################################

test_below_threshold_is_a_no_op() {
    start_test "below the threshold, nothing is pruned"
    local out
    out=$("$SCRIPTS/disk-cleanup.sh" 2>&1)
    if [[ "$out" == *"no cleanup needed"* ]] && image_runs "$BASE_IMAGE"; then pass; else fail "$out"; fi
}

test_unreadable_usage_falls_back_to_prune() {
    start_test "when the graph cannot be measured, the dangling prune still runs"
    local out
    out=$(DOCKER_GRAPH_HELPER_IMAGE=does-not-exist:1 "$SCRIPTS/disk-cleanup.sh" 2>&1)
    if [[ "$out" == *"could not read the docker graph's usage"* && "$out" == *"Total reclaimed space"* ]]; then
        pass
    else
        fail "$out"
    fi
}

test_orphaned_layers_are_reclaimed() {
    start_test "layers left by a dockerd killed mid-load are reclaimed, images intact"
    local base leaked after s out
    base=$(graph_mb)
    for s in 3 4 5 6 3.5 4.5 5.5; do
        kill_mid_load "$s"
        leaked=$(graph_mb)
        [[ $((leaked - base)) -gt 100 ]] && break
    done
    if [[ $((leaked - base)) -le 100 ]]; then
        fail "could not make a leak (graph ${leaked} MB, healthy ${base} MB)"
        return
    fi
    if [[ "$(docker image ls --format '{{.Repository}}:{{.Tag}}')" != "$BASE_IMAGE" ]]; then
        fail "an image other than $BASE_IMAGE exists, so the leak is not only orphaned layers"
        return
    fi
    out=$(DISK_PRUNE_THRESHOLD=0 DISK_PRUNE_TARGET=0 ORPHAN_GC_MIN_AGE_MIN=0 DISK_CLEANUP_KEEP="$BASE_IMAGE" \
          "$SCRIPTS/disk-cleanup.sh" 2>&1)
    after=$(graph_mb)
    if [[ $((after - base)) -gt 20 ]]; then
        fail "graph ${after} MB after cleanup, healthy ${base} MB, leaked ${leaked} MB: $out"
    elif ! image_runs "$BASE_IMAGE"; then
        fail "$BASE_IMAGE no longer runs"
    elif ! docker load -q -i "$WORK/leak.tar" >/dev/null || ! image_runs leak:1; then
        fail "the leaked image no longer loads and runs"
    else
        echo "    healthy ${base} MB, leaked ${leaked} MB, after ${after} MB"
        docker rmi leak:1 >/dev/null
        pass
    fi
}

test_lru_eviction() {
    start_test "images are evicted least recently used first, down to the target"
    local n d out left
    for n in a b c d; do
        d="$(mktemp -d -p "$WORK")"
        printf 'FROM %s\nRUN head -c 400000000 /dev/urandom > /%s\n' "$BASE_IMAGE" "$n" > "$d/Dockerfile"
        docker build -q -t "lru-$n:1" "$d" >/dev/null
    done
    docker builder prune --all -f >/dev/null
    # b is never used through load_from_cache.sh; then c, a, d in that order.
    for n in c a d; do sleep 1.1; docker tag "lru-$n:1" "lru-$n:1"; done
    docker run -d --name "$NAME-user" lru-a:1 sleep 100000 >/dev/null
    out=$(DISK_PRUNE_THRESHOLD=0 DISK_PRUNE_TARGET=1 ORPHAN_GC_MIN_AGE_MIN=0 \
          DOCKER_GRAPH_HELPER_IMAGE="$BASE_IMAGE" DISK_CLEANUP_KEEP="lru-d:1 $BASE_IMAGE" \
          "$SCRIPTS/disk-cleanup.sh" 2>&1)
    left=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | sort | tr '\n' ' ')
    local order
    order=$(echo "$out" | sed -n 's/^disk-cleanup: removed \([^ ]*\) .*/\1/p' | tr '\n' ' ')
    docker rm -f "$NAME-user" >/dev/null
    if [[ "$order" != "lru-b:1 lru-c:1 " ]]; then
        fail "removed '${order}', expected 'lru-b:1 lru-c:1 '"
    elif [[ "$left" != "$BASE_IMAGE lru-a:1 lru-d:1 " ]]; then
        fail "left '${left}'"
    else
        pass
    fi
    docker rmi lru-a:1 lru-d:1 >/dev/null 2>&1 || true
}

test_load_from_cache_records_use() {
    start_test "load_from_cache.sh records each use of an image"
    local cache before after
    cache="$(mktemp -d -p "$WORK")"
    mkdir -p "$cache/debian"
    : > "$cache/debian/bookworm-slim.tar.zst"   # present locally, so not loaded
    before=$(docker image inspect -f '{{json .Metadata.LastTagTime}}' "$BASE_IMAGE")
    sleep 1.1
    (cd "$REPO_ROOT" && CACHE_ROOT="$cache" DISK_CLEANUP=0 \
        ./buildkite/scripts/docker/load_from_cache.sh --if-present "$BASE_IMAGE" >/dev/null)
    after=$(docker image inspect -f '{{json .Metadata.LastTagTime}}' "$BASE_IMAGE")
    if [[ "$after" > "$before" ]]; then pass; else fail "LastTagTime ${before} -> ${after}"; fi
}

test_orphans_on_a_graph_with_no_images() {
    start_test "a graph with no images but full of orphaned layers is reclaimed (pulls a helper)"
    local s usage out
    for s in 3 4 5 6 3.5 4.5 5.5; do
        kill_mid_load "$s"
        docker system prune --all --volumes -f >/dev/null
        docker builder prune --all -f >/dev/null
        # measure with a helper pulled for the purpose, then leave no image
        docker pull -q busybox:1.36.1 >/dev/null
        usage=$(graph_usage busybox:1.36.1 2>/dev/null)
        docker rmi busybox:1.36.1 >/dev/null
        [[ "${usage:-0}" -ge 8 ]] && break
    done
    if [[ "${usage:-0}" -lt 8 || -n "$(docker image ls -q)" ]]; then
        fail "could not make an image-less leaked graph (usage ${usage:-?}%)"
        return
    fi
    # busybox's `find -mmin +0` only matches what is at least a whole minute old
    sleep 61
    out=$(DISK_PRUNE_THRESHOLD=0 DISK_PRUNE_TARGET=0 ORPHAN_GC_MIN_AGE_MIN=0 "$SCRIPTS/disk-cleanup.sh" 2>&1)
    usage=$(graph_usage busybox:1.36.1 2>/dev/null)
    if [[ "${usage:-100}" -le 3 ]]; then
        echo "    image-less graph reclaimed to ${usage}%"
        pass
    else
        fail "graph at ${usage:-?}% after cleanup: $out"
    fi
}

################################################################################
# Main
################################################################################

echo "Starting a ${DIND_IMAGE} sidecar on a 5G graph"
host pull -q "$DIND_IMAGE" >/dev/null
host pull -q "$CLI_IMAGE" >/dev/null
host pull -q "$BASE_IMAGE" >/dev/null
start_sidecar
docker pull -q "$BASE_IMAGE" >/dev/null
make_leak_tar

test_below_threshold_is_a_no_op
test_unreadable_usage_falls_back_to_prune
test_orphaned_layers_are_reclaimed
test_lru_eviction
test_load_from_cache_records_use
test_orphans_on_a_graph_with_no_images

echo
echo "${TESTS_PASSED}/${TESTS_RUN} passed"
if [[ "$TESTS_FAILED" -gt 0 ]]; then
    printf '  %s\n' "${FAILURES[@]}"
    exit 1
fi
