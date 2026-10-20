#!/usr/bin/env python3
"""Normalise one daemon-startup scenario run for differential comparison.

Usage: normalise.py RUN_DIR

RUN_DIR contains stdout, stderr, exit_code and conf/mina.log as written by
run.sh. Writes RUN_DIR/normalised, a stable text summary in which volatile
details (timestamps, log source locations, backtraces, paths under the run
directory, commit ids, pids) are masked, so that two binaries can be compared
with a plain diff.
"""

import json
import os
import re
import sys

# Log messages whose presence or content depends on timing rather than on the
# startup logic under test.
VOLATILE_MESSAGES = (
    "Long async cycle",
    "Long_async_cycle",
    "Long async job",
    "Long_async_job",
)


def mask(text, run_dir, commit_ids):
    text = text.replace(os.path.realpath(run_dir), "$RUN")
    text = text.replace(run_dir, "$RUN")
    for commit in commit_ids:
        if commit:
            text = text.replace(commit, "$COMMIT")
    text = re.sub(r"\b[0-9a-f]{40}\b", "$COMMIT", text)
    text = re.sub(r"process id \d+", "process id $PID", text)
    text = re.sub(
        r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
        "$UUID",
        text,
    )
    text = re.sub(
        r"coda_crash_report_\d{4}-\d\d-\d\d_\d\d-\d\d-\d\d\.\d+",
        "coda_crash_report_$TIME",
        text,
    )
    text = re.sub(r"Raised (at|by primitive operation at) .*", "$BACKTRACE", text)
    text = re.sub(r"Called from .*", "$BACKTRACE", text)
    text = re.sub(
        r"\d{4}-\d\d-\d\d[ T]\d\d:\d\d:\d\d(\.\d+)?(Z|[+-]\d\d:?\d\d)?",
        "$TIME",
        text,
    )
    return text


def strip_backtraces(value):
    """Remove backtrace fields from structured error metadata."""
    if isinstance(value, dict):
        return {
            k: strip_backtraces(v)
            for k, v in value.items()
            if k not in ("backtrace", "trace")
        }
    if isinstance(value, list):
        return [strip_backtraces(v) for v in value]
    return value


def classify(stdout, log_messages):
    if "encountered a configuration error" in stdout:
        return "user-error"
    if "Generating crash report" in "\n".join(log_messages) or "crashed" in stdout:
        return "crash"
    if any(m.startswith("Creating daemon with commit id") for m in log_messages):
        return "reached-create"
    if any(m.startswith("Unhandled") for m in log_messages):
        return "unhandled"
    return "other"


def main():
    run_dir = sys.argv[1]

    def read(name):
        path = os.path.join(run_dir, name)
        if not os.path.exists(path):
            return ""
        with open(path, errors="replace") as f:
            return f.read()

    commit_ids = read("commit_id").split()
    stdout = read("stdout")
    stderr = read("stderr")
    exit_code = read("exit_code").strip()

    log_lines = []
    log_messages = []
    for line in read("conf/mina.log").splitlines():
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            log_lines.append("UNPARSEABLE " + line)
            continue
        message = entry.get("message", "")
        if any(message.startswith(v) for v in VOLATILE_MESSAGES):
            continue
        log_messages.append(message)
        metadata = strip_backtraces(entry.get("metadata", {}))
        log_lines.append(
            "%s %s %s"
            % (
                entry.get("level", "?"),
                message,
                json.dumps(metadata, sort_keys=True),
            )
        )

    outcome = classify(stdout, log_messages)
    # A run killed at the [Mina_lib.create] marker has no meaningful exit code.
    if outcome == "reached-create":
        exit_code = "killed-at-create"

    out = []
    out.append("outcome: " + outcome)
    out.append("exit_code: " + exit_code)
    out.append("--- stdout")
    out.append(stdout.rstrip())
    out.append("--- stderr")
    out.append(stderr.rstrip())
    out.append("--- mina.log")
    out.extend(log_lines)

    with open(os.path.join(run_dir, "normalised"), "w") as f:
        f.write(mask("\n".join(out), run_dir, commit_ids) + "\n")
    with open(os.path.join(run_dir, "outcome"), "w") as f:
        f.write(outcome + "\n")


if __name__ == "__main__":
    main()
