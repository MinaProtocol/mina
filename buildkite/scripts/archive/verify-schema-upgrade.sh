#!/bin/bash

# Archive Schema Upgrade Verification Test
#
# This script verifies that applying upgrade_to_mesa.sql to the source
# (Berkeley/compatible) schema produces the same schema as the target
# (Mesa/develop) branch's create_schema.sql, and that downgrade_to_berkeley.sql
# reverses the upgrade correctly.
#
# The upgrade/downgrade scripts are always taken from the current working tree,
# while source and target schemas are fetched from their respective remote branches.
#
# USAGE:
#   verify-schema-upgrade.sh [OPTIONS]
#
# OPTIONS:
#   -s, --source-branch BRANCH   Source (pre-upgrade) branch (default: compatible)
#   -t, --target-branch BRANCH   Target (post-upgrade) branch (default: develop)
#   -h, --help                   Show this help message
#
# REQUIRES:
#   - Docker daemon running
#   - Git repository with access to source and target branches
#
# EXIT CODES:
#   0: All schema comparisons pass
#   1: Schema mismatch detected or error

set -euo pipefail

# --- Constants ---
POSTGRES_CONTAINER="postgres-schema-test-$$"
POSTGRES_IMAGE="postgres:12.4-alpine"
PG_USER="postgres"
PG_PASSWORD="postgres"
REPO_ROOT="$(git rev-parse --show-toplevel)"

SOURCE_BRANCH="compatible"
TARGET_BRANCH="develop"

# --- Argument Parsing ---
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source-branch)
                SOURCE_BRANCH="$2"
                shift 2
                ;;
            -t|--target-branch)
                TARGET_BRANCH="$2"
                shift 2
                ;;
            -h|--help)
                grep '^#' "$0" | sed 's/^# //' | sed 's/^#//'
                exit 0
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

# --- Cleanup trap ---
cleanup() {
    echo "Cleaning up..."
    docker stop "$POSTGRES_CONTAINER" 2>/dev/null || true
    docker rm "$POSTGRES_CONTAINER" 2>/dev/null || true
    rm -f /tmp/source_schema_$$.sql /tmp/target_schema_$$.sql /tmp/schema_*_$$.sql 2>/dev/null || true
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
dump_and_normalize() {
    local db="$1"
    local output_file="$2"

    docker exec "$POSTGRES_CONTAINER" \
        pg_dump --schema-only --no-owner --no-privileges \
        --exclude-table=migration_history \
        -U "$PG_USER" "$db" \
    | grep -v '^--' \
    | grep -v '^$' \
    | awk '/^CREATE TYPE.*migration_status/{skip=1} skip && /\);/{skip=0; next} !skip' \
    | sed -E 's/ DEFAULT [0-9]+//g' \
    | sed '/^SELECT pg_catalog.setval/d' \
    > "$output_file"
}

# --- Main ---
main() {
    parse_args "$@"

    echo "=== Archive Schema Upgrade Verification ==="
    echo "Source branch (pre-upgrade):  $SOURCE_BRANCH"
    echo "Target branch (post-upgrade): $TARGET_BRANCH"
    echo "Upgrade/downgrade scripts:    current working tree"
    echo ""

    # Fetch both branches
    git fetch origin "$SOURCE_BRANCH" "$TARGET_BRANCH"

    start_postgres

    # Extract schemas from remote branches
    local source_schema_file="/tmp/source_schema_$$.sql"
    local target_schema_file="/tmp/target_schema_$$.sql"
    git show "origin/${SOURCE_BRANCH}:src/app/archive/create_schema.sql" > "$source_schema_file"
    git show "origin/${TARGET_BRANCH}:src/app/archive/create_schema.sql" > "$target_schema_file"

    local upgrade_script="${REPO_ROOT}/src/app/archive/upgrade_to_mesa.sql"
    local downgrade_script="${REPO_ROOT}/src/app/archive/downgrade_to_berkeley.sql"

    # Verify upgrade/downgrade scripts exist in working tree
    for f in "$upgrade_script" "$downgrade_script"; do
        if [[ ! -f "$f" ]]; then
            echo "ERROR: Required file not found: $f"
            exit 1
        fi
    done

    # Copy schemas into the container
    docker cp "$source_schema_file" "${POSTGRES_CONTAINER}:/tmp/source_schema.sql"
    docker cp "$target_schema_file" "${POSTGRES_CONTAINER}:/tmp/target_schema.sql"

    # --- Test 1: Upgrade path produces correct schema ---
    echo ""
    echo "=== Test 1: Upgrade path verification ==="
    echo "  Expected: ${SOURCE_BRANCH} schema + upgrade_to_mesa.sql == ${TARGET_BRANCH} schema"

    create_db "archive_fresh"
    create_db "archive_upgraded"

    echo "Applying ${TARGET_BRANCH}'s create_schema.sql to fresh database..."
    run_psql "archive_fresh" -f "/tmp/target_schema.sql"

    echo "Applying ${SOURCE_BRANCH}'s create_schema.sql to upgrade database..."
    run_psql "archive_upgraded" -f "/tmp/source_schema.sql"

    echo "Applying upgrade_to_mesa.sql..."
    run_psql "archive_upgraded" -f "/workdir/src/app/archive/upgrade_to_mesa.sql"

    local schema_fresh="/tmp/schema_fresh_$$.sql"
    local schema_upgraded="/tmp/schema_upgraded_$$.sql"

    dump_and_normalize "archive_fresh" "$schema_fresh"
    dump_and_normalize "archive_upgraded" "$schema_upgraded"

    echo "Comparing schemas..."
    if diff -u "$schema_fresh" "$schema_upgraded"; then
        echo "PASS: Upgraded schema matches ${TARGET_BRANCH}'s fresh schema"
    else
        echo ""
        echo "FAIL: Schema mismatch between upgrade path and fresh create"
        echo "  Left:  ${TARGET_BRANCH}'s create_schema.sql applied directly"
        echo "  Right: ${SOURCE_BRANCH}'s create_schema.sql + upgrade_to_mesa.sql"
        exit 1
    fi

    # --- Test 2: Downgrade path restores source schema ---
    echo ""
    echo "=== Test 2: Downgrade path verification ==="
    echo "  Expected: ${SOURCE_BRANCH} schema + upgrade + downgrade == ${SOURCE_BRANCH} schema"

    create_db "archive_downgraded"
    create_db "archive_source_ref"

    echo "Applying ${SOURCE_BRANCH}'s create_schema.sql to reference database..."
    run_psql "archive_source_ref" -f "/tmp/source_schema.sql"

    echo "Applying ${SOURCE_BRANCH}'s create_schema.sql + upgrade + downgrade..."
    run_psql "archive_downgraded" -f "/tmp/source_schema.sql"
    run_psql "archive_downgraded" -f "/workdir/src/app/archive/upgrade_to_mesa.sql"
    run_psql "archive_downgraded" -f "/workdir/src/app/archive/downgrade_to_berkeley.sql"

    local schema_source_ref="/tmp/schema_source_ref_$$.sql"
    local schema_downgraded="/tmp/schema_downgraded_$$.sql"

    dump_and_normalize "archive_source_ref" "$schema_source_ref"
    dump_and_normalize "archive_downgraded" "$schema_downgraded"

    echo "Comparing schemas..."
    if diff -u "$schema_source_ref" "$schema_downgraded"; then
        echo "PASS: Downgraded schema matches ${SOURCE_BRANCH}'s fresh schema"
    else
        echo ""
        echo "FAIL: Schema mismatch between downgrade path and fresh source schema"
        echo "  Left:  ${SOURCE_BRANCH}'s create_schema.sql applied directly"
        echo "  Right: ${SOURCE_BRANCH}'s create_schema.sql + upgrade + downgrade"
        exit 1
    fi

    echo ""
    echo "=== All schema verification tests passed ==="
    exit 0
}

main "$@"
