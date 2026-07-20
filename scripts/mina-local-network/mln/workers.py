from __future__ import annotations

import base64
import json
import os
import random
import re
import struct
import subprocess
import tempfile
import time
import urllib.request
from typing import Optional, Tuple, assert_never
from urllib.error import HTTPError, URLError

from mln.amounts import nanomina_to_decimal_mina
from mln.errors import (
    ErrorCode,
    GraphQLError,
    KeyError_,
)
from mln.graphql import (
    SendOutcome,
    account_inferred_nonce,
    account_ledger_nonce,
    extract_graphql_document,
    graphql_post,
    send_payment,
)
from mln.models import (
    GraphQLResponse,
    ITNAuthResult,
    ItnMaxCostPayload,
    ValueTransferPayload,
    WorkloadPayload,
    ZkappPayload,
)
from mln.workload import WorkerContext

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


def _extract_fee_payer_sk(
    ctx: WorkerContext, mina_exe: str, privkey_path: str
) -> str:
    """Run ``mina advanced dump-keypair`` and extract the base58check SK.

    Returns the SK value after ``Private key: `` in the stdout.
    Raises ``KeyError_`` if extraction fails.
    """
    result = ctx.run(
        [mina_exe, "advanced", "dump-keypair", "--privkey-path", privkey_path],
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


_PROGRESS_EVERY = 25
# Cap replays per send so a replay_probability near 1.0 can't flood the network
# (the geometric tail is truncated here — acceptable for noise generation).
_MAX_REPLAYS_PER_SEND = 8


def _log_op_progress(
    ctx: WorkerContext, kind: str, n: int, first_detail: str
) -> None:
    """Log the first successful op (with detail) and every _PROGRESS_EVERY-th.

    Proves a workload is doing real work without flooding a long or high-TPS
    run; failures are logged separately at each call site, and the supervisor
    logs the terminal outcome.
    """
    if n == 1:
        ctx.log(f"{kind}: {first_detail}")
    elif n % _PROGRESS_EVERY == 0:
        ctx.log(f"{kind}: {n} ops so far")


# A fork daemon is not queryable the instant its genesis passes — the account is
# briefly absent from the served ledger and the endpoint may refuse — so the
# carry-over read polls until it answers rather than reading once.
_CARRYOVER_READ_TIMEOUT_SEC = 600.0
_CARRYOVER_READ_POLL_SEC = 2.0


def _read_carryover_nonce(
    ctx: WorkerContext, node_uri: str, pubkey: str, name: str
) -> int:
    """The ledger nonce of *pubkey* on *node_uri*, retried until the daemon answers.

    Raises (failing the workload) after ``_CARRYOVER_READ_TIMEOUT_SEC`` so an
    account that never becomes readable — a genuinely broken carry-over — fails
    the run rather than hanging until the CI timeout.
    """
    deadline = time.monotonic() + _CARRYOVER_READ_TIMEOUT_SEC
    attempt = 0
    while True:
        try:
            return account_ledger_nonce(node_uri, pubkey)
        except Exception as exc:  # noqa: BLE001 — any read failure is retried until ready
            attempt += 1
            if time.monotonic() >= deadline:
                ctx.log(
                    f"value_transfer: gave up reading {name}'s carry-over nonce after "
                    f"{int(_CARRYOVER_READ_TIMEOUT_SEC)}s: {exc}"
                )
                raise SystemExit(1)
            if attempt == 1 or attempt % 15 == 0:
                ctx.log(f"value_transfer: waiting for {name}'s nonce to be readable: {exc}")
            ctx.sleep(_CARRYOVER_READ_POLL_SEC)


def run_value_transfer(p: ValueTransferPayload, ctx: WorkerContext) -> None:
    """Run the randomized value-transfer worker from a typed payload.

    Each transfer draws a random sender + receiver from the account pool and a
    random amount in ``[amount_min, amount_max]``, and submits to the *sender's*
    home node.  Each account's nonce is tracked and pinned on every send, so one
    account's sequence stays contiguous on its one daemon (no cross-node nonce
    gaps).  A drained sender is warned once and dropped.  With probability
    ``replay_probability`` a successful send is resubmitted identically as replay
    noise (the network's nonce/dedup path rejects it).  Runs external commands
    through *ctx* so a stop request kills the in-flight command and unwinds.
    """
    mina_exe = p.mina_exe
    by_name = {a.name: a for a in p.accounts}
    eligible: set[str] = set(by_name)  # senders not yet drained
    nonces: dict[str, int] = {name: p.first_nonce for name in by_name}
    unlocked: set[tuple[str, str]] = set()  # (home_rest_uri, name) already unlocked
    drained_warned: set[str] = set()
    send_count = 0

    # Verify inherited nonces before any send (fork network only). Each pool
    # account carrying an expectation must show, on the fork chain, the nonce it
    # reached pre-fork — proving the fork inherited the account structure intact.
    # This runs before the send loop, so the value read is the inherited one and
    # not one this worker moved — the ordering that makes the check race-free.
    # It also seeds each account's nonce from the chain, so the loop's first send
    # pins the inherited value instead of first_nonce.
    for name in sorted(p.assert_carryover_nonces):
        acct = by_name.get(name)
        if acct is None:
            continue  # a ref outside this pool — nothing here to check
        expected = p.assert_carryover_nonces[name]
        got = _read_carryover_nonce(ctx, acct.home_rest_uri, acct.pubkey, name)
        if got != expected:
            ctx.log(
                f"CARRYOVER FAILED: pool account {name} shows nonce {got} on the fork, "
                f"expected the pre-fork {expected} — the fork broke account structure."
            )
            raise SystemExit(1)
        ctx.log(f"value_transfer: carry-over OK — {name} inherited nonce {got}.")
        nonces[name] = got

    while True:
        ctx.sleep(p.interval_secs)

        if not eligible:
            ctx.log("value_transfer: all senders drained — exiting.")
            break

        sender = by_name[random.choice(sorted(eligible))]
        receiver = by_name[random.choice([n for n in by_name if n != sender.name])]
        node = sender.home_rest_uri

        # Import + unlock the sender on its home node once, lazily.
        if (node, sender.name) not in unlocked:
            imp = ctx.run(
                [mina_exe, "account", "import", "-rest-server", node,
                 "-privkey-path", sender.privkey_path],
            )
            if imp.returncode != 0:
                ctx.log(
                    f"value_transfer: import {sender.name}@{node} failed, dropping: {imp.stderr}"
                )
                eligible.discard(sender.name)  # can't use this account; don't spin on it
                continue
            unl = ctx.run(
                [mina_exe, "account", "unlock", "-rest-server", node,
                 "-public-key", sender.pubkey],
            )
            if unl.returncode != 0:
                ctx.log(
                    f"value_transfer: unlock {sender.name}@{node} failed, dropping: {unl.stderr}"
                )
                eligible.discard(sender.name)
                continue
            unlocked.add((node, sender.name))

        nonce = nonces[sender.name]
        amount_nanomina = random.randint(p.amount_min_nanomina, p.amount_max_nanomina)

        result = send_payment(
            node,
            from_pk=sender.pubkey,
            to_pk=receiver.pubkey,
            amount_nanomina=amount_nanomina,
            fee_nanomina=p.fee_nanomina,
            nonce=nonce,
        )
        if result.outcome is not SendOutcome.SENT:
            if result.outcome is SendOutcome.INSUFFICIENT:
                if sender.name not in drained_warned:
                    ctx.log(
                        f"value_transfer: {sender.name} drained — dropping from sender pool"
                    )
                    drained_warned.add(sender.name)
                eligible.discard(sender.name)
                continue
            ctx.log(
                f"value_transfer: send {sender.name} nonce {nonce} "
                f"failed ({result.outcome.value}): {result.detail}"
            )
            if result.outcome is SendOutcome.NONCE_STALE:
                # Our tracked nonce disagrees with the ledger — e.g. a prior send
                # returned OK but its txn never reached the pool (lost), so every
                # pinned send now gaps. Re-read the daemon's inferred nonce to
                # recover. Best-effort: a failed query just retries next loop.
                try:
                    resp = graphql_post(
                        node,
                        f'query {{ account(publicKey: "{sender.pubkey}") {{ inferredNonce }} }}',
                    )
                    synced = account_inferred_nonce(resp, public_key=sender.pubkey)
                except Exception as exc:  # noqa: BLE001 — recovery is best-effort
                    ctx.log(f"value_transfer: nonce re-sync for {sender.name} failed: {exc}")
                else:
                    if synced != nonces[sender.name]:
                        ctx.log(
                            f"WARNING: value_transfer re-syncing {sender.name} nonce "
                            f"{nonces[sender.name]} → {synced} (possible lost txn)"
                        )
                        nonces[sender.name] = synced
            # AFTER_TX_END / UNAVAILABLE / REJECTED: nothing to fix here — retry on
            # the next iteration, since the condition is often transient.
            continue

        nonces[sender.name] = nonce + 1
        send_count += 1
        # Log EVERY send: each is a distinct account/amount/node, so there is no
        # repetitive flooding to sample away (unlike a single-account workload).
        ctx.log(
            f"value_transfer: sent {nanomina_to_decimal_mina(amount_nanomina)} "
            f"{sender.name}→{receiver.name} @ {node} (nonce {nonce})"
        )

        # Replay noise: resubmit the identical payment with probability p, cascading
        # (p, p^2, …). Rejected by nonce/dedup — an accepted replay would be a
        # double-spend bug.
        replays = 0
        while replays < _MAX_REPLAYS_PER_SEND and random.random() < p.replay_probability:
            send_payment(
                node,
                from_pk=sender.pubkey,
                to_pk=receiver.pubkey,
                amount_nanomina=amount_nanomina,
                fee_nanomina=p.fee_nanomina,
                nonce=nonce,
            )
            replays += 1
        if replays:
            ctx.log(
                f"value_transfer: replayed {sender.name} nonce {nonce} ×{replays} "
                f"(expect rejection)"
            )

        if p.count is not None and send_count >= p.count:
            ctx.log(f"value_transfer: completed {send_count} send(s), exiting.")
            break

    raise SystemExit(0)


def run_zkapp(p: ZkappPayload, ctx: WorkerContext) -> None:
    """Run the zkApp worker from a typed payload.

    Runs create-zkapp-account optionally, then loops transfer-funds-one-receiver
    + update-state against the GraphQL endpoint.  Signs offline from key
    files — does NOT import or unlock accounts on the daemon.  Runs external
    commands through *ctx* so a stop request kills the in-flight command and
    unwinds the loop.
    """
    zkapp_exe = p.zkapp_exe
    graphql_uri = p.graphql_uri
    fee_payer_privkey_path = p.fee_payer_privkey_path
    fee_payer_pubkey = p.fee_payer_pubkey
    sender_privkey_path = p.sender_privkey_path
    sender_pubkey = p.sender_pubkey
    zkapp_privkey_path = p.zkapp_privkey_path
    zkapp_pubkey = p.zkapp_pubkey
    transfer_amount = p.transfer_amount
    receiver_amount = p.receiver_amount
    fee = p.fee
    interval_secs = p.interval_secs
    create_account = p.create_account
    count = p.count

    # Phase 1: create zkApp account (if --create-account)
    if create_account:
        create_result = ctx.run(
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
        )
        if create_result.returncode != 0:
            ctx.log(f"zkapp: create-zkapp-account failed: {create_result.stderr}")
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
            ctx.sleep(1.0)
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
        ctx.sleep(interval_secs)

        # a) transfer-funds-one-receiver
        transfer_result = ctx.run(
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
        )
        if transfer_result.returncode != 0:
            ctx.log(
                f"zkapp: transfer-funds-one-receiver failed: {transfer_result.stderr}"
            )
            raise SystemExit(transfer_result.returncode or 1)
        transfer_mutation = extract_graphql_document(transfer_result.stdout)
        graphql_post(graphql_uri, transfer_mutation)
        fee_payer_nonce += 1
        sender_nonce += 1

        # b) update-state
        update_result = ctx.run(
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
        )
        if update_result.returncode != 0:
            ctx.log(f"zkapp: update-state failed: {update_result.stderr}")
            raise SystemExit(update_result.returncode or 1)
        update_mutation = extract_graphql_document(update_result.stdout)
        graphql_post(graphql_uri, update_mutation)
        fee_payer_nonce += 1
        state_counter += 1

        iteration += 1
        _log_op_progress(
            ctx,
            "zkapp",
            iteration,
            f"updated zkapp state (iteration #1, nonce {fee_payer_nonce})",
        )
        if count is not None and iteration >= count:
            ctx.log(f"zkapp: completed {iteration} iteration(s), exiting.")
            break

    raise SystemExit(0)


def run_itn_max_cost(p: ItnMaxCostPayload, ctx: WorkerContext) -> None:
    """Run the ITN max-cost worker from a typed payload.

    Authenticates to the ITN GraphQL endpoint using the generated Ed25519
    keypair, extracts the fee payer's secret key via ``mina advanced
    dump-keypair``, and posts a ``scheduleZkappCommands`` mutation.  This is
    a fire-and-forget operation — exit 0 once the mutation is accepted.
    """
    # Phase 1: Extract fee-payer base58check SK via dump-keypair
    fee_payer_sk: str = _extract_fee_payer_sk(ctx, p.mina_exe, p.fee_payer_privkey_path)
    if not fee_payer_sk:
        raise KeyError_(
            ErrorCode.KEY_EXTRACTION_FAILED,
            message="itn_max_cost: extracted fee payer SK is empty",
        )

    # Phase 2: Post scheduleZkappCommands
    _itn_schedule_mutation(
        itn_uri=p.itn_graphql_uri,
        privkey_path=p.itn_privkey_path,
        pubkey_b64=p.itn_pubkey,
        fee_payer_sk=fee_payer_sk,
        duration_min=p.duration_min,
        tps=p.tps,
        num_zkapps_to_deploy=p.num_zkapps_to_deploy,
        max_cost_num_updates=p.max_cost_num_updates,
        num_new_accounts=p.num_new_accounts,
        account_queue_size=p.account_queue_size,
        memo_prefix=p.memo_prefix,
        no_precondition=p.no_precondition,
        min_balance_change=p.min_balance_change,
        max_balance_change=p.max_balance_change,
        min_new_zkapp_balance=p.min_new_zkapp_balance,
        max_new_zkapp_balance=p.max_new_zkapp_balance,
        init_balance=p.init_balance,
        min_fee=p.min_fee,
        max_fee=p.max_fee,
        deployment_fee=p.deployment_fee,
    )

    ctx.log(
        f"itn_max_cost: scheduleZkappCommands posted successfully "
        f"(duration={p.duration_min}m, tps={p.tps:.6f})."
    )
    raise SystemExit(0)


# ── Worker dispatch ──────────────────────────────────────────────────────


def dispatch_workload(payload: WorkloadPayload, ctx: WorkerContext) -> None:
    """Run the worker that matches *payload* — the single dispatch point.

    Called on the worker thread by :class:`~mln.workload.ThreadWorkload`, and
    directly by unit tests (no thread, no subprocess).
    """
    match payload:
        case ValueTransferPayload():
            run_value_transfer(payload, ctx)
        case ZkappPayload():
            run_zkapp(payload, ctx)
        case ItnMaxCostPayload():
            run_itn_max_cost(payload, ctx)
        case _ as unreachable:
            # Exhaustiveness anchor: a type checker errors here if a new
            # WorkloadPayload variant is added without a case above.
            assert_never(unreachable)
