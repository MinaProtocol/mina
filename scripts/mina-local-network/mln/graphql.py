"""GraphQL client helpers for Mina local-network operations."""

from __future__ import annotations

import json
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Optional
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from mln.errors import (
    ErrorCode,
    GraphQLError,
)
from mln.models import GraphQLResponse, SyncStatusPayload
from mln.process_types import StopChecker, WatchedProcess


def extract_graphql_document(stdout: str) -> str:
    """Extract a GraphQL document from zkApp CLI stdout.

    Scans stdout lines for the first line starting with a GraphQL marker
    (``mutation``, ``query``, or ``{`` after optional whitespace) and returns
    from that line to the end.  Raises ``GraphQLError`` if no marker
    is found.
    """
    for i, line in enumerate(stdout.splitlines()):
        stripped = line.lstrip()
        if stripped.startswith(("mutation", "query", "{")):
            return "\n".join(stdout.splitlines()[i:])
    raise GraphQLError(
        ErrorCode.GRAPHQL_PARSE_ERROR,
        message="Failed to extract GraphQL document from zkApp CLI output. "
        "No line starts with 'mutation', 'query', or '{'.",
    )


def _post_raw(uri: str, query_str: str) -> dict:
    """POST a GraphQL query and return the parsed JSON body verbatim.

    Raises ``GraphQLError`` only on transport, HTTP, or JSON failure — a GraphQL
    ``errors`` array in a 200 response is left in the returned dict for the caller
    to interpret, since "the daemon rejected this operation" is not the same kind
    of failure as "the daemon could not be reached". Uses stdlib ``urllib`` only.
    """
    query_body = json.dumps({"query": query_str}).encode("utf-8")
    req = Request(
        uri,
        data=query_body,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        method="POST",
    )
    try:
        with urlopen(req, timeout=30.0) as resp:
            if not (200 <= resp.status < 300):
                raise GraphQLError(
                    ErrorCode.HTTP_ERROR,
                    message=f"GraphQL POST to {uri} returned HTTP {resp.status}",
                )
            raw = resp.read().decode("utf-8")
    except GraphQLError:
        raise
    except (HTTPError, URLError, OSError) as exc:
        raise GraphQLError(
            ErrorCode.HTTP_ERROR,
            message=f"GraphQL POST to {uri} failed: {exc}",
        ) from exc

    try:
        return json.loads(raw)
    except json.JSONDecodeError as exc:
        raise GraphQLError(
            ErrorCode.GRAPHQL_PARSE_ERROR,
            message=f"GraphQL response from {uri} is not valid JSON: {exc}",
        ) from exc


def graphql_post(uri: str, query_str: str) -> GraphQLResponse:
    """POST a GraphQL query to *uri* and return the parsed JSON response.

    Requires HTTP 2xx; parses JSON; raises on top-level ``errors`` or
    ``data == null``. For operations where a GraphQL ``errors`` reply is an
    expected outcome to be classified rather than an exception (a payment the
    daemon rejects), use the operation-specific helper — see ``send_payment``.

    Returns the validated response model on success.
    """
    parsed = _post_raw(uri, query_str)
    if "errors" in parsed and parsed["errors"]:
        raise GraphQLError(
            ErrorCode.GRAPHQL_ERROR,
            message=f"GraphQL errors from {uri}: {parsed['errors']}",
        )
    if not isinstance(parsed.get("data"), dict):
        raise GraphQLError(
            ErrorCode.GRAPHQL_RESPONSE_INVALID,
            message=f"GraphQL response from {uri} has null or non-object data",
        )
    return GraphQLResponse.model_validate(parsed)


class SendOutcome(Enum):
    """How the daemon answered a ``sendPayment``.

    Each variant is a distinct handling decision for the value_transfer worker,
    read from the daemon's structured GraphQL reply rather than guessed from the
    prose the ``mina client`` CLI would have wrapped it in.
    """

    SENT = "sent"  # accepted into the pool
    INSUFFICIENT = "insufficient"  # sender can't afford it — drop the sender
    NONCE_STALE = "nonce_stale"  # our nonce disagrees with the ledger — resync
    AFTER_TX_END = "after_tx_end"  # chain is past slot-tx-end — no more sends land
    UNAVAILABLE = "unavailable"  # daemon unreachable / not answering — retry later
    REJECTED = "rejected"  # any other daemon rejection


@dataclass(frozen=True)
class SendResult:
    """The classified outcome of a ``sendPayment`` and the daemon's own message."""

    outcome: SendOutcome
    detail: str


def _classify_send_errors(errors: Any) -> SendResult:
    """Map a GraphQL ``errors`` array from ``sendPayment`` to a typed outcome.

    Mina reports the reason in each error's ``message`` (there is no stable error
    code on the wire), so the discrimination is by message — but over the daemon's
    own clean text, one matcher per known mode, not over CLI-wrapped prose.
    """
    messages = []
    if isinstance(errors, list):
        for e in errors:
            if isinstance(e, dict) and isinstance(e.get("message"), str):
                messages.append(e["message"])
    detail = "; ".join(messages) or json.dumps(errors)
    low = detail.lower()

    if "insufficient" in low or "not enough" in low:
        return SendResult(SendOutcome.INSUFFICIENT, detail)
    if "after_slot_tx_end" in low or "after slot tx end" in low:
        return SendResult(SendOutcome.AFTER_TX_END, detail)
    # A nonce that ran ahead of / behind the ledger, or a duplicate already in the
    # pool: recoverable by re-reading the ledger's nonce.
    if "nonce" in low or "already in the pool" in low or "duplicate" in low:
        return SendResult(SendOutcome.NONCE_STALE, detail)
    return SendResult(SendOutcome.REJECTED, detail)


def send_payment(
    uri: str,
    *,
    from_pk: str,
    to_pk: str,
    amount_nanomina: int,
    fee_nanomina: int,
    nonce: int,
) -> SendResult:
    """Submit a payment via the daemon's ``sendPayment`` mutation, classified.

    Submits against the daemon's GraphQL directly — the account must be unlocked
    on it, as ``mina client send-payment`` also arranges — so the reply is a
    structured success or a typed rejection, not an exit code plus prose on
    stderr. Amounts and fees are nanomina (UInt64), the nonce a UInt32; all are
    stringified, as the daemon serializes these scalars as strings.
    """
    mutation = (
        "mutation { sendPayment(input: {"
        f'from: "{from_pk}", to: "{to_pk}", '
        f'amount: "{amount_nanomina}", fee: "{fee_nanomina}", nonce: "{nonce}"'
        "}) { payment { nonce } } }"
    )
    try:
        parsed = _post_raw(uri, mutation)
    except GraphQLError as exc:
        # Transport/HTTP/JSON failure — the daemon is down or not yet answering.
        return SendResult(SendOutcome.UNAVAILABLE, str(exc))

    errors = parsed.get("errors")
    if errors:
        return _classify_send_errors(errors)
    return SendResult(SendOutcome.SENT, "")


def _parse_account_nonce(raw: object, *, field: str, public_key: str) -> int:
    """Parse an AccountNonce scalar.

    The daemon serializes AccountNonce with ``Make_scalar_using_to_string``, so it
    is always a decimal string on the wire — never a JSON number.  Anything else
    means the response is not what it claims to be, and guessing at it would only
    turn a clear error into a wrong number.
    """
    if isinstance(raw, str) and raw.isdigit():
        return int(raw)
    raise GraphQLError(
        ErrorCode.GRAPHQL_RESPONSE_INVALID,
        message=f"GraphQL {field} for {public_key} is not a decimal string: {raw!r}",
    )


def account_inferred_nonce(response: GraphQLResponse, *, public_key: str) -> int:
    """Extract account.inferredNonce, treating a missing account as nonce 0."""

    account = response.data.get("account")
    match account:
        case None:
            return 0
        case dict():
            raw_nonce = account.get("inferredNonce")
        case _:
            raise GraphQLError(
                ErrorCode.GRAPHQL_RESPONSE_INVALID,
                message=f"GraphQL account response for {public_key} is not an object",
            )

    if raw_nonce is None:
        return 0
    return _parse_account_nonce(raw_nonce, field="inferredNonce", public_key=public_key)


def daemon_genesis_timestamp(graphql_uri: str) -> datetime:
    """Ask a running daemon for the genesis timestamp it is actually using.

    Asked at runtime, and never inferred from anything on disk, because no static
    source answers the question for every network:

    - The plan usually holds a *delay* (``PT120S``), not an instant.  The absolute
      time is worked out at materialize (``now + delay``) and never written back,
      so the plan can say how long after some earlier moment genesis fell, but not
      when.
    - ``<state_root>/daemon.json`` holds the resolved instant, but only for the
      network materialize last wrote it for.  A caller that replans over an
      existing root leaves that file describing the previous network.
    - Per-node ``daemon.json`` files may not be mln's at all: ``patch topology``
      deliberately does not regenerate them, so a caller may supply its own — and
      then the genesis in force is one mln never saw.

    The daemon is the only party that knows which config won.  It reports the
    genesis it loaded, whoever wrote it, so this holds for every network mln can
    spawn rather than the subset it authored.  There is deliberately no static
    fallback: a check that silently reads a different source in some cases is a
    check nobody can reason about.

    Returns a timezone-aware UTC datetime.
    """
    response = graphql_post(graphql_uri, "query { genesisConstants { genesisTimestamp } }")

    constants = response.data.get("genesisConstants")
    if not isinstance(constants, dict):
        raise GraphQLError(
            ErrorCode.GRAPHQL_RESPONSE_INVALID,
            message=f"GraphQL genesisConstants from {graphql_uri} is not an object",
        )

    raw = constants.get("genesisTimestamp")
    if not isinstance(raw, str):
        raise GraphQLError(
            ErrorCode.GRAPHQL_RESPONSE_INVALID,
            message=f"GraphQL genesisTimestamp from {graphql_uri} is not a string: {raw!r}",
        )

    # The daemon reports ISO 8601 with a trailing "Z", which fromisoformat only
    # accepts from Python 3.11.
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError as exc:
        raise GraphQLError(
            ErrorCode.GRAPHQL_RESPONSE_INVALID,
            message=f"GraphQL genesisTimestamp from {graphql_uri} is not an ISO 8601 "
            f"timestamp: {raw!r}",
        ) from exc

    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def account_ledger_nonce(graphql_uri: str, public_key: str) -> int:
    """Read an account's nonce as recorded in the ledger.

    The ledger nonce, not ``inferredNonce``: inference folds in transactions
    sitting in the pool, which are a property of this daemon at this moment
    rather than of the chain.  A caller asking what an account has *done* — for
    instance to carry it across a hardfork, where what survives is the ledger —
    wants the committed number.
    """
    response = graphql_post(
        graphql_uri,
        'query { account(publicKey: "' + public_key + '") { nonce } }',
    )

    account = response.data.get("account")
    if not isinstance(account, dict):
        raise GraphQLError(
            ErrorCode.GRAPHQL_RESPONSE_INVALID,
            message=f"No account {public_key} at {graphql_uri}. An account absent from the "
            f"ledger has no nonce to report.",
        )
    return _parse_account_nonce(account.get("nonce"), field="nonce", public_key=public_key)


def parse_sync_status(response: GraphQLResponse) -> SyncStatusPayload:
    """Extract and validate ``syncStatus`` from a GraphQL response.

    Returns a typed ``SyncStatusPayload``.  Never returns a raw ``dict``.
    """
    return SyncStatusPayload.model_validate(response.data)


def wait_for_graphql_ready(
    graphql_uri: str,
    timeout_sec: float = 60,
    interval_sec: float = 1,
    should_stop: Optional[StopChecker] = None,
    watched_proc: Optional[WatchedProcess] = None,
    label: str = "GraphQL",
) -> None:
    """Poll a GraphQL endpoint until it returns a valid 2xx JSON response.

    POSTs ``{"query": "query { syncStatus }"}`` to *graphql_uri* using
    stdlib only (``urllib.request``).  An HTTP 2xx with a JSON-ish body
    is treated as ready.

    Returns normally (``None``) when the endpoint is ready.
    """
    deadline = time.time() + timeout_sec
    query_body = json.dumps({"query": "query { syncStatus }"}).encode("utf-8")

    while time.time() < deadline:
        if should_stop is not None and should_stop():
            raise SystemExit(143)
        if watched_proc is not None and watched_proc.poll() is not None:
            code = watched_proc.returncode
            raise GraphQLError(
                ErrorCode.GRAPHQL_READY_TIMEOUT,
                message=f"Daemon process exited with code {code} before "
                f"{label} became ready.  Check daemon logs for errors.",
            )
        try:
            req = Request(
                graphql_uri,
                data=query_body,
                headers={
                    "Content-Type": "application/json",
                    "Accept": "application/json",
                },
                method="POST",
            )
            with urlopen(req, timeout=5.0) as resp:
                if 200 <= resp.status < 300:
                    return
        except (HTTPError, URLError, OSError):
            pass
        time.sleep(interval_sec)

    raise GraphQLError(
        ErrorCode.GRAPHQL_READY_TIMEOUT,
        message=f"{label} not ready at {graphql_uri} after {timeout_sec}s. "
        "Check daemon logs for errors.",
    )


def wait_for_graphql_synced(
    graphql_uri: str,
    timeout_sec: float = 300,
    interval_sec: float = 2,
    should_stop: Optional[StopChecker] = None,
    watched_proc: Optional[WatchedProcess] = None,
    label: str = "GraphQL sync",
) -> None:
    """Poll a GraphQL endpoint until syncStatus reports SYNCED.

    POSTs the ``syncStatus`` query via ``graphql_post`` and validates
    the response with ``SyncStatusPayload``.  No raw dict access.

    Returns normally (``None``) when the syncStatus is SYNCED.
    """
    deadline = time.time() + timeout_sec

    while time.time() < deadline:
        if should_stop is not None and should_stop():
            raise SystemExit(143)
        if watched_proc is not None and watched_proc.poll() is not None:
            code = watched_proc.returncode
            raise GraphQLError(
                ErrorCode.GRAPHQL_SYNC_TIMEOUT,
                message=f"Daemon process exited with code {code} before "
                f"{label} completed.  Check daemon logs for errors.",
            )
        try:
            response = graphql_post(graphql_uri, "query { syncStatus }")
            payload = parse_sync_status(response)
            if payload.syncStatus == "SYNCED":
                return
        except GraphQLError:
            pass
        time.sleep(interval_sec)

    raise GraphQLError(
        ErrorCode.GRAPHQL_SYNC_TIMEOUT,
        message=f"{label} not synced at {graphql_uri} after {timeout_sec}s. "
        "Check daemon logs for errors.",
    )


def wait_for_genesis(
    graphql_uri: str,
    timeout_sec: float = 300,
    interval_sec: float = 2,
    should_stop: Optional[StopChecker] = None,
    watched_proc: Optional[WatchedProcess] = None,
    label: str = "genesis",
) -> None:
    """Poll until the daemon is SYNCED *and* its genesis instant has passed.

    ``SYNCED`` alone is reached roughly one genesis-delay *before* the chain
    starts: the daemon syncs to the genesis ledger while still counting down to
    genesis. A load workload that sends in that window hits "sender is not in the
    ledger" (the chain has produced nothing, so no account nonce is inferrable).
    This gate additionally requires the wall clock — the daemon and any local
    workload share it — to have reached the genesis timestamp the daemon reports,
    so the chain has actually begun before the workload sends anything.
    """
    deadline = time.time() + timeout_sec

    while time.time() < deadline:
        if should_stop is not None and should_stop():
            raise SystemExit(143)
        if watched_proc is not None and watched_proc.poll() is not None:
            code = watched_proc.returncode
            raise GraphQLError(
                ErrorCode.GRAPHQL_SYNC_TIMEOUT,
                message=f"Daemon process exited with code {code} before "
                f"{label} completed.  Check daemon logs for errors.",
            )
        try:
            response = graphql_post(graphql_uri, "query { syncStatus }")
            if parse_sync_status(response).syncStatus == "SYNCED":
                if datetime.now(timezone.utc) >= daemon_genesis_timestamp(graphql_uri):
                    return
        except GraphQLError:
            pass
        time.sleep(interval_sec)

    raise GraphQLError(
        ErrorCode.GRAPHQL_SYNC_TIMEOUT,
        message=f"{label} not reached at {graphql_uri} after {timeout_sec}s "
        "(daemon never synced past its genesis timestamp). Check daemon logs.",
    )
