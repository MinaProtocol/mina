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

# Blacklist stale mina.list by default — install.sh creates it for a temporary
# local aptly server and should clean it up, but if a previous build crashed
# the file may persist and cause apt-get update to fail on localhost:8080.
BLACKLISTED_REPOS=("mina.list")
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
#######################################
# Comment out the source lines apt reported as carrying an expired Release.
#
# When a distribution leaves LTS its security pocket stops being re-signed:
# bullseye left LTS on 2026-08-31, so
#   http://deb.debian.org/debian-security bullseye-security
# now serves a Release whose Valid-Until has passed and will never be
# refreshed. apt reports
#   E: Release file for .../bullseye-security/InRelease is expired
# and exits non-zero, which is fatal for every caller of this script.
#
# The o1Labs deb-mirror already carries that pocket in full (see the bullseye
# note in dockerfiles/scripts/configure-apt-proxy.sh), so on CI images the
# expired upstream entry contributes nothing and is the only thing that can
# fail. This is the same policy configure-apt-proxy.sh applies at image build
# time via MIRROR_AUTHORITATIVE, applied at run time to images that were built
# before that flag existed.
#
# We act only on the exact URL+suite apt named, never on a hardcoded codename
# list, and we refuse to act at all if it would leave apt with no sources --
# an image with no deb-mirror must keep its expired upstream and fail loudly
# rather than silently lose every package source.
#
# Globals:
#   SUDO_CMD
# Arguments:
#   $1 - file holding the captured apt-get update output
# Returns:
#   0 if at least one source was disabled, 1 otherwise
#######################################
disable_expired_release_sources() {
    local apt_output="$1"
    local expired base suite disabled=0

    # "E: Release file for <base>/dists/<suite>/InRelease is expired (...)"
    expired=$(sed -nE \
        's|^E: Release file for (https?://.+)/dists/([^/]+)/(InRelease\|Release) is expired.*|\1 \2|p' \
        "${apt_output}" | sort -u)

    if [[ -z "${expired}" ]]; then
        return 1
    fi

    local -a source_files=()
    [[ -f /etc/apt/sources.list ]] && source_files+=(/etc/apt/sources.list)
    while IFS= read -r f; do
        source_files+=("${f}")
    done < <(find "${APT_SOURCES_DIR}" -maxdepth 1 -name '*.list' 2>/dev/null)

    if [[ ${#source_files[@]} -eq 0 ]]; then
        return 1
    fi

    # Count the deb lines that would survive before touching anything: if the
    # expired pocket is all we have, disabling it is worse than the failure.
    # Sum in bash: bc is not present in a plain Debian/Ubuntu base image.
    local total_before=0 survivors n
    while IFS= read -r n; do
        total_before=$(( total_before + n ))
    done < <(grep -chE '^[[:space:]]*deb(-src)?[[:space:]]' "${source_files[@]}")

    local match_count=0
    while read -r base suite; do
        [[ -n "${base}" ]] || continue
        # Anchored on the exact repository URL and suite apt named. The
        # optional [options] block is what carries [trusted=yes] / [arch=...].
        while IFS= read -r n; do
            match_count=$(( match_count + n ))
        done < <(grep -chE \
            "^[[:space:]]*deb(-src)?[[:space:]]+(\\[[^]]*\\][[:space:]]+)?${base//\//\\/}/?[[:space:]]+${suite}([[:space:]]|\$)" \
            "${source_files[@]}")
    done <<< "${expired}"

    survivors=$(( total_before - match_count ))
    if [[ "${survivors}" -le 0 ]]; then
        error "every remaining apt source carries an expired Release; refusing to disable them all"
        return 1
    fi

    while read -r base suite; do
        [[ -n "${base}" ]] || continue
        log "Disabling expired apt source: ${base} ${suite}"
        ${SUDO_CMD} sed -i -E \
            "s|^([[:space:]]*deb(-src)?[[:space:]]+(\\[[^]]*\\][[:space:]]+)?${base//\//\\/}/?[[:space:]]+${suite}([[:space:]].*)?)\$|# disabled by update.sh (expired Release): \\1|" \
            "${source_files[@]}"
        disabled=1
    done <<< "${expired}"

    [[ "${disabled}" -eq 1 ]]
}

run_apt_update() {
    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY RUN: Would run: ${SUDO_CMD} apt-get update"
        return 0
    fi
    
    # Bypass any configured APT proxy for localhost
    eval "$(./buildkite/scripts/debian/apt-proxy-bypass.sh localhost)"

    # Captured as well as streamed: the retry below has to know WHICH source
    # apt objected to, and CI still wants the live output.
    local apt_output
    apt_output="$(mktemp)"

    log "Running apt-get update..."
    if ${SUDO_CMD} apt-get update $APT_PROXY_BYPASS_OPTS 2>&1 | tee "${apt_output}"; then
        rm -f "${apt_output}"
        log "apt-get update completed successfully"
        return 0
    fi

    if disable_expired_release_sources "${apt_output}"; then
        log "Retrying apt-get update without the expired sources..."
        if ${SUDO_CMD} apt-get update $APT_PROXY_BYPASS_OPTS; then
            rm -f "${apt_output}"
            log "apt-get update completed successfully"
            return 0
        fi
    fi

    rm -f "${apt_output}"
    error "apt-get update failed"
    return 1
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
