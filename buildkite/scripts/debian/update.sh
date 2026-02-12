#!/usr/bin/env bash

# update.sh - Specialized apt-get update with repository blacklisting support
#
# This script provides a safe way to run apt-get update while temporarily
# disabling problematic repositories. It automatically handles sudo detection
# and provides options to blacklist specific repository files.
#
# Usage:
#   ./update.sh [OPTIONS]
#
# Options:
#   -b, --blacklist FILE    Blacklist a repository file (can be used multiple times)
#   -h, --help             Show this help message
#   -v, --verbose          Enable verbose output
#   -n, --dry-run          Show what would be done without executing
#
# Examples:
#   ./update.sh -b /etc/apt/sources.list.d/helm-stable-debian.list
#   ./update.sh --blacklist helm-stable-debian.list --verbose

set -euo pipefail

# Global variables
SCRIPT_NAME="$(basename "${0}")"
APT_SOURCES_DIR="/etc/apt/sources.list.d"

# Don't prompt for answers during apt-get install
export DEBIAN_FRONTEND=noninteractive

# Configuration

# Set BLACKLISTED_REPOS=() to start with no blacklisted repos
# Usage: Specify name of repo files (not full paths) to blacklist by default

BLACKLISTED_REPOS=()
VERBOSE=false
DRY_RUN=false
SUDO_CMD=""

# Backup directory for temporarily moved files
readonly BACKUP_DIR="/tmp/${SCRIPT_NAME}_backup_$$"

#######################################
# Print usage information
# Globals:
#   SCRIPT_NAME
# Arguments:
#   None
# Outputs:
#   Usage information to stdout
#######################################
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Specialized apt-get update with repository blacklisting support.

OPTIONS:
    -b, --blacklist FILE    Blacklist a repository file (can be used multiple times)
    -h, --help             Show this help message
    -v, --verbose          Enable verbose output
    -n, --dry-run          Show what would be done without executing

EXAMPLES:
    ${SCRIPT_NAME} -b /etc/apt/sources.list.d/helm-stable-debian.list
    ${SCRIPT_NAME} --blacklist helm-stable-debian.list --verbose
    ${SCRIPT_NAME} --dry-run --blacklist problematic-repo.list

EOF
}

#######################################
# Log message with optional verbose mode
# Globals:
#   VERBOSE
# Arguments:
#   $1 - Message to log
# Outputs:
#   Message to stderr if verbose mode is enabled
#######################################
log() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "[INFO] $*" >&2
    fi
}

#######################################
# Log error message
# Arguments:
#   $1 - Error message
# Outputs:
#   Error message to stderr
#######################################
error() {
    echo "[ERROR] $*" >&2
}

#######################################
# Detect if sudo is needed and available
# Globals:
#   SUDO_CMD
# Arguments:
#   None
# Returns:
#   Sets SUDO_CMD variable
#######################################
detect_sudo() {
    if [[ "${EUID}" -eq 0 ]]; then
        log "Running as root, sudo not needed"
        SUDO_CMD=""
    elif command -v sudo >/dev/null 2>&1; then
        log "Using sudo for privileged operations"
        SUDO_CMD="sudo"
    else
        error "Not running as root and sudo is not available"
        return 1
    fi
}

#######################################
# Resolve repository file path
# Arguments:
#   $1 - Repository file (basename or full path)
# Outputs:
#   Full path to repository file
# Returns:
#   0 if file exists, 1 otherwise
#######################################
resolve_repo_path() {
    local repo_file="$1"
    
    # If it's already a full path, use it
    if [[ "${repo_file}" == /* ]]; then
        echo "${repo_file}"
        return 0
    fi
    
    # Otherwise, assume it's in the standard sources.list.d directory
    local full_path="${APT_SOURCES_DIR}/${repo_file}"
    echo "${full_path}"
    
    if [[ -f "${full_path}" ]]; then
        return 0
    else
        return 1
    fi
}

#######################################
# Create backup directory
# Globals:
#   BACKUP_DIR, DRY_RUN
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
create_backup_dir() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY RUN: Would create backup directory: ${BACKUP_DIR}"
        return 0
    fi
    
    log "Creating backup directory: ${BACKUP_DIR}"
    if ! mkdir -p "${BACKUP_DIR}"; then
        error "Failed to create backup directory: ${BACKUP_DIR}"
        return 1
    fi
}

#######################################
# Move blacklisted repositories to backup location
# Globals:
#   BLACKLISTED_REPOS, BACKUP_DIR, SUDO_CMD, DRY_RUN
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
disable_repos() {
    local repo_path backup_path
    
    for repo in "${BLACKLISTED_REPOS[@]}"; do
        if ! repo_path="$(resolve_repo_path "${repo}")"; then
            error "Repository file not found: ${repo}"
            continue
        fi
        
        if [[ ! -f "${repo_path}" ]]; then
            log "Repository file does not exist: ${repo_path}"
            continue
        fi
        
        backup_path="${BACKUP_DIR}/$(basename "${repo_path}")"
        
        if [[ "${DRY_RUN}" == "true" ]]; then
            log "DRY RUN: Would move ${repo_path} to ${backup_path}"
        else
            log "Temporarily disabling repository: ${repo_path}"
            if ! ${SUDO_CMD} mv "${repo_path}" "${backup_path}"; then
                error "Failed to move repository file: ${repo_path}"
                return 1
            fi
        fi
    done
}

#######################################
# Restore blacklisted repositories from backup location
# Globals:
#   BACKUP_DIR, SUDO_CMD, DRY_RUN
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
restore_repos() {
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        log "No backup directory found, nothing to restore"
        return 0
    fi
    
    local backup_file original_path
    
    for backup_file in "${BACKUP_DIR}"/*; do
        if [[ ! -f "${backup_file}" ]]; then
            continue
        fi
        
        original_path="${APT_SOURCES_DIR}/$(basename "${backup_file}")"
        
        if [[ "${DRY_RUN}" == "true" ]]; then
            log "DRY RUN: Would restore ${backup_file} to ${original_path}"
        else
            log "Restoring repository: ${original_path}"
            if ! ${SUDO_CMD} mv "${backup_file}" "${original_path}"; then
                error "Failed to restore repository file: ${original_path}"
                return 1
            fi
        fi
    done
    
    # Clean up backup directory
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY RUN: Would remove backup directory: ${BACKUP_DIR}"
    else
        log "Removing backup directory: ${BACKUP_DIR}"
        rmdir "${BACKUP_DIR}" 2>/dev/null || true
    fi
}

#######################################
# Run apt-get update
# Globals:
#   SUDO_CMD, DRY_RUN
# Arguments:
#   None
# Returns:
#   0 on success, 1 on failure
#######################################
run_apt_update() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY RUN: Would run: ${SUDO_CMD} apt-get update"
        return 0
    fi
    
    log "Running apt-get update..."
    if ! ${SUDO_CMD} apt-get update; then
        error "apt-get update failed"
        return 1
    fi
    
    log "apt-get update completed successfully"
}

#######################################
# Cleanup function for trap
# Globals:
#   None
# Arguments:
#   None
#######################################
cleanup() {
    log "Cleaning up..."
    restore_repos || true
}

#######################################
# Main function
# Arguments:
#   All command line arguments
# Returns:
#   0 on success, 1 on failure
#######################################
main() {
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--blacklist)
                if [[ -z "${2:-}" ]]; then
                    error "Option $1 requires an argument"
                    usage
                    return 1
                fi
                BLACKLISTED_REPOS+=("$2")
                shift 2
                ;;
            -h|--help)
                usage
                return 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -*)
                error "Unknown option: $1"
                usage
                return 1
                ;;
            *)
                error "Unexpected argument: $1"
                usage
                return 1
                ;;
        esac
    done
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Detect sudo requirement
    if ! detect_sudo; then
        return 1
    fi

    # Configure APT mirrors if enabled (for CI reliability)
    if [[ "${APT_MIRROR_ENABLED:-false}" == "true" ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        MIRROR_SCRIPT="${SCRIPT_DIR}/../apt/configure-mirrors.sh"
        if [[ -f "${MIRROR_SCRIPT}" ]]; then
            log "Configuring APT mirrors..."
            bash "${MIRROR_SCRIPT}" || log "Warning: Mirror configuration failed, continuing with defaults"
        fi
    fi

    # Create backup directory if we have repos to blacklist
    if [[ ${#BLACKLISTED_REPOS[@]} -gt 0 ]]; then
        if ! create_backup_dir; then
            return 1
        fi
        
        # Disable blacklisted repositories
        if ! disable_repos; then
            return 1
        fi
    fi
    
    # Run apt-get update
    if ! run_apt_update; then
        return 1
    fi
    
    log "Update completed successfully"
    return 0
}

main "$@"
