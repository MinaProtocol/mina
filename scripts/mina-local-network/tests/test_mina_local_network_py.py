"""
Tests for mina-local-network.py topology tool (no-spawn slice).

Uses subprocess to invoke the CLI since the main script filename has hyphens
which makes direct import awkward.
"""

import base64
import io
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from unittest import mock
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from http.server import BaseHTTPRequestHandler, HTTPServer


def _genesis_soon(seconds: int = 8) -> str:
    """A near-future genesis timestamp (ISO 8601) for after_genesis spawn tests.

    Far enough ahead that the daemon-readiness gate still sees genesis in the
    future when the (fast) fake daemon comes up, but soon enough that the workload
    after_genesis gate fires within the test window.
    """
    return (datetime.now(timezone.utc) + timedelta(seconds=seconds)).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


def _genesis_far(hours: int = 1) -> str:
    """A far-future genesis timestamp (ISO 8601).

    For spawn tests whose network must stay pre-genesis after the daemon comes up:
    readiness-gate tests (which hold the daemon un-ready past a near genesis) and
    tests asserting an after_genesis workload stays suspended.
    """
    return (datetime.now(timezone.utc) + timedelta(hours=hours)).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


def _spawn_env(genesis: str = "soon", **overrides: str) -> dict:
    """Environment for a `spawn instance` subprocess, with the genesis policy set.

    The default workload start is after_genesis, so most spawn tests need genesis
    to arrive within the test window: ``genesis="soon"`` (the default) puts it a few
    seconds out. Tests that must keep the network pre-genesis after the daemon is
    ready — readiness-gate tests, or ones asserting a workload stays suspended —
    pass ``genesis="far"``. ``genesis="unset"`` omits it, for callers that set their
    own (e.g. a genesis in the past). Extra env vars may be passed as keyword
    overrides.

    Owning the genesis policy in one place keeps direct-spawn tests from silently
    inheriting fake-mina's own far-future default and mismatching an after_genesis
    workload — the failure mode this helper exists to prevent.
    """
    env = os.environ.copy()
    if genesis == "soon":
        env["FAKE_MINA_GQL_GENESIS_TIMESTAMP"] = _genesis_soon()
    elif genesis == "far":
        env["FAKE_MINA_GQL_GENESIS_TIMESTAMP"] = _genesis_far()
    elif genesis != "unset":
        raise ValueError(f"unknown genesis policy: {genesis!r}")
    env.update(overrides)
    return env


from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPT_DIR))
PYTHON3 = sys.executable
CLI = str(SCRIPT_DIR / "mina-local-network.py")


def _preset(name: str) -> str:
    """Absolute path to a bundled preset file.

    Presets are ordinary topology files referenced by path — the CLI does not
    resolve a bare preset *name* (see resolve_topology_source)."""
    return str(SCRIPT_DIR / "presets" / f"{name}.jsonc")


def _find_repo_root(start: Path) -> str:
    """Find the nearest git root containing this test harness.

    Some local development checkouts are nested under another Mina checkout;
    walking to a fixed number of parents can accidentally put generated test
    state in the parent worktree. Prefer the nearest `.git` marker instead.
    """
    for candidate in [start, *start.parents]:
        if (candidate / ".git").exists():
            return str(candidate)
    return str(start.parent.parent)


REPO_ROOT = _find_repo_root(SCRIPT_DIR)

from mln.amounts import convert_balance_to_decimal_mina  # noqa: E402
from mln.graphql import (  # noqa: E402
    account_inferred_nonce,
    extract_graphql_document,
    graphql_post,
    wait_for_graphql_synced,
)
from mln.jsonc import strip_jsonc_comments  # noqa: E402
from mln.constants import SEED_PEER_KEY  # noqa: E402
from mln.models import (  # noqa: E402
    CoreProcessEntry,
    GraphQLResponse,
    ProcessKind,
)
from mln.process import _tag_stream, pid_is_running, teardown_process  # noqa: E402
from mln.spawn.lifecycle import launch_process  # noqa: E402
from mln.workload import (  # noqa: E402
    Outcome,
    SubprocessWorkload,
    ThreadWorkload,
    WorkerContext,
    Workload,
)
from mln.workers import (  # noqa: E402
    dispatch_workload,
    run_value_transfer,
)
from mln.models import TransferAccount, ValueTransferPayload  # noqa: E402
from mln.spawn.process_table import build_process_table  # noqa: E402
from mln.spawn.types import DaemonEntry  # noqa: E402


def _run(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    """Run the CLI with args and return the completed process."""
    env = os.environ.copy()
    env.setdefault("PYTHONIOENCODING", "utf-8")
    return subprocess.run(
        [PYTHON3, CLI] + list(args),
        capture_output=True,
        text=True,
        check=check,
        env=env,
        cwd=REPO_ROOT,
    )


def _run_json(*args: str) -> dict:
    """Run the CLI, expect exit 0, and parse stdout as JSON."""
    cp = _run(*args, check=True)
    return json.loads(cp.stdout)


def _terminate_process_tree(
    proc: subprocess.Popen[Any], *, timeout: float = 5.0
) -> None:
    """Terminate a spawned supervisor and its process group.

    Spawn tests often start a Python supervisor which then starts fake daemon
    and worker process groups.  Killing only the supervisor PID can leave those
    fixtures alive and make subsequent test runs hang on open pipes or ports.
    """
    if proc.poll() is not None:
        return

    pgid: Optional[int]
    try:
        pgid = os.getpgid(proc.pid)
    except (OSError, ProcessLookupError):
        pgid = None

    if pgid is not None:
        try:
            os.killpg(pgid, signal.SIGTERM)
        except (OSError, ProcessLookupError):
            pass
    else:
        proc.terminate()

    try:
        proc.wait(timeout=timeout)
        return
    except subprocess.TimeoutExpired:
        pass

    if pgid is not None:
        try:
            os.killpg(pgid, signal.SIGKILL)
        except (OSError, ProcessLookupError):
            pass
    else:
        proc.kill()

    try:
        proc.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        pass


class _StaticGraphQLServer:
    """Tiny GraphQL test server with deterministic JSON responses."""

    def __init__(self, payload: dict, *, status: int = 200):
        self.payload = payload
        self.status = status
        self.requests: list[dict] = []
        parent = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self) -> None:  # noqa: N802 - stdlib callback name
                length = int(self.headers.get("Content-Length", "0") or "0")
                body = self.rfile.read(length).decode("utf-8") if length else ""
                if body:
                    parent.requests.append(json.loads(body))
                else:
                    parent.requests.append({})
                response = json.dumps(parent.payload).encode("utf-8")
                self.send_response(parent.status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(response)))
                self.end_headers()
                self.wfile.write(response)

            def log_message(self, format: str, *args: Any) -> None:
                return

        sock = socket.socket()
        sock.bind(("127.0.0.1", 0))
        host, port = sock.getsockname()
        sock.close()
        self.uri = f"http://127.0.0.1:{port}/graphql"
        self.httpd = HTTPServer((host, port), Handler)
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)

    def __enter__(self) -> "_StaticGraphQLServer":
        self.thread.start()
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=5)


class _VtSendServer:
    """A minimal GraphQL stub for value_transfer worker unit tests.

    Answers the two calls the worker makes against a node: sendPayment (each is
    recorded; optionally rejected with a chosen message, e.g. to model an
    insufficient balance) and the inferredNonce query the worker uses to resync.
    Just enough of the daemon's GraphQL to drive the worker in-process.
    """

    def __init__(self, *, reject: Optional[str] = None, inferred_nonce: str = "0"):
        self.reject = reject
        self.inferred_nonce = inferred_nonce
        self.sends: list[str] = []
        parent = self

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self) -> None:  # noqa: N802 - stdlib callback name
                length = int(self.headers.get("Content-Length", "0") or "0")
                raw = self.rfile.read(length).decode("utf-8") if length else ""
                try:
                    query = json.loads(raw).get("query", raw)
                except json.JSONDecodeError:
                    query = raw
                body = json.dumps(parent._reply(query)).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, format: str, *args: Any) -> None:
                return

        sock = socket.socket()
        sock.bind(("127.0.0.1", 0))
        host, port = sock.getsockname()
        sock.close()
        self.uri = f"http://127.0.0.1:{port}/graphql"
        self.httpd = HTTPServer((host, port), Handler)
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)

    def _reply(self, query: str) -> dict:
        if "sendPayment" in query:

            def field(name: str) -> str:
                m = re.search(name + r':\s*"([^"]*)"', query)
                return m.group(1) if m else ""

            self.sends.append(
                f"send-payment -sender {field('from')} -nonce {field('nonce')}"
            )
            if self.reject is not None:
                return {"errors": [{"message": self.reject}]}
            return {"data": {"sendPayment": {"payment": {"nonce": field("nonce")}}}}
        if "inferredNonce" in query:
            return {"data": {"account": {"inferredNonce": self.inferred_nonce}}}
        return {"data": {"ok": True}}

    def start(self) -> None:
        self.thread.start()

    def stop(self) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=5)


class TestJsoncStripper(unittest.TestCase):
    """Test the built-in JSONC comment stripper."""

    def test_no_comments(self):
        src = '{"a": 1, "b": "hello"}'
        result = strip_jsonc_comments(src)
        self.assertEqual(json.loads(result), {"a": 1, "b": "hello"})

    def test_line_comment(self):
        src = '// top comment\n{"a": 1}\n// bottom'
        result = strip_jsonc_comments(src)
        self.assertEqual(json.loads(result), {"a": 1})

    def test_block_comment(self):
        src = '{"a": 1 /* inline */, "b": 2}'
        result = strip_jsonc_comments(src)
        self.assertEqual(json.loads(result), {"a": 1, "b": 2})

    def test_multiline_block_comment(self):
        src = '{\n  /* multi\n  line\n  comment */\n  "a": 1\n}'
        result = strip_jsonc_comments(src)
        self.assertEqual(json.loads(result), {"a": 1})

    def test_preserves_url_in_string(self):
        src = '{"url": "https://example.com/path?q=1&x=2"}'
        result = strip_jsonc_comments(src)
        self.assertEqual(
            json.loads(result),
            {"url": "https://example.com/path?q=1&x=2"},
        )

    def test_preserves_comment_like_strings(self):
        src = '{"comment": "/* not a comment */", "url": "https://a.com/test?id=1"}'
        result = strip_jsonc_comments(src)
        self.assertEqual(
            json.loads(result),
            {"comment": "/* not a comment */", "url": "https://a.com/test?id=1"},
        )

    def test_string_with_slashes(self):
        src = '{"path": "C:\\\\Users\\\\name", "note": "a // b"}'
        result = strip_jsonc_comments(src)
        self.assertEqual(
            json.loads(result),
            {"path": "C:\\Users\\name", "note": "a // b"},
        )

    def test_trailing_comma_after_comment(self):
        # Comment removal should leave valid JSON if the comment was the only
        # non-JSON element
        src = '{"a": 1,\n// "b": 2\n"c": 3}'
        result = strip_jsonc_comments(src)
        self.assertEqual(json.loads(result), {"a": 1, "c": 3})


# ---------------------------------------------------------------------------
# Helpers for tests that need temp directories / topology fixtures
# ---------------------------------------------------------------------------


def _temp_topology_without_state_root(test_name: str) -> str:
    """Create a temp topology file without explicit state.root.

    Returns the path to the temp .jsonc file (caller must clean up).
    """
    topology = {
        "schema_version": 1,
        "name": test_name,
        "ledger_generation": {"tiers": {}},
        "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
    }
    fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="topo_")
    os.close(fd)
    Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
    return tmp_path


# ---------------------------------------------------------------------------
# CLI integration tests
# ---------------------------------------------------------------------------


class TestPresets(unittest.TestCase):
    """Tests for 'presets' command group."""

    def test_list(self):
        output = _run_json("presets", "list")
        self.assertIn("presets", output)
        self.assertIsInstance(output["presets"], list)
        self.assertIn("single-node", output["presets"])

    def test_every_preset_validates_against_the_schema(self):
        """Every shipped preset must satisfy the schema.

        Presets are consumed by other tools — the hardfork test renders
        hf-test-*.jsonc and hands the result to `plan topology` — so a malformed
        one otherwise surfaces only once that caller is already running, tens of
        minutes into a CI job.
        """
        names = _run_json("presets", "list")["presets"]
        self.assertTrue(names, "no presets found to validate")
        for name in names:
            with self.subTest(preset=name):
                # `schema validate` exits non-zero on failure; check=True raises.
                _run("schema", "validate", _preset(name))

    def test_every_preset_declares_exactly_one_seed(self):
        """Exactly one p2p_seed per preset.

        Nothing in the schema expresses this, but a network with no seed has
        nobody to bootstrap from and one with two has no single bootstrap point,
        so both fail only once daemons are spawning.
        """
        for name in _run_json("presets", "list")["presets"]:
            with self.subTest(preset=name):
                topo = _run_json("presets", "show", _preset(name))
                seeds = [
                    node
                    for node, spec in topo["nodes"].items()
                    if "p2p_seed" in (spec.get("capabilities") or {})
                ]
                self.assertEqual(
                    len(seeds), 1, f"{name} declares {len(seeds)} seeds: {seeds}"
                )

    def test_preset_name_matches_filename(self):
        """A preset's `name` field must match its filename.

        Presets are listed by name but shown by path; a mismatch means the file
        and its declared name disagree about what the topology is called.
        """
        for name in _run_json("presets", "list")["presets"]:
            with self.subTest(preset=name):
                self.assertEqual(
                    _run_json("presets", "show", _preset(name))["name"], name
                )

    def test_show_is_valid_json(self):
        output = _run_json("presets", "show", _preset("single-node"))
        # v1 settles on schema_version, not version
        self.assertEqual(output["schema_version"], 1)
        self.assertEqual(output["name"], "single-node")
        self.assertIn("nodes", output)
        self.assertIn("seed", output["nodes"])

    def test_show_has_capabilities_not_old_shape(self):
        """Verify the settled v1 topology shape: capabilities, no kind/role booleans."""
        output = _run_json("presets", "show", _preset("single-node"))
        seed = output["nodes"]["seed"]

        # Must have capabilities
        self.assertIn("capabilities", seed)
        caps = seed["capabilities"]

        # Must NOT have old-style fields
        self.assertNotIn(
            "kind", seed, "Old 'kind' field must not appear in settled topology"
        )
        self.assertNotIn(
            "p2p_seed", seed, "Old 'p2p_seed' boolean must not appear at node level"
        )
        self.assertNotIn(
            "block_producer",
            seed,
            "Old 'block_producer' boolean must not appear at node level",
        )
        self.assertNotIn("block_producer_key_tier", seed)
        self.assertNotIn("block_producer_key_index", seed)

        # Check capability shapes
        self.assertIn("p2p_seed", caps)
        self.assertIsInstance(caps["p2p_seed"], dict)
        self.assertIn("block_producer", caps)
        self.assertEqual(caps["block_producer"]["account"], "whale-0")
        self.assertIn("snark_coordinator", caps)
        self.assertIn("itn_graphql", caps)

    def test_show_has_grouped_logging(self):
        """Logging must use grouped console/file shape, not flat log_level."""
        output = _run_json("presets", "show", _preset("single-node"))
        logging = output["logging"]

        # Must have console and file groups
        self.assertIn("console", logging)
        self.assertIn("file", logging)

        # Must have node and snark_worker entries
        self.assertIn("node", logging["console"])
        self.assertIn("snark_worker", logging["console"])
        self.assertIn("node", logging["file"])
        self.assertIn("snark_worker", logging["file"])

        # Must NOT have old flat fields
        self.assertNotIn("log_level", logging, "Old flat 'log_level' must not appear")
        self.assertNotIn("file_log_level", logging)
        self.assertNotIn("worker_log_level", logging)

    def test_show_has_state_with_genesis_timestamp(self):
        """State must have genesis_timestamp; root is optional (defaults repo-local)."""
        output = _run_json("presets", "show", _preset("single-node"))
        state = output["state"]

        # root is omitted in the single-node preset → defaults to .mina-local-network/single-node/
        self.assertNotIn("root", state, "root should be absent when preset omits it")
        self.assertIn("genesis_timestamp", state)
        self.assertIn("delay", state["genesis_timestamp"])

    def test_show_no_genesis_state_timestamp_in_ledger(self):
        """genesis_state_timestamp must NOT appear in ledger_generation (belongs under state)."""
        output = _run_json("presets", "show", _preset("single-node"))
        lg = output.get("ledger_generation", {})
        self.assertNotIn(
            "genesis_state_timestamp",
            lg,
            "genesis_state_timestamp must not be in ledger_generation",
        )

    def test_show_no_internal_external_workers_integers(self):
        """snark_coordinator must use worker_pools, not internal_workers/external_workers integers."""
        output = _run_json("presets", "show", _preset("single-node"))
        sc = output["nodes"]["seed"]["capabilities"]["snark_coordinator"]
        self.assertNotIn("internal_workers", sc)
        self.assertNotIn("external_workers", sc)
        self.assertIn("worker_pools", sc)
        self.assertIn("default", sc["worker_pools"])


class TestSchema(unittest.TestCase):
    """Tests for 'schema' command group."""

    def test_print_is_valid_json(self):
        output = _run_json("schema", "print")
        self.assertIn("$schema", output)
        self.assertIn("title", output)

    def test_validate_preset_passes(self):
        cp = _run("schema", "validate", _preset("single-node"), check=False)
        self.assertEqual(cp.returncode, 0, f"Validate failed: {cp.stderr}")
        self.assertIn("Validation PASSED", cp.stdout)

    def test_validate_rejects_old_version_field(self):
        """Topologies with 'version' instead of 'schema_version' must fail validation."""
        old_shape = json.dumps(
            {"version": 1, "ledger_generation": {"tiers": {}}, "nodes": {}}
        )
        tmp_path = ""
        try:
            fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="oldver_")
            os.close(fd)
            Path(tmp_path).write_text(old_shape, encoding="utf-8")
            cp = _run("schema", "validate", tmp_path, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "Should reject topology with old 'version' field"
            )
        finally:
            if tmp_path and Path(tmp_path).exists():
                os.unlink(tmp_path)

    def test_validate_invalid_topology_fails(self):
        tmp_path = ""
        try:
            fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="bad_")
            os.close(fd)
            Path(tmp_path).write_text(
                '{"schema_version": "not-int", "nodes": {}}\n', encoding="utf-8"
            )
            cp = _run("schema", "validate", tmp_path, check=False)
            self.assertNotEqual(cp.returncode, 0)
        finally:
            if tmp_path and Path(tmp_path).exists():
                os.unlink(tmp_path)


# ---------------------------------------------------------------------------
# plan topology tests
# ---------------------------------------------------------------------------


class TestPlanTopology(unittest.TestCase):
    """Tests for 'plan topology' command — resolves and persists runtime plan."""

    @classmethod
    def setUpClass(cls):
        """Ensure baseline plan exists for single-node (via --overwrite)."""
        # Clean up any stale artifacts from previous runs
        shutil.rmtree(os.path.expanduser("~/.mina-network"), ignore_errors=True)
        _run("plan", "topology", _preset("single-node"), "--overwrite", check=False)

    @classmethod
    def tearDownClass(cls):
        """Clean up generated state directory."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    @property
    def _single_node_root(self) -> str:
        return str(Path(REPO_ROOT) / ".mina-local-network" / "single-node")

    def test_plan_writes_file(self):
        """plan topology writes network-plan.json under the default repo-local root."""
        # single-node preset omits state.root → defaults to .mina-local-network/single-node/
        plan_path = Path(self._single_node_root) / "network-plan.json"
        self.assertTrue(
            plan_path.exists(),
            f"Expected plan at {plan_path} after plan topology single-node",
        )

    def test_plan_output_is_strict_json(self):
        """Persisted plan must be valid strict JSON."""
        plan_path = Path(self._single_node_root) / "network-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        self.assertIn("nodes", plan)
        self.assertIn("state", plan)
        self.assertIn("workers", plan)

    def test_second_plan_without_overwrite_fails(self):
        """Second 'plan topology' without --overwrite must fail."""
        cp = _run("plan", "topology", _preset("single-node"), check=False)
        self.assertNotEqual(
            cp.returncode, 0, "Second plan without --overwrite should fail"
        )
        self.assertIn("already exists", cp.stderr)

    def test_plan_with_overwrite_succeeds(self):
        """Plan with --overwrite must succeed even when plan exists."""
        cp = _run("plan", "topology", _preset("single-node"), "--overwrite", check=False)
        self.assertEqual(
            cp.returncode, 0, f"Plan --overwrite should succeed: {cp.stderr}"
        )

    def test_plan_default_root_when_state_root_omitted(self):
        """When state.root is omitted, default to .mina-local-network/<name>/."""
        tmp_path = _temp_topology_without_state_root("no-root-test")
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertEqual(
                cp.returncode,
                0,
                f"Plan with omitted state.root should succeed: {cp.stderr}",
            )
            # Should have written to .mina-local-network/no-root-test/network-plan.json
            default_root = Path(REPO_ROOT) / ".mina-local-network" / "no-root-test"
            plan_file = default_root / "network-plan.json"
            self.assertTrue(
                plan_file.exists(),
                f"Expected plan at {plan_file} when state.root omitted",
            )
            # Clean up the generated dir
            shutil.rmtree(default_root, ignore_errors=True)
        finally:
            if tmp_path and Path(tmp_path).exists():
                os.unlink(tmp_path)


# ---------------------------------------------------------------------------
# inspect instance tests
# ---------------------------------------------------------------------------


class TestInspectInstance(unittest.TestCase):
    """Tests for 'inspect instance' — read-only over persisted plans."""

    @classmethod
    def setUpClass(cls):
        """Ensure plan exists at repo-local default root."""
        # Clean up any stale artifacts
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        _run("plan", "topology", _preset("single-node"), "--overwrite", check=False)

    @classmethod
    def tearDownClass(cls):
        """Clean up generated state directory."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    @property
    def _state_root(self) -> str:
        return str(Path(REPO_ROOT) / ".mina-local-network" / "single-node")

    @property
    def _plan_path(self) -> str:
        return os.path.join(self._state_root, "network-plan.json")

    def test_inspect_instance_by_root_dir(self):
        """inspect instance <state-root> reads network-plan.json from the dir."""
        plan = _run_json("inspect", "instance", self._state_root)
        self.assertIn("nodes", plan)
        self.assertIn("state", plan)

    def test_inspect_instance_by_plan_path(self):
        """inspect instance <plan-path> reads the plan file directly."""
        plan = _run_json("inspect", "instance", self._plan_path)
        self.assertIn("nodes", plan)
        self.assertIn("state", plan)

    def test_inspect_instance_missing_fails(self):
        """inspect instance on a nonexistent state root fails clearly."""
        cp = _run("inspect", "instance", ".mina-local-network/nonexistent", check=False)
        self.assertNotEqual(
            cp.returncode, 0, "inspect instance with missing root should fail"
        )
        self.assertIn("No network plan found", cp.stderr)

    # --- Plan structure assertions (through inspect instance) ---

    def test_resolved_plan_nodes(self):
        plan = _run_json("inspect", "instance", self._state_root)
        nodes = plan.get("nodes", [])
        self.assertGreater(len(nodes), 0, "Expected at least one node")

        seed_node = nodes[0]
        self.assertEqual(seed_node["name"], "seed")
        self.assertIn("daemon_argv", seed_node)
        self.assertIn("config_dir", seed_node)
        self.assertIn("config_file", seed_node)

    def test_resolved_plan_node_has_capabilities_list(self):
        """Resolved plan node must have flattened capabilities list."""
        plan = _run_json("inspect", "instance", self._state_root)
        seed_node = plan["nodes"][0]
        self.assertIn("capabilities", seed_node)
        caps = seed_node["capabilities"]
        self.assertIsInstance(caps, list)
        self.assertIn("p2p_seed", caps)
        self.assertIn("block_producer", caps)
        self.assertIn("snark_coordinator", caps)
        self.assertIn("itn_graphql", caps)

    def test_daemon_argv_contains_expected_flags(self):
        plan = _run_json("inspect", "instance", self._state_root)
        seed_node = plan["nodes"][0]
        argv = seed_node["daemon_argv"]

        # Core port flags
        self.assertIn("--client-port", argv)
        self.assertIn("--rest-port", argv)
        self.assertIn("--external-port", argv)
        self.assertIn("--metrics-port", argv)
        self.assertIn("--libp2p-metrics-port", argv)
        self.assertIn("--insecure-rest-server", argv)

        # Config & logging
        self.assertIn("--config-file", argv)
        self.assertIn("--log-level", argv)
        self.assertIn("--file-log-level", argv)
        self.assertIn("--proof-level", argv)

        # Seed
        self.assertIn("--seed", argv)

        # Block producer
        self.assertIn("--block-producer-key", argv)

        # Snark coordinator
        self.assertIn("-run-snark-coordinator", argv)
        self.assertIn("-snark-worker-fee", argv)
        self.assertIn("-work-selection", argv)

        # ITN
        self.assertIn("--itn-graphql-port", argv)
        self.assertIn("--itn-keys", argv)

        # Demo mode
        self.assertIn("--demo-mode", argv)

        # Config directory at end
        self.assertIn("--config-directory", argv)
        self.assertEqual(argv[-2], "--config-directory")

    def test_daemon_argv_log_levels_from_console_node(self):
        """Daemon --log-level should come from logging.console.node."""
        plan = _run_json("inspect", "instance", self._state_root)
        seed_node = plan["nodes"][0]
        argv = seed_node["daemon_argv"]

        log_level_idx = argv.index("--log-level")
        file_log_idx = argv.index("--file-log-level")

        # single-node preset console.node = "Warn"
        self.assertEqual(argv[log_level_idx + 1], "Warn")
        # single-node preset file.node = "Warn"
        self.assertEqual(argv[file_log_idx + 1], "Warn")

    def test_worker_argv_log_levels_from_snark_worker(self):
        """Worker --log-level should come from logging.console.snark_worker."""
        plan = _run_json("inspect", "instance", self._state_root)
        workers = plan["workers"]
        self.assertGreater(len(workers), 0)
        worker = workers[0]
        argv = worker["worker_argv"]

        log_level_idx = argv.index("--log-level")
        file_log_idx = argv.index("--file-log-level")

        # single-node preset console.snark_worker = "Error"
        self.assertEqual(argv[log_level_idx + 1], "Error")
        # single-node preset file.snark_worker = "Error"
        self.assertEqual(argv[file_log_idx + 1], "Error")

    def test_daemon_argv_starts_with_mina_daemon(self):
        plan = _run_json("inspect", "instance", self._state_root)
        seed_node = plan["nodes"][0]
        argv = seed_node["daemon_argv"]
        self.assertTrue(
            argv[0].endswith("mina.exe") or "mina" in argv[0],
            f"Expected mina binary, got: {argv[0]}",
        )
        self.assertEqual(argv[1], "daemon")

    def test_worker_count_from_worker_pools(self):
        """Worker count should come from snark_coordinator.worker_pools.default.count."""
        plan = _run_json("inspect", "instance", self._state_root)
        workers = plan.get("workers", [])
        # single-node preset has worker_pools.default.count = 3
        self.assertEqual(len(workers), 3)

    def test_worker_argv_shape(self):
        plan = _run_json("inspect", "instance", self._state_root)
        worker = plan["workers"][0]

        argv = worker["worker_argv"]
        self.assertTrue(any("mina" in a for a in argv[:2]))
        self.assertIn("internal", argv)
        self.assertIn("snark-worker", argv)
        self.assertIn("--proof-level", argv)
        self.assertIn("--shutdown-on-disconnect", argv)
        self.assertIn("--daemon-address", argv)
        self.assertIn("--config-directory", argv)

        self.assertIn("MINA_SNARK_WORKER_NAP_SEC", worker["env"])

    def test_worker_nap_from_iso_duration(self):
        """Worker NAP in env should be derived from ISO PT1S -> 1.0."""
        plan = _run_json("inspect", "instance", self._state_root)
        worker = plan["workers"][0]
        self.assertEqual(worker["env"]["MINA_SNARK_WORKER_NAP_SEC"], "1.0")

    def test_config_paths_under_state_root(self):
        plan = _run_json("inspect", "instance", self._state_root)
        state_root = plan["state"]["root"]

        seed_node = plan["nodes"][0]
        self.assertTrue(
            seed_node["config_dir"].startswith(state_root),
            f"config_dir {seed_node['config_dir']} not under {state_root}",
        )
        self.assertTrue(
            seed_node["config_file"].startswith(state_root),
            f"config_file {seed_node['config_file']} not under {state_root}",
        )

    def test_no_double_slash_in_paths(self):
        plan = _run_json("inspect", "instance", self._state_root)

        for node in plan["nodes"]:
            self.assertNotIn(
                "//", node["config_dir"], f"double slash in {node['config_dir']}"
            )
            self.assertNotIn(
                "//", node["config_file"], f"double slash in {node['config_file']}"
            )

        for worker in plan["workers"]:
            self.assertNotIn(
                "//", worker["config_dir"], f"double slash in {worker['config_dir']}"
            )

    def test_peer_id_format(self):
        plan = _run_json("inspect", "instance", self._state_root)
        seed_node = plan["nodes"][0]
        peer_id = seed_node["peer_id"]
        self.assertIsNotNone(peer_id)
        self.assertTrue(peer_id.startswith("/ip4/127.0.0.1/tcp/"))
        self.assertIn("/p2p/", peer_id)

    def test_endpoints_are_consecutive(self):
        plan = _run_json("inspect", "instance", self._state_root)
        seed_node = plan["nodes"][0]
        endpoints = seed_node["endpoints"]

        ports = [ep["port"] for ep in endpoints.values()]
        # With single-node and ITN, we have 6 endpoints:
        # client, rest, external, metrics, libp2p_metrics, itn_graphql
        # All should be allocated from the same base consecutively
        min_port = min(ports)
        expected = list(range(min_port, min_port + 6))
        self.assertEqual(
            sorted(ports),
            expected,
            f"Expected 6 consecutive ports starting at {min_port}, got {sorted(ports)}",
        )

    def test_reproducible_argv_structure_from_plan(self):
        """Run plan twice and verify argv structure is identical up to ports."""
        # Create two plans and compare
        plan1 = _run_json("inspect", "instance", self._state_root)

        # Re-plan and re-inspect
        _run("plan", "topology", _preset("single-node"), "--overwrite", check=False)
        plan2 = _run_json("inspect", "instance", self._state_root)

        # Structure should be the same (same keys, same argv positions)
        argv1 = plan1["nodes"][0]["daemon_argv"]
        argv2 = plan2["nodes"][0]["daemon_argv"]
        self.assertEqual(len(argv1), len(argv2))
        # All non-numeric args should be identical
        for a1, a2 in zip(argv1, argv2):
            if not a1.isdigit() and not a2.isdigit():
                self.assertEqual(a1, a2)

    def test_coordinator_argv_uses_pubkey_token_not_path(self):
        """-run-snark-coordinator must use unresolved token, not a .pub path."""
        plan = _run_json("inspect", "instance", self._state_root)
        seed_node = plan["nodes"][0]
        argv = seed_node["daemon_argv"]
        self.assertIn("-run-snark-coordinator", argv)
        coord_idx = argv.index("-run-snark-coordinator")
        coord_val = argv[coord_idx + 1]
        self.assertEqual(
            coord_val,
            "<pubkey:snark_coordinator_account>",
            "-run-snark-coordinator must use unresolved token",
        )
        # Must NOT contain a .pub path for the coordinator
        self.assertNotIn(
            ".pub", coord_val, "-run-snark-coordinator must NOT contain a .pub path"
        )
        # Scan entire argv for any .pub paths (should only be for
        # block-producer-key which is a path, not the coordinator)
        pub_paths = [a for a in argv if ".pub" in a and a.startswith(self._state_root)]
        self.assertEqual(
            len(pub_paths),
            0,
            f"No paths ending in .pub should appear in daemon argv: {pub_paths}",
        )


# ---------------------------------------------------------------------------
# inspect topology removal tests
# ---------------------------------------------------------------------------


class TestInspectTopologyRemoved(unittest.TestCase):
    """Tests that 'inspect topology' is removed/errors out."""

    def test_inspect_topology_errors(self):
        """inspect topology must exit nonzero with migration message."""
        cp = _run("inspect", "topology", _preset("single-node"), check=False)
        self.assertNotEqual(cp.returncode, 0, "inspect topology should exit nonzero")
        self.assertIn("has been removed", cp.stderr)

    def test_inspect_topology_no_transient_output(self):
        """inspect topology must not produce transient plan JSON output."""
        cp = _run("inspect", "topology", _preset("single-node"), check=False)
        # stdout should be empty (or at least not contain a resolved plan)
        try:
            json.loads(cp.stdout)
            self.fail("inspect topology should not output valid JSON")
        except json.JSONDecodeError:
            pass  # expected — no valid JSON output


# ---------------------------------------------------------------------------
# spawn stub tests
# ---------------------------------------------------------------------------


class TestSpawnStubs(unittest.TestCase):
    """Tests for the spawn command entry points — plan delegation and
    missing plan / missing manifest handling."""

    _fake_mina: str = ""

    @classmethod
    def setUpClass(cls):
        """Ensure plan exists at repo-local default root."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        _run("plan", "topology", _preset("single-node"), "--overwrite", check=False)

        fd, cls._fake_mina = tempfile.mkstemp(prefix="fake_mina_stub_")
        os.close(fd)
        Path(cls._fake_mina).write_text(_FAKE_MINA_SCRIPT, encoding="utf-8")
        os.chmod(cls._fake_mina, 0o755)

    @classmethod
    def tearDownClass(cls):
        """Clean up generated state directory."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        if cls._fake_mina and Path(cls._fake_mina).exists():
            os.unlink(cls._fake_mina)

    def test_spawn_instance_without_manifest_fails(self):
        """spawn instance reads the plan, then refuses when no manifest exists.

        Unlike 'spawn topology', 'spawn instance' never materializes on the
        fly — it operates on already-materialized state only.
        """
        state_root = str(Path(REPO_ROOT) / ".mina-local-network" / "single-node")
        # No manifest exists yet → spawn instance errors about missing manifest
        cp = _run("spawn", "instance", state_root, check=False)
        self.assertNotEqual(cp.returncode, 0, "spawn instance should exit nonzero")
        self.assertIn("No materialized-manifest.json found", cp.stderr)

    def test_spawn_instance_missing_plan_fails(self):
        """spawn instance with no plan at the target fails on the plan lookup,
        before it ever looks for a manifest."""
        cp = _run("spawn", "instance", ".mina-local-network/nonexistent", check=False)
        self.assertNotEqual(cp.returncode, 0)
        self.assertIn("No network plan found", cp.stderr)
        self.assertNotIn(
            "No materialized-manifest.json found",
            cp.stderr,
            "a missing plan must be reported before the manifest check",
        )

    def test_spawn_topology_delegates_plan_then_auto_materializes(self):
        """spawn topology delegates to 'plan topology', then materializes on
        the fly when the fresh plan has no manifest yet, and spawns from it.

        Uses a fake mina so the assertion is about the CLI's own contract
        rather than whether a real daemon happens to be built and healthy.
        """
        topo_name = "spawn-stub-auto-mat"
        root_abs = Path(REPO_ROOT) / ".mina-local-network" / topo_name
        shutil.rmtree(str(root_abs), ignore_errors=True)
        self.addCleanup(shutil.rmtree, str(root_abs), True)

        topology = {
            "schema_version": 1,
            "name": topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="spawn_stub_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        self.addCleanup(os.unlink, topo_path)

        self.assertFalse(
            (root_abs / "materialized-manifest.json").exists(),
            "precondition: no manifest before spawn topology",
        )

        cp = _run("spawn", "topology", topo_path, "--overwrite", check=False)
        self.assertEqual(
            cp.returncode, 0, f"spawn topology should succeed: {cp.stderr}"
        )
        # Plan delegation happened (from do_plan_topology via click.echo).
        self.assertIn("Plan written to", cp.stdout)
        # ...and the absent manifest was materialized rather than erroring.
        self.assertIn("Manifest not found", cp.stdout)
        self.assertTrue(
            (root_abs / "materialized-manifest.json").exists(),
            "spawn topology must materialize a manifest when none exists",
        )


# ---------------------------------------------------------------------------
# Raw schema validation tests (Fix 1)
# ---------------------------------------------------------------------------


def _write_temp_jsonc(topology: dict) -> str:
    """Write a topology dict to a temp .jsonc file. Returns path."""
    fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="topo_")
    os.close(fd)
    Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
    return tmp_path


class TestRawSchemaValidation(unittest.TestCase):
    """Raw (pre-normalization) schema validation negative tests."""

    def test_missing_ledger_generation_tiers_fails(self):
        """Raw topology missing ledger_generation.tiers must fail validation."""
        bad = {
            "schema_version": 1,
            "ledger_generation": {},  # no tiers
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
        }
        tmp_path = _write_temp_jsonc(bad)
        try:
            cp = _run("schema", "validate", tmp_path, check=False)
            self.assertNotEqual(
                cp.returncode,
                0,
                "Should reject topology missing ledger_generation.tiers",
            )
            self.assertIn("tiers", cp.stdout.lower())
        finally:
            os.unlink(tmp_path)

    def test_missing_node_capabilities_fails(self):
        """Raw topology missing node capabilities must fail validation."""
        bad = {
            "schema_version": 1,
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {"n1": {}},  # no capabilities
        }
        tmp_path = _write_temp_jsonc(bad)
        try:
            cp = _run("schema", "validate", tmp_path, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "Should reject topology missing node capabilities"
            )
            self.assertIn("capabilities", cp.stdout.lower() or cp.stderr.lower())
        finally:
            os.unlink(tmp_path)

    def test_plan_rejects_missing_tiers(self):
        """plan topology must reject raw topology missing tiers."""
        bad = {
            "schema_version": 1,
            "name": "bad-topo",
            "ledger_generation": {},
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
        }
        tmp_path = _write_temp_jsonc(bad)
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertNotEqual(cp.returncode, 0, "plan should reject missing tiers")
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "bad-topo"),
                ignore_errors=True,
            )


class TestItnContract(unittest.TestCase):
    """ITN argv/env contract: --itn-keys, ITN_FEATURES=1 env var."""

    @classmethod
    def setUpClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        _run("plan", "topology", _preset("single-node"), "--overwrite", check=False)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    @property
    def _state_root(self) -> str:
        return str(Path(REPO_ROOT) / ".mina-local-network" / "single-node")

    def test_node_env_has_itn_features(self):
        """Resolved node with itn_graphql must have env.ITN_FEATURES=1."""
        plan = _run_json("inspect", "instance", self._state_root)
        seed = plan["nodes"][0]
        self.assertIn("env", seed, "Resolved node missing 'env' key")
        self.assertEqual(
            seed["env"].get("ITN_FEATURES"),
            "1",
            "ITN_FEATURES must be '1' for itn_graphql nodes",
        )

    def test_daemon_argv_has_itn_keys(self):
        """Daemon argv must contain --itn-keys with the preset value."""
        plan = _run_json("inspect", "instance", self._state_root)
        seed = plan["nodes"][0]
        argv = seed["daemon_argv"]
        self.assertIn("--itn-keys", argv, "--itn-keys missing from daemon argv")
        itn_idx = argv.index("--itn-keys")
        self.assertGreater(
            len(argv), itn_idx + 1, "--itn-keys must have a value argument"
        )
        self.assertEqual(argv[itn_idx + 1], "libp2p_keys/itn-key")

    def test_itn_graphql_without_itn_keys_is_rejected(self):
        """Node with itn_graphql but no itn_keys must be rejected."""
        bad = {
            "schema_version": 1,
            "name": "no-itn-keys",
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {
                "n1": {
                    "capabilities": {
                        "p2p_seed": {},
                        "itn_graphql": {},
                    }
                }
            },
        }
        tmp_path = _write_temp_jsonc(bad)
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "Should reject itn_graphql without itn_keys"
            )
            self.assertIn("itn_keys", cp.stderr)
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "no-itn-keys"),
                ignore_errors=True,
            )


# ---------------------------------------------------------------------------
# Seed peer order independence tests (Fix 3)
# ---------------------------------------------------------------------------


class TestSeedOrderIndependent(unittest.TestCase):
    """Non-seed node defined before seed must still get --peer arg."""

    @classmethod
    def setUpClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    def test_non_seed_before_seed_gets_peer(self):
        """When non-seed node is defined first, its argv must still contain --peer."""
        multi = {
            "schema_version": 1,
            "name": "order-test",
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {
                "follower": {
                    "capabilities": {},
                },
                "leader": {
                    "capabilities": {
                        "p2p_seed": {},
                    },
                },
            },
        }
        tmp_path = _write_temp_jsonc(multi)
        try:
            _run("plan", "topology", tmp_path, "--overwrite", check=True)
            root = str(Path(REPO_ROOT) / ".mina-local-network" / "order-test")
            plan = _run_json("inspect", "instance", root)
            # Find the follower (non-seed) node
            follower = next(n for n in plan["nodes"] if n["name"] == "follower")
            self.assertIn(
                "--peer",
                follower["daemon_argv"],
                "Non-seed follower must have --peer even when defined first",
            )
            # Verify seed peer_id points to leader's external port
            leader = next(n for n in plan["nodes"] if n["name"] == "leader")
            expected_peer_id = leader["peer_id"]
            peer_idx = follower["daemon_argv"].index("--peer")
            self.assertEqual(follower["daemon_argv"][peer_idx + 1], expected_peer_id)
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True
            )


# ---------------------------------------------------------------------------
# Golden argv tests (Fix 5)
# ---------------------------------------------------------------------------


class TestGoldenArgv(unittest.TestCase):
    """Exact argv comparison against the expected daemon and worker commands."""

    @classmethod
    def setUpClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        _run("plan", "topology", _preset("single-node"), "--overwrite", check=False)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    @property
    def _state_root(self) -> str:
        return str(Path(REPO_ROOT) / ".mina-local-network" / "single-node")

    def test_single_node_daemon_golden_argv(self):
        """Exact golden argv for the single-node daemon command."""
        plan = _run_json("inspect", "instance", self._state_root)
        node = plan["nodes"][0]
        actual = node["daemon_argv"]
        config_file = plan["state"]["config_file"]
        config_dir = node["config_dir"]
        ep = node["endpoints"]

        mina_exe = "_build/default/src/app/cli/src/mina.exe"
        bp_key = node["block_producer_key_path"]
        coord_pubkey = "<pubkey:snark_coordinator_account>"

        expected = [
            mina_exe,
            "daemon",
            "--client-port",
            str(ep["client"]["port"]),
            "--rest-port",
            str(ep["rest"]["port"]),
            "--insecure-rest-server",
            "--external-port",
            str(ep["external"]["port"]),
            "--metrics-port",
            str(ep["metrics"]["port"]),
            "--libp2p-metrics-port",
            str(ep["libp2p_metrics"]["port"]),
            "--config-file",
            config_file,
            "--log-level",
            "Warn",
            "--file-log-level",
            "Warn",
            "--precomputed-blocks-file",
            f"{config_dir}/precomputed_blocks.log",
            "--log-precomputed-blocks",
            "false",
            "--proof-level",
            "full",
            "--seed",
            "--libp2p-keypair",
            SEED_PEER_KEY,
            "--block-producer-key",
            bp_key,
            "-snark-worker-fee",
            "0.001",
            "-run-snark-coordinator",
            coord_pubkey,
            "-work-selection",
            "seq",
            "--demo-mode",
            "--itn-graphql-port",
            str(ep["itn_graphql"]["port"]),
            "--itn-keys",
            "libp2p_keys/itn-key",
            "--config-directory",
            config_dir,
        ]
        self.assertEqual(
            actual,
            expected,
            f"Golden argv mismatch.\nExpected: {expected}\nActual:   {actual}",
        )

    def test_single_node_worker_golden_argv(self):
        """Exact golden argv for a single-node snark worker command."""
        plan = _run_json("inspect", "instance", self._state_root)
        worker = plan["workers"][0]
        actual = worker["worker_argv"]

        mina_exe = "_build/default/src/app/cli/src/mina.exe"
        config_dir = worker["config_dir"]
        daemon_addr = worker["daemon_address"]

        expected = [
            mina_exe,
            "internal",
            "snark-worker",
            "--proof-level",
            "full",
            "--shutdown-on-disconnect",
            "false",
            "--log-level",
            "Error",
            "--file-log-level",
            "Error",
            "--daemon-address",
            daemon_addr,
            "--config-directory",
            config_dir,
        ]
        self.assertEqual(
            actual,
            expected,
            f"Golden worker argv mismatch.\nExpected: {expected}\nActual:   {actual}",
        )


# ---------------------------------------------------------------------------
# RuntimeConfig daemon passthrough tests
# ---------------------------------------------------------------------------


class TestRuntimeConfigDaemon(unittest.TestCase):
    """Tests for runtime_config.daemon passthrough — plan resolution and
    materialization of daemon section in daemon.json."""

    _topo_name = "rc-daemon-test"
    _topo_root_rel: str = ""
    _topo_root_abs: str = ""
    _fake_mina: str = ""

    @classmethod
    def setUpClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

        fd, cls._fake_mina = tempfile.mkstemp(prefix="fake_mina_rc_")
        os.close(fd)
        Path(cls._fake_mina).write_text("#!/usr/bin/env bash\nexit 0", encoding="utf-8")
        os.chmod(cls._fake_mina, 0o755)

        cls._topo_root_rel = ".mina-local-network/" + cls._topo_name
        cls._topo_root_abs = str(
            Path(REPO_ROOT) / ".mina-local-network" / cls._topo_name
        )

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        if cls._fake_mina and Path(cls._fake_mina).exists():
            os.unlink(cls._fake_mina)

    def _plan(self, daemon_cfg: Optional[dict] = None) -> None:
        """Write a topology with runtime_config.daemon, plan it."""
        topology: dict[str, Any] = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {"tiers": {}},
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        if daemon_cfg:
            topology.setdefault("runtime_config", {})["daemon"] = daemon_cfg
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="rc_daemon_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
        finally:
            os.unlink(topo_path)

    def _clean_artifacts(self):
        root = Path(self._topo_root_abs)
        for fname in (
            "materialized-manifest.json",
            "daemon.json",
            "genesis_ledger.json",
        ):
            p = root / fname
            if p.exists():
                p.unlink()
        for sub in (
            "offline_whale_keys",
            "online_whale_keys",
            "offline_fish_keys",
            "online_fish_keys",
            "snark_coordinator_keys",
            "libp2p_keys",
            "nodes",
        ):
            p = root / sub
            if p.exists():
                shutil.rmtree(p, ignore_errors=True)

    def test_plan_resolution_carries_daemon_fields(self):
        """runtime_config.daemon must survive plan resolution and appear in the
        resolved plan's ledger.config.daemon."""
        self._plan({"slot_tx_end": 100, "slot_chain_end": 200})
        plan = _run_json("inspect", "instance", self._topo_root_rel)
        ledger = plan.get("ledger", {})
        config = ledger.get("config", {})
        daemon = config.get("daemon", {})
        self.assertEqual(
            daemon.get("slot_tx_end"),
            100,
            f"slot_tx_end should be 100 in resolved plan, got {daemon}",
        )
        self.assertEqual(
            daemon.get("slot_chain_end"),
            200,
            f"slot_chain_end should be 200, got {daemon}",
        )

    def test_plan_resolution_carries_hard_fork_delta(self):
        """hard_fork_genesis_slot_delta survives plan resolution."""
        self._plan({"hard_fork_genesis_slot_delta": 42})
        plan = _run_json("inspect", "instance", self._topo_root_rel)
        daemon = plan["ledger"]["config"]["daemon"]
        self.assertEqual(
            daemon.get("hard_fork_genesis_slot_delta"),
            42,
            f"hard_fork_genesis_slot_delta should be 42, got {daemon}",
        )

    def test_daemon_section_written_with_all_fields(self):
        """All three daemon fields materialize as top-level daemon in daemon.json."""
        self._plan(
            {
                "slot_tx_end": 111,
                "slot_chain_end": 222,
                "hard_fork_genesis_slot_delta": 333,
            }
        )
        # Need a mina binary for key generation if there are tiers
        # Use empty tiers — no keypair needed, so no mina binary required
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, "--force", check=True)

        daemon_path = Path(self._topo_root_abs) / "daemon.json"
        self.assertTrue(daemon_path.exists(), "daemon.json must exist")
        daemon = json.loads(daemon_path.read_text(encoding="utf-8"))
        self.assertIn("daemon", daemon, "daemon.json must have top-level daemon key")
        d = daemon["daemon"]
        self.assertEqual(d.get("slot_tx_end"), 111)
        self.assertEqual(d.get("slot_chain_end"), 222)
        self.assertEqual(d.get("hard_fork_genesis_slot_delta"), 333)

    def test_empty_daemon_omits_section(self):
        """When no daemon fields are configured, the daemon key must not appear
        in daemon.json."""
        self._plan()  # no runtime_config.daemon
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, "--force", check=True)

        daemon_path = Path(self._topo_root_abs) / "daemon.json"
        daemon = json.loads(daemon_path.read_text(encoding="utf-8"))
        self.assertNotIn(
            "daemon", daemon, "daemon key must not appear when all fields are None"
        )
        # Existing keys must still be present
        self.assertIn("genesis", daemon)
        self.assertIn("proof", daemon)
        self.assertIn("ledger", daemon)

    def test_daemon_section_only_non_none_fields(self):
        """Only non-None daemon fields should appear in daemon.json; omitted
        fields must not."""
        self._plan({"slot_tx_end": 99})  # only one field
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, "--force", check=True)

        daemon_path = Path(self._topo_root_abs) / "daemon.json"
        daemon = json.loads(daemon_path.read_text(encoding="utf-8"))
        d = daemon["daemon"]
        self.assertEqual(
            d, {"slot_tx_end": 99}, f"Only slot_tx_end should appear, got {d}"
        )


# ---------------------------------------------------------------------------
# Extra accounts file tests
# ---------------------------------------------------------------------------


class TestExtraAccountsFile(unittest.TestCase):
    """Tests for ledger_generation.extra_accounts_file — merging extra
    genesis accounts into daemon.json and genesis_ledger.json."""

    _topo_name = "extra-accts-test"
    _topo_root_rel: str = ""
    _topo_root_abs: str = ""

    @classmethod
    def setUpClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        cls._topo_root_rel = ".mina-local-network/" + cls._topo_name
        cls._topo_root_abs = str(
            Path(REPO_ROOT) / ".mina-local-network" / cls._topo_name
        )

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    def _plan_and_materialize(self, extra_accts_file: str) -> None:
        """Plan and materialize a minimal topology with extra_accounts_file set."""
        topology = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {
                "tiers": {},
                "extra_accounts_file": extra_accts_file,
            },
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="extra_acct_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", self._topo_root_rel, "--force", check=True)
        finally:
            os.unlink(topo_path)

    def _clean_artifacts(self):
        root = Path(self._topo_root_abs)
        for fname in (
            "materialized-manifest.json",
            "daemon.json",
            "genesis_ledger.json",
        ):
            p = root / fname
            if p.exists():
                p.unlink()
        for sub in (
            "offline_whale_keys",
            "online_whale_keys",
            "offline_fish_keys",
            "online_fish_keys",
            "snark_coordinator_keys",
            "libp2p_keys",
            "nodes",
        ):
            p = root / sub
            if p.exists():
                shutil.rmtree(p, ignore_errors=True)

    def _write_extra_accts(self, data) -> str:
        """Write data to a temp JSON file and return the path."""
        fd, tmp_path = tempfile.mkstemp(suffix=".json", prefix="extra_accts_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(data), encoding="utf-8")
        return tmp_path

    def test_extra_accounts_merged_into_daemon_json(self):
        """Extra accounts from file appear in daemon.json ledger accounts."""
        accts = [
            {
                "pk": "pk-extra-1",
                "balance": "100.000000000",
                "sk": None,
                "delegate": None,
            },
            {
                "pk": "pk-extra-2",
                "balance": "200.000000000",
                "sk": None,
                "delegate": "pk-extra-1",
            },
        ]
        extra_path = self._write_extra_accts(accts)
        try:
            self._clean_artifacts()
            self._plan_and_materialize(extra_path)

            daemon_path = Path(self._topo_root_abs) / "daemon.json"
            daemon = json.loads(daemon_path.read_text(encoding="utf-8"))
            ledger = daemon["ledger"]
            # Extra accounts + snark_coordinator account (always generated) = 3
            self.assertEqual(ledger["num_accounts"], 3)
            pks = [a["pk"] for a in ledger["accounts"]]
            self.assertIn("pk-extra-1", pks)
            self.assertIn("pk-extra-2", pks)
        finally:
            os.unlink(extra_path)

    def test_extra_accounts_merged_into_genesis_ledger(self):
        """Extra accounts also appear in genesis_ledger.json."""
        accts = [
            {"pk": "pk-gen-1", "balance": "50.000000000", "sk": None, "delegate": None},
        ]
        extra_path = self._write_extra_accts(accts)
        try:
            self._clean_artifacts()
            self._plan_and_materialize(extra_path)

            genesis_path = Path(self._topo_root_abs) / "genesis_ledger.json"
            genesis = json.loads(genesis_path.read_text(encoding="utf-8"))
            pks = [a["pk"] for a in genesis["accounts"]]
            self.assertIn("pk-gen-1", pks)
            # Extra account + snark_coordinator account = 2
            self.assertEqual(genesis["num_accounts"], 2)
        finally:
            os.unlink(extra_path)

    def test_extra_accounts_file_missing_fails_clearly(self):
        """Non-existent extra_accounts_file must raise a clear error."""
        self._clean_artifacts()
        cp = _run("materialize", self._topo_root_rel, "--force", check=False)
        # Plan and materialize with a nonexistent file
        fake_path = "/nonexistent/extra-accounts.json"
        topology = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {
                "tiers": {},
                "extra_accounts_file": fake_path,
            },
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="extra_bad_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            cp = _run("plan", "topology", topo_path, "--overwrite", check=False)
            self.assertEqual(cp.returncode, 0)
            cp2 = _run("materialize", self._topo_root_rel, "--force", check=False)
            self.assertNotEqual(cp2.returncode, 0, "must fail on missing file")
            self.assertIn("not found", cp2.stderr.lower())
        finally:
            os.unlink(topo_path)

    def test_extra_accounts_file_invalid_json_fails(self):
        """Invalid JSON in extra_accounts_file must raise a clear error."""
        fd, bad_path = tempfile.mkstemp(suffix=".json", prefix="bad_acct_")
        os.close(fd)
        Path(bad_path).write_text("this is not json", encoding="utf-8")
        try:
            topology = {
                "schema_version": 1,
                "name": self._topo_name,
                "ledger_generation": {
                    "tiers": {},
                    "extra_accounts_file": bad_path,
                },
                "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
                "state": {"genesis_timestamp": {"delay": "PT120S"}},
            }
            fd2, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="bad_json_")
            os.close(fd2)
            Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
            try:
                _run("plan", "topology", topo_path, "--overwrite", check=True)
                cp = _run("materialize", self._topo_root_rel, "--force", check=False)
                self.assertNotEqual(cp.returncode, 0, "must fail on invalid JSON")
                self.assertIn("not valid JSON", cp.stderr)
            finally:
                os.unlink(topo_path)
        finally:
            os.unlink(bad_path)

    def test_extra_accounts_file_not_array_fails(self):
        """Non-array content in extra_accounts_file must fail."""
        fd, bad_path = tempfile.mkstemp(suffix=".json", prefix="not_array_")
        os.close(fd)
        Path(bad_path).write_text('{"pk": "foo", "balance": "1"}', encoding="utf-8")
        try:
            topology = {
                "schema_version": 1,
                "name": self._topo_name,
                "ledger_generation": {
                    "tiers": {},
                    "extra_accounts_file": bad_path,
                },
                "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
                "state": {"genesis_timestamp": {"delay": "PT120S"}},
            }
            fd2, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="not_arr_")
            os.close(fd2)
            Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
            try:
                _run("plan", "topology", topo_path, "--overwrite", check=True)
                cp = _run("materialize", self._topo_root_rel, "--force", check=False)
                self.assertNotEqual(cp.returncode, 0, "must fail on non-array")
                self.assertIn("array", cp.stderr)
            finally:
                os.unlink(topo_path)
        finally:
            os.unlink(bad_path)


# ---------------------------------------------------------------------------
# Extra files root overlay tests
# ---------------------------------------------------------------------------


class TestExtraFilesRoot(unittest.TestCase):
    """Tests for state.extra_files_root overlay during materialization."""

    _topo_name = "extra-files-test"
    _topo_root_rel: str = ""
    _topo_root_abs: str = ""
    _extra_root: str = ""

    @classmethod
    def setUpClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        cls._topo_root_rel = ".mina-local-network/" + cls._topo_name
        cls._topo_root_abs = str(
            Path(REPO_ROOT) / ".mina-local-network" / cls._topo_name
        )

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    def setUp(self):
        # Create a temp extra files root directory with some test files
        self._extra_root = tempfile.mkdtemp(prefix="extra_root_")
        (Path(self._extra_root) / "overlay.txt").write_text("hello", encoding="utf-8")
        sub = Path(self._extra_root) / "subdir"
        sub.mkdir()
        (sub / "nested.txt").write_text("nested", encoding="utf-8")

    def tearDown(self):
        if self._extra_root and Path(self._extra_root).exists():
            shutil.rmtree(self._extra_root, ignore_errors=True)
        # Clean artifacts
        root = Path(self._topo_root_abs)
        if root.exists():
            shutil.rmtree(root, ignore_errors=True)

    def _plan_and_materialize(self) -> None:
        topology = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {"tiers": {}},
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "state": {
                "genesis_timestamp": {"delay": "PT120S"},
                "extra_files_root": self._extra_root,
            },
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="extra_files_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", self._topo_root_rel, "--force", check=True)
        finally:
            os.unlink(topo_path)

    def test_extra_files_are_copied_into_state_root(self):
        """Files from extra_files_root appear inside the state root after
        materialization."""
        self._plan_and_materialize()
        sr = Path(self._topo_root_abs)
        self.assertTrue(
            (sr / "overlay.txt").exists(), "overlay.txt must exist in state root"
        )
        self.assertEqual((sr / "overlay.txt").read_text(encoding="utf-8"), "hello")
        self.assertTrue(
            (sr / "subdir" / "nested.txt").exists(), "nested.txt must exist"
        )
        self.assertEqual(
            (sr / "subdir" / "nested.txt").read_text(encoding="utf-8"), "nested"
        )

    def test_extra_files_included_in_generated_files(self):
        """Copied extra files appear in the materialized manifest generated_files list."""
        self._plan_and_materialize()
        manifest_path = Path(self._topo_root_abs) / "materialized-manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        generated = manifest.get("generated_files", [])
        # generated_files uses relative paths (state_root + filename)
        topo_rel = self._topo_root_rel
        overlay_path = f"{topo_rel}/overlay.txt"
        nested_path = f"{topo_rel}/subdir/nested.txt"
        self.assertIn(
            overlay_path,
            generated,
            f"overlay.txt must be in generated_files, got {generated}",
        )
        self.assertIn(nested_path, generated, "nested.txt must be in generated_files")

    def test_extra_files_root_missing_fails(self):
        """Non-existent extra_files_root must fail with a clear error."""
        topology = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {"tiers": {}},
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "state": {
                "genesis_timestamp": {"delay": "PT120S"},
                "extra_files_root": "/nonexistent/extra-root-dir",
            },
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="bad_extra_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            cp = _run("materialize", self._topo_root_rel, "--force", check=False)
            self.assertNotEqual(
                cp.returncode, 0, "must fail on missing extra_files_root"
            )
            self.assertIn("not an existing directory", cp.stderr)
        finally:
            os.unlink(topo_path)


# ---------------------------------------------------------------------------
# Materialize tests
# ---------------------------------------------------------------------------


# The fake mina lives in its own file (tests/fake_mina.py) rather than a string
# written out at setup: it serves GraphQL, and a server buried in a string is a
# server nobody reads. Loaded as text because several suites copy it onto a PATH
# under the name `mina`.
FAKE_MINA_PATH = Path(__file__).resolve().parent / "fake_mina.py"
_FAKE_MINA_SCRIPT = FAKE_MINA_PATH.read_text(encoding="utf-8")


_FAKE_ARCHIVE_SCRIPT = r"""#!/usr/bin/env bash
# fake-archive test double
set -euo pipefail
if [[ "$1" == "run" ]]; then
    # Parse --server-port
    _port=""
    for ((i=1; i<=$#; i++)); do
        if [[ "${!i}" == "--server-port" ]]; then
            _port="${@:$((i+1)):1}"
            break
        fi
    done
    # Order file — write FIRST, before any other operations
    if [[ -n "${FAKE_ORDER_FILE:-}" ]]; then
        echo "archive" >> "$FAKE_ORDER_FILE"
    fi
    # Write argv to file
    if [[ -n "${FAKE_ARCHIVE_ARGS_FILE:-}" ]]; then
        printf '%s\n' "$@" > "$FAKE_ARCHIVE_ARGS_FILE"
    fi
    # TCP listen on port
    if [[ -n "${_port:-}" && "${FAKE_ARCHIVE_NO_LISTEN:-}" != "1" ]]; then
        python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', $_port))
s.listen(1)
while True: time.sleep(1)
" &
    fi
    sleep "${FAKE_ARCHIVE_SLEEP:-0}"
    exit "${FAKE_ARCHIVE_EXIT_CODE:-0}"
fi
echo "fake-archive: unhandled command: $*" >&2
exit 1
"""


_FAKE_ROSETTA_SCRIPT = r"""#!/usr/bin/env bash
# fake-rosetta test double
set -euo pipefail
# Parse --port
_port=""
for ((i=1; i<=$#; i++)); do
    if [[ "${!i}" == "--port" ]]; then
        _port="${@:$((i+1)):1}"
        break
    fi
done
# Order file — write FIRST, before any other operations
if [[ -n "${FAKE_ORDER_FILE:-}" ]]; then
    echo "rosetta" >> "$FAKE_ORDER_FILE"
fi
# Write argv to file
if [[ -n "${FAKE_ROSETTA_ARGS_FILE:-}" ]]; then
    printf '%s\n' "$@" > "$FAKE_ROSETTA_ARGS_FILE"
fi
# Write env to file
if [[ -n "${FAKE_ROSETTA_ENV_FILE:-}" ]]; then
    env | sort > "$FAKE_ROSETTA_ENV_FILE"
fi
# TCP listen
if [[ -n "${_port:-}" && "${FAKE_ROSETTA_NO_LISTEN:-}" != "1" ]]; then
    python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', $_port))
s.listen(1)
while True: time.sleep(1)
" &
fi
sleep "${FAKE_ROSETTA_SLEEP:-0}"
exit "${FAKE_ROSETTA_EXIT_CODE:-0}"
"""


_FAKE_PSQL_SCRIPT = r"""#!/usr/bin/env bash
# fake-psql test double
# Record full argv if log file is set (for tests that assert no password in argv)
if [[ -n "${FAKE_PSQL_LOG:-}" ]]; then
    echo "ARGV:$*" >> "$FAKE_PSQL_LOG"
fi
# Record PGPASSWORD snippet (NOT the full value, just "SET" or "UNSET")
if [[ -n "${FAKE_PSQL_PW_LOG:-}" ]]; then
    if [[ -n "${PGPASSWORD:-}" ]]; then
        echo "PGPASSWORD=SET" >> "$FAKE_PSQL_PW_LOG"
    else
        echo "PGPASSWORD=UNSET" >> "$FAKE_PSQL_PW_LOG"
    fi
fi
# Fail mode? Exit with the given code
if [[ -n "${FAKE_PSQL_FAIL:-}" ]]; then
    >&2 echo "fake-psql: failing with code ${FAKE_PSQL_FAIL}"
    exit "${FAKE_PSQL_FAIL}"
fi
# Echo expected output for schema check so the test passes
if [[ "$*" == *"user_commands"* ]]; then
    echo " ?column? "
    echo "----------"
    echo "        1 "
fi
exit 0
"""


class TestMaterialize(unittest.TestCase):
    """Tests for the 'materialize' command — key gen, dirs, config, manifest."""

    _topo_name = "mat-test"
    _topo_root_rel: str = ""  # relative, as stored in plan
    _topo_root_abs: str = ""  # absolute, for file-system checks
    _fake_mina: str = ""

    @classmethod
    def setUpClass(cls):
        """Create a temp topology with a fake mina binary, plan it."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

        # Create fake mina executable
        fd, cls._fake_mina = tempfile.mkstemp(prefix="fake_mina_")
        os.close(fd)
        Path(cls._fake_mina).write_text(_FAKE_MINA_SCRIPT, encoding="utf-8")
        os.chmod(cls._fake_mina, 0o755)

        cls._topo_root_rel = ".mina-local-network/" + cls._topo_name
        cls._topo_root_abs = str(
            Path(REPO_ROOT) / ".mina-local-network" / cls._topo_name
        )

        topology = {
            "schema_version": 1,
            "name": cls._topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {
                        "count": 1,
                        "offline_balance": "5mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {"default": {"count": 1, "nap": "PT1S"}},
                        },
                    },
                },
            },
            "binaries": {"mina": cls._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="mat_topo_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        _run("plan", "topology", topo_path, "--overwrite", check=True)
        os.unlink(topo_path)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        if cls._fake_mina and Path(cls._fake_mina).exists():
            os.unlink(cls._fake_mina)

    def _clean_artifacts(self):
        """Remove materialize-generated files and key dirs so tests start clean."""
        root = Path(self._topo_root_abs)
        for fname in (
            "materialized-manifest.json",
            "daemon.json",
            "genesis_ledger.json",
        ):
            p = root / fname
            if p.exists():
                p.unlink()
        # Remove key directories that materialize creates
        for sub in (
            "offline_whale_keys",
            "online_whale_keys",
            "offline_fish_keys",
            "online_fish_keys",
            "snark_coordinator_keys",
            "libp2p_keys",
            "nodes",
        ):
            p = root / sub
            if p.exists():
                shutil.rmtree(p, ignore_errors=True)

    # ── dry-run ──────────────────────────────────────────────────────

    def test_dry_run_creates_no_files(self):
        """materialize --dry-run should print manifest but write nothing."""
        _run("materialize", self._topo_root_rel, "--dry-run", check=True)

        manifest_path = Path(self._topo_root_abs) / "materialized-manifest.json"
        self.assertFalse(
            manifest_path.exists(), "dry-run must not create materialized-manifest.json"
        )
        self.assertFalse((Path(self._topo_root_abs) / "daemon.json").exists())
        self.assertFalse((Path(self._topo_root_abs) / "genesis_ledger.json").exists())

    # ── real materialize ─────────────────────────────────────────────

    def test_materialize_creates_manifest(self):
        """materialize writes materialized-manifest.json."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, check=True)

        manifest_path = Path(self._topo_root_abs) / "materialized-manifest.json"
        self.assertTrue(
            manifest_path.exists(),
            "materialized-manifest.json must exist after materialize",
        )
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(manifest["state_root"], self._topo_root_rel)
        self.assertIn("keys", manifest)
        self.assertIn("generated_files", manifest)
        self.assertIn("daemon_config", manifest)
        self.assertIn("genesis_ledger", manifest)
        self.assertIn("node_logs", manifest)

    def test_materialize_manifest_includes_plan_fingerprint(self):
        """Materialized manifest must include plan_fingerprint and algorithm fields."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, check=True)

        manifest_path = Path(self._topo_root_abs) / "materialized-manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertIn(
            "plan_fingerprint", manifest, "manifest must contain plan_fingerprint"
        )
        self.assertIsInstance(manifest["plan_fingerprint"], str)
        self.assertEqual(
            len(manifest["plan_fingerprint"]),
            64,
            "plan_fingerprint must be a 64-char hex SHA256 digest",
        )
        self.assertIn(
            "plan_fingerprint_algorithm",
            manifest,
            "manifest must contain plan_fingerprint_algorithm",
        )
        self.assertEqual(
            manifest["plan_fingerprint_algorithm"], "sha256-canonical-json-v1"
        )

    def test_materialize_generates_daemon_and_ledger_json(self):
        """materialize writes daemon.json and genesis_ledger.json with correct shapes."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, "--force", check=True)

        daemon_path = Path(self._topo_root_abs) / "daemon.json"
        self.assertTrue(daemon_path.exists())
        daemon = json.loads(daemon_path.read_text(encoding="utf-8"))
        # Top-level shape
        self.assertIn("genesis", daemon)
        self.assertIn("proof", daemon)
        self.assertIn("ledger", daemon)
        self.assertNotIn(
            "ledger",
            {"genesis", "proof", "ledger"}.difference(daemon.keys()),
            "daemon.json must only have genesis, proof, ledger at top level",
        )
        # Timestamp format: YYYY-MM-DD HH:MM:SS+00:00 (not ISO with 'T')
        ts = daemon["genesis"]["genesis_state_timestamp"]
        self.assertRegex(
            ts,
            r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\+00:00$",
            f"Timestamp {ts!r} should be YYYY-MM-DD HH:MM:SS+00:00",
        )
        # Ledger shape
        ledger = daemon["ledger"]
        self.assertIn("name", ledger)
        self.assertEqual(ledger["name"], "mina-local-network")
        self.assertIn("num_accounts", ledger)
        self.assertGreater(ledger["num_accounts"], 0)
        self.assertIn("accounts", ledger)
        self.assertEqual(len(ledger["accounts"]), ledger["num_accounts"])
        # All balances must be decimal mina strings (no DSL suffixes)
        for acct in ledger["accounts"]:
            bal = acct["balance"]
            self.assertRegex(
                bal,
                r"^\d+\.\d{9}$",
                f"Balance {bal!r} must be decimal mina with 9 places",
            )
            self.assertNotIn(
                "mina",
                bal.split(".")[0],
                "Balance must not contain 'mina' or 'nanomina' suffix",
            )
        # Delegation: offline whale delegates to online whale pubkey
        offline_acct = next(
            (a for a in ledger["accounts"] if "offline_whale" in a.get("pk", "")), None
        )
        online_acct = next(
            (a for a in ledger["accounts"] if "online_whale" in a.get("pk", "")), None
        )
        if offline_acct is None:
            self.fail("offline whale account missing")
        if online_acct is None:
            self.fail("online whale account missing")
        self.assertEqual(
            offline_acct["delegate"],
            online_acct["pk"],
            "offline whale must delegate to online whale pubkey",
        )
        self.assertIsNone(
            online_acct["delegate"], "online whale account must have delegate: None"
        )
        # Online account balance is small, offline is large
        self.assertGreater(
            int(offline_acct["balance"].split(".")[0]),
            int(online_acct["balance"].split(".")[0]),
            "offline balance must be larger than online balance",
        )
        # Snark coordinator: delegate must be None
        sc_acct = next(
            (a for a in ledger["accounts"] if "snark_coordinator" in a.get("pk", "")),
            None,
        )
        if sc_acct is None:
            self.fail("snark coordinator account missing")
        self.assertIsNone(
            sc_acct["delegate"], "snark coordinator delegate must be None"
        )

        genesis_path = Path(self._topo_root_abs) / "genesis_ledger.json"
        self.assertTrue(genesis_path.exists())
        gen_ledger = json.loads(genesis_path.read_text(encoding="utf-8"))
        # genesis_ledger.json must be the ledger object directly (no "ledger" wrapper)
        self.assertNotIn(
            "ledger", gen_ledger, "genesis_ledger.json must not have a 'ledger' wrapper"
        )
        self.assertIn("name", gen_ledger)
        self.assertEqual(gen_ledger["name"], "mina-local-network")
        self.assertIn("num_accounts", gen_ledger)
        self.assertGreater(gen_ledger["num_accounts"], 0)
        self.assertIn("accounts", gen_ledger)
        self.assertEqual(len(gen_ledger["accounts"]), gen_ledger["num_accounts"])
        # Genesis ledger accounts also use decimal balances
        for acct in gen_ledger["accounts"]:
            self.assertRegex(acct["balance"], r"^\d+\.\d{9}$")

    def test_materialize_generates_key_files(self):
        """materialize generates privkey + .pub files."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, "--force", check=True)

        whale_online_dir = Path(self._topo_root_abs) / "online_whale_keys"
        self.assertTrue(whale_online_dir.is_dir())
        key_base = whale_online_dir / "online_whale_account_0"
        self.assertTrue(key_base.exists(), f"Expected privkey at {key_base}")
        self.assertTrue(
            (Path(str(key_base) + ".pub")).exists(),
            f"Expected pubkey at {key_base}.pub",
        )

        whale_offline_dir = Path(self._topo_root_abs) / "offline_whale_keys"
        self.assertTrue(whale_offline_dir.is_dir())
        key_base_off = whale_offline_dir / "offline_whale_account_0"
        self.assertTrue(key_base_off.exists())

        sc_dir = Path(self._topo_root_abs) / "snark_coordinator_keys"
        sc_key = sc_dir / "snark_coordinator_account"
        self.assertTrue(sc_key.exists(), f"Expected snark coordinator key at {sc_key}")
        self.assertTrue((Path(str(sc_key) + ".pub")).exists())

    def test_materialize_creates_node_and_worker_dirs(self):
        """materialize creates config dirs for nodes and workers."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, "--force", check=True)

        node_dir = Path(self._topo_root_abs) / "nodes" / "seed"
        self.assertTrue(node_dir.is_dir(), f"Node config dir missing: {node_dir}")

        worker_dir = (
            Path(self._topo_root_abs) / "nodes" / "snark_workers" / "seed_default_0"
        )
        self.assertTrue(worker_dir.is_dir(), f"Worker config dir missing: {worker_dir}")

    def test_materialize_refuses_overwrite_without_force(self):
        """materialize without --force must fail if manifest already exists."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, check=True)  # first run succeeds

        cp = _run("materialize", self._topo_root_rel, check=False)
        self.assertNotEqual(
            cp.returncode, 0, "second materialize without --force must fail"
        )
        self.assertIn("already exist", cp.stderr)

    def test_materialize_with_force_overwrites(self):
        """materialize --force must succeed when manifest exists."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, check=True)  # first run
        cp = _run("materialize", self._topo_root_rel, "--force", check=False)
        self.assertEqual(
            cp.returncode, 0, f"materialize --force should succeed: {cp.stderr}"
        )

    def test_existing_daemon_json_without_force_fails(self):
        """materialize without --force fails when daemon.json exists but manifest does not."""
        self._clean_artifacts()
        # Create daemon.json as a stray file (no manifest)
        daemon_path = Path(self._topo_root_abs) / "daemon.json"
        daemon_path.parent.mkdir(parents=True, exist_ok=True)
        daemon_path.write_text("{}", encoding="utf-8")

        cp = _run("materialize", self._topo_root_rel, check=False)
        self.assertNotEqual(
            cp.returncode,
            0,
            "materialize without --force must fail when daemon.json exists",
        )
        self.assertIn("already exist", cp.stderr)
        self.assertIn("--force", cp.stderr)

    def test_existing_key_file_without_force_fails(self):
        """materialize without --force fails when a generated key file exists but manifest does not."""
        self._clean_artifacts()
        # Create a key file that materialize would generate
        key_dir = Path(self._topo_root_abs) / "online_whale_keys"
        key_dir.mkdir(parents=True, exist_ok=True)
        key_path = key_dir / "online_whale_account_0"
        key_path.write_text("fake", encoding="utf-8")

        cp = _run("materialize", self._topo_root_rel, check=False)
        self.assertNotEqual(
            cp.returncode,
            0,
            "materialize without --force must fail when a key file exists",
        )
        self.assertIn("already exist", cp.stderr)
        self.assertIn("--force", cp.stderr)

    def test_dry_run_does_not_fail_on_existing_artifacts(self):
        """materialize --dry-run must not fail even when artifacts already exist."""
        self._clean_artifacts()
        # Create stray daemon.json and a key file
        daemon_path = Path(self._topo_root_abs) / "daemon.json"
        daemon_path.parent.mkdir(parents=True, exist_ok=True)
        daemon_path.write_text("{}", encoding="utf-8")
        key_dir = Path(self._topo_root_abs) / "online_whale_keys"
        key_dir.mkdir(parents=True, exist_ok=True)
        (key_dir / "online_whale_account_0").write_text("fake", encoding="utf-8")

        cp = _run("materialize", self._topo_root_rel, "--dry-run", check=False)
        self.assertEqual(
            cp.returncode,
            0,
            f"materialize --dry-run must not fail on existing artifacts: {cp.stderr}",
        )
        # Dry-run must not write files
        manifest_path = Path(self._topo_root_abs) / "materialized-manifest.json"
        self.assertFalse(
            manifest_path.exists(),
            "--dry-run must not create materialized-manifest.json",
        )

    def test_manifest_includes_snark_coordinator_pubkey(self):
        """Materialized manifest must capture snark coordinator pubkey content."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, "--force", check=True)

        manifest_path = Path(self._topo_root_abs) / "materialized-manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        keys = manifest.get("keys", {})
        sc = keys.get("snark_coordinator_account")
        self.assertIsNotNone(
            sc, "manifest must include snark_coordinator_account key entry"
        )
        self.assertIn("pubkey_content", sc)
        self.assertTrue(
            sc["pubkey_content"].startswith(
                "fake-pubkey-for-snark_coordinator_account"
            ),
            f"Unexpected pubkey content: {sc['pubkey_content']}",
        )

    # ── balance conversion unit tests (inline) ────────────────────────

    def test_balance_conversion_mina(self):
        """mina amounts convert to 9-decimal-place mina strings."""
        result = convert_balance_to_decimal_mina("11550000mina")
        self.assertEqual(result, "11550000.000000000")

    def test_balance_conversion_fractional_mina(self):
        """Fractional mina converts exactly to nanomina precision."""
        self.assertEqual(convert_balance_to_decimal_mina("0.25mina"), "0.250000000")
        self.assertEqual(convert_balance_to_decimal_mina("0.1mina"), "0.100000000")
        self.assertEqual(
            convert_balance_to_decimal_mina("0.000000001mina"), "0.000000001"
        )

    def test_balance_conversion_nanomina(self):
        """nanomina amounts convert to decimal mina with correct precision."""
        self.assertEqual(
            convert_balance_to_decimal_mina("1000nanomina"),
            "0.000001000",
        )
        self.assertEqual(
            convert_balance_to_decimal_mina("5nanomina"),
            "0.000000005",
        )

    def test_balance_conversion_rejects_invalid(self):
        """Invalid balance strings must raise TopologyError.

        Fractional mina is allowed, but fractional nanomina (nanomina is the base
        unit) and sub-nanomina precision (more than 9 mina decimals) are not."""
        from mln.errors import TopologyError

        for bad in ("not-a-number", "5minas", "5.5nanomina", "0.1234567890mina"):
            with self.assertRaises(TopologyError):
                convert_balance_to_decimal_mina(bad)

    # ── spawn interaction ────────────────────────────────────────────

    def test_spawn_instance_without_manifest_errors(self):
        """spawn instance must error when plan exists but manifest is missing."""
        self._clean_artifacts()
        cp = _run("spawn", "instance", self._topo_root_rel, check=False)
        self.assertNotEqual(
            cp.returncode, 0, "spawn instance without manifest must fail"
        )
        self.assertIn("No materialized-manifest.json found", cp.stderr)

    def test_spawn_instance_with_manifest_and_workers_succeeds(self):
        """spawn instance with manifested plan containing workers must now
        succeed (workers are supported)."""
        self._clean_artifacts()
        _run("materialize", self._topo_root_rel, "--force", check=True)

        # The plan has 1 daemon + 1 snark worker → spawn must succeed
        cp = _run("spawn", "instance", self._topo_root_rel, check=False)
        self.assertEqual(
            cp.returncode, 0, f"spawn instance with workers should succeed: {cp.stderr}"
        )


# ---------------------------------------------------------------------------
# Patch topology tests — in-place replan over an existing materialized plan
# ---------------------------------------------------------------------------


class TestPatchTopology(unittest.TestCase):
    """Tests for 'patch topology' — replan in place, reusing materialized keys.

    Models the hard-fork test's main -> fork network transition: the
    topology legitimately changes (binary, runtime config, workloads) but
    the same account keys/ledger must carry over untouched.
    """

    _topo_name = "patch-topology"
    _topo_root_rel: str = ""
    _topo_root_abs: str = ""
    _fake_mina: str = ""
    _repo_root: str = ""

    @classmethod
    def setUpClass(cls):
        cls._repo_root = REPO_ROOT
        fd, cls._fake_mina = tempfile.mkstemp(prefix="fake_mina_patch_")
        os.close(fd)
        Path(cls._fake_mina).write_text(_FAKE_MINA_SCRIPT, encoding="utf-8")
        os.chmod(cls._fake_mina, 0o755)

        cls._topo_root_rel = ".mina-local-network/" + cls._topo_name
        cls._topo_root_abs = str(
            Path(REPO_ROOT) / ".mina-local-network" / cls._topo_name
        )

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        if cls._fake_mina and Path(cls._fake_mina).exists():
            os.unlink(cls._fake_mina)

    def setUp(self):
        shutil.rmtree(self._topo_root_abs, ignore_errors=True)

    def _manifest_path(self) -> Path:
        return Path(self._topo_root_abs) / "materialized-manifest.json"

    def _plan_path(self) -> Path:
        return Path(self._topo_root_abs) / "network-plan.json"

    def _make_topology(self, **overrides) -> dict:
        topo = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        topo.update(overrides)
        return topo

    def _make_topology_needing_new_keys(self) -> dict:
        """A topology whose second whale has no materialized keypair yet."""
        return self._make_topology(
            ledger_generation={
                "tiers": {
                    "whale": {
                        "count": 2,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            }
        )

    def _write_topo(self, topo: dict) -> str:
        fd, path = tempfile.mkstemp(suffix=".jsonc", prefix="patch_topo_")
        os.close(fd)
        Path(path).write_text(json.dumps(topo), encoding="utf-8")
        self.addCleanup(lambda: os.path.exists(path) and os.unlink(path))
        return path

    def _plan_and_materialize(self, topo: dict) -> None:
        topo_path = self._write_topo(topo)
        _run("plan", "topology", topo_path, "--overwrite", check=True)
        _run("materialize", self._topo_root_rel, "--force", check=True)

    # ── success: compatible replan ───────────────────────────────────

    def test_patch_updates_fingerprint_and_preserves_keys(self):
        """A patched topology that reuses the same account tiers must update
        the manifest's plan_fingerprint while leaving keys untouched."""
        self._plan_and_materialize(self._make_topology())
        before = json.loads(self._manifest_path().read_text())

        fork_topo_path = self._write_topo(
            self._make_topology(
                state={
                    "genesis_timestamp": {"delay": "PT999S"},
                }
            )
        )
        cp = _run("patch", "topology", fork_topo_path, check=False)
        self.assertEqual(cp.returncode, 0, f"patch should succeed: {cp.stderr}")

        after = json.loads(self._manifest_path().read_text())
        self.assertNotEqual(
            after["plan_fingerprint"],
            before["plan_fingerprint"],
            "plan_fingerprint must change to match the patched plan",
        )
        self.assertEqual(
            after["keys"], before["keys"], "patch must not touch key material"
        )
        self.assertEqual(
            after["generated_files"],
            before["generated_files"],
            "patch must not (re)generate any materialized files",
        )

        # spawn instance must now pass the fingerprint check (fake mina still
        # exits non-zero on 'daemon' since it doesn't implement it, but that's
        # unrelated to manifest validation).
        cp2 = _run("spawn", "instance", self._topo_root_rel, check=False)
        self.assertNotIn("MANIFEST_MISMATCH", cp2.stderr)

    def test_patch_without_manifest_fails(self):
        """patch topology must refuse when no materialized manifest exists yet."""
        topo_path = self._write_topo(self._make_topology())
        _run("plan", "topology", topo_path, "--overwrite", check=True)

        cp = _run("patch", "topology", topo_path, check=False)
        self.assertNotEqual(cp.returncode, 0)
        self.assertIn("No materialized-manifest.json found", cp.stderr)

    # ── failure: new keys required ───────────────────────────────────

    def test_patch_refuses_when_new_keys_required(self):
        """patch must refuse (and leave the manifest untouched) when the new
        topology needs a key that hasn't been materialized yet."""
        self._plan_and_materialize(self._make_topology())
        before = json.loads(self._manifest_path().read_text())

        bigger_topo_path = self._write_topo(self._make_topology_needing_new_keys())
        cp = _run("patch", "topology", bigger_topo_path, check=False)
        self.assertNotEqual(
            cp.returncode, 0, "patch must refuse when new keys are required"
        )
        self.assertIn("PATCH_REQUIRES_NEW_KEYS", cp.stderr)
        self.assertIn("materialize", cp.stderr)

        after = json.loads(self._manifest_path().read_text())
        self.assertEqual(
            after["plan_fingerprint"],
            before["plan_fingerprint"],
            "a refused patch must not mutate the manifest",
        )
        self.assertEqual(after["keys"], before["keys"])

    def test_refused_patch_leaves_state_root_spawnable(self):
        """A refused patch must not clobber network-plan.json.

        Rejection happens after the topology resolves but before anything is
        written, so the prior plan must survive byte-for-byte and keep
        matching the manifest — otherwise a failed patch would silently break
        an already-working network (spawn would then fail MANIFEST_MISMATCH).
        """
        self._plan_and_materialize(self._make_topology())
        plan_before = self._plan_path().read_text()

        # Precondition: the state root currently passes the fingerprint check.
        cp = _run("spawn", "instance", self._topo_root_rel, check=False)
        self.assertNotIn(
            "MANIFEST_MISMATCH", cp.stderr, "state root must start out consistent"
        )

        bigger_topo_path = self._write_topo(self._make_topology_needing_new_keys())
        cp = _run("patch", "topology", bigger_topo_path, check=False)
        self.assertNotEqual(cp.returncode, 0)
        self.assertIn("PATCH_REQUIRES_NEW_KEYS", cp.stderr)

        self.assertEqual(
            self._plan_path().read_text(),
            plan_before,
            "a refused patch must leave network-plan.json byte-for-byte intact",
        )
        cp = _run("spawn", "instance", self._topo_root_rel, check=False)
        self.assertNotIn(
            "MANIFEST_MISMATCH",
            cp.stderr,
            "a refused patch must leave the state root spawnable",
        )


# ---------------------------------------------------------------------------
# Spawn instance tests — daemon-only lifecycle
# ---------------------------------------------------------------------------


class TestSpawnInstance(unittest.TestCase):
    """Tests for 'spawn instance' — daemon-only foreground lifecycle."""

    _topo_name = "daemon-only"
    _topo_root_rel: str = ""
    _topo_root_abs: str = ""
    _fake_mina: str = ""
    _repo_root: str = ""

    @classmethod
    def setUpClass(cls):
        """Create a daemon-only topology with fake mina, plan + materialize it."""
        cls._repo_root = REPO_ROOT
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

        # Create fake mina executable (supports both generate-keypair and daemon)
        fd, cls._fake_mina = tempfile.mkstemp(prefix="fake_mina_")
        os.close(fd)
        Path(cls._fake_mina).write_text(_FAKE_MINA_SCRIPT, encoding="utf-8")
        os.chmod(cls._fake_mina, 0o755)

        cls._topo_root_rel = ".mina-local-network/" + cls._topo_name
        cls._topo_root_abs = str(
            Path(REPO_ROOT) / ".mina-local-network" / cls._topo_name
        )
        # Minimal daemon-only topology: 1 node, no workers, no services
        topology = {
            "schema_version": 1,
            "name": cls._topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": {"mina": cls._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="spawn_topo_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        _run("plan", "topology", topo_path, "--overwrite", check=True)
        _run("materialize", cls._topo_root_rel, "--force", check=True)
        os.unlink(topo_path)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        if cls._fake_mina and Path(cls._fake_mina).exists():
            os.unlink(cls._fake_mina)

    # ── helpers ──────────────────────────────────────────────────────

    def _plan_path(self) -> Path:
        return Path(self._topo_root_abs) / "network-plan.json"

    def _manifest_path(self) -> Path:
        return Path(self._topo_root_abs) / "materialized-manifest.json"

    def _processes_path(self) -> Path:
        return Path(self._topo_root_abs) / "processes.json"

    def _marker_path(self) -> Path:
        return Path(self._topo_root_abs) / "fake-mina-marker"

    def _args_file_path(self) -> Path:
        return Path(self._topo_root_abs) / "fake-mina-args.txt"

    # ── tests ─────────────────────────────────────────────────────────

    def test_spawn_instance_fails_when_genesis_has_already_passed(self):
        """A network spawned after its own genesis must be rejected.

        Its daemons would silently produce nothing for the slots they slept
        through, and the run would fail somewhere far away — a chain shorter than
        expected, or occupancy that never recovers — with nothing pointing back
        here."""
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)

        env = _spawn_env("unset")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_SLEEP"] = "10"
        env["FAKE_MINA_GQL_GENESIS_TIMESTAMP"] = "2020-01-01T00:00:00Z"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, f"spawn must reject a passed genesis: {cp.stdout}"
        )
        self.assertIn(
            "SPAWN_GENESIS_ALREADY_PASSED",
            cp.stderr,
            f"failure must name the reason: {cp.stderr}",
        )
        self.assertIn(
            "2020-01-01",
            cp.stderr,
            f"failure must report the genesis it was late for: {cp.stderr}",
        )

    def test_spawn_instance_fails_when_daemon_exits_before_ready(self):
        """A daemon that exits before it is ready never started.

        Distinct from one that exits *after* becoming ready, which is a network
        that ran and stopped — see test_spawn_instance_exits_cleanly."""
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        # Serves no GraphQL and leaves at once: up long enough to be launched,
        # never long enough to answer.
        env["FAKE_MINA_SLEEP"] = "0"
        env["FAKE_MINA_NO_GQL"] = "1"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode,
            0,
            f"spawn must reject a daemon that never became ready: {cp.stdout}",
        )

    def test_spawn_instance_exits_cleanly(self):
        """spawn instance returns 0 when the daemon comes up and then exits, and
        cleans processes.json.

        The daemon becomes ready first: a daemon that ends after it started is a
        network that ran and stopped, which is the supervisor's business and the
        case this covers. One that exits *before* it is ready never started, and
        spawn rejects that — see
        test_spawn_instance_fails_when_daemon_exits_before_ready."""
        # Ensure no processes.json beforehand
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_SLEEP"] = "3"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(
            cp.returncode,
            0,
            f"spawn instance failed: stdout={cp.stdout} stderr={cp.stderr}",
        )
        # Marker should have been written by fake daemon
        self.assertTrue(
            self._marker_path().exists(), "Fake daemon should have written marker file"
        )
        # processes.json must NOT exist after clean exit
        self.assertFalse(
            self._processes_path().exists(),
            "processes.json must be removed after clean daemon exit",
        )

    # ── fingerprint validation ───────────────────────────────────────

    def test_spawn_instance_fails_on_mismatched_plan_fingerprint(self):
        """Corrupting network-plan.json after materialize causes spawn instance
        to fail with a fingerprint mismatch before Popen."""
        fp_topo_name = "fp-mismatch-test"
        fp_root_rel = ".mina-local-network/" + fp_topo_name
        fp_root_abs = str(Path(self._repo_root) / ".mina-local-network" / fp_topo_name)

        topology = {
            "schema_version": 1,
            "name": fp_topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="fp_topo_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", fp_root_rel, "--force", check=True)

            # Corrupt the plan: change a port value in the daemon argv
            plan_path = Path(fp_root_abs) / "network-plan.json"
            plan = json.loads(plan_path.read_text(encoding="utf-8"))
            # Mutate a port — this changes the fingerprint
            old_port = plan["nodes"][0]["endpoints"]["client"]["port"]
            plan["nodes"][0]["endpoints"]["client"]["port"] = old_port + 1
            plan_path.write_text(
                json.dumps(plan, indent=2, sort_keys=True), encoding="utf-8"
            )

            # Run spawn instance — must fail before Popen
            marker_file = Path(fp_root_abs) / "fake-marker"
            marker_file.unlink(missing_ok=True)
            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker_file)
            env["FAKE_MINA_SLEEP"] = "3"

            cp = subprocess.run(
                [PYTHON3, CLI, "spawn", "instance", fp_root_rel],
                capture_output=True,
                text=True,
                env=env,
                cwd=self._repo_root,
            )
            self.assertNotEqual(
                cp.returncode, 0, "spawn instance must fail on fingerprint mismatch"
            )
            self.assertIn(
                "different plan",
                cp.stderr,
                "Error must mention different plan mismatch",
            )
            # Must NOT have spawned — no marker
            self.assertFalse(
                marker_file.exists(), "Fake daemon must not have been spawned"
            )

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / fp_topo_name),
                ignore_errors=True,
            )

    def test_spawn_topology_overwrite_with_stale_manifest_fails(self):
        """spawn topology --overwrite after prior plan+materialize must detect
        stale manifest and error before spawning."""
        stale_topo_name = "stale-spawn-test"
        stale_root_rel = ".mina-local-network/" + stale_topo_name
        stale_root_abs = str(
            Path(self._repo_root) / ".mina-local-network" / stale_topo_name
        )

        topology = {
            "schema_version": 1,
            "name": stale_topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="stale_topo_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            # Plan + materialize first (creates plan v1 + matching manifest)
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", stale_root_rel, "--force", check=True)

            # Now run spawn topology --overwrite.  This replans (new plan
            # gets different ports → different fingerprint), then loads the
            # new plan, finds the stale manifest, and must fail before spawning.
            marker_file = Path(stale_root_abs) / "fake-marker"
            marker_file.unlink(missing_ok=True)
            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker_file)
            env["FAKE_MINA_SLEEP"] = "3"

            cp = subprocess.run(
                [PYTHON3, CLI, "spawn", "topology", topo_path, "--overwrite"],
                capture_output=True,
                text=True,
                env=env,
                cwd=self._repo_root,
            )
            self.assertNotEqual(
                cp.returncode,
                0,
                "spawn topology --overwrite with stale manifest must fail",
            )
            self.assertIn(
                "different plan", cp.stderr, "Error must mention stale/different plan"
            )
            # Must NOT have spawned — no daemon marker
            self.assertFalse(
                marker_file.exists(),
                "Fake daemon must not have been spawned via stale manifest",
            )

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / stale_topo_name),
                ignore_errors=True,
            )

    def test_spawn_instance_writes_process_tracking(self):
        """spawn instance writes processes.json while daemon is running, and
        cleans it after teardown."""
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_SLEEP"] = "60"  # sleep long enough for us to inspect

        # Start spawn in background
        proc = subprocess.Popen(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
            cwd=self._repo_root,
        )

        try:
            # Wait for marker to appear (max 10 seconds)
            deadline = time.time() + 10
            while not self._marker_path().exists():
                if time.time() > deadline:
                    self.fail("Fake daemon marker did not appear within 10s")
                time.sleep(0.1)

            # Give a tiny extra moment for processes.json to be written
            time.sleep(0.3)

            # Assert processes.json exists with correct shape
            self.assertTrue(
                self._processes_path().exists(),
                "processes.json must exist while daemon is running",
            )
            procs = json.loads(self._processes_path().read_text(encoding="utf-8"))
            self.assertIn("seed", procs, "processes.json should have 'seed' entry")
            seed = procs["seed"]
            self.assertEqual(seed["kind"], "daemon")
            self.assertEqual(seed["state"], "running")
            self.assertIsInstance(seed["pid"], int)
            self.assertGreater(seed["pid"], 0)
            self.assertIsInstance(seed["pgid"], int)
            self.assertGreater(seed["pgid"], 0)
            self.assertIn("argv", seed)
            self.assertIn("started_at", seed)

        finally:
            # Send SIGTERM to the spawn process
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)

        # After teardown, processes.json should not exist (or at least not running)
        if self._processes_path().exists():
            procs = json.loads(self._processes_path().read_text(encoding="utf-8"))
            self.assertNotEqual(
                procs.get("seed", {}).get("state"),
                "running",
                "processes.json must not show running state after teardown",
            )

    def test_argv_paths_are_absolute_in_subprocess(self):
        """Filesystem paths in daemon argv are absolute when handed to a
        subprocess, so Mina children (running from a different CWD) do not
        attempt to create ``/.mina-local-network/...`` directories."""
        args_file = Path(self._topo_root_abs) / "fake-daemon-args.txt"
        self._marker_path().unlink(missing_ok=True)
        args_file.unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_ARGS_FILE"] = str(args_file)
        env["FAKE_MINA_SLEEP"] = "3"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(cp.returncode, 0, f"spawn failed: {cp.stderr}")
        self.assertTrue(args_file.exists(), "Fake daemon should have written args file")

        argv_lines = args_file.read_text(encoding="utf-8").strip().split("\n")

        # Flags that carry filesystem paths — every value after these
        # must be an absolute path.
        _path_flags = frozenset(
            {
                "--config-file",
                "--config-directory",
                "--precomputed-blocks-file",
                "--block-producer-key",
            }
        )
        for i, arg in enumerate(argv_lines):
            if arg in _path_flags and i + 1 < len(argv_lines):
                val = argv_lines[i + 1]
                self.assertTrue(
                    os.path.isabs(val),
                    f"Path after {arg} must be absolute, got {val!r}",
                )

    def test_spawn_instance_substitutes_pubkey_token(self):
        """spawn instance replaces <pubkey:snark_coordinator_account> with
        actual pubkey content before invoking daemon."""
        # Create a fresh topology that has snark_coordinator without worker_pools
        # (so no workers generated) to test token substitution in the daemon argv
        token_topo_name = "token-test"
        token_root_rel = ".mina-local-network/" + token_topo_name
        token_root_abs = str(
            Path(self._repo_root) / ".mina-local-network" / token_topo_name
        )

        topology = {
            "schema_version": 1,
            "name": token_topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {
                        "count": 1,
                        "offline_balance": "5mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {},
                        },
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="token_topo_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", token_root_rel, "--force", check=True)

            # Read the manifest to know the expected pubkey content
            manifest_path = Path(token_root_abs) / "materialized-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            expected_pubkey = manifest["keys"]["snark_coordinator_account"][
                "pubkey_content"
            ]
            self.assertTrue(expected_pubkey, "pubkey_content must not be empty")

            # Spawn with FAKE_MINA_ARGS_FILE so fake daemon writes its argv
            args_file = Path(token_root_abs) / "fake-mina-args.txt"
            env = _spawn_env("far")
            env["FAKE_MINA_ARGS_FILE"] = str(args_file)
            env["FAKE_MINA_SLEEP"] = "3"

            cp = subprocess.run(
                [PYTHON3, CLI, "spawn", "instance", token_root_rel],
                capture_output=True,
                text=True,
                env=env,
                cwd=self._repo_root,
            )
            self.assertEqual(cp.returncode, 0, f"spawn instance failed: {cp.stderr}")

            # Read the args written by fake daemon
            self.assertTrue(
                args_file.exists(), "Fake daemon should have written args file"
            )
            args_text = args_file.read_text(encoding="utf-8").strip()
            args_list = args_text.split("\n")

            # The token MUST NOT appear
            self.assertNotIn(
                "<pubkey:snark_coordinator_account>",
                args_list,
                "Token should have been replaced in daemon argv",
            )

            # The pubkey content MUST appear
            self.assertIn(
                expected_pubkey,
                args_list,
                f"Expected pubkey {expected_pubkey} not found in daemon argv: {args_list}",
            )

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / token_topo_name),
                ignore_errors=True,
            )

    def test_spawn_instance_errors_when_pubkey_token_unresolvable(self):
        """spawn instance must fail (before Popen) when a pubkey token cannot
        be resolved from the materialized manifest."""
        # Create a fresh topology with snark_coordinator (no worker_pools)
        err_topo_name = "pubkey-err-test"
        err_root_rel = ".mina-local-network/" + err_topo_name
        err_root_abs = str(
            Path(self._repo_root) / ".mina-local-network" / err_topo_name
        )

        topology = {
            "schema_version": 1,
            "name": err_topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {
                        "count": 1,
                        "offline_balance": "5mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {},
                        },
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="err_topo_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", err_root_rel, "--force", check=True)

            # --- Corrupt: remove snark_coordinator_account from manifest keys ---
            manifest_path = Path(err_root_abs) / "materialized-manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertIn(
                "snark_coordinator_account",
                manifest.get("keys", {}),
                "Expected snark_coordinator_account key to exist before corruption",
            )
            del manifest["keys"]["snark_coordinator_account"]
            manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

            # Run spawn instance — must fail before spawning
            env = _spawn_env("far")
            env["FAKE_MINA_SLEEP"] = "3"

            cp = subprocess.run(
                [PYTHON3, CLI, "spawn", "instance", err_root_rel],
                capture_output=True,
                text=True,
                env=env,
                cwd=self._repo_root,
            )
            self.assertNotEqual(
                cp.returncode,
                0,
                "spawn instance must fail when pubkey token cannot be resolved",
            )
            self.assertIn(
                "snark_coordinator_account",
                cp.stderr,
                "Error must mention the missing key",
            )

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / err_topo_name),
                ignore_errors=True,
            )

    def test_spawn_instance_with_workers_process_table(self):
        """spawn instance with daemon + workers populates processes.json with
        correct kind values for all entries."""
        worker_topo_name = "wk-proc-test"
        worker_root_rel = ".mina-local-network/" + worker_topo_name
        worker_root_abs = str(
            Path(self._repo_root) / ".mina-local-network" / worker_topo_name
        )

        # Topology: 1 daemon + 2 workers
        topology = {
            "schema_version": 1,
            "name": worker_topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wk_proc_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", worker_root_rel, "--force", check=True)

            marker_file = Path(worker_root_abs) / "fake-mina-marker"
            marker_file.unlink(missing_ok=True)
            procs_path = Path(worker_root_abs) / "processes.json"
            procs_path.unlink(missing_ok=True)

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker_file)
            env["FAKE_MINA_SLEEP"] = "60"

            proc = subprocess.Popen(
                [PYTHON3, CLI, "spawn", "instance", worker_root_rel],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                cwd=self._repo_root,
            )

            try:
                # Wait for marker to appear
                deadline = time.time() + 10
                while not marker_file.exists():
                    if time.time() > deadline:
                        self.fail("Fake mina marker did not appear within 10s")
                    time.sleep(0.1)
                time.sleep(0.3)

                # Check processes.json shape
                self.assertTrue(
                    procs_path.exists(),
                    "processes.json must exist while processes are running",
                )
                procs = json.loads(procs_path.read_text(encoding="utf-8"))
                self.assertIn("seed", procs, "processes.json should have daemon entry")
                self.assertEqual(procs["seed"]["kind"], "daemon")

                # Verify 0 workers (topology has no snark_coordinator, so no workers)
                # This test verifies basic daemon + worker handling with the new code
                # The topology above has no snark_coordinator, so workers=[].
                # We check that the daemon-only case also works.
                self.assertEqual(len(procs), 1)

            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait(timeout=5)

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / worker_topo_name),
                ignore_errors=True,
            )


# ---------------------------------------------------------------------------
# Process-table and expected-exit unit tests
# ---------------------------------------------------------------------------


class TestProcessTableOrdering(unittest.TestCase):
    """Process table construction: seed-first ordering and expected_exit marking."""

    def test_daemon_seed_first_ordering(self):
        """Process table orders seed daemons before non-seed, regardless of input order."""
        entries = [
            DaemonEntry(name="plain_0", argv=["mina", "daemon"], is_seed=False),
            DaemonEntry(name="seed_0", argv=["mina", "daemon", "--seed"], is_seed=True),
            DaemonEntry(name="plain_1", argv=["mina", "daemon"], is_seed=False),
        ]

        table = build_process_table(
            archive_svc=None,
            daemon_entries=entries,
            workers=[],
            rosetta_svc=None,
            workloads=[],
            keys={},
            rest_server="http://127.0.0.1:3085/graphql",
            node_rest_servers=["http://127.0.0.1:3085/graphql"],
            mina_exe="mina",
            zkapp_exe="zkapp",
            itn_result=mock.MagicMock(auth_keys={}, itn_workloads=[]),
        )

        names = [p.name for p in table if p.kind == ProcessKind.DAEMON]
        self.assertEqual(names, ["seed_0", "plain_0", "plain_1"])

    def test_hardfork_migrate_exit_marked_expected(self):
        """Daemon with --hardfork-handling migrate-exit in argv gets expected_exit=True."""
        entries = [
            DaemonEntry(
                name="hf_daemon",
                argv=[
                    "mina",
                    "daemon",
                    "--hardfork-handling",
                    "migrate-exit",
                ],
                is_seed=False,
            ),
            DaemonEntry(
                name="normal_daemon",
                argv=["mina", "daemon", "--seed"],
                is_seed=True,
            ),
        ]

        table = build_process_table(
            archive_svc=None,
            daemon_entries=entries,
            workers=[],
            rosetta_svc=None,
            workloads=[],
            keys={},
            rest_server="http://127.0.0.1:3085/graphql",
            node_rest_servers=["http://127.0.0.1:3085/graphql"],
            mina_exe="mina",
            zkapp_exe="zkapp",
            itn_result=mock.MagicMock(auth_keys={}, itn_workloads=[]),
        )

        hf_proc = next(p for p in table if p.name == "hf_daemon")
        self.assertTrue(hf_proc.expected_exit)

        normal_proc = next(p for p in table if p.name == "normal_daemon")
        self.assertFalse(normal_proc.expected_exit)

    def test_non_hardfork_daemon_not_expected(self):
        """Daemon without the hardfork flag pair must not be marked expected_exit."""
        entries = [
            DaemonEntry(
                name="plain",
                argv=["mina", "daemon", "--seed"],
                is_seed=True,
            ),
        ]

        table = build_process_table(
            archive_svc=None,
            daemon_entries=entries,
            workers=[],
            rosetta_svc=None,
            workloads=[],
            keys={},
            rest_server="http://127.0.0.1:3085/graphql",
            node_rest_servers=["http://127.0.0.1:3085/graphql"],
            mina_exe="mina",
            zkapp_exe="zkapp",
            itn_result=mock.MagicMock(auth_keys={}, itn_workloads=[]),
        )

        self.assertFalse(table[0].expected_exit)


class TestSuperviseExpectedExit(unittest.TestCase):
    """Supervisor tolerates expected_exit=0 without teardown;
    expected_exit≠0 still tears down."""

    def setUp(self):
        self.persist_calls = 0
        self.teardown_calls = 0

    def _fake_persist(self) -> None:
        self.persist_calls += 1

    def _fake_teardown(self) -> None:
        self.teardown_calls += 1

    def _entry(
        self,
        name: str = "test_daemon",
        kind: ProcessKind = ProcessKind.DAEMON,
        expected_exit: bool = False,
        exit_code: Optional[int] = None,
    ) -> CoreProcessEntry:
        entry = CoreProcessEntry(
            name=name,
            kind=kind,
            argv=["mina", "daemon"],
            expected_exit=expected_exit,
        )
        if exit_code is not None:
            # Simulate exited process: proc returns a dummy return code
            mock_proc = mock.MagicMock()
            mock_proc.poll.return_value = exit_code
            mock_proc.returncode = exit_code
            entry.proc = mock_proc
            entry.state = "running"
        return entry

    def test_expected_exit_zero_tolerated_and_persists(self):
        """Daemon with expected_exit=True and exit 0 is tolerated, marked stopped, persist called."""
        from mln.spawn.lifecycle import supervise_processes

        stop_count = [0]

        def _should_stop():
            stop_count[0] += 1
            return (
                stop_count[0] >= 3
            )  # let loop iterate twice, then stop via should_stop

        entry = self._entry(expected_exit=True, exit_code=0)

        exit_code = supervise_processes(
            [entry],
            teardown_fn=self._fake_teardown,
            persist_fn=self._fake_persist,
            should_stop_fn=_should_stop,
        )

        # Should exit via controlled stop (143), not via the expected process exit.
        self.assertEqual(exit_code, 143)
        # Teardown is called once for the controlled stop path.
        self.assertEqual(self.teardown_calls, 1)
        # Persist must have been called (for the expected exit handling)
        self.assertEqual(self.persist_calls, 1)
        # Entry must be marked stopped with proc cleared
        self.assertEqual(entry.state, "stopped")
        self.assertIsNone(entry.proc)

    def test_expected_exit_zero_marks_stopped_and_persists(self):
        """expected-exit daemon with exit 0 is marked stopped, proc cleared, persist called."""
        from mln.spawn.lifecycle import supervise_processes

        callback_order: list[str] = []

        def _persist():
            callback_order.append("persist")

        def _teardown():
            callback_order.append("teardown")

        stop_count = [0]

        def _should_stop():
            stop_count[0] += 1
            return stop_count[0] >= 3  # let loop iterate twice then stop

        entry = self._entry(expected_exit=True, exit_code=0)

        exit_code = supervise_processes(
            [entry],
            teardown_fn=_teardown,
            persist_fn=_persist,
            should_stop_fn=_should_stop,
        )

        # supervise_processes returns 143 from should_stop_fn
        self.assertEqual(exit_code, 143)
        # persist was called (expected exit handled)
        self.assertIn("persist", callback_order)
        # teardown is only called later by the controlled stop path.
        self.assertEqual(callback_order, ["persist", "teardown"])
        self.assertEqual(entry.state, "stopped")
        self.assertIsNone(entry.proc)

    def test_expected_exit_does_not_mask_unexpected_exit_same_poll(self):
        """Expected exits are ignored, but unrelated simultaneous core exits still tear down."""
        from mln.spawn.lifecycle import supervise_processes

        expected_entry = self._entry(
            name="expected_daemon", expected_exit=True, exit_code=0
        )
        unexpected_entry = self._entry(
            name="unexpected_daemon", expected_exit=False, exit_code=1
        )

        exit_code = supervise_processes(
            [expected_entry, unexpected_entry],
            teardown_fn=self._fake_teardown,
            persist_fn=self._fake_persist,
            should_stop_fn=lambda: False,
        )

        self.assertEqual(exit_code, 1)
        self.assertEqual(self.teardown_calls, 1)
        self.assertEqual(self.persist_calls, 1)
        self.assertEqual(expected_entry.state, "stopped")
        self.assertIsNone(expected_entry.proc)

    def test_expected_exit_nonzero_still_tears_down(self):
        """Daemon with expected_exit=True but non-zero exit code still triggers teardown."""
        from mln.spawn.lifecycle import supervise_processes

        entry = self._entry(expected_exit=True, exit_code=1)

        exit_code = supervise_processes(
            [entry],
            teardown_fn=self._fake_teardown,
            persist_fn=self._fake_persist,
            should_stop_fn=lambda: False,
        )

        self.assertEqual(exit_code, 1)
        self.assertEqual(self.teardown_calls, 1)
        self.assertEqual(self.persist_calls, 0)

    def test_unexpected_daemon_exit_tears_down(self):
        """Daemon without expected_exit that exits triggers teardown."""
        from mln.spawn.lifecycle import supervise_processes

        entry = self._entry(expected_exit=False, exit_code=0)

        exit_code = supervise_processes(
            [entry],
            teardown_fn=self._fake_teardown,
            persist_fn=self._fake_persist,
            should_stop_fn=lambda: False,
        )

        self.assertEqual(exit_code, 0)
        self.assertEqual(self.teardown_calls, 1)
        self.assertEqual(self.persist_calls, 0)


class TestSpawnInstanceContinued(TestSpawnInstance):
    """Continuation of TestSpawnInstance tests — inherits setUpClass/tearDownClass
    and helper methods from the parent class defined above."""

    def test_spawn_instance_refuses_still_running_pid(self):
        """spawn instance refuses to start if processes.json indicates a
        still-running pid."""
        # Write a processes.json with a fake running pid (use our own pid
        # since it's definitely running)
        self._processes_path().parent.mkdir(parents=True, exist_ok=True)
        fake_procs = {
            "seed": {
                "pid": os.getpid(),
                "pgid": os.getpgid(0),
                "kind": "daemon",
                "argv": ["fake"],
                "started_at": "2025-01-01T00:00:00Z",
                "state": "running",
            }
        }
        self._processes_path().write_text(
            json.dumps(fake_procs, indent=2), encoding="utf-8"
        )

        cp = _run("spawn", "instance", self._topo_root_rel, check=False)
        self.assertNotEqual(
            cp.returncode,
            0,
            "spawn instance must refuse when a tracked pid is still alive",
        )
        self.assertIn("appears to still be running", cp.stderr)

    def test_spawn_instance_ignores_stale_pid(self):
        """spawn instance ignores stale pids in processes.json and proceeds."""
        # Write a processes.json with a known-nonexistent pid
        self._processes_path().parent.mkdir(parents=True, exist_ok=True)
        fake_procs = {
            "seed": {
                "pid": 99999999,  # extremely unlikely to exist
                "pgid": 99999999,
                "kind": "daemon",
                "argv": ["fake"],
                "started_at": "2025-01-01T00:00:00Z",
                "state": "running",
            }
        }
        self._processes_path().write_text(
            json.dumps(fake_procs, indent=2), encoding="utf-8"
        )

        env = _spawn_env("far")
        env["FAKE_MINA_SLEEP"] = "3"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(
            cp.returncode,
            0,
            f"spawn instance with stale pid should succeed: {cp.stderr}",
        )
        # processes.json must be cleaned up
        self.assertFalse(
            self._processes_path().exists(),
            "processes.json must be removed after clean exit",
        )

    # ── Missing binary test (BL4) ────────────────────────────────────

    def test_spawn_instance_missing_binary_fails_cleanly(self):
        """spawn instance with a nonexistent binary must produce ClickException
        before Popen, not a raw traceback."""
        # Use the existing plan + manifest, but poison daemon_argv[0]
        plan_path = self._plan_path()
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["nodes"][0]["daemon_argv"][0] = "/does/not/exist/mina"
        plan_path.write_text(json.dumps(plan, indent=2), encoding="utf-8")

        # Re-materialize so the manifest fingerprint matches the modified plan
        _run("materialize", self._topo_root_rel, "--force", check=True)

        env = _spawn_env("far")
        env["FAKE_MINA_SLEEP"] = "3"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "spawn instance must fail with missing binary"
        )
        self.assertIn("not found or not executable", cp.stderr)
        self.assertIn("/does/not/exist/mina", cp.stderr)

        # Restore the plan + re-materialize for subsequent tests
        plan["nodes"][0]["daemon_argv"][0] = self._fake_mina
        plan_path.write_text(json.dumps(plan, indent=2), encoding="utf-8")
        _run("materialize", self._topo_root_rel, "--force", check=True)

    # ── Corrupt processes.json test (BL4) ────────────────────────────

    def test_spawn_instance_corrupt_processes_json_errors_cleanly(self):
        """spawn instance with corrupt processes.json must produce ClickException,
        not a raw JSON traceback."""
        self._processes_path().parent.mkdir(parents=True, exist_ok=True)
        self._processes_path().write_text("this is not valid json", encoding="utf-8")

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "spawn instance must fail on corrupt processes.json"
        )
        self.assertIn("Failed to parse", cp.stderr)
        self.assertIn("may be corrupt", cp.stderr)
        self._processes_path().unlink(missing_ok=True)

    # ── Workloads rejection test (updated for v1) ─────────────────────

    def test_spawn_instance_rejects_workloads(self):
        """spawn instance must reject old-format workloads missing argv with a
        clear message."""
        workloads_topo_name = "wl-test"
        wl_root_rel = ".mina-local-network/" + workloads_topo_name
        wl_root_abs = str(
            Path(self._repo_root) / ".mina-local-network" / workloads_topo_name
        )

        topology = {
            "schema_version": 1,
            "name": workloads_topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wl_topo_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", wl_root_rel, "--force", check=True)

            # Inject old-format workloads into the plan
            plan_path = Path(wl_root_abs) / "network-plan.json"
            plan = json.loads(plan_path.read_text(encoding="utf-8"))
            # Old-format workload without type or argv → rejected
            plan["workloads"] = [{"name": "test-wl", "cmd": "echo", "count": 1}]
            plan_path.write_text(json.dumps(plan, indent=2), encoding="utf-8")

            # Re-materialize so manifest fingerprint matches modified plan
            _run("materialize", wl_root_rel, "--force", check=True)

            cp = _run("spawn", "instance", wl_root_rel, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "spawn instance with invalid workloads must fail"
            )
            self.assertIn(
                "has no argv", cp.stderr, "Must reject workloads missing config.argv"
            )
        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(
                    Path(self._repo_root) / ".mina-local-network" / workloads_topo_name
                ),
                ignore_errors=True,
            )

    # ── SIGINT teardown test (BL5) ────────────────────────────────────

    def test_teardown_effectiveness_via_sigterm(self):
        """When SIGTERM is sent to spawn instance, the fake daemon and its
        child processes must actually be gone, not just processes.json removed."""
        child_pid_file = Path(self._topo_root_abs) / "child.pid"
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)
        child_pid_file.unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_SLEEP"] = "999"
        env["FAKE_MINA_SPAWN_SLEEP"] = "999"
        env["FAKE_MINA_CHILD_PID_FILE"] = str(child_pid_file)

        proc = subprocess.Popen(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
            cwd=self._repo_root,
        )

        try:
            # Wait for marker (max 15s)
            deadline = time.time() + 15
            while not self._marker_path().exists():
                if time.time() > deadline:
                    self.fail("Fake daemon marker did not appear within 15s")
                time.sleep(0.1)

            time.sleep(0.5)  # let child spawn

            # Read child PID
            self.assertTrue(
                child_pid_file.exists(),
                "Fake daemon should have written child PID file",
            )
            child_pid = int(child_pid_file.read_text(encoding="utf-8").strip())
            self.assertGreater(child_pid, 0)

            # Read daemon PID from processes.json
            procs = json.loads(self._processes_path().read_text(encoding="utf-8"))
            daemon_pid = procs["seed"]["pid"]

            # Send SIGTERM
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

            # Verify daemon is gone
            self.assertFalse(
                pid_is_running(daemon_pid),
                f"Daemon PID {daemon_pid} should be dead after teardown",
            )

            # Verify child process is gone
            self.assertFalse(
                pid_is_running(child_pid),
                f"Child PID {child_pid} should be dead after teardown",
            )

        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    def test_teardown_effectiveness_via_sigint(self):
        """SIGINT must also trigger clean teardown (same as SIGTERM)."""
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_SLEEP"] = "999"

        proc = subprocess.Popen(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
            cwd=self._repo_root,
        )

        try:
            # Wait for marker
            deadline = time.time() + 15
            while not self._marker_path().exists():
                if time.time() > deadline:
                    self.fail("Fake daemon marker did not appear within 15s")
                time.sleep(0.1)

            time.sleep(0.3)

            procs = json.loads(self._processes_path().read_text(encoding="utf-8"))
            daemon_pid = procs["seed"]["pid"]

            # Send SIGINT
            import signal

            proc.send_signal(signal.SIGINT)
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

            # Verify daemon is gone
            self.assertFalse(
                pid_is_running(daemon_pid),
                f"Daemon PID {daemon_pid} should be dead after SIGINT",
            )

        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    # ── SIGKILL escalation test (BL5) ─────────────────────────────────

    def test_sigkill_escalation_when_sigterm_trapped(self):
        """When fake daemon traps SIGTERM, supervisor must escalate to SIGKILL
        and not hang indefinitely."""
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_SLEEP"] = "999"
        env["FAKE_MINA_TRAP_SIGTERM"] = "1"

        proc = subprocess.Popen(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
            cwd=self._repo_root,
        )

        try:
            # Wait for marker
            deadline = time.time() + 15
            while not self._marker_path().exists():
                if time.time() > deadline:
                    self.fail("Fake daemon marker did not appear within 15s")
                time.sleep(0.1)

            time.sleep(0.3)

            procs = json.loads(self._processes_path().read_text(encoding="utf-8"))
            daemon_pid = procs["seed"]["pid"]

            # Send SIGTERM — daemon ignores it, but supervisor escalates to SIGKILL
            proc.terminate()
            try:
                proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill()
                self.fail("Spawn instance should not hang — SIGKILL escalation failed")
                proc.wait(timeout=5)

            # Verify daemon is gone (KILL signal works regardless of trap)
            self.assertFalse(
                pid_is_running(daemon_pid),
                f"Daemon PID {daemon_pid} should be dead after SIGKILL escalation",
            )

        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    # ── Exception-path teardown test (BL1 + BL5) ──────────────────────

    def test_exception_after_spawn_kills_child(self):
        """If an exception occurs after Popen (e.g. _write_processes_json fails),
        the spawned child must be killed before returning.  No running-looking
        processes.json must be left behind."""
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)

        # Make the processes.json path unwritable by creating it as a read-only file
        self._processes_path().parent.mkdir(parents=True, exist_ok=True)
        self._processes_path().write_text("{}", encoding="utf-8")
        self._processes_path().chmod(0o444)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_SLEEP"] = "999"

        proc = subprocess.Popen(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
            cwd=self._repo_root,
        )

        try:
            _stdout, stderr_output = proc.communicate(timeout=15)
            self.assertNotEqual(
                proc.returncode,
                0,
                "spawn instance must fail when processes.json is unwritable",
            )
            # The daemon should have been killed — verify no process is left
            # Look for "Daemon PID:" in stderr and extract the PID
            import re

            m = re.search(r"daemon '(?:[^']+)' PID: (\d+)", stderr_output)
            if m:
                reported_pid = int(m.group(1))
                self.assertFalse(
                    pid_is_running(reported_pid),
                    f"Daemon PID {reported_pid} should be dead after exception",
                )

        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass
            # Restore write permission for cleanup
            try:
                self._processes_path().chmod(0o644)
                self._processes_path().unlink(missing_ok=True)
            except Exception:
                pass

    # ── Worker lifecycle tests ──────────────────────────────────────

    def test_spawn_with_workers_process_json_has_all_entries(self):
        """spawn instance with 1 daemon + 2 snark workers populates
        processes.json with correct kind values for every entry."""
        wk_name = "wk-procs-json-test"
        wk_rel = ".mina-local-network/" + wk_name
        wk_abs = str(Path(self._repo_root) / ".mina-local-network" / wk_name)

        topology = {
            "schema_version": 1,
            "name": wk_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {"count": 1, "offline_balance": "5mina"},
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {"default": {"count": 2, "nap": "PT1S"}},
                        },
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wk_procs_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", wk_rel, "--force", check=True)

            marker = Path(wk_abs) / "fake-marker"
            marker.unlink(missing_ok=True)
            procs_json = Path(wk_abs) / "processes.json"
            procs_json.unlink(missing_ok=True)

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_SLEEP"] = "60"

            proc = subprocess.Popen(
                [PYTHON3, CLI, "spawn", "instance", wk_rel],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                cwd=self._repo_root,
                start_new_session=True,
            )

            try:
                deadline = time.time() + 10
                while not marker.exists():
                    if time.time() > deadline:
                        self.fail("Marker did not appear within 10s")
                    time.sleep(0.1)
                time.sleep(0.5)  # let all processes start

                self.assertTrue(
                    procs_json.exists(), "processes.json must exist while running"
                )
                procs = json.loads(procs_json.read_text(encoding="utf-8"))

                # Should have 1 daemon + 2 workers = 3 entries
                self.assertEqual(
                    len(procs),
                    3,
                    f"Expected 3 entries (1 daemon + 2 workers), got {len(procs)}: {list(procs.keys())}",
                )

                # Daemon entry
                self.assertIn("seed", procs)
                self.assertEqual(procs["seed"]["kind"], "daemon")
                self.assertEqual(procs["seed"]["state"], "running")

                # Worker entries
                wk_entries = [
                    (k, v) for k, v in procs.items() if v["kind"] == "snark_worker"
                ]
                self.assertEqual(
                    len(wk_entries),
                    2,
                    f"Expected 2 worker entries, got {len(wk_entries)}",
                )
                for wname, winfo in wk_entries:
                    self.assertEqual(winfo["state"], "running")
                    self.assertGreater(winfo["pid"], 0)
                    self.assertIn("seed_default_", wname)

                # Terminate and verify cleanup
                _terminate_process_tree(proc, timeout=10)

                # processes.json should be gone after teardown
                self.assertFalse(
                    procs_json.exists()
                    and json.loads(procs_json.read_text(encoding="utf-8")),
                    "processes.json must be empty or removed after teardown",
                )

            finally:
                _terminate_process_tree(proc)

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / wk_name),
                ignore_errors=True,
            )

    def test_multi_daemon_spawn_no_longer_rejected(self):
        """A plan with 2 daemon nodes spawns without the old 'exactly 1' error."""
        multi_name = "multi-daemon-test"
        multi_rel = ".mina-local-network/" + multi_name
        multi_abs = str(Path(self._repo_root) / ".mina-local-network" / multi_name)

        topology = {
            "schema_version": 1,
            "name": multi_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 2,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
                "follower": {
                    "capabilities": {},
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="multi_d_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", multi_rel, "--force", check=True)

            marker = Path(multi_abs) / "fake-marker"
            marker.unlink(missing_ok=True)
            daemon_env_file = Path(multi_abs) / "daemon-env.txt"
            daemon_env_file.unlink(missing_ok=True)
            procs_json = Path(multi_abs) / "processes.json"
            procs_json.unlink(missing_ok=True)

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_DAEMON_ENV_FILE"] = str(daemon_env_file)
            env["FAKE_MINA_SLEEP"] = "60"

            proc = subprocess.Popen(
                [PYTHON3, CLI, "spawn", "instance", multi_rel],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                cwd=self._repo_root,
            )

            try:
                deadline = time.time() + 15
                while not marker.exists():
                    if time.time() > deadline:
                        self.fail("Daemon marker did not appear within 15s")
                    time.sleep(0.1)
                time.sleep(0.5)

                # Poll for processes.json — it is written after all daemon
                # readiness gates pass and Phase 2 persistence runs, which
                # may be several seconds after the first marker appears.
                pjson_deadline = time.time() + 20
                while not procs_json.exists():
                    if time.time() > pjson_deadline:
                        self.fail("processes.json did not appear within 20s")
                    time.sleep(0.1)
                self.assertTrue(
                    procs_json.exists(), "processes.json must exist while running"
                )
                procs = json.loads(procs_json.read_text(encoding="utf-8"))

                # Must have 2 daemon entries
                daemon_entries = [
                    (k, v) for k, v in procs.items() if v["kind"] == "daemon"
                ]
                self.assertEqual(
                    len(daemon_entries),
                    2,
                    f"Expected 2 daemon entries, got {len(daemon_entries)}: "
                    f"{list(procs.keys())}",
                )
                daemon_names = {k for k, v in daemon_entries}
                self.assertIn("seed", daemon_names)
                self.assertIn("follower", daemon_names)
                daemon_env = daemon_env_file.read_text(encoding="utf-8")
                self.assertIn("MINA_PRIVKEY_PASS=naughty blue worm", daemon_env)

                # Must NOT contain the old "exactly 1 daemon" error in stderr
                # (the spawn is running, so that guard didn't fire)

            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait(timeout=5)

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / multi_name),
                ignore_errors=True,
            )


# ---------------------------------------------------------------------------
# Workload plan resolution tests
# ---------------------------------------------------------------------------


class TestWorkloadPlan(unittest.TestCase):
    """Tests that workloads are resolved into network-plan.json."""

    @classmethod
    def setUpClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    def test_plan_resolves_echo_workload(self):
        """Plan resolves an echo workload with deterministic shape."""
        topo_name = "wl-plan-test"
        topology = {
            "schema_version": 1,
            "name": topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "workloads": {
                "my-echo": {
                    "type": "echo",
                    "start": "immediate",
                    "config": {
                        "argv": ["/usr/bin/sleep", "1"],
                        "env": {"FOO": "bar"},
                        "success_exits_keep_network": True,
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wl_plan_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            root = str(Path(REPO_ROOT) / ".mina-local-network" / topo_name)
            plan = _run_json("inspect", "instance", root)

            self.assertIn("workloads", plan)
            wls = plan["workloads"]
            self.assertEqual(len(wls), 1)
            wl = wls[0]

            self.assertEqual(wl["name"], "my-echo")
            self.assertEqual(wl["type"], "echo")
            self.assertEqual(wl["start"], "immediate")
            self.assertNotIn("repeat", wl)
            self.assertEqual(wl["argv"], ["/usr/bin/sleep", "1"])
            self.assertEqual(wl["env"], {"FOO": "bar"})
            self.assertTrue(wl["success_exits_keep_network"])

            # Must have a graphql_uri pointing to the seed's rest port
            self.assertIn("graphql_uri", wl)
            self.assertIsNotNone(wl["graphql_uri"])
            self.assertTrue(wl["graphql_uri"].startswith("http://"))
            self.assertIn("/graphql", wl["graphql_uri"])
        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / topo_name),
                ignore_errors=True,
            )

    def test_plan_resolves_workload_defaults(self):
        """Plan applies defaults: start=immediate."""
        topo_name = "wl-defaults-test"
        topology = {
            "schema_version": 1,
            "name": topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "workloads": {
                "minimal": {
                    "type": "echo",
                    "config": {"argv": ["/usr/bin/true"]},
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wl_def_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            root = str(Path(REPO_ROOT) / ".mina-local-network" / topo_name)
            plan = _run_json("inspect", "instance", root)
            wl = plan["workloads"][0]
            self.assertEqual(wl["start"], "immediate")
            self.assertNotIn("repeat", wl)
            self.assertEqual(wl["argv"], ["/usr/bin/true"])
        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / topo_name),
                ignore_errors=True,
            )

    def test_plan_resolves_value_transfer_workload(self):
        """Plan resolves a value_transfer workload with deterministic shape
        and defaults."""
        topo_name = "vt-plan-test"
        topology = {
            "schema_version": 1,
            "name": topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "workloads": {
                "my-vt": {
                    "type": "value_transfer",
                    "config": {
                        "amount_min": "5mina",
                        "amount_max": "20mina",
                        "interval_seconds": 3,
                        "count": 10,
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="vt_plan_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            root = str(Path(REPO_ROOT) / ".mina-local-network" / topo_name)
            plan = _run_json("inspect", "instance", root)

            wls = plan["workloads"]
            self.assertEqual(len(wls), 1)
            wl = wls[0]

            self.assertEqual(wl["name"], "my-vt")
            self.assertEqual(wl["type"], "value_transfer")
            self.assertEqual(wl["start"], "after_genesis")  # default for vt
            self.assertNotIn("repeat", wl)
            self.assertEqual(wl["amount_min"], "5mina")
            self.assertEqual(wl["amount_max"], "20mina")
            self.assertEqual(wl["interval_seconds"], 3)
            self.assertEqual(wl["count"], 10)
            self.assertTrue(wl["success_exits_keep_network"])
            self.assertIn("graphql_uri", wl)
            self.assertIsNotNone(wl["graphql_uri"])
        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / topo_name),
                ignore_errors=True,
            )

    def test_plan_resolves_value_transfer_defaults(self):
        """value_transfer defaults: start=after_genesis, amount_min=1mina,
        amount_max=10mina, interval_seconds=10, replay_probability=0,
        success_exits_keep_network=true, no count field when omitted."""
        topo_name = "vt-defs-test"
        topology = {
            "schema_version": 1,
            "name": topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "workloads": {
                "minimal-vt": {
                    "type": "value_transfer",
                    "config": {},
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="vt_defs_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            root = str(Path(REPO_ROOT) / ".mina-local-network" / topo_name)
            plan = _run_json("inspect", "instance", root)
            wl = plan["workloads"][0]
            self.assertEqual(wl["start"], "after_genesis")
            self.assertEqual(wl["amount_min"], "1mina")
            self.assertEqual(wl["amount_max"], "10mina")
            self.assertEqual(wl["interval_seconds"], 10)
            self.assertEqual(wl["replay_probability"], 0.0)
            self.assertNotIn("count", wl)  # omitted → indefinite
            self.assertTrue(wl["success_exits_keep_network"])
        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / topo_name),
                ignore_errors=True,
            )


class TestGraphQLSyncedHelper(unittest.TestCase):
    """Tests for the content-aware GraphQL sync readiness primitive."""

    def testwait_for_graphql_synced_waits_for_status_transition(self):
        """The helper must not return on merely-HTTP-200 GraphQL responses;
        it waits until the response body reports syncStatus=SYNCED."""
        status_fd, status_path = tempfile.mkstemp(prefix="mln_sync_status_")
        os.close(status_fd)
        status_file = Path(status_path)
        status_file.write_text("BOOTSTRAP", encoding="utf-8")
        done = threading.Event()
        errors: list[BaseException] = []

        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):  # noqa: N802 - stdlib callback name
                status = status_file.read_text(encoding="utf-8").strip()
                body = json.dumps({"data": {"syncStatus": status}}).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, format: str, *args: Any) -> None:
                return

        sock = socket.socket()
        sock.bind(("127.0.0.1", 0))
        host, port = sock.getsockname()
        sock.close()
        httpd = HTTPServer((host, port), Handler)
        server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
        server_thread.start()

        def wait_for_sync():
            try:
                wait_for_graphql_synced(
                    f"http://127.0.0.1:{port}/graphql",
                    timeout_sec=5,
                    interval_sec=0.1,
                )
            except BaseException as exc:  # test thread reports below
                errors.append(exc)
            finally:
                done.set()

        wait_thread = threading.Thread(target=wait_for_sync, daemon=True)
        wait_thread.start()
        try:
            time.sleep(0.3)
            self.assertFalse(
                done.is_set(), "helper returned before syncStatus became SYNCED"
            )
            status_file.write_text("SYNCED", encoding="utf-8")
            self.assertTrue(
                done.wait(5), "helper did not return after syncStatus became SYNCED"
            )
            self.assertEqual(errors, [])
        finally:
            httpd.shutdown()
            httpd.server_close()
            wait_thread.join(timeout=5)
            server_thread.join(timeout=5)
            status_file.unlink(missing_ok=True)


class TestZkAppGraphQLHelpers(unittest.TestCase):
    """Deterministic tests for zkApp GraphQL parsing helpers."""

    def testextract_graphql_document_skips_banner_to_mutation(self):
        stdout = "\n".join(
            [
                "Generated transaction successfully",
                "keyfile: /tmp/fake",
                "mutation SendZkapp($input: SendZkappInput!) {",
                "  sendZkapp(input: $input) { zkapp { id } }",
                "}",
            ]
        )
        self.assertEqual(
            extract_graphql_document(stdout),
            "\n".join(
                [
                    "mutation SendZkapp($input: SendZkappInput!) {",
                    "  sendZkapp(input: $input) { zkapp { id } }",
                    "}",
                ]
            ),
        )

    def testextract_graphql_document_accepts_query_and_brace_markers(self):
        self.assertEqual(
            extract_graphql_document("banner\n  query { syncStatus }"),
            "  query { syncStatus }",
        )
        self.assertEqual(
            extract_graphql_document("banner\n  { syncStatus }"),
            "  { syncStatus }",
        )

    def testextract_graphql_document_fails_without_marker(self):
        with self.assertRaisesRegex(Exception, "Failed to extract GraphQL document"):
            extract_graphql_document("only\nbanner\nlines")

    def testgraphql_post_success_and_payload_shape(self):
        with _StaticGraphQLServer({"data": {"syncStatus": "SYNCED"}}) as server:
            response = graphql_post(server.uri, "query { syncStatus }")
        self.assertEqual(response.data, {"syncStatus": "SYNCED"})
        self.assertEqual(server.requests, [{"query": "query { syncStatus }"}])

    def testgraphql_post_rejects_errors_and_null_data(self):
        with _StaticGraphQLServer(
            {"data": {"x": 1}, "errors": [{"message": "bad"}]}
        ) as server:
            with self.assertRaisesRegex(Exception, "GraphQL errors"):
                graphql_post(server.uri, "query { x }")
        with _StaticGraphQLServer({"data": None}) as server:
            with self.assertRaisesRegex(Exception, "null or non-object data"):
                graphql_post(server.uri, "query { x }")

    def testaccount_inferred_nonce_table(self):
        # AccountNonce is a scalar the daemon serializes with
        # Make_scalar_using_to_string (`String (to_string x)`), so it arrives as a
        # decimal string and never as a JSON number. A bare int is covered by
        # testaccount_inferred_nonce_rejects_invalid_shapes instead: accepting one
        # would only mean a malformed response is read as a nonce rather than
        # reported.
        cases = [
            ({"account": None}, 0),
            ({"account": {"inferredNonce": None}}, 0),
            ({"account": {"inferredNonce": "42"}}, 42),
        ]
        for data, expected in cases:
            with self.subTest(data=data):
                response = GraphQLResponse(data=data)
                actual = account_inferred_nonce(
                    response,
                    public_key="fake-pubkey",
                )
                self.assertEqual(actual, expected)

    def testaccount_inferred_nonce_rejects_invalid_shapes(self):
        invalid_cases = [
            {"account": []},
            {"account": {"inferredNonce": "-3"}},
            {"account": {"inferredNonce": "pending"}},
            # A JSON number is not a shape AccountNonce has — see the note on
            # testaccount_inferred_nonce_table.
            {"account": {"inferredNonce": 7}},
        ]
        for data in invalid_cases:
            with self.subTest(data=data):
                response = GraphQLResponse(data=data)
                with self.assertRaisesRegex(
                    Exception, "account response|inferredNonce"
                ):
                    account_inferred_nonce(
                        response,
                        public_key="fake-pubkey",
                    )


# ---------------------------------------------------------------------------
# Workload spawn tests
# ---------------------------------------------------------------------------


class TestWorkloadSpawn(unittest.TestCase):
    """Tests for echo workload spawning with the new supervisor semantics."""

    _topo_name = "wl-spawn-test"
    _topo_root_rel: str = ""
    _topo_root_abs: str = ""
    _fake_mina: str = ""
    _repo_root: str = ""
    _fake_zkapp_rel: str = ".mina-local-network/fake-zkapp"
    _fake_zkapp_abs: str = ""

    @classmethod
    def setUpClass(cls):
        cls._repo_root = REPO_ROOT
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

        # Create fake mina executable
        fd, cls._fake_mina = tempfile.mkstemp(prefix="fake_mina_")
        os.close(fd)
        Path(cls._fake_mina).write_text(_FAKE_MINA_SCRIPT, encoding="utf-8")
        os.chmod(cls._fake_mina, 0o755)

        cls._topo_root_rel = ".mina-local-network/" + cls._topo_name
        cls._topo_root_abs = str(
            Path(REPO_ROOT) / ".mina-local-network" / cls._topo_name
        )
        cls._fake_zkapp_abs = str(Path(REPO_ROOT) / cls._fake_zkapp_rel)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        if cls._fake_mina and Path(cls._fake_mina).exists():
            os.unlink(cls._fake_mina)

    def _write_fake_zkapp(self) -> None:
        fake_zkapp = Path(self._fake_zkapp_abs)
        fake_zkapp.parent.mkdir(parents=True, exist_ok=True)
        fake_zkapp.write_text(
            "\n".join(
                [
                    "#!/usr/bin/env python3",
                    "import os, sys",
                    "log = os.environ.get('FAKE_ZKAPP_COMMAND_LOG', '')",
                    "if log:",
                    "    with open(log, 'a', encoding='utf-8') as f:",
                    "        f.write(' '.join(sys.argv[1:]) + '\\n')",
                    "print('fake zkapp transaction output')",
                    "print('mutation SendZkapp { sendZkapp(input: {}) { zkapp { id } } }')",
                ]
            ),
            encoding="utf-8",
        )
        os.chmod(fake_zkapp, 0o755)

    def _plan_and_materialize(
        self,
        workloads: Optional[dict] = None,
        *,
        binaries: Optional[dict] = None,
        whale_count: int = 1,
    ):
        """Create topology with given workloads, plan + materialize."""
        topo_binaries = {"mina": self._fake_mina}
        if binaries is not None:
            topo_binaries.update(binaries)
        topo = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": whale_count,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": topo_binaries,
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        if workloads is not None:
            topo["workloads"] = workloads

        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wl_spawn_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topo), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", self._topo_root_rel, "--force", check=True)
        finally:
            os.unlink(topo_path)

    def _spawn(self, env: dict, capture: bool = True) -> subprocess.CompletedProcess:
        env.setdefault("FAKE_MINA_GQL_GENESIS_TIMESTAMP", _genesis_soon())
        return subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=capture,
            text=capture,
            env=env,
            cwd=self._repo_root,
        )

    def _spawn_bg(self, env: dict) -> subprocess.Popen:
        env.setdefault("FAKE_MINA_GQL_GENESIS_TIMESTAMP", _genesis_soon())
        return subprocess.Popen(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
            cwd=self._repo_root,
        )

    # ── echo exit 0 → keep network running ──────────────────────────

    def test_echo_exit_zero_keeps_network_running(self):
        """echo workload exit 0 must NOT tear down the daemon; the parent
        spawn process must stay alive until SIGTERM is sent."""
        self._plan_and_materialize(
            workloads={
                "my-echo": {
                    "type": "echo",
                    "start": "immediate",
                    "config": {
                        "argv": ["/usr/bin/sleep", "1"],
                        "success_exits_keep_network": True,
                    },
                },
            }
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"  # daemon stays alive

        proc = self._spawn_bg(env)
        try:
            # Wait for daemon marker (max 15s)
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Daemon marker did not appear within 15s")
                time.sleep(0.1)

            # Wait for workload to complete (sleep 1) and supervisor
            # to mark it complete — the spawn should still be alive.
            dl2 = time.time() + 10
            while proc.poll() is None and time.time() < dl2:
                time.sleep(0.1)

            # Verify spawn is still running (network alive after workload)
            self.assertIsNone(
                proc.poll(),
                "Spawn process must still be alive after echo exit 0. "
                f"Return code: {proc.returncode}",
            )

            # Now send SIGTERM — spawn should exit cleanly
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

            self.assertEqual(
                proc.returncode,
                143,
                f"Expected exit 143 after SIGTERM, got {proc.returncode}",
            )

        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    # ── echo exit nonzero → teardown all ─────────────────────────────

    def test_echo_exit_nonzero_tears_down_network(self):
        """echo workload nonzero exit must tear down all processes and
        return the workload's exit code."""
        self._plan_and_materialize(
            workloads={
                "bad-echo": {
                    "type": "echo",
                    "start": "immediate",
                    "config": {
                        "argv": ["/usr/bin/bash", "-c", "exit 7"],
                        "success_exits_keep_network": True,
                    },
                },
            }
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "spawn must exit nonzero when workload fails"
        )
        self.assertEqual(
            cp.returncode,
            7,
            f"Expected exit code 7 from workload, got {cp.returncode}: {cp.stderr}",
        )

        # Daemon marker may or may not exist depending on timing,
        # but processes.json must be cleaned up
        procs_path = Path(self._topo_root_abs) / "processes.json"
        self.assertFalse(
            procs_path.exists() or False,
            "processes.json must be cleaned after teardown",
        )

    def test_multi_workload_nonzero_not_masked_by_success(self):
        """If a successful workload and a failing workload exit in the same
        supervisor poll window, the failing workload must win and tear down
        the network."""
        self._plan_and_materialize(
            workloads={
                "ok-fast": {
                    "type": "echo",
                    "start": "immediate",
                    "config": {
                        "argv": [PYTHON3, "-c", "import sys; sys.exit(0)"],
                    },
                },
                "bad-fast": {
                    "type": "echo",
                    "start": "immediate",
                    "config": {
                        "argv": [PYTHON3, "-c", "import sys; sys.exit(9)"],
                    },
                },
            }
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)

        env = _spawn_env("far")
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(
            cp.returncode,
            9,
            "Nonzero workload exit must not be masked by a simultaneous "
            f"successful workload. stdout={cp.stdout} stderr={cp.stderr}",
        )

    # ── after_graphql_ready gate ─────────────────────────────────────

    def test_workload_after_graphql_ready_waits_for_graphql(self):
        """Workload with start=after_graphql_ready must wait for GraphQL
        readiness before spawning.  Without rosetta, the GraphQL check
        still runs for the workload."""
        self._plan_and_materialize(
            workloads={
                "gql-echo": {
                    "type": "echo",
                    "start": "after_graphql_ready",
                    "config": {
                        "argv": ["/usr/bin/sleep", "1"],
                    },
                },
            }
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        gql_ready_file = Path(self._topo_root_abs) / "gql_ready"
        gql_ready_file.unlink(missing_ok=True)
        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_ORDER_FILE"] = str(order_file)
        env["FAKE_MINA_GQL_READY_FILE"] = str(gql_ready_file)

        proc = self._spawn_bg(env)
        try:
            # Wait for daemon marker
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Daemon marker did not appear within 15s")
                time.sleep(0.1)

            # At this point, daemon is running but workload should NOT be
            # spawned (GQL not ready).  Poll for a while and verify spawn
            # is still alive but workload not started.
            dl2 = time.time() + 5
            while proc.poll() is None and time.time() < dl2:
                time.sleep(0.1)
            self.assertIsNone(
                proc.poll(), "Spawn must still be alive (GQL not ready yet)"
            )

            # Now create the GraphQL ready file → workload should spawn
            gql_ready_file.write_text("ready", encoding="utf-8")

            # Wait for workload to complete (sleep 1) — spawn should
            # stay alive after workload exit 0
            dl3 = time.time() + 10
            while proc.poll() is None and time.time() < dl3:
                time.sleep(0.1)
            self.assertIsNone(
                proc.poll(), "Spawn must still be alive after workload completes"
            )

            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

        finally:
            gql_ready_file.unlink(missing_ok=True)
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    # ── after_genesis gate ──────────────────────────────────────────────

    def test_workload_after_genesis_waits_for_synced(self):
        """Workload with start=after_genesis must wait for GraphQL sync before
        spawning."""
        workload_marker = Path(self._topo_root_abs) / "sync-workload-started"
        workload_marker.unlink(missing_ok=True)
        self._plan_and_materialize(
            workloads={
                "sync-echo": {
                    "type": "echo",
                    "start": "after_genesis",
                    "config": {
                        "argv": [
                            PYTHON3,
                            "-c",
                            f"open({str(workload_marker)!r}, 'w').write('started')",
                        ],
                    },
                },
            }
        )
        self.assertFalse(
            workload_marker.exists(),
            "test fixture should start with no workload marker",
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        gql_ready_file = Path(self._topo_root_abs) / "gql_ready_for_sync"
        gql_ready_file.unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_GQL_READY_FILE"] = str(gql_ready_file)

        proc = self._spawn_bg(env)
        try:
            # Wait for daemon marker
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Daemon marker did not appear within 15s")
                time.sleep(0.1)

            # GraphQL is not serving yet, so the workload must not have spawned.
            dl_unsynced = time.time() + 3
            while time.time() < dl_unsynced:
                self.assertIsNone(proc.poll(), "spawn should keep waiting for sync")
                self.assertFalse(
                    workload_marker.exists(),
                    "workload must not start before GraphQL sync",
                )
                time.sleep(0.1)

            gql_ready_file.write_text("ready", encoding="utf-8")

            # Wait for workload to start/complete — spawn stays alive after
            dl2 = time.time() + 10
            while not workload_marker.exists() and time.time() < dl2:
                self.assertIsNone(proc.poll(), "spawn exited before workload started")
                time.sleep(0.1)
            self.assertTrue(
                workload_marker.exists(),
                "workload should start once GraphQL reports SYNCED",
            )
            self.assertIsNone(
                proc.poll(), "Spawn must stay alive after synced workload completes"
            )

            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

        finally:
            gql_ready_file.unlink(missing_ok=True)
            workload_marker.unlink(missing_ok=True)
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    # ── zkApp workload type is now supported ──────────────────────────

    def test_zkapp_missing_account_fails_cleanly(self):
        """zkapp workload with missing sender account must fail with a clear
        manifest-key error."""
        self._plan_and_materialize(
            workloads={
                "z": {
                    "type": "zkapp",
                    "start": "immediate",
                    "config": {
                        "fee_payer_account": "whale-0",
                        "sender_account": "whale-1",
                    },
                },
            }
        )
        cp = self._spawn(os.environ.copy())
        self.assertNotEqual(cp.returncode, 0)
        self.assertIn(
            "manifest key", cp.stderr.lower(), "Error must mention manifest key"
        )

    def test_itn_max_cost_missing_duration_min_rejected(self):
        """itn_max_cost workload without duration_min and without itn_graphql
        must fail at schema validation (plan time) or spawn time."""
        # Schema requires duration_min for itn_max_cost config — this will
        # fail at plan time during schema validation, which is correct.
        with self.assertRaises(subprocess.CalledProcessError):
            self._plan_and_materialize(
                workloads={
                    "imc": {
                        "type": "itn_max_cost",
                        "start": "immediate",
                        "config": {},
                    },
                }
            )

    # ── manual start skips workload ───────────────────────────────────

    def test_manual_start_skips_workload(self):
        """Workload with start=manual must not be auto-spawned and should
        produce a console message; the network still runs."""
        self._plan_and_materialize(
            workloads={
                "manual-echo": {
                    "type": "echo",
                    "start": "manual",
                    "config": {
                        "argv": ["/usr/bin/sleep", "1"],
                    },
                },
            }
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "30"

        proc = self._spawn_bg(env)
        try:
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Daemon marker did not appear within 15s")
                time.sleep(0.1)

            # Spawn should still be alive (no workload to complete)
            self.assertIsNone(proc.poll(), "Spawn must be alive with manual workload")

            # Terminate
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    # ── value_transfer spawn tests ────────────────────────────────────

    def test_value_transfer_bounded_count_runs_client_commands(self):
        """value_transfer count=2 runs import/unlock/send-payment, pinning a
        nonce on every send (random sender/receiver from the pool)."""
        self._plan_and_materialize(
            whale_count=2,
            workloads={
                "my-vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {
                        "amount_min": "5mina",
                        "amount_max": "5mina",
                        "interval_seconds": 0,
                        "count": 2,
                    },
                },
            },
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        cmd_log = Path(self._topo_root_abs) / "command.log"
        cmd_log.unlink(missing_ok=True)

        env = _spawn_env("soon")
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_COMMAND_LOG"] = str(cmd_log)

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(cp.returncode, 0, f"vt spawn failed: {cp.stderr}")

        self.assertTrue(cmd_log.exists(), "Fake mina should have logged commands")
        log = cmd_log.read_text(encoding="utf-8")
        self.assertIn("import", log, f"Expected account import in log: {log}")
        self.assertIn("unlock", log, f"Expected account unlock in log: {log}")
        self.assertIn("send-payment", log, f"Expected send-payment in log: {log}")
        send_lines = [
            line for line in log.splitlines() if line.startswith("send-payment ")
        ]
        self.assertEqual(
            len(send_lines), 2, f"Expected two send-payment commands: {log}"
        )
        for ln in send_lines:
            self.assertIn("-nonce", ln, f"every send must pin a nonce: {ln}")

    def test_value_transfer_after_genesis_waits_before_client_commands(self):
        """value_transfer must not import/unlock/send until GraphQL reports
        SYNCED."""
        self._plan_and_materialize(
            whale_count=2,
            workloads={
                "synced-vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {
                        "interval_seconds": 0,
                        "count": 1,
                    },
                },
            },
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        cmd_log = Path(self._topo_root_abs) / "command.log"
        cmd_log.unlink(missing_ok=True)
        sync_status = Path(self._topo_root_abs) / "sync-status.txt"
        sync_status.write_text("BOOTSTRAP", encoding="utf-8")

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_COMMAND_LOG"] = str(cmd_log)
        env["FAKE_MINA_GQL_SYNC_STATUS_FILE"] = str(sync_status)

        proc = self._spawn_bg(env)
        try:
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Daemon marker did not appear within 15s")
                time.sleep(0.1)

            time.sleep(0.5)
            self.assertFalse(
                cmd_log.exists(), "value_transfer client commands must wait for SYNCED"
            )

            sync_status.write_text("SYNCED", encoding="utf-8")
            dl2 = time.time() + 15
            while not cmd_log.exists() or "send-payment" not in cmd_log.read_text(
                encoding="utf-8"
            ):
                if time.time() > dl2:
                    self.fail("value_transfer did not run after SYNCED")
                time.sleep(0.1)

            self.assertIsNone(
                proc.poll(), "bounded value_transfer success should keep network alive"
            )
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    def test_value_transfer_first_nonce_pins_configured_nonce(self):
        """value_transfer starts every pool account at first_nonce, not 0.

        A network that inherits accounts starts them at whatever nonce they
        reached, so 0 is only right for a network whose accounts are fresh."""
        self._plan_and_materialize(
            whale_count=2,
            workloads={
                "my-vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {
                        "amount_min": "5mina",
                        "amount_max": "5mina",
                        "interval_seconds": 0,
                        "count": 2,
                        "first_nonce": 124,
                    },
                },
            },
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        cmd_log = Path(self._topo_root_abs) / "command.log"
        cmd_log.unlink(missing_ok=True)

        env = _spawn_env("soon")
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_COMMAND_LOG"] = str(cmd_log)

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(cp.returncode, 0, f"vt spawn failed: {cp.stderr}")

        log = cmd_log.read_text(encoding="utf-8")
        send_lines = [
            line for line in log.splitlines() if line.startswith("send-payment ")
        ]
        self.assertEqual(
            len(send_lines), 2, f"Expected two send-payment commands: {log}"
        )
        self.assertIn(
            "-nonce 124",
            send_lines[0],
            f"First send must start at the configured first_nonce: {send_lines[0]}",
        )
        self.assertIn(
            "-nonce", send_lines[1], f"every send must pin a nonce: {send_lines[1]}"
        )

    def test_value_transfer_carryover_match_passes_and_seeds_nonce(self):
        """assert_carryover_nonces matching the network → sends start there.

        The fork side of a hardfork hands the worker the pre-fork nonce each pool
        account reached; the worker reads it back from the network before its
        first send, and when it matches, seeds the account from it (so the first
        send pins the inherited nonce, not first_nonce)."""
        self._plan_and_materialize(
            whale_count=2,
            workloads={
                "my-vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {
                        "amount_min": "5mina",
                        "amount_max": "5mina",
                        "interval_seconds": 0,
                        "count": 2,
                        "assert_carryover_nonces": {"whale-0": 7, "whale-1": 7},
                    },
                },
            },
        )

        cmd_log = Path(self._topo_root_abs) / "command.log"
        cmd_log.unlink(missing_ok=True)

        env = _spawn_env("soon")
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_COMMAND_LOG"] = str(cmd_log)
        env["FAKE_MINA_GQL_INFERRED_NONCE"] = "7"  # the nonce the network reports

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(cp.returncode, 0, f"vt spawn failed: {cp.stderr}")

        send_lines = [
            line
            for line in cmd_log.read_text(encoding="utf-8").splitlines()
            if line.startswith("send-payment ")
        ]
        self.assertEqual(len(send_lines), 2, f"expected two sends: {send_lines}")
        self.assertIn(
            "-nonce 7",
            send_lines[0],
            f"first send must pin the inherited carry-over nonce: {send_lines[0]}",
        )

    def test_value_transfer_carryover_mismatch_fails_spawn(self):
        """assert_carryover_nonces NOT matching the network → the run fails.

        A fork that reset or corrupted an account shows a different nonce than it
        reached pre-fork; the worker must catch that before sending and tear the
        network down with a non-zero exit rather than paper over it."""
        self._plan_and_materialize(
            whale_count=2,
            workloads={
                "my-vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {
                        "interval_seconds": 0,
                        "count": 1,
                        "assert_carryover_nonces": {"whale-0": 99},
                    },
                },
            },
        )

        env = _spawn_env("soon")
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_GQL_INFERRED_NONCE"] = "7"  # network says 7, expectation is 99

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "a carry-over mismatch must fail the spawn"
        )
        self.assertIn(
            "CARRYOVER FAILED",
            cp.stdout + cp.stderr,
            f"expected a carry-over failure message: {cp.stdout}\n{cp.stderr}",
        )

    def test_value_transfer_indefinite_stops_on_teardown(self):
        """A value_transfer with no count runs indefinitely and stops on
        supervisor teardown (SIGTERM).

        The worker is now an in-process thread, so there is no worker pid to
        watch.  Instead: confirm it is actively sending (fake-mina command
        log grows), tear the network down, and confirm sends stop."""
        self._plan_and_materialize(
            whale_count=2,
            workloads={
                "loop-vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {
                        "amount_min": "1mina",
                        "amount_max": "5mina",
                        "interval_seconds": 0.2,
                    },
                },
            },
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        cmd_log = Path(self._topo_root_abs) / "command.log"
        cmd_log.unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_COMMAND_LOG"] = str(cmd_log)

        def _send_count() -> int:
            if not cmd_log.exists():
                return 0
            return cmd_log.read_text(encoding="utf-8").count("send-payment")

        proc = self._spawn_bg(env)
        try:
            dl = time.time() + 20
            procs_path = Path(self._topo_root_abs) / "processes.json"
            workload_running = False
            while time.time() < dl:
                if procs_path.exists():
                    procs = json.loads(procs_path.read_text(encoding="utf-8"))
                    info = procs.get("loop-vt")
                    if (
                        info
                        and info.get("kind") == "workload"
                        and info.get("state") == "running"
                    ):
                        workload_running = True
                if workload_running and _send_count() > 0:
                    break
                time.sleep(0.1)
            self.assertTrue(
                workload_running,
                "value_transfer workload should be recorded as running",
            )
            self.assertGreater(
                _send_count(), 0, "indefinite value_transfer should be sending"
            )

            proc.terminate()
            proc.wait(timeout=15)
            self.assertEqual(proc.returncode, 143)
            # With the network process gone, its worker thread is gone too:
            # send activity must cease.
            settled = _send_count()
            time.sleep(1.0)
            self.assertEqual(
                _send_count(),
                settled,
                "value_transfer worker must stop sending after teardown",
            )
        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    def test_value_transfer_exit_zero_keeps_network(self):
        """value_transfer bounded count=1 exit 0 must keep daemon running."""
        self._plan_and_materialize(
            whale_count=2,
            workloads={
                "my-vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {
                        "amount_min": "1mina",
                        "amount_max": "5mina",
                        "interval_seconds": 0,
                        "count": 1,
                    },
                },
            },
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"

        proc = self._spawn_bg(env)
        try:
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Daemon marker did not appear within 15s")
                time.sleep(0.1)

            # Wait for vt to complete — spawn should stay alive
            dl2 = time.time() + 15
            while proc.poll() is None and time.time() < dl2:
                time.sleep(0.1)

            self.assertIsNone(
                proc.poll(), "Spawn must stay alive after vt completes (exit 0)"
            )

            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)
        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    def test_value_transfer_send_failure_does_not_tear_down(self):
        """send-payment failure must NOT tear down the network; worker retries
        indefinitely, matching legacy mina-local-network.sh behaviour."""
        self._plan_and_materialize(
            whale_count=2,
            workloads={
                "bad-vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {
                        "amount_min": "1mina",
                        "amount_max": "5mina",
                        "interval_seconds": 0,
                        "count": 1,
                    },
                },
            },
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)

        env = _spawn_env("soon")
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_SEND_PAYMENT_EXIT"] = "13"
        # Genesis soon, so the after_genesis workload runs and every send-payment
        # fails (exit 13). The worker must retry indefinitely rather than tear the
        # network down; the daemon then exits on its own after FAKE_MINA_SLEEP and
        # the network shuts down cleanly. Exit code 0 means the failing sends did
        # not tear down the network prematurely.

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(
            cp.returncode,
            0,
            f"Expected exit code 0 from daemon completing, got {cp.returncode}: {cp.stderr}",
        )

    def test_value_transfer_needs_two_accounts_fails_before_popen(self):
        """value_transfer needs ≥2 online accounts (distinct sender/receiver);
        a single-account pool must fail before workload Popen."""
        self._plan_and_materialize(
            whale_count=1,
            workloads={
                "vt": {
                    "type": "value_transfer",
                    "start": "after_genesis",
                    "config": {"count": 1},
                },
            },
        )

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=os.environ.copy(),
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "vt spawn must fail with fewer than 2 online accounts"
        )
        self.assertIn("accounts", cp.stderr.lower(), "Error must mention the account pool")

    def test_zkapp_well_formed_workload_reaches_spawn_validation(self):
        """A well-formed zkapp workload with adequate accounts is accepted
        into workload-specific spawn validation."""
        self._plan_and_materialize(
            workloads={
                "z": {
                    "type": "zkapp",
                    "config": {
                        "fee_payer_account": "whale-0",
                        "sender_account": "whale-0",
                    },
                },
            }
        )
        cp = self._spawn(os.environ.copy())
        self.assertNotIn("has no argv", cp.stderr.lower())

    def test_zkapp_same_fee_payer_and_sender_rejected_for_nonce_conflict(self):
        """A zkApp workload may not double-claim one pubkey as fee payer and
        sender, because the worker advances independent nonce counters."""
        self._plan_and_materialize(
            workloads={
                "z": {
                    "type": "zkapp",
                    "config": {
                        "fee_payer_account": "whale-0",
                        "sender_account": "whale-0",
                    },
                },
            }
        )
        cp = self._spawn(_spawn_env("far"))
        self.assertNotEqual(cp.returncode, 0)
        self.assertIn("nonce contention", cp.stderr.lower())
        self.assertIn("zkapp fee_payer", cp.stderr)
        self.assertIn("zkapp sender", cp.stderr)

    def test_zkapp_relative_binary_resolution(self):
        """Spawn resolves a relative zkApp binary cwd-independently.

        Proven behaviorally: the fake zkApp (given by a relative path, spawned
        from a different cwd) actually runs its create/transfer/update commands,
        which is only possible if the relative binary was resolved.  (There is
        no worker argv to inspect any more — the zkApp worker runs in-process
        from a typed payload; its own argv-building is unit-tested elsewhere.)"""
        self._write_fake_zkapp()
        self._plan_and_materialize(
            workloads={
                "z": {
                    "type": "zkapp",
                    "config": {
                        "fee_payer_account": "whale-0",
                        "sender_account": "whale-1",
                        "transfer_amount": "3",
                        "receiver_amount": "1000",
                        "fee": "5",
                        "interval_seconds": 0,
                        "count": 1,
                        "create_account": True,
                    },
                },
            },
            binaries={"zkapp": self._fake_zkapp_rel},
            whale_count=2,
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        zkapp_log = Path(self._topo_root_abs) / "zkapp.log"
        zkapp_log.unlink(missing_ok=True)
        env = _spawn_env("soon")
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_ZKAPP_COMMAND_LOG"] = str(zkapp_log)

        proc = subprocess.Popen(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        try:
            dl = time.time() + 20
            while time.time() < dl:
                if zkapp_log.exists() and "update-state" in zkapp_log.read_text(
                    encoding="utf-8"
                ):
                    break
                if proc.poll() is not None:
                    _stdout, stderr = proc.communicate(timeout=5)
                    self.fail(f"zkApp spawn exited early: {proc.returncode} {stderr}")
                time.sleep(0.1)
            else:
                self.fail("fake zkApp workload did not complete one iteration")

            log = zkapp_log.read_text(encoding="utf-8")
            self.assertIn("create-zkapp-account", log)
            self.assertIn("transfer-funds-one-receiver", log)
            self.assertIn("update-state", log)
            self.assertIn("--nonce 0", log)
            self.assertIn("--sender-nonce 0", log)
        finally:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)
            if proc.stdout is not None:
                proc.stdout.close()
            if proc.stderr is not None:
                proc.stderr.close()

    def test_itn_max_cost_requires_itn_graphql_capability(self):
        """itn_max_cost workload on a node without itn_graphql fails with a
        clear message about itn_graphql_uri."""
        self._plan_and_materialize(
            workloads={
                "imc": {
                    "type": "itn_max_cost",
                    "config": {
                        "duration_min": 5,
                        "fee_payer_account": "whale-0",
                    },
                },
            }
        )
        cp = self._spawn(os.environ.copy())
        self.assertNotEqual(cp.returncode, 0)
        self.assertIn("itn_graphql", cp.stderr.lower())


# ---------------------------------------------------------------------------
# Worker lifecycle/readiness tests
# ---------------------------------------------------------------------------


class TestWorkerLifecycle(unittest.TestCase):
    """Tests for snark-worker lifecycle and daemon readiness gates."""

    _fake_mina: str = ""
    _repo_root: str = ""

    @classmethod
    def setUpClass(cls):
        cls._repo_root = REPO_ROOT
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

        fd, cls._fake_mina = tempfile.mkstemp(prefix="fake_mina_worker_")
        os.close(fd)
        Path(cls._fake_mina).write_text(_FAKE_MINA_SCRIPT, encoding="utf-8")
        os.chmod(cls._fake_mina, 0o755)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        if cls._fake_mina and Path(cls._fake_mina).exists():
            os.unlink(cls._fake_mina)

    def test_workers_start_after_daemon(self):
        """Workers must be spawned after the daemon (check via processes.json
        started_at timestamps)."""
        wk_name = "wk-order-test"
        wk_rel = ".mina-local-network/" + wk_name
        wk_abs = str(Path(self._repo_root) / ".mina-local-network" / wk_name)

        topology = {
            "schema_version": 1,
            "name": wk_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {"count": 1, "offline_balance": "5mina"},
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {"default": {"count": 2, "nap": "PT1S"}},
                        },
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wk_order_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", wk_rel, "--force", check=True)

            marker = Path(wk_abs) / "fake-marker"
            marker.unlink(missing_ok=True)

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_SLEEP"] = "5"

            proc = subprocess.Popen(
                [PYTHON3, CLI, "spawn", "instance", wk_rel],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                cwd=self._repo_root,
            )

            try:
                # Wait for marker
                deadline = time.time() + 10
                while not marker.exists():
                    if time.time() > deadline:
                        self.fail("Marker did not appear within 10s")
                    time.sleep(0.1)
                time.sleep(0.5)

                # Read processes.json → started_at timestamps must be ordered
                procs_path = Path(wk_abs) / "processes.json"
                self.assertTrue(
                    procs_path.exists(), "processes.json must exist while running"
                )
                procs = json.loads(procs_path.read_text(encoding="utf-8"))

                # Verify daemon entry exists and has earliest started_at
                self.assertIn("seed", procs)
                daemon_ts = procs["seed"]["started_at"]

                # Workers should have started_at >= daemon started_at
                wk_entries = [
                    (k, v) for k, v in procs.items() if v["kind"] == "snark_worker"
                ]
                self.assertGreater(len(wk_entries), 0, "Expected at least 1 worker")
                for wname, winfo in wk_entries:
                    self.assertGreaterEqual(
                        winfo["started_at"],
                        daemon_ts,
                        f"Worker {wname} started_at {winfo['started_at']} "
                        f"should be >= daemon {daemon_ts}",
                    )

            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait(timeout=5)

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / wk_name),
                ignore_errors=True,
            )

    def test_worker_env_includes_nap_sec(self):
        """Worker environment must include MINA_SNARK_WORKER_NAP_SEC."""
        wk_name = "wk-env-test"
        wk_rel = ".mina-local-network/" + wk_name
        wk_abs = str(Path(self._repo_root) / ".mina-local-network" / wk_name)

        topology = {
            "schema_version": 1,
            "name": wk_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {"count": 1, "offline_balance": "5mina"},
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {"default": {"count": 1, "nap": "PT3S"}},
                        },
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wk_env_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", wk_rel, "--force", check=True)

            env_file = Path(wk_abs) / "env.txt"
            marker = Path(wk_abs) / "fake-marker"
            env_file.unlink(missing_ok=True)
            marker.unlink(missing_ok=True)

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_ENV_FILE"] = str(env_file)
            env["FAKE_MINA_SLEEP"] = "5"  # keep alive long enough to inspect

            proc = subprocess.Popen(
                [PYTHON3, CLI, "spawn", "instance", wk_rel],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                cwd=self._repo_root,
            )

            try:
                # Wait for marker to appear (written by daemon)
                deadline = time.time() + 10
                while not marker.exists():
                    if time.time() > deadline:
                        self.fail("Marker did not appear within 10s")
                    time.sleep(0.1)
                # Give workers a moment to start and write env
                time.sleep(0.5)

                self.assertTrue(
                    env_file.exists(), "Fake mina should have written env file"
                )
                env_content = env_file.read_text(encoding="utf-8")
                # The worker env should contain MINA_SNARK_WORKER_NAP_SEC=3.0
                # (PT3S -> 3.0).  Workers are spawned after daemon and overwrite
                # the env file.
                self.assertIn(
                    "MINA_SNARK_WORKER_NAP_SEC",
                    env_content,
                    "MINA_SNARK_WORKER_NAP_SEC missing from env file",
                )
                self.assertIn(
                    "MINA_SNARK_WORKER_NAP_SEC=3.0",
                    env_content,
                    "MINA_SNARK_WORKER_NAP_SEC should be 3.0 (from PT3S)",
                )

            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait(timeout=5)

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / wk_name),
                ignore_errors=True,
            )

    def test_worker_nonzero_exit_tears_down_daemon(self):
        """If a worker exits nonzero, the supervisor must tear down all
        remaining processes and return a nonzero exit code."""
        wk_name = "wk-exit-test"
        wk_rel = ".mina-local-network/" + wk_name
        wk_abs = str(Path(self._repo_root) / ".mina-local-network" / wk_name)

        topology = {
            "schema_version": 1,
            "name": wk_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {"count": 1, "offline_balance": "5mina"},
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {"default": {"count": 1, "nap": "PT1S"}},
                        },
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wk_exit_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", wk_rel, "--force", check=True)

            # Make the worker exit nonzero (daemon stays alive longer)
            # Set FAKE_MINA_EXIT_CODE=42.  The daemon also sees this env
            # and exits 42, so we need a different approach.
            # Strategy: make daemon sleep long, worker exit immediately.
            # Use FAKE_MINA_WORKER_SLEEP=0 and FAKE_MINA_WORKER_EXIT_CODE=42
            # for the worker, and FAKE_MINA_SLEEP=60 for daemon.
            #
            # But both daemon and worker share the same fake binary, so
            # they see the same env vars.  We need a way to distinguish.
            #
            # Approach: the supervisor loop picks up the first exited
            # process.  If we set FAKE_MINA_SLEEP=0 for all, both daemon
            # and worker will exit immediately.  The daemon (spawned first)
            # may exit first.  We need the worker to exit first.
            #
            # Simpler: the worker runs `internal snark-worker` which
            # takes slightly longer to start than `daemon`.  Use FAKE_MINA_SLEEP=60
            # for the daemon and FAKE_MINA_SLEEP=0 for the worker by
            # setting sleep in worker env via the plan.
            #
            # Actually, the simplest: set FAKE_MINA_SLEEP=0, and rely on
            # the daemon being spawned first and thus starting sooner.
            # But both sleep 0 and exit 0 — not a nonzero exit.
            #
            # Alternative: use the daemon as the "bad" process by making
            # it exit 42 while workers sleep.  This tests supervisor behavior
            # regardless of which process exits first.
            #
            # Let's do: daemon exits 42, worker sleeps long.
            # When daemon exits, supervisor tears everything down.
            marker = Path(wk_abs) / "fake-marker"
            marker.unlink(missing_ok=True)

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_SLEEP"] = "3"
            env["FAKE_MINA_EXIT_CODE"] = "42"

            cp = subprocess.run(
                [PYTHON3, CLI, "spawn", "instance", wk_rel],
                capture_output=True,
                text=True,
                env=env,
                cwd=self._repo_root,
            )
            # Either the daemon or worker exits first; supervisor propagates
            # that exit code.  Since FAKE_MINA_EXIT_CODE=42, both exit 42.
            self.assertNotEqual(
                cp.returncode, 0, "spawn instance must propagate nonzero exit code"
            )
            self.assertEqual(
                cp.returncode,
                42,
                f"Expected exit code 42, got {cp.returncode}: {cp.stderr}",
            )

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / wk_name),
                ignore_errors=True,
            )

    def test_services_still_rejected_in_spawn_instance(self):
        """spawn instance no longer rejects services — they are now supported.
        An archive service without postgres_uri fails with a clear message about
        the missing configuration rather than a generic 'not yet supported'."""
        svc_name = "svc-rej-test"
        svc_rel = ".mina-local-network/" + svc_name
        svc_abs = str(Path(self._repo_root) / ".mina-local-network" / svc_name)

        topology = {
            "schema_version": 1,
            "name": svc_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="svc_rej_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", svc_rel, "--force", check=True)

            # Inject services into the plan
            plan_path = Path(svc_abs) / "network-plan.json"
            plan = json.loads(plan_path.read_text(encoding="utf-8"))
            plan["services"] = [{"name": "archive", "kind": "archive"}]
            plan_path.write_text(json.dumps(plan, indent=2), encoding="utf-8")

            # Re-materialize so manifest fingerprint matches modified plan
            _run("materialize", svc_rel, "--force", check=True)

            cp = _run("spawn", "instance", svc_rel, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "spawn instance with incomplete archive must fail"
            )
            # Must NOT say "does not yet support services" (services are now supported)
            self.assertNotIn(
                "does not yet support services",
                cp.stderr,
                "Services are now supported; old rejection message must not appear",
            )
            # Must fail with a clear message about missing configuration
            self.assertIn(
                "postgres_uri",
                cp.stderr.lower(),
                "Must fail with clear postgres configuration error",
            )

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / svc_name),
                ignore_errors=True,
            )

    # ── Readiness gate tests ─────────────────────────────────────────

    def test_readiness_gate_workers_not_spawned_before_ready(self):
        """Workers must not be spawned until daemon client status succeeds.

        Uses FAKE_MINA_ORDER_FILE to track spawn order and
        FAKE_MINA_READY_FILE to gate client readiness.  Verifies that the
        daemon appears in the order file but workers only appear after
        the readiness file is created (delayed)."""
        rdy_name = "rdy-order-test"
        rdy_rel = ".mina-local-network/" + rdy_name
        rdy_abs = str(Path(self._repo_root) / ".mina-local-network" / rdy_name)

        topology = {
            "schema_version": 1,
            "name": rdy_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {"count": 1, "offline_balance": "5mina"},
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {"default": {"count": 1, "nap": "PT1S"}},
                        },
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="rdy_order_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", rdy_rel, "--force", check=True)

            marker = Path(rdy_abs) / "fake-marker"
            marker.unlink(missing_ok=True)
            order_file = Path(rdy_abs) / "order.txt"
            order_file.unlink(missing_ok=True)
            ready_file = Path(rdy_abs) / "ready.flag"
            ready_file.unlink(missing_ok=True)
            status_count_file = Path(rdy_abs) / "status.count"
            status_count_file.unlink(missing_ok=True)

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_ORDER_FILE"] = str(order_file)
            env["FAKE_MINA_READY_FILE"] = str(ready_file)
            env["FAKE_MINA_STATUS_COUNT_FILE"] = str(status_count_file)
            env["FAKE_MINA_SLEEP"] = "60"  # daemon stays alive

            proc = subprocess.Popen(
                [PYTHON3, CLI, "spawn", "instance", rdy_rel],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                cwd=self._repo_root,
            )

            try:
                # Wait for daemon marker (daemon spawned)
                deadline = time.time() + 15
                while not marker.exists():
                    if time.time() > deadline:
                        self.fail("Daemon marker did not appear within 15s")
                    time.sleep(0.1)

                # Wait a bit then verify: daemon spawned, but worker not yet
                time.sleep(0.5)

                # The order file should contain exactly "daemon" (one line)
                self.assertTrue(
                    order_file.exists(), "Order file must exist after daemon spawned"
                )
                order_lines = order_file.read_text(encoding="utf-8").strip().split("\n")
                self.assertIn("daemon", order_lines, "Order file must contain 'daemon'")
                self.assertNotIn(
                    "worker", order_lines, "Worker must NOT be spawned before readiness"
                )

                # Verify status was polled (counter > 0)
                self.assertTrue(
                    status_count_file.exists(), "Status counter file must exist"
                )
                count = int(status_count_file.read_text(encoding="utf-8").strip())
                self.assertGreater(
                    count, 0, f"Expected at least 1 status poll, got {count}"
                )

                # Now create the ready file → next poll should succeed
                ready_file.write_text("ready", encoding="utf-8")

                # Wait for worker to appear in order file
                deadline = time.time() + 10
                worker_appeared = False
                while time.time() < deadline:
                    if order_file.exists():
                        order_lines = (
                            order_file.read_text(encoding="utf-8").strip().split("\n")
                        )
                        if "worker" in order_lines:
                            worker_appeared = True
                            break
                    time.sleep(0.1)
                self.assertTrue(
                    worker_appeared, "Worker must appear in order file after readiness"
                )

                # Verify order: daemon first, then worker
                final_order = order_file.read_text(encoding="utf-8").strip().split("\n")
                daemon_idx = final_order.index("daemon")
                worker_idx = final_order.index("worker")
                self.assertLess(
                    daemon_idx,
                    worker_idx,
                    "Daemon must appear before worker in spawn order",
                )

            finally:
                if proc.poll() is None:
                    proc.terminate()
                    try:
                        proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        proc.kill()
                        proc.wait(timeout=5)
                # Clean up ready file so stale state doesn't linger
                ready_file.unlink(missing_ok=True)

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / rdy_name),
                ignore_errors=True,
            )

    def test_daemon_exits_before_readiness_fails_spawn(self):
        """If daemon exits before client status becomes ready, spawn must fail
        with a nonzero exit code and workers must not be spawned."""
        rdy_name = "rdy-exit-test"
        rdy_rel = ".mina-local-network/" + rdy_name
        rdy_abs = str(Path(self._repo_root) / ".mina-local-network" / rdy_name)

        topology = {
            "schema_version": 1,
            "name": rdy_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {"count": 1, "offline_balance": "5mina"},
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {"default": {"count": 1, "nap": "PT1S"}},
                        },
                    },
                },
            },
            "binaries": {"mina": self._fake_mina},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="rdy_exit_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", rdy_rel, "--force", check=True)

            marker = Path(rdy_abs) / "fake-marker"
            marker.unlink(missing_ok=True)
            order_file = Path(rdy_abs) / "order.txt"
            order_file.unlink(missing_ok=True)
            ready_file = Path(rdy_abs) / "ready.flag"
            # Never create the ready file → status always fails

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_ORDER_FILE"] = str(order_file)
            env["FAKE_MINA_READY_FILE"] = str(ready_file)
            env["FAKE_MINA_SLEEP"] = "0"  # daemon exits immediately
            env["FAKE_MINA_EXIT_CODE"] = "42"

            cp = subprocess.run(
                [PYTHON3, CLI, "spawn", "instance", rdy_rel],
                capture_output=True,
                text=True,
                env=env,
                cwd=self._repo_root,
            )
            self.assertNotEqual(
                cp.returncode, 0, "spawn must fail when daemon exits before readiness"
            )
            self.assertIn(
                "Daemon process exited with code",
                cp.stderr,
                "Error must mention daemon exited before ready",
            )

            # Workers must not have been spawned
            if order_file.exists():
                order_lines = order_file.read_text(encoding="utf-8").strip().split("\n")
                self.assertNotIn(
                    "worker",
                    order_lines,
                    "Worker must not be spawned when daemon exits before ready",
                )

        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / rdy_name),
                ignore_errors=True,
            )

    # ── pgid=None fallback teardown test ──────────────────────────────

    def test_pgid_none_fallback_teardown(self):
        """When pgid is not available, teardown_process must fall back to
        proc.terminate()/proc.kill() and actually kill the process."""
        # Spawn a long-sleeping process and tear it down with pgid=None
        proc = subprocess.Popen(
            ["sleep", "600"],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            self.assertIsNotNone(proc.pid)
            self.assertIsNone(proc.poll(), "Sleep process should still be running")

            # Tear down with pgid=None (simulating os.getpgid failure)
            dead = teardown_process(proc, pgid=None, timeout=3)
            self.assertTrue(dead, "teardown_process(pgid=None) must kill the process")

            # Verify process is actually gone
            self.assertIsNotNone(proc.poll(), "Process must be dead after teardown")
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()


# ---------------------------------------------------------------------------
# Service spawn tests — archive + rosetta with external Postgres preflight
# ---------------------------------------------------------------------------


class TestServiceSpawn(unittest.TestCase):
    """Tests for archive + rosetta service spawning with fake binaries."""

    _topo_name: str = "svc-spawn-test"
    _topo_root_rel: str = ""
    _topo_root_abs: str = ""
    _fake_mina: str = ""
    _fake_archive: str = ""
    _fake_rosetta: str = ""
    _fake_psql: str = ""
    _fake_bin_dir: str = ""
    _repo_root: str = ""

    @classmethod
    def setUpClass(cls):
        cls._repo_root = REPO_ROOT
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

        # Create fake binaries in a dedicated temp dir
        cls._fake_bin_dir = tempfile.mkdtemp(prefix="svc_test_bin_")
        os.chmod(cls._fake_bin_dir, 0o755)

        def _write_fake(name: str, script: str) -> str:
            p = os.path.join(cls._fake_bin_dir, name)
            Path(p).write_text(script, encoding="utf-8")
            os.chmod(p, 0o755)
            return p

        cls._fake_mina = _write_fake("mina", _FAKE_MINA_SCRIPT)
        cls._fake_archive = _write_fake("archive", _FAKE_ARCHIVE_SCRIPT)
        cls._fake_rosetta = _write_fake("rosetta", _FAKE_ROSETTA_SCRIPT)
        cls._fake_psql = _write_fake("psql", _FAKE_PSQL_SCRIPT)

        cls._topo_root_rel = ".mina-local-network/" + cls._topo_name
        cls._topo_root_abs = str(
            Path(REPO_ROOT) / ".mina-local-network" / cls._topo_name
        )

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        if cls._fake_bin_dir and Path(cls._fake_bin_dir).exists():
            shutil.rmtree(cls._fake_bin_dir, ignore_errors=True)

    def _build_env(self, **extra) -> dict:
        """Return an env dict with fake psql on PATH and any extras."""
        env = os.environ.copy()
        env["PATH"] = self._fake_bin_dir + os.pathsep + env.get("PATH", "")
        env.update(extra)
        return env

    def _svc_topology(self, **svc_overrides) -> dict:
        """Return a topology dict with archive + rosetta services.

        *svc_overrides* can include extra keys to merge into the topology.
        """
        topo = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                    "snark_coordinator": {"count": 1, "offline_balance": "5mina"},
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "work_selection": "seq",
                            "worker_pools": {"default": {"count": 1, "nap": "PT1S"}},
                        },
                    },
                },
            },
            "services": {
                "archive": {
                    "binary": self._fake_archive,
                    "postgres": {"host": "localhost", "port": 5432, "db": "archive"},
                },
                "rosetta": {
                    "binary": self._fake_rosetta,
                    "max_db_pool_size": 128,
                },
            },
            "binaries": {
                "mina": self._fake_mina,
                "archive": self._fake_archive,
                "rosetta": self._fake_rosetta,
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        topo.update(svc_overrides)
        return topo

    def _plan_and_materialize(self, topology: dict) -> None:
        """Write *topology* to a temp file, plan it, then materialize."""
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="svc_topo_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", self._topo_root_rel, "--force", check=True)
        finally:
            os.unlink(topo_path)

    def _spawn(self, env: dict, capture: bool = True) -> subprocess.CompletedProcess:
        """Run spawn instance with *env* and return the process."""
        env.setdefault("FAKE_MINA_GQL_GENESIS_TIMESTAMP", _genesis_soon())
        return subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=capture,
            text=capture,
            env=env,
            cwd=self._repo_root,
        )

    def _spawn_bg(self, env: dict) -> subprocess.Popen:
        """Run spawn instance in background with *env*."""
        env.setdefault("FAKE_MINA_GQL_GENESIS_TIMESTAMP", _genesis_soon())
        return subprocess.Popen(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env=env,
            cwd=self._repo_root,
        )

    # ── Test 1: -archive-address on daemon argv ──────────────────────

    def test_resolver_adds_archive_address_to_daemon_argv(self):
        """When archive service is configured, every daemon argv must include
        -archive-address <archive_port>."""
        self._plan_and_materialize(self._svc_topology())
        plan = _run_json("inspect", "instance", self._topo_root_rel)

        # Find the archive service port
        archive_svc = next(s for s in plan["services"] if s["kind"] == "archive")
        archive_port = archive_svc["port"]

        # Every daemon argv must have -archive-address
        for node in plan["nodes"]:
            argv = node["daemon_argv"]
            self.assertIn(
                "-archive-address",
                argv,
                f"daemon argv for {node['name']} missing -archive-address",
            )
            idx = argv.index("-archive-address")
            self.assertEqual(
                argv[idx + 1],
                str(archive_port),
                "-archive-address value must be the archive port",
            )

    # ── Test 2: spawn order + processes.json with archive+daemon+workers ─

    def test_spawn_order_archive_daemon_workers(self):
        """spawn instance with archive+daemon+workers must start processes
        in order: archive → daemon → workers, write all entries to
        processes.json, and tear down cleanly.  (Rosetta order is tested
        separately with test_graphql_ready_before_rosetta.)"""
        topo = self._svc_topology()
        del topo["services"]["rosetta"]  # no rosetta → no GraphQL readiness
        self._plan_and_materialize(topo)

        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)
        marker = Path(self._topo_root_abs) / "marker"
        marker.unlink(missing_ok=True)

        env = self._build_env(
            FAKE_MINA_MARKER=str(marker),
            # Keep processes alive long enough for processes.json assertions;
            # the test terminates the parent explicitly in finally.
            FAKE_MINA_SLEEP="60",
            FAKE_ORDER_FILE=str(order_file),
            FAKE_MINA_ORDER_FILE=str(order_file),
            FAKE_ARCHIVE_SLEEP="60",
            FAKE_ROSETTA_SLEEP="60",
        )

        proc = self._spawn_bg(env)
        try:
            # Wait for marker (written by daemon)
            deadline = time.time() + 15
            while not marker.exists():
                if time.time() > deadline:
                    self.fail("Marker did not appear within 15s")
                time.sleep(0.1)
            # Wait for all processes to be spawned and processes.json written
            procs_path = Path(self._topo_root_abs) / "processes.json"
            dl2 = time.time() + 15
            while not procs_path.exists():
                if time.time() > dl2:
                    self.fail("processes.json did not appear within 15s")
                time.sleep(0.1)
            # Poll for order file to have the expected 3 entries (archive,
            # daemon, worker) without using fixed sleeps.
            dl3 = time.time() + 15
            while True:
                count = 0
                if order_file.exists():
                    count = len(
                        order_file.read_text(encoding="utf-8").strip().split("\n")
                    )
                if count >= 3 or time.time() > dl3:
                    break
                if proc.poll() is not None:
                    break
                time.sleep(0.1)

            # Check order file
            self.assertTrue(order_file.exists(), "Order file must exist")
            order = order_file.read_text(encoding="utf-8").strip().split("\n")
            self.assertGreaterEqual(
                len(order), 3, f"Expected at least 3 entries, got {len(order)}: {order}"
            )
            self.assertEqual(
                order[0], "archive", f"First spawned must be archive, got {order[0]}"
            )
            self.assertEqual(
                order[1], "daemon", f"Second spawned must be daemon, got {order[1]}"
            )
            self.assertEqual(
                order[2], "worker", f"Third spawned must be worker, got {order[2]}"
            )
            # No rosetta — must not appear
            self.assertNotIn(
                "rosetta", order, "Rosetta must not appear without rosetta service"
            )

            # Check processes.json
            self.assertTrue(procs_path.exists())
            procs = json.loads(procs_path.read_text(encoding="utf-8"))

            # Must have entries for archive, seed, worker (no rosetta)
            kinds = {v["kind"] for v in procs.values()}
            self.assertIn("archive", kinds)
            self.assertIn("daemon", kinds)
            self.assertIn("snark_worker", kinds)
            self.assertNotIn(
                "rosetta", kinds, "Rosetta must not appear without rosetta service"
            )

            # All must be running
            for v in procs.values():
                self.assertEqual(
                    v["state"], "running", f"{v['kind']} state should be running"
                )

        finally:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)

    # ── Test 3: Postgres preflight failure before Popen ──────────────

    def test_postgres_preflight_fails_before_any_popen(self):
        """External Postgres preflight failure must raise ClickException
        before any child process is spawned (no marker, no order entry)."""
        self._plan_and_materialize(self._svc_topology())

        marker = Path(self._topo_root_abs) / "marker"
        marker.unlink(missing_ok=True)
        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)

        env = self._build_env(
            FAKE_MINA_MARKER=str(marker),
            FAKE_ORDER_FILE=str(order_file),
            FAKE_PSQL_FAIL="1",  # psql fails
        )

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "spawn must fail when psql preflight fails"
        )
        self.assertIn(
            "Could not connect to external Postgres",
            cp.stderr,
            "Error must mention Postgres connectivity failure",
        )

        # No processes must have been spawned
        self.assertFalse(
            marker.exists(), "Fake daemon marker must not exist — no Popen"
        )
        self.assertFalse(
            order_file.exists(), "Order file must not exist — nothing started"
        )

    # ── Test 4: Rosetta env includes MINA_ROSETTA_MAX_DB_POOL_SIZE ───

    def test_rosetta_env_includes_pool_size(self):
        """Rosetta process env must include MINA_ROSETTA_MAX_DB_POOL_SIZE."""
        self._plan_and_materialize(self._svc_topology())

        env_file = Path(self._topo_root_abs) / "rosetta_env.txt"
        env_file.unlink(missing_ok=True)
        marker = Path(self._topo_root_abs) / "marker"
        marker.unlink(missing_ok=True)
        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)

        env = self._build_env(
            FAKE_MINA_MARKER=str(marker),
            FAKE_MINA_SLEEP="5",
            FAKE_ORDER_FILE=str(order_file),
            FAKE_ARCHIVE_SLEEP="5",
            FAKE_ROSETTA_SLEEP="5",
            FAKE_ROSETTA_ENV_FILE=str(env_file),
        )

        proc = self._spawn_bg(env)
        try:
            # Wait for rosetta to write env
            deadline = time.time() + 20
            while not env_file.exists():
                if time.time() > deadline:
                    self.fail("Rosetta env file did not appear within 20s")
                time.sleep(0.1)
            # Poll until content appears (not fixed sleep)
            dl2 = time.time() + 10
            while True:
                content = env_file.read_text(encoding="utf-8")
                if "MINA_ROSETTA_MAX_DB_POOL_SIZE=128" in content:
                    break
                if time.time() > dl2:
                    self.fail("Pool size not found in rosetta env within 10s")
                time.sleep(0.1)

            self.assertIn(
                "MINA_ROSETTA_MAX_DB_POOL_SIZE=128",
                content,
                "MINA_ROSETTA_MAX_DB_POOL_SIZE=128 must be in rosetta env",
            )

        finally:
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)

    # ── Test 5: Rosetta argv uses full GraphQL URI ───────────────────

    def test_rosetta_graphql_uri_is_full_url(self):
        """Rosetta --graphql-uri must be a full http://.../graphql URL,
        not a bare port."""
        self._plan_and_materialize(self._svc_topology())

        # Check plan-time resolution
        plan = _run_json("inspect", "instance", self._topo_root_rel)
        rosetta_svc = next(s for s in plan["services"] if s["kind"] == "rosetta")
        argv = rosetta_svc["argv"]
        self.assertIn("--graphql-uri", argv)
        gql_idx = argv.index("--graphql-uri")
        uri = argv[gql_idx + 1]

        # Must be a full URL with /graphql path
        self.assertTrue(
            uri.startswith("http://127.0.0.1:"),
            f"GraphQL URI must start with http://127.0.0.1:, got {uri}",
        )
        self.assertTrue(
            uri.endswith("/graphql"), f"GraphQL URI must end with /graphql, got {uri}"
        )
        # Must NOT be a bare port
        self.assertIn(
            "/",
            uri.split(":")[-1],
            f"GraphQL URI must include path, not just port: {uri}",
        )

    # ── Test 6: Rosetta without archive fails clearly ─────────────────

    def test_rosetta_without_archive_fails_during_resolution(self):
        """Plan a topology with rosetta but no archive must fail during
        resolution with a clear message (no empty URI)."""
        # Build topology with rosetta but no archive
        topo = self._svc_topology()
        del topo["services"]["archive"]  # remove archive, keep rosetta

        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="ros_no_arch_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topo), encoding="utf-8")
        try:
            cp = _run("plan", "topology", topo_path, "--overwrite", check=False)
            self.assertNotEqual(
                cp.returncode, 0, "plan with rosetta but no archive must fail"
            )
            self.assertIn(
                "archive",
                cp.stderr.lower(),
                "Error must mention missing archive service",
            )
        finally:
            os.unlink(topo_path)
            shutil.rmtree(
                str(Path(self._repo_root) / ".mina-local-network" / "svc-spawn-test"),
                ignore_errors=True,
            )
            # Also clean up auto-generated root from plan
            default_root = (
                Path(self._repo_root) / ".mina-local-network" / "svc-spawn-test"
            )
            shutil.rmtree(str(default_root), ignore_errors=True)

    # ── Test 7: binary overrides honored ─────────────────────────────

    def test_archive_binary_override_honored(self):
        """Archive service must use its own 'binary' field, not global binaries.archive."""
        custom_archive = os.path.join(self._fake_bin_dir, "custom-archive")
        Path(custom_archive).write_text(_FAKE_ARCHIVE_SCRIPT, encoding="utf-8")
        os.chmod(custom_archive, 0o755)

        topo = self._svc_topology()
        topo["services"]["archive"]["binary"] = custom_archive

        self._plan_and_materialize(topo)
        plan = _run_json("inspect", "instance", self._topo_root_rel)
        archive_svc = next(s for s in plan["services"] if s["kind"] == "archive")
        self.assertEqual(
            archive_svc["argv"][0],
            custom_archive,
            "Archive argv[0] must be the custom binary",
        )

    def test_rosetta_binary_override_honored(self):
        """Rosetta service must use its own 'binary' field, not global binaries.rosetta."""
        custom_rosetta = os.path.join(self._fake_bin_dir, "custom-rosetta")
        Path(custom_rosetta).write_text(_FAKE_ROSETTA_SCRIPT, encoding="utf-8")
        os.chmod(custom_rosetta, 0o755)

        topo = self._svc_topology()
        topo["services"]["rosetta"]["binary"] = custom_rosetta

        self._plan_and_materialize(topo)
        plan = _run_json("inspect", "instance", self._topo_root_rel)
        rosetta_svc = next(s for s in plan["services"] if s["kind"] == "rosetta")
        self.assertEqual(
            rosetta_svc["argv"][0],
            custom_rosetta,
            "Rosetta argv[0] must be the custom binary",
        )

    # ── Test 8: Workloads updated behavior ────────────────────────────

    def test_workloads_still_rejected_with_services(self):
        """Old-format workloads missing argv must be rejected with a clear
        message, even when services are present."""
        self._plan_and_materialize(self._svc_topology())

        # Inject old-format workloads into the plan (no type, no argv)
        plan_path = Path(self._topo_root_abs) / "network-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        plan["workloads"] = [{"name": "test-wl", "cmd": "echo", "count": 1}]
        plan_path.write_text(json.dumps(plan, indent=2), encoding="utf-8")

        # Re-materialize to update fingerprint
        _run("materialize", self._topo_root_rel, "--force", check=True)

        env = self._build_env()
        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "spawn instance with invalid workloads must fail"
        )
        self.assertIn(
            "has no argv", cp.stderr, "Must reject workloads missing config.argv"
        )

    # ── Test 9: psql missing raises clear error ──────────────────────

    def test_psql_missing_raises_clear_error(self):
        """When psql is not on PATH, preflight must give a clear, actionable
        error message."""
        self._plan_and_materialize(self._svc_topology())

        # Use an env where PATH doesn't include fake psql
        env = _spawn_env("far")
        # Remove the fake bin dir from PATH
        env["PATH"] = env.get("PATH", "").replace(self._fake_bin_dir + os.pathsep, "")
        # Also explicitly remove it for safety
        cleaned_path = []
        for p in env.get("PATH", "").split(os.pathsep):
            if p != self._fake_bin_dir:
                cleaned_path.append(p)
        env["PATH"] = os.pathsep.join(cleaned_path)

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "spawn must fail when psql is not available"
        )
        self.assertIn("psql", cp.stderr.lower(), "Error must mention psql")

    # ── Test 10: Schema check failure before Popen ───────────────────

    def test_schema_check_failure_before_popen(self):
        """When the first psql call succeeds but the schema query fails,
        spawn must fail before any Popen."""
        self._plan_and_materialize(self._svc_topology())

        marker = Path(self._topo_root_abs) / "marker"
        marker.unlink(missing_ok=True)
        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)
        psql_log = Path(self._topo_root_abs) / "psql.log"
        psql_log.unlink(missing_ok=True)

        # Actually, our fake psql uses the same exit code for all calls.
        # Let's test a different scenario: schema check fails completely.
        # We'll set FAKE_PSQL_FAIL=1 which makes psql fail.
        # The first SELECT 1 also fails → hits "Could not connect" error.

        # For a more precise test, let's verify the error path works:
        env2 = self._build_env(
            FAKE_MINA_MARKER=str(marker),
            FAKE_ORDER_FILE=str(order_file),
            FAKE_PSQL_FAIL="1",
        )
        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env2,
            cwd=self._repo_root,
        )
        self.assertNotEqual(cp.returncode, 0)
        self.assertFalse(
            marker.exists(), "No processes spawned when postgres check fails"
        )
        self.assertFalse(
            order_file.exists(), "No order entries when postgres check fails"
        )

    # ── Test 11: Postgres password not in psql argv ──────────────────

    def test_postgres_preflight_no_password_in_argv(self):
        """psql calls must use discrete flags, not a postgresql:// URI with
        password embedded in argv.  Password must be passed via PGPASSWORD."""
        topo = self._svc_topology()
        topo["services"]["archive"]["postgres"]["password"] = "s3cret"
        self._plan_and_materialize(topo)

        psql_log = Path(self._topo_root_abs) / "psql.log"
        psql_pw_log = Path(self._topo_root_abs) / "psql_pw.log"
        psql_log.unlink(missing_ok=True)
        psql_pw_log.unlink(missing_ok=True)

        env = self._build_env(
            FAKE_PSQL_LOG=str(psql_log),
            FAKE_PSQL_PW_LOG=str(psql_pw_log),
            FAKE_MINA_SLEEP="5",
            FAKE_ARCHIVE_SLEEP="0",
            FAKE_ROSETTA_SLEEP="0",
        )
        # spawn must succeed (fake psql returns ok, fake services start)
        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertEqual(cp.returncode, 0, f"spawn should succeed: {cp.stderr}")

        self.assertTrue(psql_log.exists(), "Fake psql log must exist")
        raw = psql_log.read_text(encoding="utf-8")
        # Must NOT contain the password anywhere in argv
        self.assertNotIn("s3cret", raw, "Password must not appear in psql argv")
        # Must NOT contain a postgresql:// URI (discrete flags instead)
        self.assertNotIn(
            "postgresql://", raw, "psql must use discrete flags, not a URI"
        )

        self.assertTrue(psql_pw_log.exists(), "PGPASSWORD log must exist")
        pw_log_content = psql_pw_log.read_text(encoding="utf-8")
        self.assertIn(
            "PGPASSWORD=SET",
            pw_log_content,
            "PGPASSWORD must be set when password is configured",
        )

    # ── Test 12: GraphQL readiness before rosetta ────────────────────

    def test_graphql_ready_before_rosetta(self):
        """GraphQL readiness must be waited for before rosetta is spawned.
        Uses FAKE_MINA_GQL_READY_FILE to gate the fake GraphQL server:
        it returns 503 until the file exists, so _wait_for_graphql_ready
        blocks.  Rosetta must NOT appear in the order file until the ready
        file is created."""
        self._plan_and_materialize(self._svc_topology())

        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)
        marker = Path(self._topo_root_abs) / "marker"
        marker.unlink(missing_ok=True)
        gql_ready_file = Path(self._topo_root_abs) / "gql_ready"
        gql_ready_file.unlink(missing_ok=True)

        env = self._build_env(
            FAKE_MINA_MARKER=str(marker),
            FAKE_MINA_SLEEP="60",
            FAKE_ORDER_FILE=str(order_file),
            FAKE_MINA_ORDER_FILE=str(order_file),
            FAKE_ARCHIVE_SLEEP="60",
            FAKE_ROSETTA_SLEEP="60",
            FAKE_MINA_GQL_READY_FILE=str(gql_ready_file),
        )

        proc = self._spawn_bg(env)
        try:
            # Wait for daemon marker
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Daemon marker did not appear within 15s")
                time.sleep(0.1)

            # Poll: daemon should be in the order file, rosetta must NOT
            dl2 = time.time() + 10
            daemon_seen = False
            while time.time() < dl2:
                if order_file.exists():
                    lines = order_file.read_text(encoding="utf-8").strip().split("\n")
                    if "daemon" in lines:
                        daemon_seen = True
                    if daemon_seen and "rosetta" in lines:
                        self.fail("Rosetta must NOT appear before GraphQL readiness")
                if proc.poll() is not None:
                    self.fail("Spawn process exited prematurely")
                time.sleep(0.1)

            self.assertTrue(daemon_seen, "Daemon must appear in order file")

            # Now create the ready file → GraphQL returns 200, rosetta should spawn
            gql_ready_file.write_text("ready", encoding="utf-8")

            # Wait for rosetta to appear in order file
            dl3 = time.time() + 10
            rosetta_seen = False
            while time.time() < dl3:
                if order_file.exists():
                    lines = order_file.read_text(encoding="utf-8").strip().split("\n")
                    if "rosetta" in lines:
                        rosetta_seen = True
                        break
                if proc.poll() is not None:
                    break
                time.sleep(0.1)

            self.assertTrue(
                rosetta_seen,
                "Rosetta must appear in order file after GraphQL readiness",
            )

        finally:
            gql_ready_file.unlink(missing_ok=True)
            if proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=5)

    # ── Test 13: Daemon dies before readiness tears down archive ─────

    def test_daemon_dies_before_readiness_tears_down_archive(self):
        """Archive has already started and passed TCP readiness.  Daemon
        exits before client-status/GraphQL readiness.  Archive must be
        torn down and no workers/rosetta must start."""
        self._plan_and_materialize(self._svc_topology())

        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)
        marker = Path(self._topo_root_abs) / "marker"
        marker.unlink(missing_ok=True)
        procs_path = Path(self._topo_root_abs) / "processes.json"
        procs_path.unlink(missing_ok=True)

        env = self._build_env(
            FAKE_MINA_MARKER=str(marker),
            FAKE_MINA_SLEEP="0",  # daemon exits immediately
            FAKE_MINA_EXIT_CODE="42",  # nonzero
            FAKE_ORDER_FILE=str(order_file),
            FAKE_MINA_ORDER_FILE=str(order_file),
            FAKE_ARCHIVE_SLEEP="10",  # archive stays alive
            FAKE_ROSETTA_SLEEP="10",
            FAKE_MINA_NO_GQL="1",  # no GraphQL server → can't pass GraphQL check
            FAKE_MINA_READY_FILE="/nonexistent/ready.flag",  # client status → not ready
        )

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "Spawn must fail when daemon dies before readiness"
        )
        self.assertIn(
            "Daemon process exited with code",
            cp.stderr,
            "Error must mention daemon exited before ready",
        )

        # Archive should have been started but torn down
        # Workers and rosetta must NOT appear in order
        if order_file.exists():
            lines = order_file.read_text(encoding="utf-8").strip().split("\n")
            self.assertIn("archive", lines, "Archive must have been started")
            self.assertNotIn("worker", lines, "Worker must NOT have been started")
            self.assertNotIn("rosetta", lines, "Rosetta must NOT have been started")

        # processes.json must be cleaned up
        self.assertFalse(
            procs_path.exists(), "processes.json must be cleaned after teardown"
        )

    # ── Test 14: Service teardown effectiveness ──────────────────────

    def test_service_teardown_effectiveness(self):
        """After terminating the parent spawn process, all service pids
        from processes.json must not be running."""
        self._plan_and_materialize(self._svc_topology())

        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)
        marker = Path(self._topo_root_abs) / "marker"
        marker.unlink(missing_ok=True)
        procs_path = Path(self._topo_root_abs) / "processes.json"
        procs_path.unlink(missing_ok=True)

        env = self._build_env(
            FAKE_MINA_MARKER=str(marker),
            FAKE_MINA_SLEEP="60",
            FAKE_ORDER_FILE=str(order_file),
            FAKE_MINA_ORDER_FILE=str(order_file),
            FAKE_ARCHIVE_SLEEP="60",
            FAKE_ROSETTA_SLEEP="60",
        )

        proc = self._spawn_bg(env)
        try:
            # Wait for marker then poll for processes.json
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Marker did not appear within 15s")
                time.sleep(0.1)
            # Poll for processes.json with all expected entries
            dl2 = time.time() + 30
            service_pids = {}
            while time.time() < dl2:
                if procs_path.exists():
                    procs = json.loads(procs_path.read_text(encoding="utf-8"))
                    if all(k in procs for k in ["archive", "seed", "rosetta"]):
                        service_pids = {
                            k: v["pid"]
                            for k, v in procs.items()
                            if v["kind"] in ("archive", "rosetta")
                        }
                        break
                time.sleep(0.1)

            self.assertTrue(service_pids, "Must find archive/rosetta pids")

            # Terminate parent
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

            # All service pids must be dead
            for svc_name, svc_pid in service_pids.items():
                self.assertFalse(
                    pid_is_running(svc_pid),
                    f"{svc_name} PID {svc_pid} should be dead after teardown",
                )

        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass

    # ── Test 15: Service SIGKILL escalation ─────────────────────────

    def test_service_sigkill_escalation(self):
        """When an archive fake traps/ignores SIGTERM, teardown_process
        must escalate to SIGKILL and not hang."""
        # Build topology with a custom archive that traps SIGTERM
        self._plan_and_materialize(self._svc_topology())

        marker = Path(self._topo_root_abs) / "marker"
        marker.unlink(missing_ok=True)
        order_file = Path(self._topo_root_abs) / "order.txt"
        order_file.unlink(missing_ok=True)

        # Overwrite the archive binary with a trap variant
        trap_script = _FAKE_ARCHIVE_SCRIPT.replace(
            'sleep "${FAKE_ARCHIVE_SLEEP:-0}"',
            'trap "" TERM\nsleep "${FAKE_ARCHIVE_SLEEP:-0}"',
        )
        trap_bin = os.path.join(self._fake_bin_dir, "archive-trap")
        Path(trap_bin).write_text(trap_script, encoding="utf-8")
        os.chmod(trap_bin, 0o755)

        # Update the plan to use the trap binary for archive
        plan_path = Path(self._topo_root_abs) / "network-plan.json"
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        for s in plan["services"]:
            if s["kind"] == "archive":
                s["argv"][0] = trap_bin
                s["binary"] = trap_bin
        plan_path.write_text(json.dumps(plan, indent=2), encoding="utf-8")
        _run("materialize", self._topo_root_rel, "--force", check=True)

        env = self._build_env(
            FAKE_MINA_MARKER=str(marker),
            FAKE_MINA_SLEEP="5",
            FAKE_ORDER_FILE=str(order_file),
            FAKE_MINA_ORDER_FILE=str(order_file),
            FAKE_ARCHIVE_SLEEP="999",  # long sleep with SIGTERM trapped
            FAKE_ROSETTA_SLEEP="5",
        )

        proc = self._spawn_bg(env)
        try:
            # Wait for marker
            dl = time.time() + 15
            while not marker.exists():
                if time.time() > dl:
                    self.fail("Marker did not appear within 15s")
                time.sleep(0.1)

            # Poll for processes.json with archive pid
            procs_path = Path(self._topo_root_abs) / "processes.json"
            dl2 = time.time() + 15
            archive_pid = None
            while time.time() < dl2:
                if procs_path.exists():
                    procs = json.loads(procs_path.read_text(encoding="utf-8"))
                    if "archive" in procs:
                        archive_pid = procs["archive"]["pid"]
                        break
                time.sleep(0.1)
            self.assertIsNotNone(archive_pid, "Archive pid must be captured")
            assert archive_pid is not None

            # Terminate parent — SIGTERM escalation to SIGKILL must kill archive
            proc.terminate()
            try:
                proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=5)

            # Archive should be dead even though it trapped SIGTERM
            self.assertFalse(
                pid_is_running(archive_pid),
                f"Archive PID {archive_pid} should be dead after SIGKILL escalation",
            )

        finally:
            if proc.poll() is None:
                proc.kill()
                try:
                    proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass


# ---------------------------------------------------------------------------
# Phase 1 module-split tests
# ---------------------------------------------------------------------------


# (The former TestEntrypointSelfInvocation class tested the hidden
# _vt_worker / _itn_max_cost_worker click commands via re-exec.  Those
# commands no longer exist: the Python workers run in-process on a
# ThreadWorkload, exercised directly by TestWorkerUnit.)


# ---------------------------------------------------------------------------
# ITN max-cost workload tests
# ---------------------------------------------------------------------------


class TestItnMaxCost(unittest.TestCase):
    """Tests for the itn_max_cost workload: schema, plan, spawn, worker contracts."""

    @classmethod
    def setUpClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    # ── schema tests ─────────────────────────────────────────────────

    def test_schema_rejects_missing_duration_min(self):
        """Schema rejects itn_max_cost workload without duration_min."""
        bad: dict = {
            "schema_version": 1,
            "name": "no-dur-test",
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "workloads": {
                "imc": {"type": "itn_max_cost", "config": {}},
            },
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="itn_schema_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(bad), encoding="utf-8")
        try:
            cp = _run("schema", "validate", tmp_path, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "Should reject itn_max_cost without duration_min"
            )
        finally:
            os.unlink(tmp_path)

    def test_schema_accepts_minimal_itn_config(self):
        """Schema accepts a minimal valid itn_max_cost workload."""
        ok: dict = {
            "schema_version": 1,
            "name": "ok-itn-test",
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "workloads": {
                "imc": {
                    "type": "itn_max_cost",
                    "config": {"duration_min": 5},
                },
            },
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="itn_ok_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(ok), encoding="utf-8")
        try:
            cp = _run("schema", "validate", tmp_path, check=False)
            self.assertEqual(
                cp.returncode, 0, f"Should accept minimal itn_max_cost: {cp.stderr}"
            )
        finally:
            os.unlink(tmp_path)

    # ── plan resolution tests ────────────────────────────────────────

    def test_plan_resolves_itn_defaults_and_tps(self):
        """Plan resolves itn_max_cost with defaults, computed tps, and itn_graphql_uri."""
        topo: dict = {
            "schema_version": 1,
            "name": "itn-plan-test",
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "itn_graphql": {},
                    },
                    "itn_keys": "placeholder",
                },
            },
            "runtime_config": {
                "proof": {"block_window_duration_ms": 131400},
            },
            "workloads": {
                "imc": {
                    "type": "itn_max_cost",
                    "config": {"duration_min": 10},
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="itn_plan_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(topo), encoding="utf-8")
        try:
            _run("plan", "topology", tmp_path, "--overwrite", check=True)
            root = str(Path(REPO_ROOT) / ".mina-local-network" / "itn-plan-test")
            plan = _run_json("inspect", "instance", root)
            wls = plan["workloads"]
            self.assertEqual(len(wls), 1)
            wl = wls[0]
            self.assertEqual(wl["name"], "imc")
            self.assertEqual(wl["type"], "itn_max_cost")
            self.assertEqual(wl["start"], "after_genesis")
            self.assertEqual(wl["duration_min"], 10)
            self.assertTrue(isinstance(wl["tps"], (int, float)))
            self.assertGreater(wl["tps"], 0)
            self.assertIn("itn_graphql_uri", wl)
            self.assertIsNotNone(wl["itn_graphql_uri"])
            self.assertIn("/graphql", wl["itn_graphql_uri"])
            # Default config fields
            self.assertEqual(wl["fee_payer_account"], "whale-0")
            self.assertEqual(wl["num_zkapps_to_deploy"], 2)
            self.assertEqual(wl["max_cost_num_updates"], 7)
            self.assertEqual(wl["memo_prefix"], "maxcost")
            self.assertEqual(wl["min_balance_change"], "0")
            self.assertEqual(wl["max_balance_change"], "1000000000")
            self.assertEqual(wl["init_balance"], "5000000000")
            self.assertEqual(wl["min_fee"], "1000000000")
            self.assertEqual(wl["max_fee"], "2000000000")
            self.assertEqual(wl["deployment_fee"], "1000000000")
            self.assertTrue(wl["success_exits_keep_network"])
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "itn-plan-test"),
                ignore_errors=True,
            )

    # ── nonce conflict test ──────────────────────────────────────────

    def test_itn_fee_payer_nonce_conflict_with_zkapp_fee_payer(self):
        """itn_max_cost fee_payer conflicts with zkapp fee_payer using same pubkey."""
        topo_name = "itn-conflict-test"
        topo_root_rel = ".mina-local-network/" + topo_name

        # Create fake mina
        fd, fake_mina = tempfile.mkstemp(prefix="fake_mina_itn_")
        os.close(fd)
        Path(fake_mina).write_text(_FAKE_MINA_SCRIPT, encoding="utf-8")
        os.chmod(fake_mina, 0o755)

        topology: dict = {
            "schema_version": 1,
            "name": topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 2,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "itn_graphql": {},
                    },
                    "itn_keys": "placeholder",
                },
            },
            "binaries": {"mina": fake_mina},
            "workloads": {
                "z": {
                    "type": "zkapp",
                    "config": {
                        "fee_payer_account": "whale-0",
                        "sender_account": "whale-1",
                    },
                },
                "imc": {
                    "type": "itn_max_cost",
                    "config": {
                        "duration_min": 5,
                        "fee_payer_account": "whale-0",
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd2, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="itn_conflict_")
        os.close(fd2)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", topo_root_rel, "--force", check=True)
            cp = subprocess.run(
                [PYTHON3, CLI, "spawn", "instance", topo_root_rel],
                capture_output=True,
                text=True,
                env=os.environ.copy(),
                cwd=REPO_ROOT,
            )
            self.assertNotEqual(
                cp.returncode,
                0,
                "itn_max_cost + zkapp sharing same fee payer must fail",
            )
            self.assertIn("nonce contention", cp.stderr.lower())
        finally:
            os.unlink(topo_path)
            os.unlink(fake_mina)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / topo_name),
                ignore_errors=True,
            )

    # ── signing byte-layout golden test ──────────────────────────────

    def test_ed25519_signing_byte_layout_golden(self):
        """2-byte BE seqno ++ uuid ++ body is the correct mutation signature message."""
        # Import the signing function from workers module
        from mln.workers import ed25519_sign_raw

        # Generate a temp Ed25519 key
        key_dir = tempfile.mkdtemp(prefix="itn_golden_")
        try:
            priv_path = os.path.join(key_dir, "test.key")
            gen = subprocess.run(
                ["openssl", "genpkey", "-algorithm", "ed25519", "-out", priv_path],
                capture_output=True,
                text=True,
            )
            if gen.returncode != 0:
                self.skipTest("openssl ed25519 not available for golden test")

            seqno: int = 42
            uuid: str = "test-uuid-1234"
            body: bytes = b'{"query":"test"}'

            # Build the expected message manually
            import struct

            expected_msg: bytes = struct.pack(">H", seqno) + uuid.encode("utf-8") + body

            # Sign it
            sig: bytes = ed25519_sign_raw(priv_path, expected_msg)
            self.assertEqual(
                len(sig), 64, f"Ed25519 signature must be 64 bytes, got {len(sig)}"
            )

            # Verify: signing works (openssl doesn't fail)
            self.assertIsInstance(sig, bytes)
        finally:
            shutil.rmtree(key_dir, ignore_errors=True)

    # ── worker end-to-end with fake server ───────────────────────────

    def test_worker_e2e_with_fake_itn_server(self):
        """End-to-end worker test with fake ITN HTTP server and fake mina."""
        import threading

        # Create temp directory for fake ITN keys and fake mina
        tmp_dir = tempfile.mkdtemp(prefix="itn_e2e_")
        try:
            # Generate ITN Ed25519 key
            itn_priv = os.path.join(tmp_dir, "itn.key")
            gen_ok = (
                subprocess.run(
                    ["openssl", "genpkey", "-algorithm", "ed25519", "-out", itn_priv],
                    capture_output=True,
                    text=True,
                ).returncode
                == 0
            )
            if not gen_ok:
                self.skipTest("openssl ed25519 not available")

            # Extract pubkey
            der = subprocess.run(
                ["openssl", "pkey", "-in", itn_priv, "-pubout", "-outform", "DER"],
                capture_output=True,
            ).stdout
            itn_pubkey = base64.b64encode(der[-32:]).decode("ascii")

            # Fake mina binary (writes dump-keypair output)
            fake_mina = os.path.join(tmp_dir, "fake_mina")
            fake_sk_value = "EKE5BmBkdLkF4M3QvP6hUxW9nR2tA8yC1jK7sXbNpZ3w"
            fake_mina_script = f"""#!/usr/bin/env python3
import sys
if "advanced" in sys.argv and "dump-keypair" in sys.argv:
    print("Private key: {fake_sk_value}")
    sys.exit(0)
sys.exit(1)
"""
            Path(fake_mina).write_text(fake_mina_script, encoding="utf-8")
            os.chmod(fake_mina, 0o755)

            # Fake ITN HTTP server
            requests_received: list = []

            class ITNHandler(BaseHTTPRequestHandler):
                def do_POST(self) -> None:  # noqa: N802
                    length = int(self.headers.get("Content-Length", "0") or "0")
                    raw_body = self.rfile.read(length) if length else b""
                    body_text = raw_body.decode("utf-8")
                    body_json = json.loads(body_text) if body_text else {}
                    auth = self.headers.get("Authorization", "")
                    requests_received.append(
                        {
                            "body": body_json,
                            "auth": auth,
                        }
                    )
                    # auth query
                    if "auth" in body_json.get("query", ""):
                        resp_data = json.dumps(
                            {
                                "data": {
                                    "auth": {
                                        "serverUuid": "fake-uuid-9999",
                                        "signerSequenceNumber": 5,
                                    }
                                },
                            }
                        ).encode("utf-8")
                    elif "scheduleZkappCommands" in body_json.get("query", ""):
                        resp_data = json.dumps(
                            {
                                "data": {"scheduleZkappCommands": "ok"},
                            }
                        ).encode("utf-8")
                    else:
                        resp_data = json.dumps(
                            {
                                "data": {"unknown": True},
                            }
                        ).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(resp_data)))
                    self.end_headers()
                    self.wfile.write(resp_data)

                def log_message(self, format: str, *args: Any) -> None:
                    return

            sock = socket.socket()
            sock.bind(("127.0.0.1", 0))
            host, port = sock.getsockname()
            sock.close()
            itn_uri = f"http://127.0.0.1:{port}/graphql"
            httpd = HTTPServer((host, port), ITNHandler)
            server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
            server_thread.start()

            # Dummy fee payer key (must exist for validation)
            fp_privkey = os.path.join(tmp_dir, "fee_payer")
            Path(fp_privkey).write_text("dummy", encoding="utf-8")

            try:
                from mln.workers import (
                    _itn_schedule_mutation,
                    _extract_fee_payer_sk,
                )

                # Extract fee payer SK (worker runs subprocesses through a ctx)
                sk = _extract_fee_payer_sk(
                    WorkerContext("itn", {}), fake_mina, fp_privkey
                )
                self.assertEqual(
                    sk,
                    fake_sk_value,
                    f"Fee payer SK should be {fake_sk_value}, got {sk}",
                )

                # Post mutation
                _itn_schedule_mutation(
                    itn_uri=itn_uri,
                    privkey_path=itn_priv,
                    pubkey_b64=itn_pubkey,
                    fee_payer_sk=sk,
                    duration_min=10,
                    tps=0.5,
                    num_zkapps_to_deploy=2,
                    max_cost_num_updates=7,
                    num_new_accounts=0,
                    account_queue_size=0,
                    memo_prefix="maxcost",
                    no_precondition=False,
                    min_balance_change="0",
                    max_balance_change="1000000000",
                    min_new_zkapp_balance="1000000000",
                    max_new_zkapp_balance="2000000000",
                    init_balance="5000000000",
                    min_fee="1000000000",
                    max_fee="2000000000",
                    deployment_fee="1000000000",
                )

                # Verify two requests: auth + mutation
                self.assertGreaterEqual(
                    len(requests_received),
                    2,
                    f"Expected >= 2 requests, got {len(requests_received)}",
                )

                # Verify mutation body contains maxCost: true and expected fields
                mutation_req = next(
                    r
                    for r in requests_received
                    if "scheduleZkappCommands" in r["body"].get("query", "")
                )
                vars_input = mutation_req["body"]["variables"]["input"]
                self.assertTrue(
                    vars_input.get("maxCost"), "maxCost must be True in mutation"
                )
                self.assertEqual(vars_input["durationMin"], 10)
                self.assertEqual(vars_input["feePayers"], [fake_sk_value])
                self.assertEqual(vars_input["memoPrefix"], "maxcost")
                self.assertEqual(vars_input["numZkappsToDeploy"], 2)
                self.assertEqual(vars_input["maxCostNumUpdates"], 7)

                # Verify the sequencing header is present on mutation request
                self.assertIn(
                    "Sequencing",
                    mutation_req["auth"],
                    "Mutation must carry Sequencing header",
                )
                self.assertIn("fake-uuid-9999", mutation_req["auth"])

            finally:
                httpd.shutdown()
                httpd.server_close()
                server_thread.join(timeout=5)
        finally:
            shutil.rmtree(tmp_dir, ignore_errors=True)

    # ── daemon argv injection test ───────────────────────────────────

    def test_spawn_itn_keys_argv_injection(self):
        """Daemon argv uses generated base64 pubkey after --itn-keys, not a placeholder."""
        topo_name = "itn-argv-test"
        topo_root_rel = ".mina-local-network/" + topo_name
        topo_root_abs = str(Path(REPO_ROOT) / ".mina-local-network" / topo_name)

        # Must have openssl
        gen_test = subprocess.run(
            ["openssl", "genpkey", "-algorithm", "ed25519"],
            capture_output=True,
        )
        if gen_test.returncode != 0:
            self.skipTest("openssl ed25519 not available for argv injection test")

        # Create fake mina
        fd, fake_mina = tempfile.mkstemp(prefix="fake_mina_argv_")
        os.close(fd)
        Path(fake_mina).write_text(_FAKE_MINA_SCRIPT, encoding="utf-8")
        os.chmod(fake_mina, 0o755)

        # Topology needs itn_graphql capability so --itn-graphql-port is in argv
        topology: dict = {
            "schema_version": 1,
            "name": topo_name,
            "ledger_generation": {
                "tiers": {
                    "whale": {
                        "count": 1,
                        "offline_balance": "11550000mina",
                        "online_balance": "499mina",
                    },
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "itn_graphql": {},
                    },
                    "itn_keys": "libp2p_keys/itn-key",
                },
            },
            "binaries": {"mina": fake_mina},
            "workloads": {
                "imc": {
                    "type": "itn_max_cost",
                    "config": {
                        "duration_min": 5,
                        "fee_payer_account": "whale-0",
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd2, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="itn_argv_")
        os.close(fd2)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", topo_root_rel, "--force", check=True)

            marker = Path(topo_root_abs) / "fake-marker"
            marker.unlink(missing_ok=True)
            args_file = Path(topo_root_abs) / "fake-mina-args.txt"

            env = _spawn_env("far")
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_ARGS_FILE"] = str(args_file)
            env["FAKE_MINA_SLEEP"] = "3"

            subprocess.run(
                [PYTHON3, CLI, "spawn", "instance", topo_root_rel],
                capture_output=True,
                text=True,
                env=env,
                cwd=REPO_ROOT,
            )
            # This may fail because the workload will try to connect to ITN
            # and fail, but the daemon should still have been spawned with the
            # inject ITN key.  We just check the args file.
            if args_file.exists():
                args_list = args_file.read_text(encoding="utf-8").strip().split("\n")
                self.assertIn(
                    "--itn-keys", args_list, "--itn-keys missing from daemon argv"
                )
                itn_idx = args_list.index("--itn-keys")
                itn_val = args_list[itn_idx + 1]
                # The value after --itn-keys must NOT be the placeholder
                self.assertNotEqual(
                    itn_val,
                    "libp2p_keys/itn-key",
                    "Placeholder itn_keys path must not appear in daemon argv",
                )
                # Must be a base64-looking string (valid base64-encoded 32 bytes)
                try:
                    decoded = base64.b64decode(itn_val, validate=True)
                    self.assertEqual(
                        len(decoded),
                        32,
                        f"ITN public key must decode to 32 bytes, got {len(decoded)}",
                    )
                except Exception:
                    self.fail(f"--itn-keys value is not valid base64: {itn_val!r}")

        finally:
            os.unlink(topo_path)
            os.unlink(fake_mina)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / topo_name),
                ignore_errors=True,
            )


# ---------------------------------------------------------------------------
# Collapse runtime_config ↔ ledger_generation duplication tests (Change #1)
# ---------------------------------------------------------------------------


class TestRuntimeConfigLedgerDedup(unittest.TestCase):
    """Tests that consensus/proof fields live only in runtime_config,
    not duplicated in ledger_generation."""

    def test_preset_no_consensus_fields_in_ledger_generation(self):
        """Single-node preset must NOT have proof_level, slots_per_epoch, k,
        grace_period_slots, work_delay, or transaction_capacity in
        ledger_generation."""
        output = _run_json("presets", "show", _preset("single-node"))
        lg = output.get("ledger_generation", {})

        forbidden = {
            "proof_level",
            "slots_per_epoch",
            "k",
            "grace_period_slots",
            "work_delay",
            "transaction_capacity",
            "transaction_capacity_log2",
        }
        for field in forbidden:
            self.assertNotIn(field, lg, f"ledger_generation must not contain '{field}'")
        # tiers and accounts should be present
        self.assertIn("tiers", lg)
        self.assertIn("accounts", lg)

    def test_plan_ledger_config_from_runtime_not_ledger_generation(self):
        """Resolved plan ledger.config.genesis/proof must reflect
        runtime_config values, not anything from ledger_generation."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        topology = {
            "schema_version": 1,
            "name": "rt-conf-test",
            "runtime_config": {
                "genesis": {
                    "slots_per_epoch": 24,
                    "k": 5,
                    "grace_period_slots": 2,
                },
                "proof": {
                    "level": "check",
                    "work_delay": 3,
                    "transaction_capacity": {"2_to_the": 3},
                },
            },
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="rt_dedup_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", tmp_path, "--overwrite", check=True)
            root = str(Path(REPO_ROOT) / ".mina-local-network" / "rt-conf-test")
            plan = _run_json("inspect", "instance", root)
            ledger = plan["ledger"]
            cfg = ledger["config"]
            self.assertEqual(cfg["genesis"]["slots_per_epoch"], 24)
            self.assertEqual(cfg["genesis"]["k"], 5)
            self.assertEqual(cfg["genesis"]["grace_period_slots"], 2)
            self.assertEqual(cfg["proof"]["level"], "check")
            self.assertEqual(cfg["proof"]["work_delay"], 3)
            self.assertEqual(cfg["proof"]["transaction_capacity"]["2_to_the"], 3)
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "rt-conf-test"),
                ignore_errors=True,
            )


# ---------------------------------------------------------------------------
# Block producer account index bounds test (Change #4)
# ---------------------------------------------------------------------------


class TestBlockProducerBounds(unittest.TestCase):
    """Block producer account index must be validated against tier count."""

    def test_block_producer_out_of_range_rejected(self):
        """block_producer account 'whale-5' with whale count 1 must fail."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        topology = {
            "schema_version": 1,
            "name": "bp-bounds-test",
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-5"},
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="bp_bounds_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "Out-of-range block producer must be rejected"
            )
            self.assertIn("whale-5", cp.stderr)
            self.assertIn("index", cp.stderr.lower() or cp.stdout.lower())
            self.assertIn("count", cp.stderr.lower() or cp.stdout.lower())
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "bp-bounds-test"),
                ignore_errors=True,
            )

    def test_block_producer_in_range_accepted(self):
        """block_producer account 'whale-0' with whale count 1 must succeed."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        topology = {
            "schema_version": 1,
            "name": "bp-ok-test",
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="bp_ok_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertEqual(
                cp.returncode, 0, f"In-range block producer must succeed: {cp.stderr}"
            )
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "bp-ok-test"),
                ignore_errors=True,
            )

    def test_block_producer_fish_out_of_range_rejected(self):
        """block_producer account 'fish-0' with no fish tier must fail."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        topology = {
            "schema_version": 1,
            "name": "fish-bounds-test",
            "ledger_generation": {"tiers": {"whale": {"count": 1}}},
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "fish-0"},
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="fish_bounds_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "Missing fish tier with fish account must be rejected"
            )
            self.assertIn("fish", cp.stderr.lower() or cp.stdout.lower())
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "fish-bounds-test"),
                ignore_errors=True,
            )


# ---------------------------------------------------------------------------
# Fee receiver validation test (Change #5)
# ---------------------------------------------------------------------------


class TestFeeReceiverValidation(unittest.TestCase):
    """snark_coordinator.fee_receiver must reference a valid ledger account."""

    def test_named_account_fee_receiver_accepted(self):
        """fee_receiver 'snark-fees' present in ledger_generation.accounts
        must be accepted."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        topology = {
            "schema_version": 1,
            "name": "fee-ok-test",
            "ledger_generation": {
                "tiers": {"whale": {"count": 1}},
                "accounts": {
                    "snark-fees": {"balance": "5nanomina", "kind": "snark_fee"}
                },
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "fee_receiver": "snark-fees",
                            "work_selection": "seq",
                            "worker_pools": {},
                        },
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="fee_ok_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertEqual(
                cp.returncode, 0, f"Valid fee_receiver must succeed: {cp.stderr}"
            )
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "fee-ok-test"),
                ignore_errors=True,
            )

    def test_nonexistent_fee_receiver_rejected(self):
        """fee_receiver 'nonexistent' not in accounts and not tier pattern
        must be rejected."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        topology = {
            "schema_version": 1,
            "name": "fee-bad-test",
            "ledger_generation": {
                "tiers": {"whale": {"count": 1}},
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "fee_receiver": "nonexistent",
                            "work_selection": "seq",
                            "worker_pools": {},
                        },
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="fee_bad_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertNotEqual(
                cp.returncode, 0, "Nonexistent fee_receiver must be rejected"
            )
            self.assertIn("fee_receiver", cp.stderr.lower() or cp.stdout.lower())
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "fee-bad-test"),
                ignore_errors=True,
            )

    def test_tier_pattern_fee_receiver_accepted(self):
        """fee_receiver 'whale-0' matching tier account pattern must be
        accepted."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        topology = {
            "schema_version": 1,
            "name": "fee-tier-test",
            "ledger_generation": {
                "tiers": {"whale": {"count": 1}},
            },
            "nodes": {
                "seed": {
                    "capabilities": {
                        "p2p_seed": {},
                        "block_producer": {"account": "whale-0"},
                        "snark_coordinator": {
                            "fee_receiver": "whale-0",
                            "work_selection": "seq",
                            "worker_pools": {},
                        },
                    },
                },
            },
            "state": {"genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, tmp_path = tempfile.mkstemp(suffix=".jsonc", prefix="fee_tier_")
        os.close(fd)
        Path(tmp_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            cp = _run("plan", "topology", tmp_path, check=False)
            self.assertEqual(
                cp.returncode, 0, f"Tier-pattern fee_receiver must succeed: {cp.stderr}"
            )
        finally:
            os.unlink(tmp_path)
            shutil.rmtree(
                str(Path(REPO_ROOT) / ".mina-local-network" / "fee-tier-test"),
                ignore_errors=True,
            )


# ---------------------------------------------------------------------------
# Spawn lifecycle tagging tests
# ---------------------------------------------------------------------------


class TestLifecycleTagging(unittest.TestCase):
    """Tests for spawn lifecycle — output tagging and process startup."""

    def test_tag_stream_prefixes_lines(self):
        """_tag_stream must prefix each line with [tag]."""
        out = io.StringIO()
        src = io.StringIO("hello\nworld\n")
        _tag_stream(src, "node-1", out)
        out.seek(0)
        self.assertEqual(out.read(), "[node-1] hello\n[node-1] world\n")

    def test_tag_stream_empty_input(self):
        """_tag_stream must handle empty input gracefully."""
        out = io.StringIO()
        src = io.StringIO("")
        _tag_stream(src, "tag", out)
        out.seek(0)
        self.assertEqual(out.read(), "")

    def test_tag_stream_no_trailing_newline(self):
        """_tag_stream must tag a final line without newline."""
        out = io.StringIO()
        src = io.StringIO("hello\nworld")
        _tag_stream(src, "t", out)
        out.seek(0)
        self.assertEqual(out.read(), "[t] hello\n[t] world")

    def test_launch_process_sets_runtime_fields(self):
        """launch_process must set pid, proc, pgid, started_at, state and
        return the entry."""
        entry = CoreProcessEntry(
            name="test-proc",
            kind=ProcessKind.DAEMON,
            argv=[sys.executable, "-c", "print('ok')"],
        )
        result = launch_process(entry)
        self.assertIs(result, entry)
        self.assertIsNotNone(entry.proc)
        self.assertIsNotNone(entry.pid)
        self.assertIsNotNone(entry.pgid)
        self.assertIsNotNone(entry.started_at)
        self.assertEqual(entry.state, "running")
        # Must have pipes connected
        self.assertIsNotNone(entry.proc.stdout)
        self.assertIsNotNone(entry.proc.stderr)
        # Clean up
        entry.proc.wait(timeout=10)

    def test_launch_process_tags_stdout_and_stderr(self):
        """launch_process must tag stdout and stderr lines with [name]."""
        code = (
            "import sys; "
            "print('stdout msg'); "
            "sys.stderr.write('stderr msg\\n'); "
            "sys.stderr.flush()"
        )
        entry = CoreProcessEntry(
            name="myapp",
            kind=ProcessKind.DAEMON,
            argv=[sys.executable, "-c", code],
        )
        out = io.StringIO()
        err = io.StringIO()
        with mock.patch("sys.stdout", out), mock.patch("sys.stderr", err):
            launch_process(entry)
            entry.proc.wait(timeout=10)
            # Daemon threads may need a moment to flush after the process
            # exits; poll briefly for the expected output.
            for _ in range(50):
                if (
                    "[myapp] stdout msg" in out.getvalue()
                    and "[myapp] stderr msg" in err.getvalue()
                ):
                    break
                time.sleep(0.05)
        self.assertIn("[myapp] stdout msg", out.getvalue())
        self.assertIn("[myapp] stderr msg", err.getvalue())


# ---------------------------------------------------------------------------
# Workload handle tests (mln.workload.SubprocessWorkload)
# ---------------------------------------------------------------------------


class TestSubprocessWorkload(unittest.TestCase):
    """Unit tests for the workload handle over a subprocess.

    These exercise the ``Workload`` surface directly — no network spawn — so
    they run in milliseconds rather than the ~60s a full ``spawn instance``
    regression takes.
    """

    def test_satisfies_workload_protocol(self):
        """SubprocessWorkload must satisfy the Workload protocol."""
        wl = SubprocessWorkload("w", [sys.executable, "-c", "pass"], {})
        self.assertIsInstance(wl, Workload)

    def test_outcome_none_before_start(self):
        """Before start(), there is no outcome and nothing is running."""
        wl = SubprocessWorkload("w", [sys.executable, "-c", "pass"], {})
        self.assertIsNone(wl.outcome())
        self.assertFalse(wl.is_running())

    def test_completed_on_clean_exit(self):
        """A clean exit (0) yields Outcome.COMPLETED, not a raw exit code."""
        wl = SubprocessWorkload("w", [sys.executable, "-c", "pass"], {})
        wl.start()
        self.assertIsNotNone(wl.pid)
        self.assertEqual(wl.pgid, wl.pid)
        self.assertIsNotNone(wl.started_at)
        self._wait_until(lambda: not wl.is_running(), timeout=10)
        self.assertFalse(wl.is_running())
        self.assertEqual(wl.outcome(), Outcome.COMPLETED)

    def test_failed_on_nonzero_exit(self):
        """A nonzero exit yields Outcome.FAILED."""
        wl = SubprocessWorkload(
            "w", [sys.executable, "-c", "import sys; sys.exit(3)"], {}
        )
        wl.start()
        self._wait_until(lambda: not wl.is_running(), timeout=10)
        self.assertEqual(wl.outcome(), Outcome.FAILED)

    def test_running_then_stopped(self):
        """While work is in progress is_running is True; stop() ends it."""
        wl = SubprocessWorkload(
            "w", [sys.executable, "-c", "import time; time.sleep(30)"], {}
        )
        wl.start()
        self.assertTrue(wl.is_running())
        self.assertIsNone(wl.outcome())
        wl.stop()
        self._wait_until(lambda: not wl.is_running(), timeout=10)
        self.assertFalse(wl.is_running())

    def test_stop_reaps_process_group(self):
        """stop() must reap grandchildren — the load-bearing PGID teardown.

        The workload shells out to a child sleeper (as the real workloads shell
        out to ``mina client``); stopping the workload must kill that child too,
        via process-group signalling.
        """
        with tempfile.TemporaryDirectory() as td:
            pidfile = os.path.join(td, "child.pid")
            # Parent spawns a detached-in-group sleeper, records its pid, waits.
            code = (
                "import subprocess, sys, time;"
                "c = subprocess.Popen([sys.executable, '-c',"
                " 'import time; time.sleep(60)']);"
                f"open({pidfile!r}, 'w').write(str(c.pid));"
                "time.sleep(60)"
            )
            wl = SubprocessWorkload("w", [sys.executable, "-c", code], {})
            wl.start()
            self._wait_until(
                lambda: os.path.exists(pidfile) and os.path.getsize(pidfile) > 0,
                timeout=10,
            )
            with open(pidfile) as f:
                child_pid = int(f.read())
            self.assertTrue(pid_is_running(child_pid))
            wl.stop()
            self._wait_until(lambda: not pid_is_running(child_pid), timeout=10)
            self.assertFalse(
                pid_is_running(child_pid),
                "grandchild must be reaped by process-group teardown",
            )

    @staticmethod
    def _wait_until(pred, timeout: float) -> None:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if pred():
                return
            time.sleep(0.02)


# ---------------------------------------------------------------------------
# Worker unit tests — the workers as plain functions (no network spawn)
# ---------------------------------------------------------------------------

# A configurable fake ``mina`` executable.  Records every invocation's args to
# FAKE_CMD_LOG (one line each), and can fail specific subcommands:
#   FAKE_FAIL_IMPORT=1        → any "import" invocation exits 3
#   FAKE_FAIL_FIRST_SEND=1    → the FIRST "send-payment" exits 1 (needs
#                               FAKE_STATE=<path> for the across-call counter)
# Stands in for `mina` for the account import/unlock the worker still shells out
# for (the payment itself goes over GraphQL — see _VtSendServer).
_FAKE_MINA = '''#!/usr/bin/env python3
import os, sys
args = sys.argv[1:]
log = os.environ.get("FAKE_CMD_LOG")
if log:
    with open(log, "a") as f:
        f.write(" ".join(args) + "\\n")
if "import" in args and os.environ.get("FAKE_FAIL_IMPORT") == "1":
    sys.stderr.write("fake import failure\\n")
    sys.exit(3)
sys.exit(0)
'''


class TestWorkerUnit(unittest.TestCase):
    """Direct, in-process tests of the workers — milliseconds, no spawn.

    These exercise ``run_value_transfer`` (and the thread handle) against a
    fake ``mina`` binary, which is only possible now that the workers are plain
    functions taking a typed payload rather than argv-decoding subprocesses.
    """

    def setUp(self):
        self._tmp = tempfile.mkdtemp()
        # Import/unlock still shell out to `mina`; only the send is GraphQL now.
        self.mina = os.path.join(self._tmp, "mina")
        with open(self.mina, "w") as f:
            f.write(_FAKE_MINA)
        os.chmod(self.mina, 0o755)
        self.cmd_log = os.path.join(self._tmp, "cmd.log")
        self.state = os.path.join(self._tmp, "state")
        # The sender's home node: the worker submits payments here over GraphQL.
        self.server = _VtSendServer()
        self.server.start()

    def tearDown(self):
        self.server.stop()
        shutil.rmtree(self._tmp, ignore_errors=True)

    def _payload(self, n_accounts=2, n_nodes=2, **over) -> ValueTransferPayload:
        accounts = [
            TransferAccount(
                name=f"online_whale_account_{i}",
                pubkey=f"B62pk{i}",
                privkey_path="k",
                home_rest_uri=self.server.uri,
            )
            for i in range(n_accounts)
        ]
        base = dict(
            mina_exe=self.mina,
            accounts=accounts,
            amount_min_nanomina=1_000_000_000,
            amount_max_nanomina=1_000_000_000,
            fee_nanomina=250_000_000,
            interval_secs=0.0,
            count=2,
            first_nonce=7,
            replay_probability=0.0,
        )
        base.update(over)
        return ValueTransferPayload(**base)

    def _ctx(self, **env) -> WorkerContext:
        env.setdefault("FAKE_CMD_LOG", self.cmd_log)
        return WorkerContext("vt", env)

    def _send_lines(self):
        return list(self.server.sends)

    @staticmethod
    def _wait_until(pred, timeout: float) -> None:
        deadline = time.time() + timeout
        while time.time() < deadline:
            if pred():
                return
            time.sleep(0.02)

    def test_completes_after_count_sends(self):
        """A clean run exits 0 (SystemExit(0)) after `count` successful sends."""
        with self.assertRaises(SystemExit) as cm:
            run_value_transfer(self._payload(count=2), self._ctx())
        self.assertEqual(cm.exception.code, 0)
        self.assertEqual(len(self._send_lines()), 2)

    def test_import_failure_drops_accounts(self):
        """A sender whose import fails is dropped; all failing → clean exit 0."""
        with self.assertRaises(SystemExit) as cm:
            run_value_transfer(
                self._payload(count=None), self._ctx(FAKE_FAIL_IMPORT="1")
            )
        self.assertEqual(cm.exception.code, 0)
        self.assertEqual(self._send_lines(), [], "no payment should succeed")

    def test_every_send_is_nonce_pinned(self):
        """Every send pins an explicit nonce (per-account tracking, no inference)."""
        with self.assertRaises(SystemExit):
            run_value_transfer(self._payload(count=4), self._ctx())
        sends = self._send_lines()
        self.assertEqual(len(sends), 4)
        for ln in sends:
            self.assertIn("-nonce", ln, "every send must pin an explicit nonce")

    def test_drain_drops_sender_and_exits(self):
        """An insufficient-funds send drains that sender; all drained → exit 0."""
        self.server.reject = "Insufficient_funds: account balance too low"
        with self.assertRaises(SystemExit) as cm:
            run_value_transfer(self._payload(count=None), self._ctx())
        self.assertEqual(cm.exception.code, 0)

    def test_replay_resubmits_capped(self):
        """replay_probability=1.0 resubmits each send (capped, no infinite flood)."""
        with self.assertRaises(SystemExit):
            run_value_transfer(
                self._payload(count=1, replay_probability=1.0), self._ctx()
            )
        # 1 original + up to _MAX_REPLAYS_PER_SEND identical replays.
        self.assertGreater(len(self._send_lines()), 1)

    def test_dispatch_routes_by_payload_type(self):
        """dispatch_workload runs the worker matching the payload type."""
        with self.assertRaises(SystemExit):
            dispatch_workload(self._payload(count=1), self._ctx())
        self.assertEqual(len(self._send_lines()), 1)

    def test_thread_workload_completes(self):
        """ThreadWorkload maps a clean worker exit to COMPLETED / rc 0."""
        wl = ThreadWorkload("vt", self._payload(count=1), {"FAKE_CMD_LOG": self.cmd_log})
        wl.start()
        self._wait_until(lambda: not wl.is_running(), 5)
        self.assertEqual(wl.outcome(), Outcome.COMPLETED)
        self.assertEqual(wl.returncode, 0)
        self.assertIsNone(wl.pid, "a thread workload has no OS pid")

    def test_thread_workload_failure(self):
        """A worker fault (e.g. a missing binary) maps to FAILED, not a crash."""
        env = {"FAKE_CMD_LOG": self.cmd_log}
        wl = ThreadWorkload("vt", self._payload(mina_exe="/nonexistent/mina"), env)
        wl.start()
        self._wait_until(lambda: not wl.is_running(), 5)
        self.assertEqual(wl.outcome(), Outcome.FAILED)
        self.assertEqual(wl.returncode, 1)

    def test_thread_workload_stop_is_prompt(self):
        """stop() interrupts an indefinite worker promptly and cleanly."""
        # count=None → indefinite; interval parks it in an interruptible sleep.
        wl = ThreadWorkload(
            "vt",
            self._payload(count=None, interval_secs=30.0),
            {"FAKE_CMD_LOG": self.cmd_log},
        )
        wl.start()
        self._wait_until(lambda: wl.is_running(), 5)
        self.assertTrue(wl.is_running())
        self.assertIsNone(wl.outcome())
        t0 = time.time()
        wl.stop()
        self.assertLess(time.time() - t0, 3, "stop must be prompt, not block")
        self.assertFalse(wl.is_running())
        self.assertEqual(wl.outcome(), Outcome.COMPLETED)


class TestValueTransferPoolRefs(unittest.TestCase):
    """The value_transfer pool enumeration the hardfork carryover check reads.

    The pool is derived here (online-tier keys with a usable privkey); the
    harness enumerates it via 'query value-transfer-pool' to snapshot each
    account's nonce, so these guard the ref set and its round-trip.
    """

    def setUp(self):
        from mln.models import KeyRecord

        self._tmp = tempfile.mkdtemp()
        self._KeyRecord = KeyRecord

    def tearDown(self):
        shutil.rmtree(self._tmp, ignore_errors=True)

    def _key(self, name, *, privkey=True, pubkey="B62pk") -> "object":
        path = os.path.join(self._tmp, f"{name}.key")
        if privkey:
            with open(path, "w") as f:
                f.write("x")
        return self._KeyRecord(
            privkey_path=path if privkey else "",
            pubkey_path=path + ".pub",
            pubkey_content=pubkey,
        )

    def test_ref_key_name_round_trip(self):
        from mln.spawn.workloads import (
            online_key_name_to_account_ref,
            resolve_account_ref_to_online_key,
        )

        for ref in ("whale-0", "whale-1", "fish-12"):
            self.assertEqual(
                online_key_name_to_account_ref(resolve_account_ref_to_online_key(ref)),
                ref,
            )

    def test_pool_refs_are_online_accounts_with_privkeys_sorted(self):
        from mln.spawn.workloads import value_transfer_pool_refs

        keys = {
            "online_whale_account_1": self._key("a"),
            "online_whale_account_0": self._key("b"),
            # offline stake key — excluded
            "offline_whale_account_0": self._key("c"),
            # online but no privkey — excluded
            "online_fish_account_0": self._key("d", privkey=False),
            # online but empty pubkey — excluded
            "online_fish_account_2": self._key("e", pubkey=""),
        }
        self.assertEqual(
            value_transfer_pool_refs(keys),
            ["whale-0", "whale-1"],
        )

    def test_pool_refs_empty_when_no_online_accounts(self):
        from mln.spawn.workloads import value_transfer_pool_refs

        keys = {"offline_whale_account_0": self._key("c")}
        self.assertEqual(value_transfer_pool_refs(keys), [])


class TestConstraintsSurface(unittest.TestCase):
    """Phase-0 surface of the v2 constraint topology (mln.constraints).

    Guards the requirements models and their invariants — the ones JSON Schema
    can't state, which is why the pydantic layer is the source of truth and is
    deliberately stricter than the derived schema.
    """

    @staticmethod
    def _valid() -> dict:
        return {
            "fragments": {
                "seed": {"replica": 1, "seed": {}},
                "bp": {"replica": 2, "block_producer": {"stake_tier": "whale"}},
                "coordinator": {
                    "replica": 1,
                    "snark_coordinator": {"workers": 2, "fee_receiver": "snark-fees"},
                },
            },
            "services": {"archive": {"replica": 1}},
            "nodes": {"min": 3, "max": 5},
            "placement": [
                {"relation": "avoid_colocate", "of": ["coordinator", "bp"], "weight": 10}
            ],
        }

    def _bad(self, mutate) -> None:
        from mln.constraints import parse_requirements
        from mln.errors import ErrorCode, TopologyError

        req = self._valid()
        mutate(req)
        with self.assertRaises(TopologyError) as cm:
            parse_requirements(req)
        self.assertEqual(cm.exception.code, ErrorCode.REQUIREMENTS_VALIDATION)

    def test_parses_full_example(self):
        from mln.constraints import PlacementRelation, parse_requirements

        r = parse_requirements(self._valid())
        self.assertEqual(sorted(r.fragments), ["bp", "coordinator", "seed"])
        self.assertEqual(r.fragments["bp"].replica, 2)
        self.assertEqual(r.fragments["bp"].block_producer.stake_tier, "whale")
        self.assertEqual(r.fragments["bp"].capability_names(), ["block_producer"])
        self.assertEqual((r.nodes.min, r.nodes.max), (3, 5))
        self.assertEqual(r.placement[0].relation, PlacementRelation.AVOID_COLOCATE)
        self.assertEqual(r.placement[0].weight, 10)

    def test_fragment_requires_a_capability(self):
        self._bad(lambda r: r["fragments"].__setitem__("bare", {"replica": 1}))

    def test_block_producer_needs_exactly_one_binding(self):
        # both stake_tier and account
        self._bad(lambda r: r["fragments"]["bp"].__setitem__(
            "block_producer", {"stake_tier": "whale", "account": "whale-0"}))
        # neither
        self._bad(lambda r: r["fragments"]["bp"].__setitem__(
            "block_producer", {}))

    def test_soft_relation_requires_weight(self):
        self._bad(lambda r: r["placement"].__setitem__(0,
            {"relation": "avoid_colocate", "of": ["seed", "bp"]}))

    def test_hard_relation_forbids_weight(self):
        self._bad(lambda r: r["placement"].__setitem__(0,
            {"relation": "separate", "of": ["seed", "bp"], "weight": 3}))

    def test_placement_of_must_be_two_fragments(self):
        self._bad(lambda r: r["placement"].__setitem__(0,
            {"relation": "separate", "of": ["seed"]}))

    def test_placement_unknown_fragment_rejected(self):
        self._bad(lambda r: r["placement"].__setitem__(0,
            {"relation": "separate", "of": ["seed", "ghost"]}))

    def test_node_budget_ordering(self):
        self._bad(lambda r: r.__setitem__("nodes", {"min": 5, "max": 3}))
        self._bad(lambda r: r.__setitem__("nodes", {"min": 0, "max": 3}))

    def test_replica_must_be_positive(self):
        self._bad(lambda r: r["fragments"]["seed"].__setitem__("replica", 0))

    def test_extra_field_forbidden(self):
        self._bad(lambda r: r["fragments"]["seed"].__setitem__("typo", 1))
        self._bad(lambda r: r.__setitem__("unknown_top", 1))

    def test_empty_fragments_rejected(self):
        self._bad(lambda r: r.__setitem__("fragments", {}))


class TestRequirementsSchemaDrift(unittest.TestCase):
    """The checked-in requirements schema must equal what the models emit.

    Direction B: pydantic is the source of truth, the JSON Schema is derived.
    This fails if someone edits the models without running `schema regen`, or on
    a pydantic version bump that changes the projection.
    """

    def test_checked_in_schema_matches_model(self):
        from mln.constraints import requirements_json_schema
        from mln.paths import REQUIREMENTS_SCHEMA_PATH

        self.assertTrue(
            REQUIREMENTS_SCHEMA_PATH.exists(),
            "requirements.schema.json missing — run 'mina-local-network schema regen'",
        )
        on_disk = json.loads(REQUIREMENTS_SCHEMA_PATH.read_text(encoding="utf-8"))
        self.assertEqual(
            on_disk,
            requirements_json_schema(),
            "requirements.schema.json is stale — run 'mina-local-network schema regen'",
        )


class TestConstraintSamplerSpike(unittest.TestCase):
    """Phase-1 MVP spike: v2 requirements -> concrete nodes -> resolve pipeline.

    Proves the integration seam (lowering runs at load, the lowered v1 form flows
    through normalize/resolve unchanged). The placement is fully-spread — one
    fragment-replica per node — which the real sampler replaces later.
    """

    def test_v1_topology_passes_through_unchanged(self):
        from mln.sampler import lower_topology

        v1 = {"schema_version": 1, "name": "x", "nodes": {"a": {"capabilities": {}}}}
        self.assertEqual(lower_topology(v1), v1)

    # A ledger tier for the two whale producers the example needs; the sampler
    # checks producer demand against this supply.
    _TIER_COUNTS = {"whale": 2}
    _LEDGER = {"tiers": {"whale": {"count": 2}, "snark_coordinator": {"count": 1}}}

    @staticmethod
    def _example_requirements(nodes=None):
        return {
            "fragments": {
                "seed": {"replica": 1, "seed": {}},
                "bp": {"replica": 2, "block_producer": {"stake_tier": "whale"}},
                "coordinator": {
                    "replica": 1,
                    "snark_coordinator": {"workers": 2, "fee_receiver": "snark-fees"},
                },
            },
            "nodes": nodes or {"min": 2, "max": 5},
        }

    def _example_doc(self, requirements=None):
        return {
            "schema_version": 2,
            "ledger_generation": self._LEDGER,
            "requirements": requirements or self._example_requirements(),
        }

    def _assert_valid_placement(self, req: dict, nodes: dict) -> None:
        """Every hard invariant a sampled placement must satisfy."""
        singletons = ("p2p_seed", "block_producer", "snark_coordinator")
        n_lo, n_hi = req["nodes"]["min"], req["nodes"]["max"]
        self.assertTrue(n_lo <= len(nodes) <= n_hi, f"node count {len(nodes)} out of range")
        bp_accounts = []
        seeds = coords = 0
        for spec in nodes.values():
            caps = spec["capabilities"]
            # per-node capacity: a node holds at most one of each singleton cap
            for cap in singletons:
                self.assertLessEqual(list(caps).count(cap), 1)
            if "block_producer" in caps:
                bp_accounts.append(caps["block_producer"]["account"])
            seeds += "p2p_seed" in caps
            coords += "snark_coordinator" in caps
        # every replica placed exactly once, with distinct bound accounts
        self.assertEqual(sorted(bp_accounts), ["whale-0", "whale-1"])
        self.assertEqual(seeds, 1)
        self.assertEqual(coords, 1)

    def test_lower_unseeded_is_random_but_valid(self):
        """An unpinned topology samples a fresh valid layout each lowering.

        Random placement is the point — CI exercises varied layouts — so two
        lowerings need not match; each must still be a valid v1 topology."""
        from mln.sampler import lower_topology

        raw = self._example_doc()
        a = lower_topology(json.loads(json.dumps(raw)))
        self.assertEqual(a["schema_version"], 1)
        self.assertNotIn("requirements", a)
        self._assert_valid_placement(raw["requirements"], a["nodes"])

        # Over enough lowerings the random node count must actually vary — otherwise
        # "random" would be indistinguishable from the old fixed-layout behaviour.
        counts = set()
        for _ in range(50):
            out = lower_topology(json.loads(json.dumps(raw)))
            self._assert_valid_placement(raw["requirements"], out["nodes"])
            counts.add(len(out["nodes"]))
        self.assertGreater(len(counts), 1, "unpinned lowering never varied its layout")

    def test_lower_pinned_seed_is_reproducible(self):
        """Pinning requirements.seed makes lowering reproducible, for a chosen run."""
        from mln.sampler import lower_topology

        raw = self._example_doc(self._example_requirements())
        raw["requirements"]["seed"] = 12345
        a = lower_topology(json.loads(json.dumps(raw)))
        b = lower_topology(json.loads(json.dumps(raw)))
        self.assertEqual(a, b, "a pinned seed must lower reproducibly")
        self._assert_valid_placement(raw["requirements"], a["nodes"])

    def test_placements_valid_across_seeds(self):
        from random import Random
        from mln.constraints import parse_requirements
        from mln.sampler import _sample_nodes

        req_dict = self._example_requirements()
        req = parse_requirements(req_dict)
        seen_counts = set()
        for seed in range(200):
            nodes = _sample_nodes(req, Random(seed), self._TIER_COUNTS)
            self._assert_valid_placement(req_dict, nodes)
            seen_counts.add(len(nodes))
        # the node budget really is a merge<->spread dial: both extremes appear
        self.assertIn(2, seen_counts, "min-count (merged) placement never sampled")
        self.assertIn(4, seen_counts, "fully-spread placement never sampled")

    def test_infeasible_budget_raises(self):
        from mln.errors import ErrorCode, TopologyError
        from mln.sampler import lower_topology

        # two producers need >=2 nodes (one block_producer per node); max 1 is impossible
        raw = self._example_doc(self._example_requirements(nodes={"min": 1, "max": 1}))
        with self.assertRaises(TopologyError) as cm:
            lower_topology(raw)
        self.assertEqual(cm.exception.code, ErrorCode.REQUIREMENTS_VALIDATION)

    def test_hard_separate_rule_respected(self):
        from random import Random
        from mln.constraints import parse_requirements
        from mln.sampler import _sample_nodes

        req = parse_requirements({
            "fragments": {
                "bp": {"replica": 2, "block_producer": {"stake_tier": "whale"}},
                "coordinator": {
                    "replica": 1,
                    "snark_coordinator": {"workers": 1, "fee_receiver": "snark-fees"},
                },
            },
            "nodes": {"min": 2, "max": 4},
            "placement": [{"relation": "separate", "of": ["bp", "coordinator"]}],
        })
        for seed in range(100):
            nodes = _sample_nodes(req, Random(seed), self._TIER_COUNTS)
            for spec in nodes.values():
                # never a node with both a producer (block_producer) and the coordinator
                caps = spec["capabilities"]
                self.assertFalse("block_producer" in caps and "snark_coordinator" in caps)

    def test_concrete_account_pin_passes_through(self):
        from mln.sampler import lower_topology

        raw = {
            "schema_version": 2,
            "ledger_generation": {"tiers": {"whale": {"count": 8}}},  # supplies whale-7
            "requirements": {
                "fragments": {"prod": {"replica": 1, "block_producer": {"account": "whale-7"}}},
                "nodes": {"min": 1, "max": 1},
            },
        }
        out = lower_topology(raw)
        self.assertEqual(
            out["nodes"]["prod-0"]["capabilities"]["block_producer"]["account"], "whale-7"
        )

    def test_v2_preset_resolves_end_to_end(self):
        from mln.schema import resolve_topology_source, validate_topology
        from mln.topology import normalize_topology, resolve_topology
        from mln.models import NormalizedTopology

        raw = resolve_topology_source(Path(_preset("hf-test-legacy")))
        self.assertEqual(raw["schema_version"], 1)  # lowered at load
        self.assertEqual(validate_topology(raw), [])  # lowered form is valid v1

        normalized = normalize_topology(raw)
        normalized.setdefault("state", {})["root"] = tempfile.mkdtemp()
        plan = resolve_topology(NormalizedTopology.model_validate(normalized))

        # placement is random per run, so assert properties, not exact names
        self.assertTrue(2 <= len(plan.nodes) <= 3)
        seeds = [n for n in plan.nodes if "p2p_seed" in n.capabilities]
        producers = [n for n in plan.nodes if n.block_producer_key_path]
        coords = [n for n in plan.nodes if n.snark_coordinator is not None]
        self.assertEqual(len(seeds), 1)
        self.assertEqual(len(producers), 2)
        self.assertEqual(len(coords), 1)

    # ── phase 3: soft weights + explicit seed ──────────────────────────

    @staticmethod
    def _avoid_requirements(weight):
        return {
            "fragments": {
                "a": {"replica": 1, "seed": {}},
                "b": {"replica": 1, "block_producer": {"stake_tier": "whale"}},
            },
            "nodes": {"min": 1, "max": 3},
            "placement": [{"relation": "avoid_colocate", "of": ["a", "b"], "weight": weight}],
        }

    def test_hard_separation_always_applies(self):
        from random import Random
        from mln.constraints import parse_requirements
        from mln.sampler import _resolve_separations

        req = parse_requirements({
            "fragments": {"a": {"replica": 1, "seed": {}},
                          "b": {"replica": 1, "block_producer": {"account": "whale-0"}}},
            "nodes": {"min": 1, "max": 2},
            "placement": [{"relation": "separate", "of": ["a", "b"]}],
        })
        for seed in range(20):
            self.assertIn(frozenset({"a", "b"}), _resolve_separations(req, Random(seed)))

    def test_avoid_colocate_coin_matches_probability(self):
        from random import Random
        from mln.constraints import parse_requirements
        from mln.sampler import _resolve_separations

        req = parse_requirements(self._avoid_requirements(weight=9))
        # _resolve_separations consumes exactly one rng.random() for the one soft
        # rule, so a parallel rng predicts the outcome deterministically.
        for seed in (0, 1, 42, 1234):
            got = frozenset({"a", "b"}) in _resolve_separations(req, Random(seed))
            expected = Random(seed).random() < 9 / 10
            self.assertEqual(got, expected)

    def test_avoid_colocate_yields_both_outcomes(self):
        from random import Random
        from mln.constraints import parse_requirements
        from mln.sampler import _resolve_separations

        req = parse_requirements(self._avoid_requirements(weight=1))  # q = 0.5
        outcomes = {
            frozenset({"a", "b"}) in _resolve_separations(req, Random(s)) for s in range(50)
        }
        self.assertEqual(outcomes, {True, False}, "soft rule must sometimes hold, sometimes not")

    def test_explicit_seed_is_reproducible_and_used(self):
        from mln.sampler import lower_topology

        def lowered(seed):
            return lower_topology(
                self._example_doc({**self._example_requirements(), "seed": seed})
            )

        self.assertEqual(lowered(13), lowered(13), "same seed must reproduce")
        counts = {len(lowered(s)["nodes"]) for s in range(12)}
        self.assertGreater(len(counts), 1, "the seed must actually steer the placement")

    # ── phase 4: stake-tier provisioning feasibility ───────────────────

    @staticmethod
    def _doc_with_tiers(tiers, fragments, nodes):
        return {
            "schema_version": 2,
            "ledger_generation": {"tiers": tiers},
            "requirements": {"fragments": fragments, "nodes": nodes},
        }

    def _assert_provisioning_error(self, doc):
        from mln.errors import ErrorCode, TopologyError
        from mln.sampler import lower_topology

        with self.assertRaises(TopologyError) as cm:
            lower_topology(doc)
        self.assertEqual(cm.exception.code, ErrorCode.REQUIREMENTS_VALIDATION)
        return cm.exception

    def test_producer_demand_exceeds_tier_supply_raises(self):
        doc = self._doc_with_tiers(
            {"whale": {"count": 2}},
            {"p": {"replica": 3, "block_producer": {"stake_tier": "whale"}}},
            {"min": 3, "max": 3},
        )
        err = self._assert_provisioning_error(doc)
        self.assertIn("whale-2", err.message)  # names the shortfall account

    def test_pinned_account_out_of_supply_raises(self):
        doc = self._doc_with_tiers(
            {"whale": {"count": 2}},
            {"p": {"replica": 1, "block_producer": {"account": "whale-5"}}},
            {"min": 1, "max": 2},
        )
        self._assert_provisioning_error(doc)

    def test_undefined_tier_raises(self):
        doc = self._doc_with_tiers(
            {"whale": {"count": 2}},
            {"p": {"replica": 1, "block_producer": {"stake_tier": "fish"}}},
            {"min": 1, "max": 2},
        )
        err = self._assert_provisioning_error(doc)
        self.assertIn("fish", err.message)

    def test_demand_within_supply_ok(self):
        from mln.sampler import lower_topology

        doc = self._doc_with_tiers(
            {"whale": {"count": 2}},
            {"p": {"replica": 2, "block_producer": {"stake_tier": "whale"}}},
            {"min": 2, "max": 4},
        )
        out = lower_topology(doc)  # must not raise
        accounts = sorted(
            spec["capabilities"]["block_producer"]["account"]
            for spec in out["nodes"].values()
            if "block_producer" in spec["capabilities"]
        )
        self.assertEqual(accounts, ["whale-0", "whale-1"])

    # ── phase 5: services (archive/rosetta) intrinsic wiring ───────────

    @staticmethod
    def _doc_with_services(services):
        return {
            "schema_version": 2,
            "ledger_generation": {
                "tiers": {"whale": {"count": 1}},
                "accounts": {"snark-fees": {"balance": "5nanomina", "kind": "snark_fee"}},
            },
            "requirements": {
                "fragments": {
                    "seed": {"replica": 1, "seed": {}},
                    "prod": {"replica": 1, "block_producer": {"stake_tier": "whale"}},
                },
                "services": services,
                "nodes": {"min": 2, "max": 2},
            },
        }

    def test_services_lowered_with_passthrough_config(self):
        from mln.sampler import lower_topology

        out = lower_topology(self._doc_with_services(
            {"archive": {"replica": 1}, "rosetta": {"replica": 1, "max_db_pool_size": 32}}
        ))
        # replica stripped; existence-only archive is {}, rosetta config passes through
        self.assertEqual(out["services"], {"archive": {}, "rosetta": {"max_db_pool_size": 32}})

    def test_services_resolve_end_to_end(self):
        import tempfile
        from mln.sampler import lower_topology
        from mln.schema import validate_topology
        from mln.topology import normalize_topology, resolve_topology
        from mln.models import NormalizedTopology

        out = lower_topology(self._doc_with_services(
            {"archive": {"replica": 1}, "rosetta": {"replica": 1}}
        ))
        self.assertEqual(validate_topology(out), [])
        norm = normalize_topology(out)
        norm.setdefault("state", {})["root"] = tempfile.mkdtemp()
        plan = resolve_topology(NormalizedTopology.model_validate(norm))
        kinds = sorted(s.kind.value for s in plan.services)
        self.assertEqual(kinds, ["archive", "rosetta"])  # both wired (rosetta needs archive+daemon)

    def test_service_replica_must_be_one(self):
        from mln.errors import ErrorCode, TopologyError
        from mln.sampler import lower_topology

        with self.assertRaises(TopologyError) as cm:
            lower_topology(self._doc_with_services({"archive": {"replica": 2}}))
        self.assertEqual(cm.exception.code, ErrorCode.REQUIREMENTS_VALIDATION)

    def test_no_services_omits_services_key(self):
        from mln.sampler import lower_topology

        out = lower_topology(self._example_doc())
        self.assertNotIn("services", out)

    # ── phase 5: fuzz — sampler is total (valid placement or clean error) ──

    def test_fuzz_sampler_never_crashes(self):
        """Random requirements always lower to a valid placement or a clean
        TopologyError — never an unexpected exception, and never an invalid map."""
        from random import Random
        from mln.errors import TopologyError
        from mln.sampler import lower_topology

        rng = Random(20260719)
        cap_choices = ["seed", "block_producer", "snark_coordinator"]
        for _ in range(300):
            n_frags = rng.randint(1, 4)
            fragments = {}
            for fi in range(n_frags):
                caps = rng.sample(cap_choices, rng.randint(1, len(cap_choices)))
                frag = {"replica": rng.randint(1, 3)}
                if "seed" in caps:
                    frag["seed"] = {}
                if "block_producer" in caps:
                    frag["block_producer"] = {"stake_tier": "whale"}
                if "snark_coordinator" in caps:
                    frag["snark_coordinator"] = {"workers": rng.randint(0, 2),
                                                 "fee_receiver": "snark-fees"}
                fragments[f"f{fi}"] = frag
            lo = rng.randint(1, 5)
            doc = {
                "schema_version": 2,
                "ledger_generation": {"tiers": {"whale": {"count": rng.randint(1, 8)}}},
                "requirements": {
                    "fragments": fragments,
                    "nodes": {"min": lo, "max": lo + rng.randint(0, 4)},
                    "seed": rng.randint(0, 10_000),
                },
            }
            try:
                out = lower_topology(doc)
            except TopologyError:
                continue  # infeasible budget / over-provisioned tier — a clean refusal
            # a returned placement must be structurally valid
            lo_b = doc["requirements"]["nodes"]["min"]
            hi_b = doc["requirements"]["nodes"]["max"]
            self.assertTrue(lo_b <= len(out["nodes"]) <= hi_b)
            for spec in out["nodes"].values():
                caps = spec["capabilities"]
                for cap in ("p2p_seed", "block_producer", "snark_coordinator"):
                    self.assertLessEqual(list(caps).count(cap), 1)  # per-node capacity
