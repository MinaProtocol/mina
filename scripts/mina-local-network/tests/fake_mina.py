#!/usr/bin/env python3
"""A stand-in for the `mina` binary, for tests that spawn a network.

Real enough to be spawned, planned around, and asked questions: it answers the
CLI subcommands mina-local-network drives, and — when run as a daemon — serves
the GraphQL a daemon serves, so the parts of mln that talk to a running network
have something to talk to.

Every behaviour is driven by a FAKE_MINA_* environment variable so a test can
say what this instance should do without a bespoke binary per test. They are
listed in the FAKE_MINA_* table below.

Kept as a file rather than a string a test writes out: it used to be Python
embedded in a bash string embedded in a Python string, which made the GraphQL
server invisible to anyone reading the test file — including to a reader who
concluded it did not exist.
"""

from __future__ import annotations

import http.server
import json
import os
import re
import signal
import socketserver
import subprocess
import sys
import threading
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import List, Optional

# ── FAKE_MINA_* ──────────────────────────────────────────────────────────
#
# Every knob a test has. Unset means "behave like a daemon that works".
#
#   FAKE_MINA_MARKER              touch this path once running
#   FAKE_MINA_ORDER_FILE          append "daemon"/"worker" on start (start order)
#   FAKE_MINA_ARGS_FILE           write argv, one per line
#   FAKE_MINA_ENV_FILE            worker only: dump the environment
#   FAKE_MINA_DAEMON_ENV_FILE     daemon only: append the environment, then "---"
#   FAKE_MINA_COMMAND_LOG         append each client command invoked
#   FAKE_MINA_STATUS_COUNT_FILE   count `client status` calls (poll testing)
#   FAKE_MINA_READY_FILE          `client status` fails until this path exists
#   FAKE_MINA_SEND_PAYMENT_EXIT   non-"0" makes GraphQL sendPayment fail (default 0)
#   FAKE_MINA_TRAP_SIGTERM        ignore SIGTERM (SIGKILL escalation testing)
#   FAKE_MINA_SPAWN_SLEEP         spawn a child that sleeps this long
#   FAKE_MINA_CHILD_PID_FILE      write that child's pid here
#   FAKE_MINA_SLEEP               how long to stay up, seconds (default below)
#   FAKE_MINA_EXIT_CODE           what to exit with (default 0)
#   FAKE_MINA_NO_GQL              set to "1" to serve no GraphQL at all
#   FAKE_MINA_GQL_READY_FILE      GraphQL answers 503 until this path exists
#   FAKE_MINA_GQL_SYNC_STATUS_FILE   syncStatus to report (default SYNCED)
#   FAKE_MINA_GQL_ACCOUNT_NULL    set to "1" to report account: null
#   FAKE_MINA_GQL_INFERRED_NONCE  nonce to report (default "0")
#   FAKE_MINA_GQL_GENESIS_TIMESTAMP
#                                 genesis to report. Default is an hour out, so
#                                 a network is by default spawned before its own
#                                 genesis; set it in the past to act like a
#                                 daemon that came up too late.

DEFAULT_GENESIS_AHEAD = timedelta(hours=1)

# How long a daemon stays up when a test does not say.
#
# Long enough to come up and be asked something — mln waits for its daemons to be
# ready and refuses a network whose daemons never start, so a double that exits
# at once models a broken network rather than a working one, and a test that did
# not mean to say "broken" should not have to say "working".
#
# Short, though: a test that waits for `spawn instance` to return waits this out.
# A test that wants a daemon for longer, or gone sooner, says so.
DEFAULT_SLEEP_SEC = "3"


def env(name: str, default: str = "") -> str:
    return os.environ.get(name, default)


def append_line(path: str, line: str) -> None:
    """Append a line to *path*, if *path* is set."""
    if not path:
        return
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def genesis_timestamp() -> str:
    """The genesis this daemon claims, ISO 8601.

    Defaults far ahead: the daemon-readiness gate requires genesis still future
    when a daemon comes up. A workload after_genesis gate needs it to have passed,
    so those tests set a near-future ``FAKE_MINA_GQL_GENESIS_TIMESTAMP`` — one that
    is still future when the (fast) daemon is ready but arrives within the test.
    """
    configured = env("FAKE_MINA_GQL_GENESIS_TIMESTAMP")
    if configured:
        return configured
    return (datetime.now(timezone.utc) + DEFAULT_GENESIS_AHEAD).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


# ── GraphQL ──────────────────────────────────────────────────────────────


def graphql_reply(body: str) -> dict:
    """The reply this daemon gives to *body*.

    Dispatches on the text of the query rather than parsing it: these are the
    handful of queries mln sends, and matching them by substring keeps the double
    from needing a GraphQL implementation.
    """
    if "syncStatus" in body:
        status = "SYNCED"
        status_file = env("FAKE_MINA_GQL_SYNC_STATUS_FILE")
        if status_file and os.path.exists(status_file):
            status = Path(status_file).read_text(encoding="utf-8").strip() or "SYNCED"
        return {"data": {"syncStatus": status}}

    if "genesisConstants" in body:
        return {"data": {"genesisConstants": {"genesisTimestamp": genesis_timestamp()}}}

    if "account(" in body:
        if env("FAKE_MINA_GQL_ACCOUNT_NULL") == "1":
            return {"data": {"account": None}}
        nonce = env("FAKE_MINA_GQL_INFERRED_NONCE", "0")
        # Both fields carry the same value: a test that wants them to differ has
        # not needed to yet. AccountNonce is a string on the wire.
        return {"data": {"account": {"inferredNonce": nonce, "nonce": nonce}}}

    if "sendPayment" in body:
        return send_payment_reply(body)

    return {"data": {"ok": True}}


def send_payment_reply(body: str) -> dict:
    """Answer a sendPayment mutation, and record it in the command log.

    The value_transfer worker submits payments through GraphQL, so this both
    stands in for the daemon's reply and — for tests that assert on what was
    sent — writes a `send-payment … -nonce N` line to FAKE_MINA_COMMAND_LOG, the
    shape those tests already read. FAKE_MINA_SEND_PAYMENT_EXIT set to non-"0"
    makes the send fail (a GraphQL error), standing in for a daemon rejection.
    """

    # The POST body is {"query": "...mutation..."}; the mutation's quotes are
    # JSON-escaped there, so read the un-escaped query text before matching.
    try:
        query = json.loads(body).get("query", body)
    except (json.JSONDecodeError, AttributeError):
        query = body

    def field(name: str) -> str:
        match = re.search(name + r':\s*"([^"]*)"', query)
        return match.group(1) if match else ""

    nonce = field("nonce")
    append_line(
        env("FAKE_MINA_COMMAND_LOG"),
        f"send-payment -sender {field('from')} -receiver {field('to')} "
        f"-amount {field('amount')} -fee {field('fee')} -nonce {nonce}",
    )

    fail = env("FAKE_MINA_SEND_PAYMENT_EXIT", "0")
    if fail != "0":
        return {"errors": [{"message": f"fake sendPayment rejected (knob {fail})"}]}
    return {"data": {"sendPayment": {"payment": {"nonce": nonce}}}}


class GraphQLHandler(http.server.BaseHTTPRequestHandler):
    def do_POST(self) -> None:  # noqa: N802 — name fixed by BaseHTTPRequestHandler
        ready_file = env("FAKE_MINA_GQL_READY_FILE")
        if ready_file and not os.path.exists(ready_file):
            self.send_response(503)
            self.end_headers()
            return

        if self.path != "/graphql":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length).decode("utf-8") if length else ""
        payload = json.dumps(graphql_reply(body)).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *args) -> None:
        """Silence per-request logging — it is noise in test output."""


class GraphQLServer(socketserver.ThreadingTCPServer):
    daemon_threads = True
    allow_reuse_address = True


def serve_graphql(port: int) -> None:
    """Serve GraphQL on *port* until the process exits.

    On a daemon thread on purpose: when this process goes, so does its GraphQL,
    the way a real daemon's does. A separate process would outlive the exit and
    have callers believe a dead daemon was still answering.
    """
    server = GraphQLServer(("127.0.0.1", port), GraphQLHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()


def rest_port_of(argv: List[str]) -> Optional[int]:
    """The --rest-port in *argv*, if it names one."""
    for i, arg in enumerate(argv):
        if arg == "--rest-port" and i + 1 < len(argv):
            return int(argv[i + 1])
    return None


# ── subcommands ──────────────────────────────────────────────────────────


def generate_keypair(argv: List[str]) -> int:
    """advanced generate-keypair -privkey-path PATH"""
    key_path = Path(argv[3])
    stem = key_path.name
    key_path.write_text("fake-privkey-for-" + stem + "\n", encoding="utf-8")
    key_path.with_name(stem + ".pub").write_text(
        "fake-pubkey-for-" + stem + "\n", encoding="utf-8"
    )
    return 0


def client_status() -> int:
    """client status -daemon-port N"""
    count_file = env("FAKE_MINA_STATUS_COUNT_FILE")
    if count_file:
        count = 0
        if os.path.exists(count_file):
            try:
                count = int(Path(count_file).read_text(encoding="utf-8").strip() or "0")
            except ValueError:
                count = 0
        Path(count_file).write_text(str(count + 1), encoding="utf-8")

    ready_file = env("FAKE_MINA_READY_FILE")
    if ready_file:
        return 0 if os.path.exists(ready_file) else 1
    return 0


def log_command(label: str, argv: List[str]) -> None:
    append_line(env("FAKE_MINA_COMMAND_LOG"), label + " " + " ".join(argv))


def run_daemon(argv: List[str], kind: str) -> int:
    """daemon, or internal snark-worker.

    Records what it was asked to be, serves GraphQL if it is a daemon, then stays
    up for FAKE_MINA_SLEEP seconds before exiting with FAKE_MINA_EXIT_CODE.
    """
    # Order first: a test reading start order needs it recorded before anything
    # here can block.
    append_line(env("FAKE_MINA_ORDER_FILE"), kind)

    marker = env("FAKE_MINA_MARKER")
    if marker:
        Path(marker).touch()

    args_file = env("FAKE_MINA_ARGS_FILE")
    if args_file:
        Path(args_file).write_text("\n".join(argv) + "\n", encoding="utf-8")

    environment = "\n".join(sorted(k + "=" + v for k, v in os.environ.items()))
    if kind == "worker" and env("FAKE_MINA_ENV_FILE"):
        Path(env("FAKE_MINA_ENV_FILE")).write_text(environment + "\n", encoding="utf-8")
    if kind == "daemon" and env("FAKE_MINA_DAEMON_ENV_FILE"):
        with open(env("FAKE_MINA_DAEMON_ENV_FILE"), "a", encoding="utf-8") as fh:
            fh.write(environment + "\n---\n")

    if env("FAKE_MINA_TRAP_SIGTERM"):
        signal.signal(signal.SIGTERM, signal.SIG_IGN)

    spawn_sleep = env("FAKE_MINA_SPAWN_SLEEP")
    if spawn_sleep:
        child = subprocess.Popen(["sleep", spawn_sleep])
        child_pid_file = env("FAKE_MINA_CHILD_PID_FILE")
        if child_pid_file:
            Path(child_pid_file).write_text(str(child.pid), encoding="utf-8")

    if kind == "daemon" and env("FAKE_MINA_NO_GQL") != "1":
        port = rest_port_of(argv)
        if port is not None:
            serve_graphql(port)

    time.sleep(float(env("FAKE_MINA_SLEEP", DEFAULT_SLEEP_SEC)))
    return int(env("FAKE_MINA_EXIT_CODE", "0"))


def main(argv: List[str]) -> int:
    if argv[:3] == ["advanced", "generate-keypair", "-privkey-path"]:
        return generate_keypair(argv)
    if argv[:2] == ["client", "status"]:
        return client_status()
    if argv[:2] == ["account", "import"]:
        log_command("import", argv)
        return 0
    if argv[:2] == ["account", "unlock"]:
        log_command("unlock", argv)
        return 0
    if argv[:2] == ["client", "send-payment"]:
        log_command("send-payment", argv)
        return int(env("FAKE_MINA_SEND_PAYMENT_EXIT", "0"))
    if argv[:1] == ["daemon"]:
        return run_daemon(argv, "daemon")
    if argv[:2] == ["internal", "snark-worker"]:
        return run_daemon(argv, "worker")

    sys.stderr.write("fake-mina: unhandled command: " + " ".join(argv) + "\n")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
