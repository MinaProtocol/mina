#!/bin/bash

# Archive Schema Upgrade Check Script
#
# This script verifies that when archive schema files are modified, the corresponding
# upgrade script exists. This ensures database schema changes are properly handled
# in production deployments.
#
# USAGE:
#   upgrade-script-check.sh [OPTIONS]
#
# OPTIONS:
#   -m, --mode MODE     Execution mode: 'default' or 'verbose' (default: default)
#                       default: Returns exit code 0/1 without error messages
#                       verbose: Prints error messages and fails with descriptive output
#   -b, --branch BRANCH Target branch for comparison (default: develop)
#   -h, --help          Show this help message
#
# EXIT CODES:
#   0: Success (no schema changes or upgrade script exists)
#   1: Failure (schema changes detected but upgrade script missing)
#
# FILES MONITORED:
#   - src/app/archive/create_schema.sql
#   - src/app/archive/drop_table.sql
#   - src/app/archive/upgrade_to_mesa.sql (required when above files change)

set -euo pipefail

MODE="default"
BRANCH="develop"
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                MODE="$2"
                if [[ "$MODE" != "default" && "$MODE" != "verbose" ]]; then
                    echo "Error: Mode must be 'default' or 'verbose'" >&2
                    exit 1
                fi
                shift 2
                ;;
            -b|--branch)
                BRANCH="$2"
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

# Check if required files exist in the repository
check_file_exists() {
    local file="$1"
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
        if [[ "$MODE" == "assert" ]]; then
            echo "Error: Required file does not exist: $file" >&2
        fi
        return 1
    fi
    return 0
}

# Check if files have differences against specified branch
has_changes() {
    local file="$1"
    if ! check_file_exists "$file"; then
        return 1
    fi

    # Fetch latest branch to ensure accurate comparison
    git fetch origin "$BRANCH" >/dev/null 2>&1 || {
        if [[ "$MODE" == "verbose" ]]; then
            echo "Error: Failed to fetch origin/$BRANCH" >&2
        fi
        return 1
    }

    # Check if file has differences
    git diff --quiet "origin/$BRANCH" -- "$REPO_ROOT/$file" 2>/dev/null
    return $?
}

# Main execution
main() {
    parse_args "$@"

    local monitored_scripts=(
        "src/app/archive/create_schema.sql"
        "src/app/archive/drop_table.sql"
    )

    local scripts=(
        upgrade_script="src/app/archive/upgrade-to-mesa.sql"
        rollback_script="src/app/archive/downgrade-to-berkeley.sql"
    )

    # Check if either monitored file has changes
    local schema_changed=false

    for script in "${monitored_scripts[@]}"; do
        if has_changes "$script"; then
            schema_changed=true
            if [[ "$MODE" == "verbose" ]]; then
                echo "Detected changes in: $script"
            fi
        fi
    done

    # If schema files changed, verify upgrade script exists
    if [[ "$schema_changed" == "true" ]]; then
        # Check that all required scripts exist
        for script_path in "${scripts[@]}"; do
            if ! check_file_exists "$script_path"; then
            if [[ "$MODE" == "verbose" ]]; then
                echo "Error: Archive schema files have been modified but required script is missing!"
                echo "Please create: $script_path"
                echo "This script should contain the necessary database migration steps."
            fi
            exit 1
            fi
        done

        if [[ "$MODE" == "verbose" ]]; then
            echo "✓ Archive schema changes detected and upgrade script exists"
        fi
    else
        if [[ "$MODE" == "verbose" ]]; then
            echo "✓ No archive schema changes detected"
        fi
    fi

    exit 0
}

main "$@"