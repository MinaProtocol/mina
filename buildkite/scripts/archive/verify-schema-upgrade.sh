#!/bin/bash

# Archive Schema Upgrade Verification Test
#
# Verifies the working tree's create_schema.sql, upgrade.sql and downgrade.sql.
#
# USAGE:
#   verify-schema-upgrade.sh CHECK [OPTIONS]
#
# CHECKS:
#   round-trip     Every branch.
#                    create + upgrade + downgrade + upgrade == create
#   from-release   Compatible: an operator on the last release installs the next
#                  one and runs upgrade.sql, or rolls back with downgrade.sql.
#                    release's create + upgrade         == create
#                    create + upgrade + downgrade       == release's create
#   from-branch    Develop: before the hardfork, upgrade.sql runs on a database
#                  of the from-branch, then the software is upgraded.
#                    <from-branch>'s create + upgrade   == create
#
# OPTIONS:
#   -f, --from-branch BRANCH     Branch of the pre-hardfork database
#                                (default: compatible)
#   -b, --release-branch BRANCH  Branch the release is tagged on
#                                (default: highest release/X.Y.Z branch on origin)
#   -r, --release-tag TAG        Release of the pre-upgrade database
#                                (default: newest X.Y.Z tag on the release branch)
#   -h, --help                   Show this help message
#
# REQUIRES:
#   - Docker daemon running
#   - Git repository with access to origin
#
# EXIT CODES:
#   0: All schema comparisons pass
#   1: Schema mismatch detected or error

set -euo pipefail

# --- Constants ---
POSTGRES_CONTAINER="postgres-schema-test-$$"
POSTGRES_IMAGE="postgres:17-alpine"
PG_USER="postgres"
PG_PASSWORD="postgres"
REPO_ROOT="$(git rev-parse --show-toplevel)"
WORK_DIR="/tmp/schema-test-$$"

CHECK=""
FROM_BRANCH="compatible"
RELEASE_BRANCH=""
RELEASE_TAG=""

usage() {
    grep '^#' "$0" | sed 's/^# //' | sed 's/^#//'
}

# --- Argument Parsing ---
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            round-trip|from-release|from-branch)
                CHECK="$1"
                shift
                ;;
            -f|--from-branch)
                FROM_BRANCH="$2"
                shift 2
                ;;
            -b|--release-branch)
                RELEASE_BRANCH="$2"
                shift 2
                ;;
            -r|--release-tag)
                RELEASE_TAG="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done

    if [[ -z "$CHECK" ]]; then
        echo "Error: CHECK is required" >&2
        echo "Use --help for usage information" >&2
        exit 1
    fi
}

# --- Cleanup trap ---
cleanup() {
    echo "Cleaning up..."
    docker stop "$POSTGRES_CONTAINER" 2>/dev/null || true
    docker rm "$POSTGRES_CONTAINER" 2>/dev/null || true
    rm -rf "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# --- Start PostgreSQL ---
start_postgres() {
    docker stop "$POSTGRES_CONTAINER" 2>/dev/null || true
    docker rm "$POSTGRES_CONTAINER" 2>/dev/null || true

    docker run \
        --name "$POSTGRES_CONTAINER" \
        -d \
        -e POSTGRES_USER="$PG_USER" \
        -e POSTGRES_PASSWORD="$PG_PASSWORD" \
        "$POSTGRES_IMAGE"

    echo "Waiting for PostgreSQL to be ready..."
    for _ in $(seq 1 30); do
        if docker exec "$POSTGRES_CONTAINER" pg_isready -U "$PG_USER" >/dev/null 2>&1; then
            echo "PostgreSQL is ready."
            return 0
        fi
        sleep 1
    done
    echo "ERROR: PostgreSQL did not start within 30 seconds"
    exit 1
}

# --- Helper: run psql inside the container ---
run_psql() {
    local db="$1"
    shift
    docker exec "$POSTGRES_CONTAINER" psql -U "$PG_USER" -d "$db" "$@"
}

# --- Build a database by applying SQL files from WORK_DIR in order ---
build_db() {
    local db="$1"
    shift
    run_psql "postgres" -c "DROP DATABASE IF EXISTS ${db};"
    run_psql "postgres" -c "CREATE DATABASE ${db};"
    for sql in "$@"; do
        echo "[${db}] applying ${sql}.sql"
        run_psql "$db" -v ON_ERROR_STOP=1 -f "/workdir/${sql}.sql"
    done
}

# --- Dump and normalize schema ---
# Produces deterministic, comparable output by removing:
#   - migration_history table (created by upgrade, not in create_schema.sql)
#   - migration_status enum type (created by upgrade)
#   - DEFAULT <integer> clauses (upgrade sets runtime-dependent defaults)
#   - Sequence setval calls (differ due to data inserts during upgrade)
#   - Comments and blank lines (timestamps, pg_dump version)
#   - \restrict / \unrestrict lines (random per-dump key, pg_dump >= 17.6)
dump_and_normalize() {
    local db="$1"
    local output_file="$2"

    docker exec "$POSTGRES_CONTAINER" \
        pg_dump --schema-only --no-owner --no-privileges \
        --exclude-table=migration_history \
        -U "$PG_USER" "$db" \
    | grep -v '^--' \
    | grep -v '^$' \
    | grep -Ev '^\\(un)?restrict ' \
    | awk '/^CREATE TYPE.*migration_status/{skip=1} skip && /\);/{skip=0; next} !skip' \
    | sed -E 's/ DEFAULT [0-9]+//g' \
    | sed '/^SELECT pg_catalog.setval/d' \
    > "$output_file"
}

# --- Compare two databases' schemas ---
FAILED=0
compare() {
    local name="$1"
    local expected_db="$2"
    local actual_db="$3"

    dump_and_normalize "$expected_db" "${WORK_DIR}/${expected_db}.schema"
    dump_and_normalize "$actual_db" "${WORK_DIR}/${actual_db}.schema"

    if diff -u "${WORK_DIR}/${expected_db}.schema" "${WORK_DIR}/${actual_db}.schema"; then
        echo "PASS: ${name}"
    else
        echo "FAIL: ${name}"
        echo "  Left:  ${expected_db}"
        echo "  Right: ${actual_db}"
        FAILED=1
    fi
}

# --- Copy a create_schema.sql from a git ref into the container ---
copy_schema_from_ref() {
    local ref="$1"
    local name="$2"

    git show "${ref}:src/app/archive/create_schema.sql" > "${WORK_DIR}/${name}.sql"
    docker cp "${WORK_DIR}/${name}.sql" "${POSTGRES_CONTAINER}:/workdir/${name}.sql"
}

# --- Checks ---
check_round_trip() {
    build_db "created" create_schema
    build_db "round_trip" create_schema upgrade downgrade upgrade

    compare "create + upgrade + downgrade + upgrade == create" \
        "created" "round_trip"
}

check_from_release() {
    if [[ -z "$RELEASE_BRANCH" ]]; then
        RELEASE_BRANCH="$(git ls-remote --heads origin 'release/*' \
            | sed -n 's|.*refs/heads/||p' \
            | grep -E '^release/[0-9]+\.[0-9]+\.[0-9]+$' \
            | sort -V | tail -n 1)"
    fi
    git fetch --tags origin "$RELEASE_BRANCH"
    if [[ -z "$RELEASE_TAG" ]]; then
        RELEASE_TAG="$(git describe --tags --abbrev=0 \
            --match '[0-9]*.[0-9]*.[0-9]*' --exclude '*-*' \
            "origin/${RELEASE_BRANCH}")"
    fi
    echo "Release: ${RELEASE_TAG} (newest on origin/${RELEASE_BRANCH})"

    copy_schema_from_ref "refs/tags/${RELEASE_TAG}" release_create_schema

    build_db "created" create_schema
    build_db "released" release_create_schema
    build_db "release_upgraded" release_create_schema upgrade
    build_db "downgraded" create_schema upgrade downgrade

    compare "${RELEASE_TAG}'s create + upgrade == create" \
        "created" "release_upgraded"
    compare "create + upgrade + downgrade == ${RELEASE_TAG}'s create" \
        "released" "downgraded"
}

check_from_branch() {
    git fetch origin "$FROM_BRANCH"
    echo "From branch: origin/${FROM_BRANCH}"

    copy_schema_from_ref "origin/${FROM_BRANCH}" from_create_schema

    build_db "created" create_schema
    build_db "from_upgraded" from_create_schema upgrade

    compare "${FROM_BRANCH}'s create + upgrade == create" \
        "created" "from_upgraded"
}

# --- Main ---
main() {
    parse_args "$@"

    echo "=== Archive Schema Upgrade Verification: ${CHECK} ==="
    echo "create/upgrade/downgrade: working tree"

    mkdir -p "$WORK_DIR"
    for sql in create_schema upgrade downgrade; do
        cp "${REPO_ROOT}/src/app/archive/${sql}.sql" "${WORK_DIR}/${sql}.sql"
    done

    start_postgres
    docker cp "${WORK_DIR}/." "${POSTGRES_CONTAINER}:/workdir"

    case "$CHECK" in
        round-trip) check_round_trip ;;
        from-release) check_from_release ;;
        from-branch) check_from_branch ;;
    esac

    echo ""
    if [[ "$FAILED" -ne 0 ]]; then
        echo "=== Schema verification FAILED ==="
        exit 1
    fi
    echo "=== All schema verification tests passed ==="
}

main "$@"
