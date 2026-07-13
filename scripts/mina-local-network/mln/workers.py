from __future__ import annotations

import base64
import json
import os
import re
import struct
import subprocess
import tempfile
import time
import urllib.request
from typing import Optional, Tuple
from urllib.error import HTTPError, URLError

import click

from mln.errors import (
    ErrorCode,
    GraphQLError,
    KeyError_,
)
from mln.graphql import (
    account_inferred_nonce,
    extract_graphql_document,
    graphql_post,
)
from mln.models import GraphQLResponse, ITNAuthResult


# ── ITN Ed25519 signing helpers ──────────────────────────────────────────


def ed25519_sign_raw(privkey_path: str, message: bytes) -> bytes:
    """Sign *message* with an Ed25519 private key via openssl pkeyutl.

    Returns raw 64-byte signature bytes.  Raises ``KeyError_`` on
    failure.
    """
    _tmp_path: str = ""
    try:
        _tmp_dir = os.path.dirname(privkey_path) or None
        with tempfile.NamedTemporaryFile(delete=False, dir=_tmp_dir) as _tf:
            _tf.write(message)
            _tf.flush()
            _tmp_path = _tf.name
        result = subprocess.run(
            [
                "openssl",
                "pkeyutl",
                "-sign",
                "-inkey",
                privkey_path,
                "-rawin",
                "-in",
                _tmp_path,
            ],
            capture_output=True,
        )
        if result.returncode != 0:
            raise KeyError_(
                ErrorCode.SIGNING_FAILED,
                message=f"openssl pkeyutl -sign failed: "
                f"{result.stderr.decode(errors='replace').strip()}",
            )
        return result.stdout
    except KeyError_:
        raise
    except (OSError, subprocess.SubprocessError) as exc:
        raise KeyError_(
            ErrorCode.SIGNING_FAILED,
            message=f"openssl signing failed: {exc}",
        ) from exc
    finally:
        if _tmp_path:
            try:
                os.unlink(_tmp_path)
            except OSError:
                pass


def _b64raw_sig(privkey_path: str, message: bytes) -> str:
    """Return a base64-encoded Ed25519 signature over *message*."""
    return base64.b64encode(ed25519_sign_raw(privkey_path, message)).decode("ascii")


def _itngraphql_post(
    uri: str,
    body: bytes,
    auth_header: str,
    *,
    timeout: float = 60.0,
) -> GraphQLResponse:
    """POST body to an ITN GraphQL endpoint with an Authorization header.

    Returns a validated ``GraphQLResponse``.  Raises on HTTP failure,
    top-level ``errors``, or null/missing ``data``.  Never logs the
    request body or Authorization header on error.
    """
    req = urllib.request.Request(
        uri,
        data=body,
        headers={
            "Content-Type": "application/json",
            "Authorization": auth_header,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if not (200 <= resp.status < 300):
                raise GraphQLError(
                    ErrorCode.HTTP_ERROR,
                    message=f"ITN GraphQL POST returned HTTP {resp.status}",
                )
            raw = resp.read().decode("utf-8")
    except GraphQLError:
        raise
    except (HTTPError, URLError, OSError) as exc:
        raise GraphQLError(
            ErrorCode.HTTP_ERROR,
            message=f"ITN GraphQL POST to {uri} failed: {exc}",
        ) from exc

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise GraphQLError(
            ErrorCode.GRAPHQL_PARSE_ERROR,
            message=f"ITN GraphQL response is not valid JSON: {exc}",
        ) from exc

    if "errors" in parsed and parsed.get("errors"):
        raise GraphQLError(
            ErrorCode.GRAPHQL_ERROR,
            message="ITN GraphQL returned errors (details omitted)",
        )
    if not isinstance(parsed.get("data"), dict):
        raise GraphQLError(
            ErrorCode.GRAPHQL_RESPONSE_INVALID,
            message="ITN GraphQL response has null or non-object data",
        )
    return GraphQLResponse.model_validate(parsed)


def _itn_auth(
    itn_uri: str,
    privkey_path: str,
    pubkey_b64: str,
    *,
    timeout_sec: float = 60.0,
) -> Tuple[str, int]:
    """Authenticate to the ITN GraphQL endpoint.

    Polls until success or *timeout_sec*.  Returns ``(serverUuid,
    signerSequenceNumber)``.
    """
    auth_body = json.dumps(
        {"query": "query { auth { serverUuid signerSequenceNumber } }"}
    ).encode("utf-8")
    sig = _b64raw_sig(privkey_path, auth_body)
    auth_header = f"Signature {pubkey_b64} {sig}"

    deadline = time.time() + timeout_sec
    last_exc: Optional[GraphQLError] = None
    while time.time() < deadline:
        try:
            response = _itngraphql_post(itn_uri, auth_body, auth_header)
            auth_data = response.data.get("auth")
            if isinstance(auth_data, dict):
                try:
                    result = ITNAuthResult.model_validate(auth_data)
                    return result.server_uuid, result.signer_sequence_number
                except ValueError as exc:
                    raise GraphQLError(
                        ErrorCode.GRAPHQL_RESPONSE_INVALID,
                        message=f"ITN auth response malformed: {exc}",
                    ) from exc
        except GraphQLError as exc:
            last_exc = exc
        time.sleep(1.0)

    raise GraphQLError(
        ErrorCode.GRAPHQL_READY_TIMEOUT,
        message=f"ITN auth endpoint not ready after {timeout_sec}s. Last error: {last_exc}",
    )


def _itn_schedule_mutation(
    itn_uri: str,
    privkey_path: str,
    pubkey_b64: str,
    fee_payer_sk: str,
    *,
    duration_min: int,
    tps: float,
    num_zkapps_to_deploy: int,
    max_cost_num_updates: int,
    num_new_accounts: int,
    account_queue_size: int,
    memo_prefix: str,
    no_precondition: bool,
    min_balance_change: str,
    max_balance_change: str,
    min_new_zkapp_balance: str,
    max_new_zkapp_balance: str,
    init_balance: str,
    min_fee: str,
    max_fee: str,
    deployment_fee: str,
) -> None:
    """Authenticate and post a scheduleZkappCommands mutation."""

    uuid, seqno = _itn_auth(itn_uri, privkey_path, pubkey_b64)

    zkapp_input: dict = {
        "feePayers": [fee_payer_sk],
        "numZkappsToDeploy": num_zkapps_to_deploy,
        "numNewAccounts": num_new_accounts,
        "tps": tps,
        "durationMin": duration_min,
        "memoPrefix": memo_prefix,
        "noPrecondition": no_precondition,
        "minBalanceChange": min_balance_change,
        "maxBalanceChange": max_balance_change,
        "minNewZkappBalance": min_new_zkapp_balance,
        "maxNewZkappBalance": max_new_zkapp_balance,
        "initBalance": init_balance,
        "minFee": min_fee,
        "maxFee": max_fee,
        "deploymentFee": deployment_fee,
        "accountQueueSize": account_queue_size,
        "maxCost": True,
        "maxCostNumUpdates": max_cost_num_updates,
    }
    mutation_body = json.dumps(
        {
            "query": (
                "mutation($input: ZkappCommandsDetails!) "
                "{ scheduleZkappCommands(input: $input) }"
            ),
            "variables": {"input": zkapp_input},
        }
    ).encode("utf-8")

    # The ITN protocol signs a two-byte big-endian sequence number, matching
    # the legacy max-cost-load.sh layout and graphql_internal.ml verifier.
    msg: bytes = struct.pack(">H", seqno) + uuid.encode("utf-8") + mutation_body
    sig: str = _b64raw_sig(privkey_path, msg)
    mutation_header: str = f"Signature {pubkey_b64} {sig} ; Sequencing {uuid} {seqno}"

    response = _itngraphql_post(itn_uri, mutation_body, mutation_header)
    if "scheduleZkappCommands" not in response.data:
        raise GraphQLError(
            ErrorCode.GRAPHQL_RESPONSE_INVALID,
            message="ITN GraphQL response is missing scheduleZkappCommands result",
        )
    click.echo(
        f"ITN max-cost: scheduleZkappCommands posted successfully "
        f"(duration={duration_min}m, tps={tps:.6f}).",
        err=True,
    )


def _extract_fee_payer_sk(mina_exe: str, privkey_path: str) -> str:
    """Run ``mina advanced dump-keypair`` and extract the base58check SK.

    Returns the SK value after ``Private key: `` in the stdout.
    Raises ``KeyError_`` if extraction fails.
    """
    call_env = os.environ.copy()
    result = subprocess.run(
        [mina_exe, "advanced", "dump-keypair", "--privkey-path", privkey_path],
        env=call_env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise KeyError_(
            ErrorCode.KEY_EXTRACTION_FAILED,
            message=f"mina advanced dump-keypair failed (exit {result.returncode}): "
            f"{result.stderr.strip()}",
        )
    m = re.search(r"Private key:\s*(\S+)", result.stdout)
    if not m:
        raise KeyError_(
            ErrorCode.KEY_EXTRACTION_FAILED,
            message="Could not find 'Private key: <sk>' in dump-keypair output.",
        )
    return m.group(1)


# ── Click-argument-decorated command bodies (NOT registered on any group).
# cli.py registers them on the Click group so modules don't import cli
# directly (keeping the "cli is only imported by the shim" rule).


@click.argument("mina_exe", type=str)
@click.argument("rest_server", type=str)
@click.argument("sender_privkey_path", type=str)
@click.argument("sender_pubkey", type=str)
@click.argument("receiver_pubkey", type=str)
@click.argument("amount", type=str)
@click.argument("interval_secs", type=float)
@click.argument("count", type=int, required=False, default=None)
def vt_worker_body(
    mina_exe: str,
    rest_server: str,
    sender_privkey_path: str,
    sender_pubkey: str,
    receiver_pubkey: str,
    amount: str,
    interval_secs: float,
    count: Optional[int],
):
    """Internal value-transfer worker body (not intended for direct invocation).

    Imports and unlocks the sender account, then loops sending payments
    to the receiver.  Uses *mina_exe* for all client commands.  Exits 0
    after *count* sends (if given), or runs indefinitely.
    """
    # Phase 1: import account
    import_result = subprocess.run(
        [
            mina_exe,
            "account",
            "import",
            "-rest-server",
            rest_server,
            "-privkey-path",
            sender_privkey_path,
        ],
        capture_output=True,
        text=True,
    )
    if import_result.returncode != 0:
        click.echo(
            f"value_transfer: account import failed: {import_result.stderr}", err=True
        )
        raise SystemExit(import_result.returncode or 1)

    # Phase 2: unlock account
    unlock_result = subprocess.run(
        [
            mina_exe,
            "account",
            "unlock",
            "-rest-server",
            rest_server,
            "-public-key",
            sender_pubkey,
        ],
        capture_output=True,
        text=True,
    )
    if unlock_result.returncode != 0:
        click.echo(
            f"value_transfer: account unlock failed: {unlock_result.stderr}", err=True
        )
        raise SystemExit(unlock_result.returncode or 1)

    # Phase 3: send-payment loop
    send_count = 0
    while True:
        if interval_secs > 0:
            time.sleep(interval_secs)
        send_argv = [
            mina_exe,
            "client",
            "send-payment",
            "-rest-server",
            rest_server,
            "-amount",
            amount,
        ]
        if send_count == 0:
            # Match legacy reset-mode behavior: pin only the first transfer to
            # nonce 0, then let the daemon infer subsequent nonces.
            send_argv.extend(["-nonce", "0"])
        send_argv.extend(
            [
                "-receiver",
                receiver_pubkey,
                "-sender",
                sender_pubkey,
            ]
        )
        send_result = subprocess.run(
            send_argv,
            capture_output=True,
            text=True,
        )
        if send_result.returncode != 0:
            click.echo(
                f"value_transfer: send-payment failed: {send_result.stderr}", err=True
            )
            raise SystemExit(send_result.returncode or 1)
        send_count += 1
        if count is not None and send_count >= count:
            click.echo(
                f"value_transfer: completed {send_count} send(s), exiting.", err=True
            )
            break

    raise SystemExit(0)


@click.argument("zkapp_exe", type=str)
@click.argument("graphql_uri", type=str)
@click.argument("fee_payer_privkey_path", type=str)
@click.argument("fee_payer_pubkey", type=str)
@click.argument("sender_privkey_path", type=str)
@click.argument("sender_pubkey", type=str)
@click.argument("zkapp_privkey_path", type=str)
@click.argument("zkapp_pubkey", type=str)
@click.argument("transfer_amount", type=str)
@click.argument("receiver_amount", type=str)
@click.argument("fee", type=str)
@click.argument("interval_secs", type=float)
@click.option(
    "--create-account",
    is_flag=True,
    default=False,
    help="Create the zkApp account before starting the loop",
)
@click.argument("count", type=int, required=False, default=None)
def zkapp_worker_body(
    zkapp_exe: str,
    graphql_uri: str,
    fee_payer_privkey_path: str,
    fee_payer_pubkey: str,
    sender_privkey_path: str,
    sender_pubkey: str,
    zkapp_privkey_path: str,
    zkapp_pubkey: str,
    transfer_amount: str,
    receiver_amount: str,
    fee: str,
    interval_secs: float,
    create_account: bool,
    count: Optional[int],
):
    """Internal zkApp workload worker body (not intended for direct invocation).

    Runs create-zkapp-account optionally, then loops transfer-funds-one-receiver
    + update-state against the GraphQL endpoint.  Signs offline from key
    files — does NOT import or unlock accounts on the daemon.
    """
    call_env = os.environ.copy()

    # Phase 1: create zkApp account (if --create-account)
    if create_account:
        create_result = subprocess.run(
            [
                zkapp_exe,
                "create-zkapp-account",
                "--fee-payer-key",
                fee_payer_privkey_path,
                "--nonce",
                "0",
                "--sender-key",
                sender_privkey_path,
                "--sender-nonce",
                "0",
                "--receiver-amount",
                receiver_amount,
                "--zkapp-account-key",
                zkapp_privkey_path,
                "--fee",
                fee,
            ],
            env=call_env,
            capture_output=True,
            text=True,
        )
        if create_result.returncode != 0:
            click.echo(
                f"zkapp: create-zkapp-account failed: {create_result.stderr}", err=True
            )
            raise SystemExit(create_result.returncode or 1)
        create_mutation = extract_graphql_document(create_result.stdout)
        graphql_post(graphql_uri, create_mutation)

        # Poll until the zkApp account is visible via GraphQL
        _poll_deadline = time.time() + 60.0
        while time.time() < _poll_deadline:
            _acct_query = (
                f'query {{ account(publicKey: "{zkapp_pubkey}") {{ inferredNonce }} }}'
            )
            try:
                _resp = graphql_post(graphql_uri, _acct_query)
                if _resp.data.get("account") is not None:
                    break
            except GraphQLError:
                pass
            time.sleep(1.0)
        else:
            raise GraphQLError(
                ErrorCode.GRAPHQL_READY_TIMEOUT,
                message=f"zkapp: account creation timed out after 60s. "
                f"zkApp account {zkapp_pubkey} not found via GraphQL.",
            )

    # Phase 2: initialize nonces from GraphQL inferredNonce (null → 0)
    _fp_query = (
        f'query {{ account(publicKey: "{fee_payer_pubkey}") {{ inferredNonce }} }}'
    )
    _fp_resp = graphql_post(graphql_uri, _fp_query)
    fee_payer_nonce: int = account_inferred_nonce(
        _fp_resp,
        public_key=fee_payer_pubkey,
    )

    _snd_query = (
        f'query {{ account(publicKey: "{sender_pubkey}") {{ inferredNonce }} }}'
    )
    _snd_resp = graphql_post(graphql_uri, _snd_query)
    sender_nonce: int = account_inferred_nonce(
        _snd_resp,
        public_key=sender_pubkey,
    )

    # Phase 3: transfer + update-state loop
    state_counter: int = 0
    iteration: int = 0
    while True:
        if interval_secs > 0:
            time.sleep(interval_secs)

        # a) transfer-funds-one-receiver
        transfer_result = subprocess.run(
            [
                zkapp_exe,
                "transfer-funds-one-receiver",
                "--fee-payer-key",
                fee_payer_privkey_path,
                "--nonce",
                str(fee_payer_nonce),
                "--sender-key",
                sender_privkey_path,
                "--sender-nonce",
                str(sender_nonce),
                "--receiver-amount",
                transfer_amount,
                "--fee",
                fee,
                "--receiver",
                zkapp_pubkey,
            ],
            env=call_env,
            capture_output=True,
            text=True,
        )
        if transfer_result.returncode != 0:
            click.echo(
                f"zkapp: transfer-funds-one-receiver failed: {transfer_result.stderr}",
                err=True,
            )
            raise SystemExit(transfer_result.returncode or 1)
        transfer_mutation = extract_graphql_document(transfer_result.stdout)
        graphql_post(graphql_uri, transfer_mutation)
        fee_payer_nonce += 1
        sender_nonce += 1

        # b) update-state
        update_result = subprocess.run(
            [
                zkapp_exe,
                "update-state",
                "--fee-payer-key",
                fee_payer_privkey_path,
                "--nonce",
                str(fee_payer_nonce),
                "--zkapp-account-key",
                zkapp_privkey_path,
                "--zkapp-state",
                str(state_counter),
                "--fee",
                fee,
            ],
            env=call_env,
            capture_output=True,
            text=True,
        )
        if update_result.returncode != 0:
            click.echo(f"zkapp: update-state failed: {update_result.stderr}", err=True)
            raise SystemExit(update_result.returncode or 1)
        update_mutation = extract_graphql_document(update_result.stdout)
        graphql_post(graphql_uri, update_mutation)
        fee_payer_nonce += 1
        state_counter += 1

        iteration += 1
        if count is not None and iteration >= count:
            click.echo(f"zkapp: completed {iteration} iteration(s), exiting.", err=True)
            break

    raise SystemExit(0)


@click.argument("mina_exe", type=str)
@click.argument("itn_graphql_uri", type=str)
@click.argument("fee_payer_privkey_path", type=str)
@click.argument("itn_privkey_path", type=str)
@click.argument("itn_pubkey", type=str)
@click.argument("duration_min", type=int)
@click.argument("tps", type=float)
@click.argument("num_zkapps_to_deploy", type=int)
@click.argument("max_cost_num_updates", type=int)
@click.argument("num_new_accounts", type=int)
@click.argument("account_queue_size", type=int)
@click.argument("memo_prefix", type=str)
@click.argument("no_precondition", type=str)
@click.argument("min_balance_change", type=str)
@click.argument("max_balance_change", type=str)
@click.argument("min_new_zkapp_balance", type=str)
@click.argument("max_new_zkapp_balance", type=str)
@click.argument("init_balance", type=str)
@click.argument("min_fee", type=str)
@click.argument("max_fee", type=str)
@click.argument("deployment_fee", type=str)
def itn_max_cost_worker_body(
    mina_exe: str,
    itn_graphql_uri: str,
    fee_payer_privkey_path: str,
    itn_privkey_path: str,
    itn_pubkey: str,
    duration_min: int,
    tps: float,
    num_zkapps_to_deploy: int,
    max_cost_num_updates: int,
    num_new_accounts: int,
    account_queue_size: int,
    memo_prefix: str,
    no_precondition: str,
    min_balance_change: str,
    max_balance_change: str,
    min_new_zkapp_balance: str,
    max_new_zkapp_balance: str,
    init_balance: str,
    min_fee: str,
    max_fee: str,
    deployment_fee: str,
):
    """Internal ITN max-cost workload worker body (not intended for direct invocation).

    Authenticates to the ITN GraphQL endpoint using the generated Ed25519
    keypair, extracts the fee payer's secret key via ``mina advanced
    dump-keypair``, and posts a ``scheduleZkappCommands`` mutation.  This is
    a fire-and-forget operation — exit 0 once the mutation is accepted.
    """
    # Phase 1: Extract fee-payer base58check SK via dump-keypair
    fee_payer_sk: str = _extract_fee_payer_sk(mina_exe, fee_payer_privkey_path)
    if not fee_payer_sk:
        raise KeyError_(
            ErrorCode.KEY_EXTRACTION_FAILED,
            message="itn_max_cost: extracted fee payer SK is empty",
        )

    # Phase 2: Post scheduleZkappCommands
    _no_precond_bool: bool = no_precondition == "1"
    _itn_schedule_mutation(
        itn_uri=itn_graphql_uri,
        privkey_path=itn_privkey_path,
        pubkey_b64=itn_pubkey,
        fee_payer_sk=fee_payer_sk,
        duration_min=duration_min,
        tps=tps,
        num_zkapps_to_deploy=num_zkapps_to_deploy,
        max_cost_num_updates=max_cost_num_updates,
        num_new_accounts=num_new_accounts,
        account_queue_size=account_queue_size,
        memo_prefix=memo_prefix,
        no_precondition=_no_precond_bool,
        min_balance_change=min_balance_change,
        max_balance_change=max_balance_change,
        min_new_zkapp_balance=min_new_zkapp_balance,
        max_new_zkapp_balance=max_new_zkapp_balance,
        init_balance=init_balance,
        min_fee=min_fee,
        max_fee=max_fee,
        deployment_fee=deployment_fee,
    )

    raise SystemExit(0)
