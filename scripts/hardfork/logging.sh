#!/usr/bin/env bash

# Shared logging library for hardfork test scripts
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/logging.sh"

# Prevent multiple sourcing
if [[ -n "${HARDFORK_LOGGING_LOADED:-}" ]]; then
    return 0
fi
readonly HARDFORK_LOGGING_LOADED=1

# Log levels
readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

# Default log level (can be overridden by LOG_LEVEL environment variable)
CURRENT_LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# Color codes for different log levels (if supported)
if [[ -t 2 ]] && command -v tput >/dev/null 2>&1; then
    readonly COLOR_DEBUG='\033[36m'    # Cyan
    readonly COLOR_INFO='\033[32m'     # Green  
    readonly COLOR_WARN='\033[33m'     # Yellow
    readonly COLOR_ERROR='\033[31m'    # Red
    readonly COLOR_RESET='\033[0m'     # Reset
else
    readonly COLOR_DEBUG=''
    readonly COLOR_INFO=''
    readonly COLOR_WARN=''
    readonly COLOR_ERROR=''
    readonly COLOR_RESET=''
fi

# Internal logging function
_log() {
    local level="$1"
    local level_name="$2"
    local color="$3"
    shift 3
    
    # Check if we should log this level
    if [[ $level -lt $CURRENT_LOG_LEVEL ]]; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    printf "${color}[%s] %s: %s${COLOR_RESET}\n" "$timestamp" "$level_name" "$*" >&2
}

# Public logging functions
log_debug() {
    _log $LOG_LEVEL_DEBUG "DEBUG" "$COLOR_DEBUG" "$@"
}

log_info() {
    _log $LOG_LEVEL_INFO "INFO" "$COLOR_INFO" "$@"
}

log_warn() {
    _log $LOG_LEVEL_WARN "WARN" "$COLOR_WARN" "$@"
}

log_error() {
    _log $LOG_LEVEL_ERROR "ERROR" "$COLOR_ERROR" "$@"
}

# Convenience function for debugging (same as log_debug but shorter)
log_d() {
    log_debug "$@"
}

# Convenience function for info (same as log_info but shorter)
log_i() {
    log_info "$@"
}

# Convenience function for warnings (same as log_warn but shorter)
log_w() {
    log_warn "$@"
}

# Convenience function for errors (same as log_error but shorter)  
log_e() {
    log_error "$@"
}

# Function to set log level dynamically
set_log_level() {
    local level="$1"
    case "$level" in
        debug|DEBUG|0) CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info|INFO|1) CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warn|warning|WARN|WARNING|2) CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN ;;
        error|ERROR|3) CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        *) 
            log_error "Invalid log level: $level. Valid levels: debug, info, warn, error"
            return 1
            ;;
    esac
    log_debug "Log level set to: $level"
}

# Initialize log level from environment if set
if [[ -n "${DEBUG:-}" ]] && [[ "${DEBUG}" == "true" ]]; then
    set_log_level debug
elif [[ -n "${LOG_LEVEL:-}" ]]; then
    set_log_level "$LOG_LEVEL"
fi

# NOTE: Command execution functions have been moved to cmd_exec.sh
# following SPOR (Single Point of Responsibility) pattern.
# Use: source "$(dirname "${BASH_SOURCE[0]}")/cmd_exec.sh" for command execution utilities.

# Log file operations
log_file_op() {
    local operation="$1"
    shift
    case "$operation" in
        create|write) log_info "FILE: Creating/writing $*" ;;
        read) log_info "FILE: Reading $*" ;;
        copy) log_info "FILE: Copying $1 -> $2" ;;
        move) log_info "FILE: Moving $1 -> $2" ;;
        delete|remove) log_info "FILE: Deleting $*" ;;
        chmod) log_info "FILE: Setting permissions $1 on $2" ;;
        mkdir) log_info "FILE: Creating directory $*" ;;
        *) log_info "FILE: $operation $*" ;;
    esac
}

# Log network operations
log_net_op() {
    local operation="$1"
    local target="$2"
    shift 2
    case "$operation" in
        curl) log_info "NET: HTTP request to $target $*" ;;
        graphql) log_info "NET: GraphQL query to port $target: $*" ;;
        connect) log_info "NET: Connecting to $target" ;;
        *) log_info "NET: $operation $target $*" ;;
    esac
}

# Log process operations
log_process_op() {
    local operation="$1"
    shift
    case "$operation" in
        start) log_info "PROC: Starting $*" ;;
        stop) log_info "PROC: Stopping $*" ;;
        kill) log_info "PROC: Killing process $*" ;;
        wait) log_info "PROC: Waiting for $*" ;;
        *) log_info "PROC: $operation $*" ;;
    esac
}

# Log environment setup
log_env_setup() {
    local component="$1"
    shift
    log_info "ENV: Setting up $component: $*"
}

# Log timing operations
log_timing() {
    local operation="$1"
    shift
    case "$operation" in
        sleep) log_info "TIMING: Sleeping $*" ;;
        wait) log_info "TIMING: Waiting $*" ;;
        timeout) log_info "TIMING: Timeout set to $*" ;;
        *) log_info "TIMING: $operation $*" ;;
    esac
}

# Log configuration operations
log_config() {
    local operation="$1"
    shift
    case "$operation" in
        set) log_info "CONFIG: Setting $*" ;;
        get) log_info "CONFIG: Getting $*" ;;
        validate) log_info "CONFIG: Validating $*" ;;
        generate) log_info "CONFIG: Generating $*" ;;
        *) log_info "CONFIG: $operation $*" ;;
    esac
}

# Log test assertions and validations
log_assert() {
    local description="$1"
    log_info "ASSERT: $description"
}

log_validation() {
    local component="$1"
    local status="$2"
    shift 2
    if [[ "$status" == "start" ]]; then
        log_info "VALIDATE: Starting validation of $component $*"
    elif [[ "$status" == "pass" ]]; then
        log_info "VALIDATE: ✓ $component validation passed $*"
    elif [[ "$status" == "fail" ]]; then
        log_error "VALIDATE: ✗ $component validation failed $*"
    else
        log_info "VALIDATE: $component $status $*"
    fi
}

# Export all functions for use in subshells
export -f log_debug log_info log_warn log_error log_d log_i log_w log_e set_log_level _log
export -f log_file_op log_net_op log_process_op log_env_setup log_timing log_config log_assert log_validation