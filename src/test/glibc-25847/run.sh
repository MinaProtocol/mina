#!/usr/bin/env bash
#
# run.sh — Reproduce glibc bug #25847 via Async TCP connection churn.
#
# This script builds and runs multiple instances of the TCP reproducer
# in parallel, using a nix flake to pin the glibc version. If any instance
# stops producing output, the bug has triggered.
#
# Usage:
#   ./run.sh                         # Run with defaults (glibc 2.40, 3 instances, 10-min timeout)
#   ./run.sh --fixed                 # Use glibc 2.42 (fixed)
#   ./run.sh -n 3 -t 120            # 3 instances, 2-min timeout
#   ./run.sh --client-fibers 32     # More TCP client fibers per client process
#   ./run.sh --client-procs 3       # 3 client processes per server (more churn)
#
# Options:
#   --fixed              Use glibc 2.42 (fixed) instead of glibc 2.40 (affected)
#   -n, --instances N    Number of parallel instances (default: 5)
#   -t, --timeout SECS   Per-instance timeout in seconds (default: 300)
#   --client-fibers N    TCP client fibers per client process (default: 16)
#   --client-procs N     Client processes per server (default: 1)
#   --bg-fibers N        Background In_thread.run fibers per instance (default: 0)
#   --pause-on-deadlock  When a deadlocked instance is detected, keep it alive and
#                        wait for the user to attach gdb before cleaning up
#   -h, --help           Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

GLIBC_SHELL="default"
N_INSTANCES=3
TIMEOUT=600
N_CLIENT_FIBERS=8
N_CLIENT_PROCS=1
N_BG_FIBERS=0
PAUSE_ON_DEADLOCK=0

usage() {
    sed -n '/^# Usage:/,/^[^#]/{ /^#/s/^# \?//p }' "$0"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --fixed)        GLIBC_SHELL="fixed"; shift ;;
        -n|--instances) N_INSTANCES="$2"; shift 2 ;;
        -t|--timeout)   TIMEOUT="$2"; shift 2 ;;
        --client-fibers) N_CLIENT_FIBERS="$2"; shift 2 ;;
        --client-procs) N_CLIENT_PROCS="$2"; shift 2 ;;
        --bg-fibers)    N_BG_FIBERS="$2"; shift 2 ;;
        --pause-on-deadlock) PAUSE_ON_DEADLOCK=1; shift ;;
        -h|--help)      usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Build the reproducer via nix, getting the store path with the binaries.
echo "Building reproducer (variant=$GLIBC_SHELL)..."
BUILD_PATH=$(nix build "$SCRIPT_DIR#$GLIBC_SHELL" --print-out-paths --no-link)
echo "Built: $BUILD_PATH"
echo ""

check_glibc_version() {
    local libc_path ver
    libc_path=$(ldd "$BUILD_PATH/bin/async_tcp_server" 2>/dev/null \
        | awk '/libc\.so/{print $3}') || true
    if [ -z "$libc_path" ]; then
        echo "Could not determine glibc version."
        echo ""
        return 0
    fi
    ver=$("$libc_path" 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+' || true)
    if [ -z "$ver" ]; then
        echo "Could not determine glibc version."
        echo ""
        return 0
    fi
    local major minor
    major=$(echo "$ver" | cut -d. -f1)
    minor=$(echo "$ver" | cut -d. -f2)

    echo "Binary linked glibc version: $ver"
    if [ "$major" -eq 2 ] && [ "$minor" -ge 27 ] && [ "$minor" -le 40 ]; then
        echo -e "${RED}Affected range (2.27-2.40) — bug can trigger.${NC}"
    elif [ "$major" -eq 2 ] && [ "$minor" -ge 41 ]; then
        echo -e "${GREEN}glibc >= 2.41 — bug is fixed. Test should run indefinitely.${NC}"
    else
        echo -e "${YELLOW}glibc < 2.27 — predates the buggy condvar rewrite.${NC}"
    fi
    echo ""
}

cleanup() {
    local all_pids=("${INSTANCE_PIDS[@]}" "${CLIENT_PIDS[@]}")
    if [ ${#all_pids[@]} -gt 0 ]; then
        echo ""
        echo "Cleaning up instances..."
        for pid in "${all_pids[@]}"; do
            kill "$pid" 2>/dev/null || true
        done
        # Give them a moment to exit, then force-kill stragglers
        sleep 0.5
        for pid in "${all_pids[@]}"; do
            kill -9 "$pid" 2>/dev/null || true
        done
        wait 2>/dev/null || true
    fi
}

INSTANCE_PIDS=()
CLIENT_PIDS=()
trap cleanup EXIT

run_test() {
    echo "=== glibc #25847 TCP connection churn reproducer ==="
    echo "Instances: $N_INSTANCES, timeout: ${TIMEOUT}s per instance"
    echo "Client procs/server: $N_CLIENT_PROCS, fibers/client: $N_CLIENT_FIBERS, bg In_thread fibers: $N_BG_FIBERS"
    echo ""

    check_glibc_version

    local log_dir="$SCRIPT_DIR/logs"
    mkdir -p "$log_dir"

    local preload_env=""
    if [ "$PAUSE_ON_DEADLOCK" -eq 1 ]; then
        preload_env="$BUILD_PATH/lib/allow_ptrace.so"
    fi

    for i in $(seq "$N_INSTANCES"); do
        # Launch server, wait for port, then launch client
        LD_PRELOAD="$preload_env" N_BG_FIBERS="$N_BG_FIBERS" \
            timeout "$TIMEOUT" "$BUILD_PATH/bin/async_tcp_server" \
            > "$log_dir/instance_${i}.log" 2>&1 &
        INSTANCE_PIDS+=($!)
        local server_pid=$!
        echo "  Started server $i (PID $server_pid)"

        # Wait for the server to print its listening port
        local port=""
        local wait_count=0
        while [ -z "$port" ] && [ "$wait_count" -lt 50 ]; do
            sleep 0.1
            port=$(grep -oP 'Server listening on port \K[0-9]+' "$log_dir/instance_${i}.log" 2>/dev/null || true)
            wait_count=$((wait_count + 1))
        done

        if [ -z "$port" ]; then
            echo -e "  ${RED}Failed to get port for server $i — skipping client${NC}"
            continue
        fi

        for c in $(seq "$N_CLIENT_PROCS"); do
            N_CLIENT_FIBERS="$N_CLIENT_FIBERS" \
                timeout "$TIMEOUT" "$BUILD_PATH/bin/async_tcp_client" "$port" \
                > "$log_dir/client_${i}_${c}.log" 2>&1 &
            CLIENT_PIDS+=($!)
            echo "  Started client $i.$c (PID $!) → port $port"
        done
    done

    echo ""
    echo "Waiting for instances (timeout ${TIMEOUT}s)..."
    echo ""

    # Monitor progress until all instances finish.
    # Track previous cycle counts to detect stuck instances (cycle unchanged
    # between consecutive checks means the process has deadlocked).
    local progress_interval=10
    local elapsed=0
    local -a prev_cycles=()
    for i in $(seq "$N_INSTANCES"); do prev_cycles+=("-1"); done

    while true; do
        sleep "$progress_interval"
        elapsed=$((elapsed + progress_interval))

        # Build one-line progress summary
        local summary="  [${elapsed}/${TIMEOUT}s]"
        local first_stuck=0
        for i in $(seq "$N_INSTANCES"); do
            local log="$log_dir/instance_${i}.log"
            local cycle
            cycle=$(tail -1 "$log" 2>/dev/null | sed -n 's/.*cycle=\([0-9]\+\).*/\1/p')
            cycle="${cycle:-0}"
            local marker=""
            if ! kill -0 "${INSTANCE_PIDS[$((i-1))]}" 2>/dev/null; then
                marker=" done"
            elif [ "$cycle" -gt 0 ] && [ "$cycle" -eq "${prev_cycles[$((i-1))]}" ]; then
                marker=" ${RED}STUCK${NC}"
                if [ "$first_stuck" -eq 0 ]; then first_stuck=$i; fi
            fi
            prev_cycles[$((i-1))]="$cycle"
            summary+="  ${i}:cycle=${cycle}${marker}"
        done
        echo -e "$summary"

        # If --pause-on-deadlock and a stuck instance was found, keep it alive
        # for gdb inspection. Kill all other instances and wait for user input.
        if [ "$PAUSE_ON_DEADLOCK" -eq 1 ] && [ "$first_stuck" -gt 0 ]; then
            local stuck_timeout_pid="${INSTANCE_PIDS[$((first_stuck-1))]}"
            # Find the actual binary child under the timeout wrapper
            local stuck_child_pid
            stuck_child_pid=$(pgrep -P "$stuck_timeout_pid" 2>/dev/null || true)

            if [ -n "$stuck_child_pid" ]; then
                # Kill the timeout wrapper with SIGKILL so its signal handler
                # doesn't forward SIGTERM to the child. The child becomes
                # orphaned (reparented to init) and stays alive for gdb.
                kill -9 "$stuck_timeout_pid" 2>/dev/null || true

                # Kill all other instances and all clients normally
                for j in "${!INSTANCE_PIDS[@]}"; do
                    if [ "${INSTANCE_PIDS[$j]}" != "$stuck_timeout_pid" ]; then
                        kill "${INSTANCE_PIDS[$j]}" 2>/dev/null || true
                    fi
                done
                for pid in "${CLIENT_PIDS[@]}"; do
                    kill "$pid" 2>/dev/null || true
                done
                wait 2>/dev/null || true
                INSTANCE_PIDS=()
                CLIENT_PIDS=()

                echo ""
                echo -e "${RED}Instance $first_stuck is deadlocked.${NC}"
                echo -e "Process kept alive: ${YELLOW}PID $stuck_child_pid${NC}"
                echo ""

                # Dump thread backtraces to a file for post-mortem analysis
                local dump_file="$log_dir/instance_${first_stuck}_threads.txt"
                if gdb -batch \
                    -ex 'info threads' \
                    -ex 'thread apply all bt' \
                    -p "$stuck_child_pid" > "$dump_file" 2>&1; then
                    echo "  Thread dump:  $dump_file"
                else
                    echo "  gdb attach failed (see $dump_file)"
                fi
                echo "  Attach gdb:   gdb -p $stuck_child_pid"
                echo ""
                echo "Press Enter to kill the process and exit..."
                read -r
                kill "$stuck_child_pid" 2>/dev/null || true
                echo "Killed PID $stuck_child_pid."
                return
            fi
        fi

        # Check if all instances have finished
        local all_done=true
        for pid in "${INSTANCE_PIDS[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                all_done=false
                break
            fi
        done
        if $all_done; then break; fi
    done

    # Collect exit codes
    echo ""
    local deadlock_count=0
    local timeout_count=0
    for i in "${!INSTANCE_PIDS[@]}"; do
        local idx=$((i + 1))
        if wait "${INSTANCE_PIDS[$i]}" 2>/dev/null; then
            echo -e "  Instance $idx: ${YELLOW}Exited normally (unexpected)${NC}"
        else
            local rc=$?
            if [ "$rc" -eq 124 ]; then
                timeout_count=$((timeout_count + 1))
                echo -e "  Instance $idx: ${GREEN}Timed out — no deadlock in ${TIMEOUT}s${NC}"
            elif [ "$rc" -eq 137 ]; then
                echo -e "  Instance $idx: ${YELLOW}Killed (SIGKILL)${NC}"
            else
                echo -e "  Instance $idx: ${YELLOW}Exited with code $rc${NC}"
            fi
        fi
    done

    # Check for deadlocked instances by looking for ones that stopped producing
    # output well before the timeout. An instance that deadlocked will have its
    # last log line's cycle number much lower than expected.
    echo ""
    echo "--- Log analysis ---"
    for i in $(seq "$N_INSTANCES"); do
        local log="$log_dir/instance_${i}.log"
        local lines
        lines=$(wc -l < "$log" 2>/dev/null || echo 0)
        local last
        last=$(tail -1 "$log" 2>/dev/null || echo "(empty)")
        local last_cycle
        last_cycle=$(echo "$last" | sed -n 's/.*cycle=\([0-9]\+\).*/\1/p')
        last_cycle="${last_cycle:-0}"

        # If the instance ran for the full timeout, we'd expect cycle ~= TIMEOUT.
        # If cycle is much less, the instance likely deadlocked.
        # Use 80% of timeout as threshold to account for startup time.
        local expected_min=$(( TIMEOUT * 80 / 100 ))

        if [ "$last_cycle" -gt 0 ] && [ "$last_cycle" -lt "$expected_min" ]; then
            deadlock_count=$((deadlock_count + 1))
            echo -e "  Instance $i: ${RED}DEADLOCKED at cycle $last_cycle (~${last_cycle}s)${NC}"
        else
            echo -e "  Instance $i: cycle=$last_cycle ($lines log lines)"
        fi
    done

    # Clear PIDs so the EXIT trap doesn't try to kill already-finished processes
    INSTANCE_PIDS=()
    CLIENT_PIDS=()

    echo ""
    if [ "$deadlock_count" -gt 0 ]; then
        echo -e "${RED}*** $deadlock_count of $N_INSTANCES instances deadlocked ***${NC}"
        echo -e "${RED}*** System is affected by glibc bug #25847 ***${NC}"
    else
        echo -e "${GREEN}No deadlock observed in $N_INSTANCES instances over ${TIMEOUT}s.${NC}"
        echo "This may mean the system is not affected, or the test needs a longer"
        echo "run time. Try: ./run.sh -n 10 -t 1800"
    fi
    echo ""
}

run_test
