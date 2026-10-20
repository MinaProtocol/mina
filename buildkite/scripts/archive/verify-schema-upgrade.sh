#!/bin/bash

# Archive Schema Upgrade Verification Test
#
# This script verifies that applying upgrade.sql to the released schema
# produces the same schema as the target (develop) branch's create_schema.sql,
# and that downgrade.sql reverses the upgrade correctly.
#
# The released schema is create_schema.sql at the newest release tag (X.Y.Z)
# reachable from the source branch. The source branch's own create_schema.sql
# is not used: it may already carry objects that upgrade.sql adds, so the
# downgrade would never match it.
#
# The upgrade/downgrade scripts are always taken from the current working tree,
# while the target schema is fetched from the remote target branch.
#
# USAGE:
#   verify-schema-upgrade.sh [OPTIONS]
#
# OPTIONS:
#   -s, --source-branch BRANCH   Branch the release tags are cut from (default: compatible)
#   -r, --source-tag TAG         Release tag with the pre-upgrade schema
#                                (default: newest X.Y.Z tag reachable from the source branch)
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
POSTGRES_IMAGE="postgres:17-alpine"
PG_USER="postgres"
PG_PASSWORD="postgres"
REPO_ROOT="$(git rev-parse --show-toplevel)"

SOURCE_BRANCH="compatible"
SOURCE_TAG=""
TARGET_BRANCH="develop"

# --- Argument Parsing ---
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source-branch)
                SOURCE_BRANCH="$2"
                shift 2
                ;;
            -r|--source-tag)
                SOURCE_TAG="$2"
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

# --- Normalize documented Berkeley/Mesa schema deltas ---
# A btree key over the unbounded zkapp_{events,field_array}.element_ids int[]
# overflows Postgres' 2704-byte limit for max-cost zkApps, so Mesa drops those
# UNIQUE constraints/indexes and makes events_id/actions_id nullable. On the
# compatible branch this delta shows up in two places and is intentionally
# tolerated here rather than by retroactively editing the released migration
# scripts:
#   * upgrade:   compatible's create_schema + upgrade still carries Berkeley's
#                element_ids UNIQUE/index + NOT NULL that develop's create_schema
#                has dropped.
#   * downgrade: the downgrade does not restore them (lossy) — post-Mesa data may
#                hold duplicates, oversized arrays, or NULLs Berkeley rejected.
# Strip that documented delta from both sides before comparing.
#
# TODO: the upgrade arm of this tolerance is only needed because compatible's
# released upgrade.sql never dropped the element_ids UNIQUE/index and the
# events_id/actions_id NOT NULL, while develop's does. Once compatible's migration
# carries those DROPs, stop normalizing the upgrade comparison (Test 1) and let it
# assert the constraints are gone; the downgrade arm (Test 2) stays either way,
# since the downgrade is deliberately lossy.
normalize_known_schema_deltas() {
    local schema_file="$1"
    local tmp_file="${schema_file}.known_downgrade_deltas"

    awk '
        /^ALTER TABLE ONLY public\.zkapp_(events|field_array)$/ {
            alter_line = $0
            if ((getline constraint_line) <= 0) {
                print alter_line
                next
            }
            if (constraint_line ~ /^    ADD CONSTRAINT zkapp_(events|field_array)_element_ids_key UNIQUE \(element_ids\);$/) {
                next
            }
            print alter_line
            print constraint_line
            next
        }
        /^CREATE INDEX idx_zkapp_(events|field_array)_element_ids ON public\.zkapp_(events|field_array) USING btree \(element_ids\);$/ {
            next
        }
        {
            sub(/^    events_id integer NOT NULL,/, "    events_id integer,")
            sub(/^    actions_id integer NOT NULL,/, "    actions_id integer,")
            print
        }
    ' "$schema_file" > "$tmp_file"

    mv "$tmp_file" "$schema_file"
}

# --- Main ---
main() {
    parse_args "$@"

    # Fetch both branches and the release tags
    git fetch --tags origin "$SOURCE_BRANCH" "$TARGET_BRANCH"

    if [[ -z "$SOURCE_TAG" ]]; then
        SOURCE_TAG="$(git describe --tags --abbrev=0 \
            --match '[0-9]*.[0-9]*.[0-9]*' --exclude '*-*' \
            "origin/${SOURCE_BRANCH}")"
    fi

    echo "=== Archive Schema Upgrade Verification ==="
    echo "Source (pre-upgrade):         ${SOURCE_TAG} (release tag on ${SOURCE_BRANCH})"
    echo "Target branch (post-upgrade): $TARGET_BRANCH"
    echo "Upgrade/downgrade scripts:    current working tree"
    echo ""

    start_postgres

    # Extract schemas from the release tag and the remote target branch
    local source_schema_file="/tmp/source_schema_$$.sql"
    local target_schema_file="/tmp/target_schema_$$.sql"
    git show "refs/tags/${SOURCE_TAG}:src/app/archive/create_schema.sql" > "$source_schema_file"
    git show "origin/${TARGET_BRANCH}:src/app/archive/create_schema.sql" > "$target_schema_file"

    local upgrade_script="${REPO_ROOT}/src/app/archive/upgrade.sql"
    local downgrade_script="${REPO_ROOT}/src/app/archive/downgrade.sql"

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
    echo "  Expected: ${SOURCE_TAG} schema + upgrade.sql == ${TARGET_BRANCH} schema"
    echo "            except documented Berkeley/Mesa element_ids constraint deltas"

    create_db "archive_fresh"
    create_db "archive_upgraded"

    echo "Applying ${TARGET_BRANCH}'s create_schema.sql to fresh database..."
    run_psql "archive_fresh" -f "/tmp/target_schema.sql"

    echo "Applying ${SOURCE_TAG}'s create_schema.sql to upgrade database..."
    run_psql "archive_upgraded" -f "/tmp/source_schema.sql"

    echo "Applying upgrade.sql..."
    run_psql "archive_upgraded" -f "/workdir/src/app/archive/upgrade.sql"

    local schema_fresh="/tmp/schema_fresh_$$.sql"
    local schema_upgraded="/tmp/schema_upgraded_$$.sql"

    dump_and_normalize "archive_fresh" "$schema_fresh"
    dump_and_normalize "archive_upgraded" "$schema_upgraded"
    normalize_known_schema_deltas "$schema_fresh"
    normalize_known_schema_deltas "$schema_upgraded"

    echo "Comparing schemas..."
    if diff -u "$schema_fresh" "$schema_upgraded"; then
        echo "PASS: Upgraded schema matches ${TARGET_BRANCH}'s fresh schema"
    else
        echo ""
        echo "FAIL: Schema mismatch between upgrade path and fresh create"
        echo "  Left:  ${TARGET_BRANCH}'s create_schema.sql applied directly"
        echo "  Right: ${SOURCE_TAG}'s create_schema.sql + upgrade.sql"
        exit 1
    fi

    # --- Test 2: Downgrade path restores source schema ---
    echo ""
    echo "=== Test 2: Downgrade path verification ==="
    echo "  Expected: ${SOURCE_TAG} schema + upgrade + downgrade == ${SOURCE_TAG} schema"
    echo "            except documented lossy Berkeley constraint restorations"

    create_db "archive_downgraded"
    create_db "archive_source_ref"

    echo "Applying ${SOURCE_TAG}'s create_schema.sql to reference database..."
    run_psql "archive_source_ref" -f "/tmp/source_schema.sql"

    echo "Applying ${SOURCE_TAG}'s create_schema.sql + upgrade + downgrade..."
    run_psql "archive_downgraded" -f "/tmp/source_schema.sql"
    run_psql "archive_downgraded" -f "/workdir/src/app/archive/upgrade.sql"
    run_psql "archive_downgraded" -f "/workdir/src/app/archive/downgrade.sql"

    local schema_source_ref="/tmp/schema_source_ref_$$.sql"
    local schema_downgraded="/tmp/schema_downgraded_$$.sql"

    dump_and_normalize "archive_source_ref" "$schema_source_ref"
    dump_and_normalize "archive_downgraded" "$schema_downgraded"
    normalize_known_schema_deltas "$schema_source_ref"
    normalize_known_schema_deltas "$schema_downgraded"

    echo "Comparing schemas..."
    if diff -u "$schema_source_ref" "$schema_downgraded"; then
        echo "PASS: Downgraded schema matches ${SOURCE_TAG}'s fresh schema"
    else
        echo ""
        echo "FAIL: Schema mismatch between downgrade path and fresh source schema"
        echo "  Left:  ${SOURCE_TAG}'s create_schema.sql applied directly"
        echo "  Right: ${SOURCE_TAG}'s create_schema.sql + upgrade + downgrade"
        exit 1
    fi

    echo ""
    echo "=== All schema verification tests passed ==="
    exit 0
}

main "$@"
