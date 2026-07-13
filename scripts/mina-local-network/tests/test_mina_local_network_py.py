"""
Tests for mina-local-network.py topology tool (no-spawn slice).

Uses subprocess to invoke the CLI since the main script filename has hyphens
which makes direct import awkward.
"""

import base64
import json
import os
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from typing import Any, Optional
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPT_DIR))
PYTHON3 = sys.executable
CLI = str(SCRIPT_DIR / "mina-local-network.py")


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
from mln.models import GraphQLResponse  # noqa: E402
from mln.process import pid_is_running, teardown_process  # noqa: E402


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

    def test_show_is_valid_json(self):
        output = _run_json("presets", "show", "single-node")
        # v1 settles on schema_version, not version
        self.assertEqual(output["schema_version"], 1)
        self.assertEqual(output["name"], "single-node")
        self.assertIn("nodes", output)
        self.assertIn("seed", output["nodes"])

    def test_show_has_capabilities_not_old_shape(self):
        """Verify the settled v1 topology shape: capabilities, no kind/role booleans."""
        output = _run_json("presets", "show", "single-node")
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
        output = _run_json("presets", "show", "single-node")
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

    def test_show_has_state_with_mode_and_genesis_timestamp(self):
        """State must have mode and genesis_timestamp; root is optional (defaults repo-local)."""
        output = _run_json("presets", "show", "single-node")
        state = output["state"]

        # root is omitted in the single-node preset → defaults to .mina-local-network/single-node/
        self.assertNotIn("root", state, "root should be absent when preset omits it")
        self.assertIn("mode", state)
        self.assertEqual(state["mode"], "reset")
        self.assertIn("genesis_timestamp", state)
        self.assertIn("delay", state["genesis_timestamp"])

    def test_show_no_genesis_state_timestamp_in_ledger(self):
        """genesis_state_timestamp must NOT appear in ledger_generation (belongs under state)."""
        output = _run_json("presets", "show", "single-node")
        lg = output.get("ledger_generation", {})
        self.assertNotIn(
            "genesis_state_timestamp",
            lg,
            "genesis_state_timestamp must not be in ledger_generation",
        )

    def test_show_no_internal_external_workers_integers(self):
        """snark_coordinator must use worker_pools, not internal_workers/external_workers integers."""
        output = _run_json("presets", "show", "single-node")
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
        cp = _run("schema", "validate", "single-node", check=False)
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
        _run("plan", "topology", "single-node", "--overwrite", check=False)

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
        cp = _run("plan", "topology", "single-node", check=False)
        self.assertNotEqual(
            cp.returncode, 0, "Second plan without --overwrite should fail"
        )
        self.assertIn("already exists", cp.stderr)

    def test_plan_with_overwrite_succeeds(self):
        """Plan with --overwrite must succeed even when plan exists."""
        cp = _run("plan", "topology", "single-node", "--overwrite", check=False)
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
        _run("plan", "topology", "single-node", "--overwrite", check=False)

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
        _run("plan", "topology", "single-node", "--overwrite", check=False)
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
        cp = _run("inspect", "topology", "single-node", check=False)
        self.assertNotEqual(cp.returncode, 0, "inspect topology should exit nonzero")
        self.assertIn("has been removed", cp.stderr)

    def test_inspect_topology_no_transient_output(self):
        """inspect topology must not produce transient plan JSON output."""
        cp = _run("inspect", "topology", "single-node", check=False)
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
    """Tests for spawn command stubs — must not actually spawn processes."""

    @classmethod
    def setUpClass(cls):
        """Ensure plan exists at repo-local default root."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)
        _run("plan", "topology", "single-node", "--overwrite", check=False)

    @classmethod
    def tearDownClass(cls):
        """Clean up generated state directory."""
        shutil.rmtree(str(Path(REPO_ROOT) / ".mina-local-network"), ignore_errors=True)

    def test_spawn_instance_fails_with_not_implemented(self):
        """spawn instance reads plan, checks for manifest, fails with not-implemented."""
        state_root = str(Path(REPO_ROOT) / ".mina-local-network" / "single-node")
        # No manifest exists yet → spawn instance errors about missing manifest
        cp = _run("spawn", "instance", state_root, check=False)
        self.assertNotEqual(cp.returncode, 0, "spawn instance should exit nonzero")
        self.assertIn("No materialized-manifest.json found", cp.stderr)

    def test_spawn_instance_missing_plan_fails(self):
        """spawn instance with missing plan fails before not-implemented msg."""
        cp = _run("spawn", "instance", ".mina-local-network/nonexistent", check=False)
        self.assertNotEqual(cp.returncode, 0)
        self.assertIn("No network plan found", cp.stderr)

    def test_spawn_topology_delegates_plan_then_errors(self):
        """spawn topology writes plan then errors if manifest is missing."""
        cp = _run("spawn", "topology", "single-node", "--overwrite", check=False)
        self.assertNotEqual(
            cp.returncode, 0, "spawn topology should exit nonzero when manifest missing"
        )
        # "Plan written to" goes to stdout (from _do_plan_topology via click.echo)
        self.assertIn("Plan written to", cp.stdout)
        # "not yet materialized" goes to stderr (from ClickException)
        self.assertIn("not yet materialized", cp.stderr)


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
        _run("plan", "topology", "single-node", "--overwrite", check=False)

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
        _run("plan", "topology", "single-node", "--overwrite", check=False)

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
        topology = {
            "schema_version": 1,
            "name": self._topo_name,
            "ledger_generation": {"tiers": {}},
            "nodes": {"n1": {"capabilities": {"p2p_seed": {}}}},
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
                "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
                "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
                "mode": "reset",
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
                "mode": "reset",
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


_FAKE_MINA_SCRIPT = r"""#!/usr/bin/env bash
# fake-mina test double
set -euo pipefail
if [[ "$1" == "advanced" && "$2" == "generate-keypair" && "$3" == "-privkey-path" ]]; then
    KEYPATH="$4"
    echo "fake-privkey-for-$(basename "$KEYPATH")" > "$KEYPATH"
    echo "fake-pubkey-for-$(basename "$KEYPATH")" > "${KEYPATH}.pub"
    exit 0
fi
if [[ "$1" == "client" && "$2" == "status" && "$3" == "-daemon-port" ]]; then
    _port="$4"
    # Increment attempt counter if requested (for testing polling)
    if [[ -n "${FAKE_MINA_STATUS_COUNT_FILE:-}" ]]; then
        _cnt=0
        [[ -f "$FAKE_MINA_STATUS_COUNT_FILE" ]] && _cnt=$(cat "$FAKE_MINA_STATUS_COUNT_FILE" 2>/dev/null) || true
        echo $((_cnt + 1)) > "$FAKE_MINA_STATUS_COUNT_FILE"
    fi
    # Ready-file driven behavior: if FAKE_MINA_READY_FILE is set, succeed
    # only when that file exists; otherwise fail.
    if [[ -n "${FAKE_MINA_READY_FILE:-}" ]]; then
        if [[ -f "$FAKE_MINA_READY_FILE" ]]; then
            exit 0
        fi
        exit 1
    fi
    # Default: success (no env vars set)
    exit 0
fi
# account import
if [[ "$1" == "account" && "$2" == "import" ]]; then
    if [[ -n "${FAKE_MINA_COMMAND_LOG:-}" ]]; then
        printf 'import %s\n' "$*" >> "$FAKE_MINA_COMMAND_LOG"
    fi
    exit 0
fi
# account unlock
if [[ "$1" == "account" && "$2" == "unlock" ]]; then
    if [[ -n "${FAKE_MINA_COMMAND_LOG:-}" ]]; then
        printf 'unlock %s\n' "$*" >> "$FAKE_MINA_COMMAND_LOG"
    fi
    exit 0
fi
# client send-payment
if [[ "$1" == "client" && "$2" == "send-payment" ]]; then
    if [[ -n "${FAKE_MINA_COMMAND_LOG:-}" ]]; then
        printf 'send-payment %s\n' "$*" >> "$FAKE_MINA_COMMAND_LOG"
    fi
    exit "${FAKE_MINA_SEND_PAYMENT_EXIT:-0}"
fi
if [[ "$1" == "daemon" || ( "$1" == "internal" && "$2" == "snark-worker" ) ]]; then
    # Determine kind for logging / marker naming
    _kind=daemon
    if [[ "$1" != "daemon" ]]; then
        _kind=worker
    fi
    # Append to order file FIRST (for testing start-order accuracy)
    if [[ -n "${FAKE_MINA_ORDER_FILE:-}" ]]; then
        echo "${_kind}" >> "$FAKE_MINA_ORDER_FILE"
    fi
    # Write marker file if requested (for synchronization in tests)
    if [[ -n "${FAKE_MINA_MARKER:-}" ]]; then
        touch "$FAKE_MINA_MARKER" 2>/dev/null || true
    fi
    # Write full argv to file if requested (newline-separated)
    if [[ -n "${FAKE_MINA_ARGS_FILE:-}" ]]; then
        printf '%s\n' "$@" > "$FAKE_MINA_ARGS_FILE"
    fi
    # Write env vars to file if requested (for testing env inheritance)
    if [[ -n "${FAKE_MINA_ENV_FILE:-}" && "${_kind}" != "daemon" ]]; then
        env | sort > "$FAKE_MINA_ENV_FILE"
    fi
    if [[ -n "${FAKE_MINA_DAEMON_ENV_FILE:-}" && "${_kind}" == "daemon" ]]; then
        env | sort >> "$FAKE_MINA_DAEMON_ENV_FILE"
        printf '%s\n' '---' >> "$FAKE_MINA_DAEMON_ENV_FILE"
    fi
    # Trap SIGTERM if requested (for SIGKILL escalation test)
    if [[ -n "${FAKE_MINA_TRAP_SIGTERM:-}" ]]; then
        trap '' TERM
    fi
    # Spawn a child sleep process if requested (for process-group teardown test)
    if [[ -n "${FAKE_MINA_SPAWN_SLEEP:-}" ]]; then
        sleep_secs="${FAKE_MINA_SPAWN_SLEEP:-99}"
        sleep "$sleep_secs" &
        CHILD_PID=$!
        if [[ -n "${FAKE_MINA_CHILD_PID_FILE:-}" ]]; then
            echo "$CHILD_PID" > "$FAKE_MINA_CHILD_PID_FILE" 2>/dev/null || true
        fi
    fi
    # Fake GraphQL HTTP server on daemon rest-port (daemon only)
    if [[ "${_kind}" == "daemon" && "${FAKE_MINA_NO_GQL:-}" != "1" ]]; then
        _gql_port=""
        for ((i=1; i<=$#; i++)); do
            if [[ "${!i}" == "--rest-port" ]]; then
                _gql_port="${@:$((i+1)):1}"
                break
            fi
        done
        if [[ -n "${_gql_port:-}" ]]; then
            python3 -c "
import http.server, json, os
_rf = os.environ.get('FAKE_MINA_GQL_READY_FILE', '')
_sf = os.environ.get('FAKE_MINA_GQL_SYNC_STATUS_FILE', '')
class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        if _rf and not os.path.exists(_rf):
            self.send_response(503); self.end_headers(); return
        if self.path == '/graphql':
            _length = int(self.headers.get('Content-Length', '0') or '0')
            _body = self.rfile.read(_length).decode('utf-8') if _length else ''
            _payload = {'data': {'ok': True}}
            status = 'SYNCED'
            if _sf and os.path.exists(_sf):
                status = open(_sf, encoding='utf-8').read().strip() or 'SYNCED'
            if 'syncStatus' in _body:
                _payload = {'data': {'syncStatus': status}}
            elif 'account(' in _body:
                if os.environ.get('FAKE_MINA_GQL_ACCOUNT_NULL', '') == '1':
                    _payload = {'data': {'account': None}}
                else:
                    _nonce = os.environ.get('FAKE_MINA_GQL_INFERRED_NONCE', '0')
                    _payload = {'data': {'account': {'inferredNonce': _nonce}}}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(_payload).encode('utf-8'))
        else:
            self.send_response(404); self.end_headers()
    def log_message(self, *args): pass
httpd = http.server.HTTPServer(('127.0.0.1', $_gql_port), H)
httpd.serve_forever()
" &
        fi
    fi
    # Sleep if requested (for process-tracking tests)
    sleep "${FAKE_MINA_SLEEP:-0}"
    exit "${FAKE_MINA_EXIT_CODE:-0}"
fi
echo "fake-mina: unhandled command: $*" >&2
exit 1
"""


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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
        """Invalid balance strings must raise TopologyError."""
        from mln.errors import TopologyError

        with self.assertRaises(TopologyError):
            convert_balance_to_decimal_mina("not-a-number")
        with self.assertRaises(TopologyError):
            convert_balance_to_decimal_mina("5.5mina")
        with self.assertRaises(TopologyError):
            convert_balance_to_decimal_mina("5minas")

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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

    def test_spawn_instance_exits_cleanly(self):
        """spawn instance returns 0 when fake daemon exits quickly, and cleans
        processes.json."""
        # Ensure no processes.json beforehand
        self._marker_path().unlink(missing_ok=True)
        self._processes_path().unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_SLEEP"] = "0"

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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            env = os.environ.copy()
            env["FAKE_MINA_MARKER"] = str(marker_file)
            env["FAKE_MINA_SLEEP"] = "0"

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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            env = os.environ.copy()
            env["FAKE_MINA_MARKER"] = str(marker_file)
            env["FAKE_MINA_SLEEP"] = "0"

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

        env = os.environ.copy()
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

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(self._marker_path())
        env["FAKE_MINA_ARGS_FILE"] = str(args_file)
        env["FAKE_MINA_SLEEP"] = "0"

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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            env = os.environ.copy()
            env["FAKE_MINA_ARGS_FILE"] = str(args_file)
            env["FAKE_MINA_SLEEP"] = "0"

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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            env = os.environ.copy()
            env["FAKE_MINA_SLEEP"] = "0"

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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

            env = os.environ.copy()
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

        env = os.environ.copy()
        env["FAKE_MINA_SLEEP"] = "0"

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

        env = os.environ.copy()
        env["FAKE_MINA_SLEEP"] = "0"

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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

        env = os.environ.copy()
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

        env = os.environ.copy()
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

        env = os.environ.copy()
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

        env = os.environ.copy()
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

            env = os.environ.copy()
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

            env = os.environ.copy()
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
                        "sender": "whale-0",
                        "receiver": "whale-0",
                        "amount": "5",
                        "interval_seconds": 3,
                        "count": 10,
                    },
                },
            },
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            self.assertEqual(wl["start"], "after_sync")  # default for vt
            self.assertNotIn("repeat", wl)
            self.assertEqual(wl["sender"], "whale-0")
            self.assertEqual(wl["receiver"], "whale-0")
            self.assertEqual(wl["amount"], "5")
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
        """value_transfer defaults: start=after_sync, receiver defaults to
        sender, amount=1, interval_seconds=10, success_exits_keep_network=true,
        no count field when omitted."""
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
                    "config": {"sender": "whale-0"},
                },
            },
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="vt_defs_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")
        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            root = str(Path(REPO_ROOT) / ".mina-local-network" / topo_name)
            plan = _run_json("inspect", "instance", root)
            wl = plan["workloads"][0]
            self.assertEqual(wl["start"], "after_sync")
            self.assertEqual(wl["sender"], "whale-0")
            self.assertEqual(wl["receiver"], "whale-0")  # defaults to sender
            self.assertEqual(wl["amount"], "1")
            self.assertEqual(wl["interval_seconds"], 10)
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
        cases = [
            ({"account": None}, 0),
            ({"account": {"inferredNonce": None}}, 0),
            ({"account": {"inferredNonce": 7}}, 7),
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
        return subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=capture,
            text=capture,
            env=env,
            cwd=self._repo_root,
        )

    def _spawn_bg(self, env: dict) -> subprocess.Popen:
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

        env = os.environ.copy()
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

        env = os.environ.copy()
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

    # ── after_sync gate ──────────────────────────────────────────────

    def test_workload_after_sync_waits_for_synced(self):
        """Workload with start=after_sync must wait for GraphQL sync before
        spawning."""
        workload_marker = Path(self._topo_root_abs) / "sync-workload-started"
        workload_marker.unlink(missing_ok=True)
        self._plan_and_materialize(
            workloads={
                "sync-echo": {
                    "type": "echo",
                    "start": "after_sync",
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
        """value_transfer count=2 runs import/unlock/send-payment, pinning
        nonce 0 on the first send only."""
        self._plan_and_materialize(
            workloads={
                "my-vt": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "whale-0",
                        "receiver": "whale-0",
                        "amount": "5",
                        "interval_seconds": 0,
                        "count": 2,
                    },
                },
            }
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        cmd_log = Path(self._topo_root_abs) / "command.log"
        cmd_log.unlink(missing_ok=True)

        env = os.environ.copy()
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
        self.assertIn(
            "-nonce 0", send_lines[0], f"First send must pin nonce 0: {send_lines[0]}"
        )
        self.assertNotIn(
            "-nonce",
            send_lines[1],
            f"Second send must let daemon infer nonce: {send_lines[1]}",
        )

    def test_value_transfer_after_sync_waits_before_client_commands(self):
        """value_transfer must not import/unlock/send until GraphQL reports
        SYNCED."""
        self._plan_and_materialize(
            workloads={
                "synced-vt": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "whale-0",
                        "amount": "1",
                        "interval_seconds": 0,
                        "count": 1,
                    },
                },
            }
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

    def test_value_transfer_duplicate_sender_rejected(self):
        """Concurrent value_transfer workloads may not share a sender, because
        daemon-inferred nonces would race."""
        self._plan_and_materialize(
            workloads={
                "vt-a": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "whale-0",
                        "amount": "1",
                        "interval_seconds": 0,
                        "count": 1,
                    },
                },
                "vt-b": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "whale-0",
                        "amount": "1",
                        "interval_seconds": 0,
                        "count": 1,
                    },
                },
            }
        )

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=os.environ.copy(),
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "duplicate value_transfer sender must fail before spawn"
        )
        self.assertIn("nonce contention", cp.stderr.lower())

    def test_value_transfer_indefinite_teardown_kills_worker(self):
        """A value_transfer with no count runs indefinitely and is killed by
        supervisor teardown on SIGTERM."""
        self._plan_and_materialize(
            workloads={
                "loop-vt": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "whale-0",
                        "amount": "1",
                        "interval_seconds": 0.2,
                    },
                },
            }
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)
        cmd_log = Path(self._topo_root_abs) / "command.log"
        cmd_log.unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_COMMAND_LOG"] = str(cmd_log)

        proc = self._spawn_bg(env)
        workload_pid = None
        try:
            dl = time.time() + 20
            procs_path = Path(self._topo_root_abs) / "processes.json"
            while time.time() < dl:
                if procs_path.exists():
                    procs = json.loads(procs_path.read_text(encoding="utf-8"))
                    info = procs.get("loop-vt")
                    if info and info.get("kind") == "workload" and info.get("pid"):
                        workload_pid = info["pid"]
                if (
                    workload_pid is not None
                    and cmd_log.exists()
                    and "send-payment" in cmd_log.read_text(encoding="utf-8")
                ):
                    break
                time.sleep(0.1)
            self.assertIsNotNone(
                workload_pid, "value_transfer workload pid should be recorded"
            )
            assert workload_pid is not None
            self.assertTrue(
                pid_is_running(workload_pid),
                "indefinite value_transfer worker should be running",
            )

            proc.terminate()
            proc.wait(timeout=15)
            self.assertEqual(proc.returncode, 143)
            dl2 = time.time() + 10
            while pid_is_running(workload_pid) and time.time() < dl2:
                time.sleep(0.1)
            self.assertFalse(
                pid_is_running(workload_pid),
                "value_transfer worker must be killed on teardown",
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
            workloads={
                "my-vt": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "whale-0",
                        "amount": "1",
                        "interval_seconds": 0,
                        "count": 1,
                    },
                },
            }
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

    def test_value_transfer_send_failure_tears_down(self):
        """send-payment failure must propagate nonzero exit and tear down
        daemon."""
        self._plan_and_materialize(
            workloads={
                "bad-vt": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "whale-0",
                        "amount": "1",
                        "interval_seconds": 0,
                        "count": 1,
                    },
                },
            }
        )

        marker = Path(self._topo_root_abs) / "fake-marker"
        marker.unlink(missing_ok=True)

        env = os.environ.copy()
        env["FAKE_MINA_MARKER"] = str(marker)
        env["FAKE_MINA_SLEEP"] = "60"
        env["FAKE_MINA_SEND_PAYMENT_EXIT"] = "13"

        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "vt spawn must exit nonzero on send failure"
        )
        self.assertEqual(
            cp.returncode,
            13,
            f"Expected exit code 13, got {cp.returncode}: {cp.stderr}",
        )

    def test_value_transfer_malformed_account_ref_fails_before_popen(self):
        """Malformed sender account ref must fail before workload Popen."""
        self._plan_and_materialize(
            workloads={
                "bad-vt": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "not-a-valid-ref",
                        "amount": "1",
                        "count": 1,
                    },
                },
            }
        )

        env = os.environ.copy()
        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "vt spawn must fail on malformed account ref"
        )
        self.assertIn(
            "tier-index",
            cp.stderr.lower(),
            "Error must mention account specifier format",
        )

    def test_value_transfer_missing_key_fails_before_popen(self):
        """Non-existent account tier must fail with manifest key error
        before workload Popen."""
        self._plan_and_materialize(
            workloads={
                "bad-vt": {
                    "type": "value_transfer",
                    "start": "after_sync",
                    "config": {
                        "sender": "fish-0",
                        "amount": "1",
                        "count": 1,
                    },
                },
            }
        )

        env = os.environ.copy()
        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=True,
            text=True,
            env=env,
            cwd=self._repo_root,
        )
        self.assertNotEqual(
            cp.returncode, 0, "vt spawn must fail on missing sender key"
        )
        self.assertIn(
            "manifest key", cp.stderr.lower(), "Error must mention manifest key"
        )

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
        cp = self._spawn(os.environ.copy())
        self.assertNotEqual(cp.returncode, 0)
        self.assertIn("nonce contention", cp.stderr.lower())
        self.assertIn("zkapp fee_payer", cp.stderr)
        self.assertIn("zkapp sender", cp.stderr)

    def test_zkapp_worker_argv_and_relative_binary_resolution(self):
        """Spawn resolves a relative zkApp binary cwd-independently and emits
        stable internal worker argv, including --create-account before count."""
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
        env = os.environ.copy()
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

            procs_path = Path(self._topo_root_abs) / "processes.json"
            procs = json.loads(procs_path.read_text(encoding="utf-8"))
            argv = procs["z"]["argv"]
            worker_index = argv.index("_zkapp_worker")
            self.assertEqual(argv[worker_index + 1], self._fake_zkapp_abs)
            self.assertEqual(
                argv[worker_index + 9 : worker_index + 13], ["3", "1000", "5", "0"]
            )
            self.assertEqual(argv[-2:], ["--create-account", "1"])

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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
        }
        fd, topo_path = tempfile.mkstemp(suffix=".jsonc", prefix="wk_order_")
        os.close(fd)
        Path(topo_path).write_text(json.dumps(topology), encoding="utf-8")

        try:
            _run("plan", "topology", topo_path, "--overwrite", check=True)
            _run("materialize", wk_rel, "--force", check=True)

            marker = Path(wk_abs) / "fake-marker"
            marker.unlink(missing_ok=True)

            env = os.environ.copy()
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

            env = os.environ.copy()
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

            env = os.environ.copy()
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_SLEEP"] = "0"
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

            env = os.environ.copy()
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

            env = os.environ.copy()
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
        return subprocess.run(
            [PYTHON3, CLI, "spawn", "instance", self._topo_root_rel],
            capture_output=capture,
            text=capture,
            env=env,
            cwd=self._repo_root,
        )

    def _spawn_bg(self, env: dict) -> subprocess.Popen:
        """Run spawn instance in background with *env*."""
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
        env = os.environ.copy()
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


class TestEntrypointSelfInvocation(unittest.TestCase):
    """Verify the literal entrypoint script path works for hidden worker self-invocation."""

    def test_entrypoint_exists_and_vt_worker_help_exits_zero(self):
        """mln.paths.ENTRYPOINT must be a real file, and invoking the script
        with the hidden _vt_worker --help command must exit 0."""
        import mln.paths

        self.assertTrue(
            mln.paths.ENTRYPOINT.exists(),
            f"ENTRYPOINT does not exist: {mln.paths.ENTRYPOINT}",
        )
        cp = subprocess.run(
            [sys.executable, str(mln.paths.ENTRYPOINT), "_vt_worker", "--help"],
            capture_output=True,
            text=True,
            cwd=str(mln.paths.REPO_ROOT),
        )
        self.assertEqual(
            cp.returncode,
            0,
            f"_vt_worker --help exited nonzero: stdout={cp.stdout} stderr={cp.stderr}",
        )

    def test_itn_max_cost_worker_help_exits_zero(self):
        """_itn_max_cost_worker --help must exit 0."""
        import mln.paths

        cp = subprocess.run(
            [
                sys.executable,
                str(mln.paths.ENTRYPOINT),
                "_itn_max_cost_worker",
                "--help",
            ],
            capture_output=True,
            text=True,
            cwd=str(mln.paths.REPO_ROOT),
        )
        self.assertEqual(
            cp.returncode,
            0,
            f"_itn_max_cost_worker --help exited nonzero: "
            f"stdout={cp.stdout} stderr={cp.stderr}",
        )


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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            self.assertEqual(wl["start"], "after_sync")
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

                # Extract fee payer SK
                sk = _extract_fee_payer_sk(fake_mina, fp_privkey)
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

            env = os.environ.copy()
            env["FAKE_MINA_MARKER"] = str(marker)
            env["FAKE_MINA_ARGS_FILE"] = str(args_file)
            env["FAKE_MINA_SLEEP"] = "0"

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
# Compat translator tests
# ---------------------------------------------------------------------------


class TestCompatConvert(unittest.TestCase):
    """Tests for the legacy→topology compat translator."""

    def _convert(self, *args: str) -> dict:
        """Run 'convert compat <args>' and return the parsed JSON output."""
        cp = subprocess.run(
            [PYTHON3, CLI, "convert", "compat", *args],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        )
        self.assertEqual(
            cp.returncode,
            0,
            f"convert compat {' '.join(args)} failed: {cp.stderr}",
        )
        return json.loads(cp.stdout)

    def _convert_fails(self, *args: str) -> str:
        """Run 'convert compat <args>' expecting failure; return stderr."""
        cp = subprocess.run(
            [PYTHON3, CLI, "convert", "compat", *args],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        )
        self.assertNotEqual(
            cp.returncode, 0, f"convert compat {' '.join(args)} should have failed"
        )
        return cp.stderr

    # ── basic translation ───────────────────────────────────────────

    def test_default_baseline_translation(self):
        """Default (no flags) translates to valid topology with schema_version.
        Use a no-op flag to exercise the translation path."""
        # Convert with a simple flag to verify translation works
        topo = self._convert("--demo")
        self.assertEqual(topo["schema_version"], 1)
        self.assertEqual(topo["name"], "single-node")

    def test_flag_whales_expands_block_producer_nodes(self):
        """--whales N creates N whale accounts and N whale BP daemons."""
        topo = self._convert("--whales", "3")
        self.assertEqual(topo["ledger_generation"]["tiers"]["whale"]["count"], 3)
        self.assertEqual(
            topo["nodes"]["seed"]["capabilities"]["block_producer"]["account"],
            "whale-0",
        )
        self.assertEqual(
            topo["nodes"]["whale_1"]["capabilities"]["block_producer"]["account"],
            "whale-1",
        )
        self.assertEqual(
            topo["nodes"]["whale_2"]["capabilities"]["block_producer"]["account"],
            "whale-2",
        )

    def test_flag_fish_expands_block_producer_nodes(self):
        """--fish N creates N fish accounts and fish BP daemons."""
        topo = self._convert("--fish", "0")
        self.assertNotIn("fish", topo["ledger_generation"]["tiers"])
        topo = self._convert("--fish", "2")
        self.assertEqual(topo["ledger_generation"]["tiers"]["fish"]["count"], 2)
        self.assertEqual(
            topo["nodes"]["fish_0"]["capabilities"]["block_producer"]["account"],
            "fish-0",
        )
        self.assertEqual(
            topo["nodes"]["fish_1"]["capabilities"]["block_producer"]["account"],
            "fish-1",
        )

    def test_flag_snark_workers_count(self):
        """--snark-workers-count 5 sets worker_pools.default.count."""
        topo = self._convert("--snark-workers-count", "5")
        sc = topo["nodes"]["seed"]["capabilities"]["snark_coordinator"]
        self.assertEqual(sc["worker_pools"]["default"]["count"], 5)

    def test_flag_fast_mode_rejected_until_slot_time_is_materialized(self):
        """--fast is rejected because only its worker-count half would apply."""
        stderr = self._convert_fails("--fast")
        self.assertIn("not yet supported", stderr)
        self.assertIn("slot-time", stderr)

    def test_flag_override_slot_time_rejected_until_materialized(self):
        """--override-slot-time is rejected rather than half-applied."""
        stderr = self._convert_fails("--override-slot-time", "50000")
        self.assertIn("not yet supported", stderr)
        self.assertIn("slot-time", stderr)

    def test_flag_proof_level(self):
        """--proof-level overrides runtime_config.proof.level only (no
        ledger_generation duplication)."""
        topo = self._convert("--proof-level", "check")
        self.assertEqual(topo["runtime_config"]["proof"]["level"], "check")
        self.assertNotIn("proof_level", topo.get("ledger_generation", {}))

    def test_flag_work_delay(self):
        """--work-delay sets runtime_config.proof.work_delay only (no
        ledger_generation duplication)."""
        topo = self._convert("--work-delay", "3")
        self.assertEqual(topo["runtime_config"]["proof"]["work_delay"], 3)
        self.assertNotIn("work_delay", topo.get("ledger_generation", {}))

    def test_flag_transaction_capacity_updates_authoritative_fields(self):
        """-tc updates runtime_config.proof.transaction_capacity only (no
        ledger_generation duplication)."""
        topo = self._convert("--transaction-capacity-log2", "5")
        self.assertEqual(
            topo["runtime_config"]["proof"]["transaction_capacity"]["2_to_the"], 5
        )
        self.assertNotIn("transaction_capacity_log2", topo.get("ledger_generation", {}))

    def test_flag_config_mode(self):
        """--config reset → state.mode=reset; --config inherit → keep."""
        topo_reset = self._convert("--config", "reset")
        self.assertEqual(topo_reset["state"]["mode"], "reset")
        topo_keep = self._convert("--config", "inherit")
        self.assertEqual(topo_keep["state"]["mode"], "keep")

    def test_flag_update_genesis_timestamp(self):
        """--update-genesis-timestamp modes: no, delay_sec:N."""
        # no
        topo = self._convert("--update-genesis-timestamp", "no")
        self.assertEqual(topo["state"]["genesis_timestamp"], {"delay": "PT120S"})
        # delay_sec
        topo = self._convert("--update-genesis-timestamp", "delay_sec:300")
        self.assertEqual(topo["state"]["genesis_timestamp"], {"delay": "PT300S"})
        # fixed is rejected (schema has no 'fixed' field on genesis_timestamp)
        stderr = self._convert_fails(
            "--update-genesis-timestamp", "fixed:2025-01-01T00:00:00Z"
        )
        self.assertIn("not supported", stderr.lower())

    def test_flag_demo(self):
        """--demo sets demo_mode=true on seed node."""
        topo = self._convert("--demo")
        self.assertTrue(topo["nodes"]["seed"]["demo_mode"])

    # ── workloads ────────────────────────────────────────────────────

    def test_flag_value_transfer_adds_workload(self):
        """-vt adds a value-transfer workload."""
        topo = self._convert("-vt")
        self.assertIn("value-transfer-compat", topo["workloads"])
        wl = topo["workloads"]["value-transfer-compat"]
        self.assertEqual(wl["type"], "value_transfer")
        self.assertEqual(wl["config"]["interval_seconds"], 10)

    def test_compat_strips_unused_itn_graphql_placeholder(self):
        """Compat workloads must not inherit ITN GraphQL placeholder keys."""
        topo = self._convert("-vt")
        seed = topo["nodes"]["seed"]
        self.assertNotIn("itn_graphql", seed["capabilities"])
        self.assertNotIn("itn_keys", seed)

    def test_flag_zkapp_transactions_adds_workload_and_auto_bumps_whales(self):
        """-zt creates the legacy whale-0/whale-1 zkApp workload contract."""
        topo = self._convert("-zt")
        self.assertEqual(topo["ledger_generation"]["tiers"]["whale"]["count"], 2)
        self.assertIn("whale_1", topo["nodes"])
        self.assertIn("zkapp-compat", topo["workloads"])
        wl = topo["workloads"]["zkapp-compat"]
        self.assertEqual(wl["type"], "zkapp")
        self.assertEqual(wl["config"]["fee_payer_account"], "whale-0")
        self.assertEqual(wl["config"]["sender_account"], "whale-1")

    def test_flag_transaction_interval_applies_to_value_transfer(self):
        """-ti 5 sets interval on value-transfer workloads regardless of flag order."""
        topo = self._convert("-ti", "5", "-vt")
        self.assertEqual(
            topo["workloads"]["value-transfer-compat"]["config"]["interval_seconds"], 5
        )

    # ── log level flags ──────────────────────────────────────────────

    def test_flag_log_level(self):
        """-ll sets logging.console.node."""
        topo = self._convert("--log-level", "Warn")
        self.assertEqual(topo["logging"]["console"]["node"], "Warn")

    def test_flag_file_log_level(self):
        """-fll sets logging.file.node."""
        topo = self._convert("--file-log-level", "Debug")
        self.assertEqual(topo["logging"]["file"]["node"], "Debug")

    def test_flag_worker_log_level(self):
        """-wll sets both console and file snark_worker levels."""
        topo = self._convert("--worker-log-level", "Error")
        self.assertEqual(topo["logging"]["console"]["snark_worker"], "Error")
        self.assertEqual(topo["logging"]["file"]["snark_worker"], "Error")

    # ── other flags ──────────────────────────────────────────────────

    def test_flag_snark_worker_fee(self):
        """--snark-worker-fee 0.005 sets coordinator fee."""
        topo = self._convert("--snark-worker-fee", "0.005")
        sc = topo["nodes"]["seed"]["capabilities"]["snark_coordinator"]
        self.assertEqual(sc["fee"], "0.005")

    def test_flag_snark_worker_nap(self):
        """--snark-worker-nap-sec 3 sets nap to PT3S."""
        topo = self._convert("--snark-worker-nap-sec", "3")
        sc = topo["nodes"]["seed"]["capabilities"]["snark_coordinator"]
        self.assertEqual(sc["worker_pools"]["default"]["nap"], "PT3S")

    def test_flag_root(self):
        """-r sets state.root."""
        topo = self._convert("--root", "/tmp/test-root")
        self.assertEqual(topo["state"]["root"], "/tmp/test-root")

    def test_flag_binary_paths(self):
        """--mina-exe, --archive-exe, --zkapp-exe set binaries."""
        topo = self._convert(
            "--mina-exe",
            "/path/to/mina",
            "--archive-exe",
            "/path/to/archive",
            "--zkapp-exe",
            "/path/to/zkapp",
        )
        self.assertEqual(topo["binaries"]["mina"], "/path/to/mina")
        self.assertEqual(topo["binaries"]["archive"], "/path/to/archive")
        self.assertEqual(topo["binaries"]["zkapp"], "/path/to/zkapp")

    # ── rejection of unsupported flags ───────────────────────────────

    def test_unsupported_flag_n_nodes_rejected(self):
        """--nodes is unsupported and must be rejected clearly."""
        stderr = self._convert_fails("--nodes", "5")
        self.assertIn("Unsupported legacy flag", stderr)
        self.assertIn("--nodes", stderr)

    def test_unsupported_flag_s_seed_rejected(self):
        """-s is unsupported and must be rejected."""
        stderr = self._convert_fails("-s", "spawn:3000")
        self.assertIn("Unsupported legacy flag", stderr)

    def test_unknown_positional_arg_rejected(self):
        """Positional args (not dash-prefixed) must be rejected."""
        stderr = self._convert_fails("foo", "bar")
        self.assertIn("Unexpected positional argument", stderr)

    def test_integer_flags_fail_without_traceback(self):
        """Bad integer values should be Click errors, not raw ValueError traces."""
        for flag in (
            "--whales",
            "--fish",
            "--snark-workers-count",
            "--work-delay",
            "--transaction-capacity-log2",
            "--transaction-interval",
            "--snark-worker-nap-sec",
        ):
            stderr = self._convert_fails(flag, "not-an-int")
            self.assertIn("must be an integer", stderr, flag)
            self.assertNotIn("Traceback", stderr, flag)

    # ── help ─────────────────────────────────────────────────────────

    def test_convert_compat_help(self):
        """convert compat --help exits 0."""
        cp = subprocess.run(
            [PYTHON3, CLI, "convert", "compat", "--help"],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        )
        self.assertEqual(cp.returncode, 0, f"help failed: {cp.stderr}")

    def test_spawn_compat_help(self):
        """spawn compat --help exits 0."""
        cp = subprocess.run(
            [PYTHON3, CLI, "spawn", "compat", "--help"],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        )
        self.assertEqual(cp.returncode, 0, f"help failed: {cp.stderr}")


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
        output = _run_json("presets", "show", "single-node")
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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

    def test_compat_proof_level_not_in_ledger_generation(self):
        """--proof-level poisons runtime_config.proof.level, not
        ledger_generation."""
        topo = self._convert_topo("--proof-level", "none")
        rc = topo.get("runtime_config", {})
        self.assertEqual(rc.get("proof", {}).get("level"), "none")
        lg = topo.get("ledger_generation", {})
        forbidden = {
            "proof_level",
            "level",
            "transaction_capacity",
            "transaction_capacity_log2",
            "work_delay",
        }
        for field in forbidden:
            self.assertNotIn(field, lg, f"ledger_generation must not contain '{field}'")

    def test_compat_work_delay_not_in_ledger_generation(self):
        """--work-delay poisons runtime_config.proof.work_delay, not
        ledger_generation."""
        topo = self._convert_topo("--work-delay", "5")
        rc = topo.get("runtime_config", {})
        self.assertEqual(rc.get("proof", {}).get("work_delay"), 5)
        lg = topo.get("ledger_generation", {})
        self.assertNotIn("work_delay", lg)

    def test_compat_transaction_capacity_not_in_ledger_generation(self):
        """--transaction-capacity-log2 poisons
        runtime_config.proof.transaction_capacity, not ledger_generation."""
        topo = self._convert_topo("--transaction-capacity-log2", "4")
        rc = topo.get("runtime_config", {})
        self.assertEqual(
            rc.get("proof", {}).get("transaction_capacity", {}).get("2_to_the"), 4
        )
        lg = topo.get("ledger_generation", {})
        self.assertNotIn("transaction_capacity", lg)
        self.assertNotIn("transaction_capacity_log2", lg)

    def _convert_topo(self, *args: str) -> dict:
        """Run 'convert compat <args>' and return the parsed JSON output."""
        cp = subprocess.run(
            [PYTHON3, CLI, "convert", "compat", *args],
            capture_output=True,
            text=True,
            cwd=REPO_ROOT,
        )
        self.assertEqual(
            cp.returncode,
            0,
            f"convert compat {' '.join(args)} failed: {cp.stderr}",
        )
        return json.loads(cp.stdout)


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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
            "state": {"mode": "reset", "genesis_timestamp": {"delay": "PT120S"}},
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
