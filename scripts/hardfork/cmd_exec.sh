#!/usr/bin/env bash

# Command execution utilities for hardfork test scripts
# Follows SPOR (Single Point of Responsibility) pattern
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/cmd_exec.sh"

# Prevent multiple sourcing
if [[ -n "${HARDFORK_CMD_EXEC_LOADED:-}" ]]; then
    return 0
fi
readonly HARDFORK_CMD_EXEC_LOADED=1

# Ensure logging is available (cmd_exec depends on logging for command tracing)
if [[ -z "${HARDFORK_LOGGING_LOADED:-}" ]]; then
    # Try to source logging from same directory
    script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    # shellcheck disable=SC1090
    source "$script_dir/logging.sh"
fi

# Log command execution with context
log_cmd() {
    local cmd="$*"
    log_info "EXEC: $cmd"
    if [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]]; then
        log_debug "Working directory: $(pwd)"
        log_debug "Environment: $(env | grep -E '^(MINA|GENESIS|SLOT|DEBUG|LOG_LEVEL)' | sort || true)"
    fi
}

# Execute command with logging and exit code tracking
run_cmd() {
    log_cmd "$@"
    "$@"
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Command failed with exit code $exit_code: $*"
    else
        log_debug "Command succeeded: $*"
    fi
    return $exit_code
}

# Execute command with logging and capture output
run_cmd_capture() {
    log_cmd "$@"
    local output
    local exit_code
    if output=$("$@" 2>&1); then
        exit_code=0
        log_debug "Command succeeded: $*"
        if [[ -n "$output" ]]; then
            log_debug "Output: $output"
        fi
    else
        exit_code=$?
        log_error "Command failed with exit code $exit_code: $*"
        if [[ -n "$output" ]]; then
            log_error "Output: $output"
        fi
    fi
    echo "$output"
    return $exit_code
}

# Execute command with logging but suppress output (useful for noisy commands)
run_cmd_quiet() {
    log_cmd "$@"
    local exit_code
    if "$@" >/dev/null 2>&1; then
        exit_code=0
        log_debug "Command succeeded (output suppressed): $*"
    else
        exit_code=$?
        log_error "Command failed with exit code $exit_code (output suppressed): $*"
    fi
    return $exit_code
}

# Execute command with timeout
run_cmd_timeout() {
    local timeout_duration="$1"
    shift
    
    log_cmd "timeout $timeout_duration $*"
    local exit_code
    if timeout "$timeout_duration" "$@"; then
        exit_code=0
        log_debug "Command succeeded within $timeout_duration: $*"
    else
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            log_error "Command timed out after $timeout_duration: $*"
        else
            log_error "Command failed with exit code $exit_code: $*"
        fi
    fi
    return $exit_code
}

# Execute command in background and return PID
run_cmd_background() {
    log_cmd "$@ &"
    "$@" &
    local pid=$!
    log_debug "Command started in background with PID $pid: $*"
    echo "$pid"
}

# Execute command and retry on failure
run_cmd_retry() {
    local max_attempts="$1"
    local delay="$2"
    shift 2
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        log_debug "Executing command (attempt $attempt/$max_attempts): $*"
        
        if run_cmd "$@"; then
            log_debug "Command succeeded on attempt $attempt: $*"
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            log_debug "Command failed, waiting ${delay}s before retry (attempt $attempt/$max_attempts): $*"
            sleep "$delay"
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_attempts attempts: $*"
    return 1
}

# Execute multiple commands in sequence, stop on first failure
run_cmd_sequence() {
    local cmd
    for cmd in "$@"; do
        if ! run_cmd $cmd; then
            log_error "Command sequence failed at: $cmd"
            return 1
        fi
    done
    log_debug "All commands in sequence succeeded"
    return 0
}

# Execute multiple commands in parallel and wait for all
run_cmd_parallel() {
    local pids=()
    local cmd
    local pid
    
    log_debug "Starting parallel execution of ${#@} commands"
    
    for cmd in "$@"; do
        pid=$(run_cmd_background $cmd)
        pids+=("$pid")
    done
    
    local failed=false
    local exit_code
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            exit_code=$?
            log_error "Parallel command with PID $pid failed with exit code $exit_code"
            failed=true
        fi
    done
    
    if $failed; then
        log_error "One or more parallel commands failed"
        return 1
    else
        log_debug "All parallel commands succeeded"
        return 0
    fi
}

# Check if command exists
cmd_exists() {
    local cmd="$1"
    if command -v "$cmd" >/dev/null 2>&1; then
        log_debug "Command available: $cmd"
        return 0
    else
        log_debug "Command not found: $cmd"
        return 1
    fi
}

# Validate command before execution
run_cmd_validated() {
    local cmd="$1"
    shift
    
    if ! cmd_exists "$cmd"; then
        log_error "Command not available: $cmd"
        return 127
    fi
    
    run_cmd "$cmd" "$@"
}

# Export functions for use in subshells
export -f log_cmd run_cmd run_cmd_capture run_cmd_quiet run_cmd_timeout
export -f run_cmd_background run_cmd_retry run_cmd_sequence run_cmd_parallel
export -f cmd_exists run_cmd_validated