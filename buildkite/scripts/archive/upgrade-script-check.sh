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
#   -m, --mode MODE     Execution mode: 'conditional' or 'assert' (default: conditional)
#                       conditional: Returns exit code 0/1 without error messages
#                       assert: Prints error messages and fails with descriptive output
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

MODE="conditional"
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                MODE="$2"
                if [[ "$MODE" != "conditional" && "$MODE" != "assert" ]]; then
                    echo "Error: Mode must be 'conditional' or 'assert'" >&2
                    exit 1
                fi
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

# Check if files have differences against origin/develop
has_changes() {
    local file="$1"
    if ! check_file_exists "$file"; then
        return 1
    fi
    
    # Fetch latest origin/develop to ensure accurate comparison
    git fetch origin develop >/dev/null 2>&1 || {
        if [[ "$MODE" == "assert" ]]; then
            echo "Error: Failed to fetch origin/develop" >&2
        fi
        return 1
    }
    
    # Check if file has differences
    git diff --quiet origin/develop -- "$REPO_ROOT/$file" 2>/dev/null
    return $?
}

# Main execution
main() {
    parse_args "$@"
    
    local create_schema="src/app/archive/create_schema.sql"
    local drop_table="src/app/archive/drop_table.sql" 
    local upgrade_script="src/app/archive/upgrade_to_mesa.sql"
    
    # Check if either monitored file has changes
    local schema_changed=false
    
    if has_changes "$create_schema"; then
        schema_changed=true
        if [[ "$MODE" == "assert" ]]; then
            echo "Detected changes in: $create_schema"
        fi
    fi
    
    if has_changes "$drop_table"; then
        schema_changed=true
        if [[ "$MODE" == "assert" ]]; then
            echo "Detected changes in: $drop_table"
        fi
    fi
    
    # If schema files changed, verify upgrade script exists
    if [[ "$schema_changed" == "true" ]]; then
        if ! check_file_exists "$upgrade_script"; then
            if [[ "$MODE" == "assert" ]]; then
                echo "Error: Archive schema files have been modified but upgrade script is missing!"
                echo "Please create: $upgrade_script"
                echo "This script should contain the necessary database migration steps."
            fi
            exit 1
        fi
        
        if [[ "$MODE" == "assert" ]]; then
            echo "✓ Archive schema changes detected and upgrade script exists"
        fi
    else
        if [[ "$MODE" == "assert" ]]; then
            echo "✓ No archive schema changes detected"
        fi
    fi
    
    exit 0
}

main "$@"