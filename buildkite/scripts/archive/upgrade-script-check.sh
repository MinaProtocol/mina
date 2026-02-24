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
#   -m, --mode MODE                 Execution mode: 'default' or 'verbose' (default: default)
#                                   default: Returns exit code 0/1 without error messages
#                                   verbose: Prints error messages and fails with descriptive output
#   -b, --comparison-branch BRANCH  Target branch for comparison (default: develop)
#   -h, --help                      Show this help message
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
COMPARISION_BRANCH="develop"

source "$(dirname "$0")/../export-git-env-vars.sh"

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
            -b|--comparison-branch)
                COMPARISION_BRANCH="$2"
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

# Cached merge base to avoid repeated git fetch and merge-base calculations
_MERGE_BASE=""

# Fetch comparison branch and compute merge-base (cached)
get_merge_base() {
    if [[ -n "$_MERGE_BASE" ]]; then
        return 0
    fi

    git fetch origin "$COMPARISION_BRANCH" >/dev/null 2>&1 || {
        if [[ "$MODE" == "verbose" ]]; then
            echo "Error: Failed to fetch origin/$COMPARISION_BRANCH" >&2
        fi
        return 1
    }

    _MERGE_BASE=$(git merge-base "origin/$COMPARISION_BRANCH" HEAD)
}

# Check if file has changes against the comparison branch
# Usage: has_changes [--include-worktree] <file>
#   --include-worktree: Also check staged and unstaged changes (for local testing)
has_changes() {
    local include_worktree=false
    if [[ "${1:-}" == "--include-worktree" ]]; then
        include_worktree=true
        shift
    fi

    local file="$1"
    if ! check_file_exists "$file"; then
        return 1
    fi

    if ! get_merge_base; then
        return 1
    fi

    local file_path="$REPO_ROOT/$file"

    # Check committed changes (all commits since merge-base)
    if ! git diff --quiet "$_MERGE_BASE" HEAD -- "$file_path" 2>/dev/null; then
        return 0
    fi

    if [[ "$include_worktree" == "true" ]]; then
        # Also check staged and unstaged changes (for local testing)
        if ! git diff --quiet --cached -- "$file_path" 2>/dev/null; then
            return 0
        fi
        if ! git diff --quiet -- "$file_path" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}


# Main execution
main() {
    parse_args "$@"

    local monitored_scripts=(
        "src/app/archive/create_schema.sql"
        "src/app/archive/drop_table.sql"
    )

    local scripts=(
        "src/app/archive/upgrade_to_mesa.sql"
        "src/app/archive/downgrade_to_berkeley.sql"
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

        if ./buildkite/scripts/git/check-bypass.sh "!ci-bypass-upgrade-script-check"; then
            echo "⏭️  Skipping upgrade script check as PR is bypassed"
            exit 0
        fi

        # Determine if this is a PR build
        local is_pr_build=false
        if [[ -n "${BUILDKITE_PULL_REQUEST:-}" && "${BUILDKITE_PULL_REQUEST:-}" != "false" ]]; then
            is_pr_build=true
        fi

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

            # For PR builds, check if the upgrade script itself has changes in git
            # For non-PR builds (nightlies, branch builds), schema may naturally diverge
            # from the comparison branch, so only verify that the scripts exist
            if [[ "$is_pr_build" == "true" ]]; then
                if has_changes --include-worktree "$script_path"; then
                    if [[ "$MODE" == "verbose" ]]; then
                        echo "✓ Upgrade script has been modified: $script_path"
                    fi
                else
                    if [[ "$MODE" == "verbose" ]]; then
                        echo "Error: Schema changed but upgrade script not updated: $script_path"
                        echo "Please update the upgrade script to reflect schema changes."
                        echo "This is critical to ensure smooth database migrations in production."
                        echo "Upgrade/Rollback scripts must be updated together with schema changes, in the same commit."
                        echo "For local testing, scripts can be modified in staged/unstaged git states."
                        exit 1
                    fi
                fi
            else
                if [[ "$MODE" == "verbose" ]]; then
                    echo "✓ Upgrade script exists (non-PR build, skipping modification check): $script_path"
                fi
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
