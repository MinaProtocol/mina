#!/bin/bash

# Archive Schema Upgrade Verification Test
#
# upgrade.sql names the release it starts from (`-- upgrades: <tag>`) and
# downgrade.sql the release it gives back (`-- restores: <tag>`); both must
# name the same tag. On one database made from <tag>'s create_schema.sql:
#   + upgrade.sql   == working-tree create_schema.sql
#   + downgrade.sql == <tag>'s create_schema.sql
# See src/app/archive/README.md, "Schema migrations".
#
# USAGE:
#   verify-schema-upgrade.sh
#
# REQUIRES:
#   - Docker daemon running
#   - Git repository that has <tag>, or can fetch it from origin
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
ARCHIVE_DIR="${REPO_ROOT}/src/app/archive"

# --- Read the release named by a script header ---
# header_tag FILE KEY prints the tag of the "-- KEY: <tag>" line in FILE.
header_tag() {
    local file="$1"
    local key="$2"
    local tag
    tag=$(sed -n -E "s/^-- ${key}: ([^[:space:]]+)[[:space:]]*$/\1/p" "$file")
    if [[ -z "$tag" || "$(wc -l <<< "$tag")" -ne 1 ]]; then
        echo "ERROR: $file must have exactly one '-- ${key}: <tag>' line" >&2
        exit 1
    fi
    echo "$tag"
}

# --- Cleanup trap ---
cleanup() {
    echo "Cleaning up..."
    docker stop "$POSTGRES_CONTAINER" 2>/dev/null || true
    docker rm "$POSTGRES_CONTAINER" 2>/dev/null || true
    rm -f /tmp/base_schema_$$.sql /tmp/schema_*_$$.sql 2>/dev/null || true
}
trap cleanup EXIT

# --- Start PostgreSQL ---
start_postgres() {
    docker stop "$POSTGRES_CONTAINER" 2>/dev/null || true
    docker rm "$POSTGRES_CONTAINER" 2>/dev/null || true

    docker run \
        --volume "${REPO_ROOT}:/workdir" \
        --workdir /workdir \
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

create_db() {
    local db="$1"
    run_psql "postgres" -c "DROP DATABASE IF EXISTS ${db};"
    run_psql "postgres" -c "CREATE DATABASE ${db};"
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

# --- Main ---
main() {
    case "${1:-}" in
        "") ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            exit 1
            ;;
    esac

    local base_ref restores
    base_ref=$(header_tag "${ARCHIVE_DIR}/upgrade.sql" upgrades)
    restores=$(header_tag "${ARCHIVE_DIR}/downgrade.sql" restores)
    if [[ "$base_ref" != "$restores" ]]; then
        echo "ERROR: upgrade.sql upgrades ${base_ref}, but downgrade.sql restores ${restores}" >&2
        exit 1
    fi

    echo "=== Archive Schema Upgrade Verification ==="
    echo "Base release: $base_ref"
    echo ""

    # CI checkouts do not always carry tags.
    if ! git rev-parse --verify --quiet "${base_ref}^{commit}" >/dev/null; then
        git fetch origin "refs/tags/${base_ref}:refs/tags/${base_ref}"
    fi

    local base_schema_file="/tmp/base_schema_$$.sql"
    git show "${base_ref}:src/app/archive/create_schema.sql" > "$base_schema_file"

    start_postgres

    docker cp "$base_schema_file" "${POSTGRES_CONTAINER}:/tmp/base_schema.sql"

    create_db "archive_base"
    create_db "archive_current"
    create_db "archive_migrated"

    # create_schema.sql does not stop on its own error, and an error in the
    # base schema would hit the reference and migrated databases alike.
    echo "Applying ${base_ref}'s create_schema.sql to reference database..."
    run_psql "archive_base" -v ON_ERROR_STOP=1 -f "/tmp/base_schema.sql"
    echo "Applying create_schema.sql to reference database..."
    run_psql "archive_current" -v ON_ERROR_STOP=1 -f "/workdir/src/app/archive/create_schema.sql"

    local schema_base="/tmp/schema_base_$$.sql"
    local schema_current="/tmp/schema_current_$$.sql"
    local schema_migrated="/tmp/schema_migrated_$$.sql"
    dump_and_normalize "archive_base" "$schema_base"
    dump_and_normalize "archive_current" "$schema_current"

    echo "Applying ${base_ref}'s create_schema.sql to migrated database..."
    run_psql "archive_migrated" -v ON_ERROR_STOP=1 -f "/tmp/base_schema.sql"

    # --- Test 1: upgrade.sql gives create_schema.sql ---
    echo ""
    echo "=== Test 1: Upgrade path verification ==="
    echo "  Expected: ${base_ref} schema + upgrade.sql == create_schema.sql"
    run_psql "archive_migrated" -f "/workdir/src/app/archive/upgrade.sql"
    dump_and_normalize "archive_migrated" "$schema_migrated"

    if diff -u "$schema_current" "$schema_migrated"; then
        echo "PASS: Upgraded schema matches create_schema.sql"
    else
        echo ""
        echo "FAIL: Schema mismatch between upgrade path and fresh create"
        echo "  Left:  create_schema.sql applied directly"
        echo "  Right: ${base_ref}'s create_schema.sql + upgrade.sql"
        exit 1
    fi

    # --- Test 2: downgrade.sql gives the base schema back ---
    echo ""
    echo "=== Test 2: Downgrade path verification ==="
    echo "  Expected: upgraded database + downgrade.sql == ${base_ref} schema"
    run_psql "archive_migrated" -f "/workdir/src/app/archive/downgrade.sql"
    dump_and_normalize "archive_migrated" "$schema_migrated"

    if diff -u "$schema_base" "$schema_migrated"; then
        echo "PASS: Downgraded schema matches ${base_ref}'s schema"
    else
        echo ""
        echo "FAIL: Schema mismatch between downgrade path and base schema"
        echo "  Left:  ${base_ref}'s create_schema.sql applied directly"
        echo "  Right: ${base_ref}'s create_schema.sql + upgrade.sql + downgrade.sql"
        exit 1
    fi

    echo ""
    echo "=== All schema verification tests passed ==="
    exit 0
}

main "$@"
