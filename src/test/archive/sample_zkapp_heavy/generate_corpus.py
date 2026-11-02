#!/usr/bin/env python3
"""Regenerate the zkApp-heavy precomputed-block corpus.

Bootstraps a small local network, submits heavy zkApp update-state
transactions, then extracts and repackages the produced precomputed blocks into
precomputed_blocks.tar.xz next to this script.

Build the binaries first, inside `nix develop mina`:

    dune build src/app/cli/src/mina.exe src/app/archive/archive.exe \\
      src/app/zkapp_test_transaction/zkapp_test_transaction.exe \\
      src/app/mina_graphql_client/mina_graphql_client_app.exe \\
      src/app/logproc/logproc.exe
"""

import argparse
import hashlib
import json
import os
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent


def log(message):
    print(f"[gen] {message}", flush=True)


def repo_root():
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=HERE,
        check=True,
        capture_output=True,
        text=True,
    )
    return Path(out.stdout.strip())


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--count", type=int, default=120, help="update-state commands to submit"
    )
    parser.add_argument(
        "--num-events", type=int, default=20, help="events per command"
    )
    parser.add_argument(
        "--num-actions", type=int, default=20, help="actions per command"
    )
    parser.add_argument(
        "--elements-per",
        type=int,
        default=8,
        help="field elements per event and per action",
    )
    parser.add_argument(
        "--whales", type=int, default=2, help="block-producing whale nodes"
    )
    parser.add_argument(
        "--network-dir",
        type=Path,
        default=Path(os.environ.get("MINA_NETWORK_DIR", Path.home() / ".mina-network")),
        help="local network directory",
    )
    parser.add_argument(
        "--rest-uri",
        default=os.environ.get("MINA_REST_URI", "http://127.0.0.1:4001/graphql"),
        help="GraphQL endpoint of the first whale",
    )
    parser.add_argument(
        "--genesis-delay-sec",
        type=int,
        default=180,
        help="how far in the future genesis is set; a future genesis avoids the "
        "multi-node fork stall at startup",
    )
    parser.add_argument(
        "--drain-sec",
        type=int,
        default=240,
        help="how long to wait for the mempool to drain into blocks",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=HERE / "precomputed_blocks.tar.xz",
        help="corpus archive to write",
    )
    return parser.parse_args()


def run(command, quiet=False, **kwargs):
    """Run a command and return its stdout, never raising on failure.

    A failure is reported rather than swallowed: an empty stdout otherwise
    resurfaces much later as a no-op send_raw, which says nothing about the
    keypair or zkApp command that actually failed. Callers that poll -- where a
    failure is the expected answer until the network is up -- pass quiet=True.
    """
    result = subprocess.run(
        command, capture_output=True, text=True, check=False, **kwargs
    )
    if result.returncode != 0 and not quiet:
        log(f"WARNING: {Path(command[0]).name} exited with {result.returncode}")
        # the GraphQL client reports a rejected request on stdout
        for line in (result.stderr + result.stdout).strip().splitlines()[-20:]:
            log(f"  {line}")
    return result.stdout


class Client:
    """The bits of mina_graphql_client_app this script needs."""

    def __init__(self, binary, rest_uri):
        self.binary = str(binary)
        self.rest_uri = rest_uri

    def account(self, public_key):
        out = run(
            [
                self.binary,
                "account",
                "--graphql-uri",
                self.rest_uri,
                "--public-key",
                public_key,
            ],
            quiet=True,
        )
        # one pretty-printed object; older clients printed one object per line
        try:
            documents = [json.loads(out)]
        except json.JSONDecodeError:
            documents = []
            for line in out.splitlines():
                try:
                    documents.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        return [d for d in documents if isinstance(d, dict)]

    def nonce_of(self, public_key):
        """The next nonce to use: the inferred nonce (which counts the
        mempool) when the node reports one, else the ledger nonce. The
        client omits inferred_nonce when the node returns null for it."""
        nonces = [
            int(a[key])
            for a in self.account(public_key)
            for key in ("inferred_nonce", "nonce")
            if a.get(key) is not None
        ]
        return max(nonces, default=0)

    def is_onchain(self, public_key):
        accounts = self.account(public_key)
        return bool(accounts) and accounts[-1].get("total_balance") is not None

    def sync_status(self):
        out = run(
            [self.binary, "sync-status", "--graphql-uri", self.rest_uri], quiet=True
        )
        try:
            return json.loads(out).get("sync_status")
        except (json.JSONDecodeError, AttributeError):
            return None

    def send_raw(self, query):
        return run(
            [
                self.binary,
                "send-raw",
                "--graphql-uri",
                self.rest_uri,
                "--query",
                query,
            ]
        )


def graphql_query_of(text):
    """The GraphQL query zkapp_test_transaction printed, without its preamble.

    The command prints keyfile prompts before the query, so the query is
    located by its own first line rather than by a preamble line count, which
    would silently truncate the query if that preamble ever gained a line.
    """
    lines = text.splitlines()
    # graphql_zkapp_command emits `mutation MyMutation {`; the other openings
    # are a fallback should that ever be reshaped.
    for openings in (("mutation",), ("query", "{")):
        for index, line in enumerate(lines):
            if line.lstrip().startswith(openings):
                return "\n".join(lines[index:])
    log("WARNING: no GraphQL query found in the zkapp_test_transaction output")
    return ""


def network_log(args):
    return args.network_dir.with_name(f"{args.network_dir.name}-localnet.log")


def start_network(root, args):
    """Spawn the local network in the background.

    Returns (process, logfile); the caller closes the log file once the
    network is down.
    """
    # the script empties its root itself, but only after it has started; a key
    # left by an earlier run would be read as this network's in the meantime
    shutil.rmtree(args.network_dir, ignore_errors=True)
    args.network_dir.mkdir(parents=True)
    log(f"bootstrapping local network ({args.whales} whales)...")
    # beside the root, not in it: the network script empties its root on start
    logfile = network_log(args).open("w", encoding="utf-8")
    # --proof-level none and long slots keep the network light; a future genesis
    # avoids the multi-node fork stall at startup.
    network = subprocess.Popen(
        [
            str(root / "scripts/mina-local-network/mina-local-network.sh"),
            "--root",
            str(args.network_dir),
            "--config",
            "reset",
            "--whales",
            str(args.whales),
            "--fish",
            "0",
            "--nodes",
            "0",
            "--proof-level",
            "none",
            "--override-slot-time",
            "30000",
            "--update-genesis-timestamp",
            f"delay_sec:{args.genesis_delay_sec}",
            "--log-precomputed-blocks",
        ],
        cwd=root,
        stdout=logfile,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    return network, logfile


def wait_for_synced(client, attempts=120, delay=10):
    """Answering GraphQL is not enough: a node that is still bootstrapping
    rejects sendZkapp, and the deploy is sent only once."""
    for _ in range(attempts):
        if client.sync_status() == "Synced":
            return
        time.sleep(delay)
    sys.exit("[gen] ERROR: the node never reported Synced")


def wait_for_key(network, path, args, timeout=600):
    """The whale key the network script writes while it initialises its root.

    The script resets that directory first, so the key is not there until it
    has done so; it exiting before then means it failed.
    """
    deadline = time.monotonic() + timeout
    while not path.is_file():
        if network.poll() is not None:
            sys.exit(
                f"[gen] ERROR: the network script exited ({network.returncode}) "
                f"before writing {path}; see {network_log(args)}"
            )
        if time.monotonic() > deadline:
            sys.exit(f"[gen] ERROR: {path} not written within {timeout}s")
        time.sleep(2)
    return path.read_text(encoding="utf-8").strip()


def wait_for_rest(client, public_key, attempts=120, delay=10):
    log("waiting for the network (genesis is in the future)...")
    for _ in range(attempts):
        if client.account(public_key):
            return
        time.sleep(delay)
    sys.exit("[gen] ERROR: network REST never came up")


def deploy_zkapp_account(zkapp_binary, client, fee_payer, fee_payer_pub, zkapp_key):
    """Deploy the zkApp account, using the same whale as fee-payer AND sender.

    With distinct keys create_zkapp_command sets the sender nonce precondition
    to succ(sender_nonce), which no external nonce satisfies.
    """
    zkapp_pub = Path(f"{zkapp_key}.pub").read_text(encoding="utf-8").strip()
    if client.is_onchain(zkapp_pub):
        return client.nonce_of(fee_payer_pub)
    nonce = client.nonce_of(fee_payer_pub)
    log(f"deploying zkApp account (fee-payer=sender nonce={nonce})...")
    query = graphql_query_of(
        run(
            [
                str(zkapp_binary),
                "create-zkapp-account",
                "--fee-payer-key",
                str(fee_payer),
                "--nonce",
                str(nonce),
                "--sender-key",
                str(fee_payer),
                "--sender-nonce",
                str(nonce),
                "--receiver-amount",
                "1000",
                "--zkapp-account-key",
                str(zkapp_key),
                "--fee",
                "5",
            ]
        )
    )
    log(f"deploy response: {client.send_raw(query).strip()[:200]}")
    # applied = the account exists and the fee payer's nonce moved past it;
    # the caller continues from the returned nonce
    for _ in range(40):
        onchain = client.is_onchain(zkapp_pub)
        payer_nonce = client.nonce_of(fee_payer_pub)
        if onchain and payer_nonce > nonce:
            return nonce + 1
        log(f"deploy pending: zkapp on chain={onchain}, fee payer nonce={payer_nonce}")
        time.sleep(15)
    sys.exit("[gen] ERROR: deploy never applied")


def submit_load(
    zkapp_binary, client, args, fee_payer, fee_payer_pub, zkapp_key, nonce
):
    # counted here and only ever raised: an inferred nonce read while the node
    # is busy can come back stale, and resending under it is Invalid_nonce
    nonce = max(nonce, client.nonce_of(fee_payer_pub))
    submitted = 0
    log(
        f"submitting {args.count} heavy update-states "
        f"(events={args.num_events} actions={args.num_actions} "
        f"elems={args.elements_per})..."
    )
    for i in range(args.count):
        query = graphql_query_of(
            run(
                [
                    str(zkapp_binary),
                    "update-state",
                    "--fee-payer-key",
                    str(fee_payer),
                    "--nonce",
                    str(nonce),
                    "--zkapp-account-key",
                    str(zkapp_key),
                    "--zkapp-state",
                    str((i % 7) + 1),
                    "--num-events",
                    str(args.num_events),
                    "--num-actions",
                    str(args.num_actions),
                    "--event-elements-per",
                    str(args.elements_per),
                    "--action-elements-per",
                    str(args.elements_per),
                    "--fee",
                    "5",
                ]
            )
        )
        if '"hash":"' in client.send_raw(query):
            submitted += 1
            nonce += 1
        else:
            # a rejected command consumes no nonce
            time.sleep(3)
            nonce = max(nonce, client.nonce_of(fee_payer_pub))
        time.sleep(3)
    return submitted


def zkapp_totals(block):
    """Count zkApp commands and their event/action fields in one block."""
    commands = events = actions = 0
    for part in block.get("staged_ledger_diff", {}).get("diff", []):
        if not part:
            continue
        for command in part.get("commands", []):
            data = command.get("data")
            if not (isinstance(data, list) and data and data[0] == "Zkapp_command"):
                continue
            commands += 1
            for update in data[1].get("account_updates") or []:
                body = (
                    update["elt"]["account_update"]["body"]
                    if "elt" in update
                    else update.get("body", {})
                )
                events += sum(len(x) for x in body.get("events") or [])
                actions += sum(len(x) for x in body.get("actions") or [])
    return commands, events, actions


def extract_blocks(logfile, destination):
    """Write one JSON file per distinct block, named <height>_<digest>.json."""
    seen = set()
    rows = []
    commands = events = actions = 0
    with open(logfile, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                block = json.loads(line)
            except json.JSONDecodeError:
                continue
            block = block.get("data", block)
            try:
                height = int(
                    block["protocol_state"]["body"]["consensus_state"][
                        "blockchain_length"
                    ]
                )
            except (KeyError, TypeError, ValueError):
                continue
            digest = hashlib.md5(line.encode("utf-8", "replace")).hexdigest()[:10]
            if digest in seen:
                continue
            seen.add(digest)
            block_commands, block_events, block_actions = zkapp_totals(block)
            commands += block_commands
            events += block_events
            actions += block_actions
            rows.append((height, digest, line))

    rows.sort(key=lambda row: (row[0], row[1]))
    for height, digest, line in rows:
        (destination / f"{height:07d}_{digest}.json").write_text(
            line, encoding="utf-8"
        )
    log(
        f"extracted {len(rows)} blocks, {commands} zkApp cmds, "
        f"{events} event fields, {actions} action fields"
    )
    return len(rows)


def main():
    # turn SIGTERM into SystemExit, so the finally below takes the network down
    signal.signal(signal.SIGTERM, lambda *_: sys.exit("[gen] terminated"))
    args = parse_args()
    root = repo_root()
    build = root / "_build/default"
    zkapp_binary = build / "src/app/zkapp_test_transaction/zkapp_test_transaction.exe"
    client = Client(
        build / "src/app/mina_graphql_client/mina_graphql_client_app.exe",
        args.rest_uri,
    )
    os.environ.setdefault("MINA_PRIVKEY_PASS", "naughty blue worm")

    network, logfile = start_network(root, args)
    try:
        fee_payer = args.network_dir / "offline_whale_keys/offline_whale_account_0"
        fee_payer_pub = wait_for_key(network, Path(f"{fee_payer}.pub"), args)
        wait_for_rest(client, fee_payer_pub)
        wait_for_synced(client)

        zkapp_key = args.network_dir / "zkapp_keys/zkapp_account"
        zkapp_key.parent.mkdir(parents=True, exist_ok=True)
        if not zkapp_key.exists():
            run(
                [
                    str(build / "src/app/cli/src/mina.exe"),
                    "advanced",
                    "generate-keypair",
                    "--privkey-path",
                    str(zkapp_key),
                ]
            )
        nonce = deploy_zkapp_account(
            zkapp_binary, client, fee_payer, fee_payer_pub, zkapp_key
        )

        submitted = submit_load(
            zkapp_binary, client, args, fee_payer, fee_payer_pub, zkapp_key, nonce
        )
        log(
            f"submitted ok={submitted}/{args.count}; waiting {args.drain_sec}s "
            "for the mempool to drain into blocks..."
        )
        time.sleep(args.drain_sec)

        blocks_log = args.network_dir / "nodes/whale_0/precomputed_blocks.log"
        if not blocks_log.is_file():
            sys.exit(f"[gen] ERROR: no precomputed_blocks.log at {blocks_log}")

        # the network's config travels with the corpus, as its genesis
        shutil.copyfile(
            args.network_dir / "daemon.json", args.output.with_name("genesis.json")
        )

        workdir = Path(tempfile.mkdtemp())
        try:
            extract_blocks(blocks_log, workdir)
            with tarfile.open(args.output, "w:xz") as archive:
                for block_file in sorted(workdir.iterdir()):
                    archive.add(block_file, arcname=block_file.name)
        finally:
            shutil.rmtree(workdir, ignore_errors=True)
    finally:
        # the network script spawns a process group; take the whole group down
        os.killpg(os.getpgid(network.pid), signal.SIGTERM)
        try:
            network.wait(timeout=30)
        except subprocess.TimeoutExpired:
            os.killpg(os.getpgid(network.pid), signal.SIGKILL)
            network.wait()
        logfile.close()

    size_mib = args.output.stat().st_size / (1024 * 1024)
    log(f"wrote {args.output} ({size_mib:.1f} MiB)")


if __name__ == "__main__":
    main()
