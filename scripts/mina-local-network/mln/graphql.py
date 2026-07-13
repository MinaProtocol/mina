"""GraphQL client helpers for Mina local-network operations."""

from __future__ import annotations

import json
import time
from typing import Optional
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


def graphql_post(uri: str, query_str: str) -> GraphQLResponse:
    """POST a GraphQL query to *uri* and return the parsed JSON response.

    Uses stdlib ``urllib.request`` only — no extra dependencies.
    Requires HTTP 2xx; parses JSON; raises on top-level ``errors`` or
    ``data == null``.

    Returns the validated response model on success.
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
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise GraphQLError(
            ErrorCode.GRAPHQL_PARSE_ERROR,
            message=f"GraphQL response from {uri} is not valid JSON: {exc}",
        ) from exc

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

    match raw_nonce:
        case None:
            return 0
        case int():
            return raw_nonce
        case str() if raw_nonce.isdigit():
            return int(raw_nonce)
        case _:
            raise GraphQLError(
                ErrorCode.GRAPHQL_RESPONSE_INVALID,
                message=f"GraphQL inferredNonce for {public_key} is not an integer: "
                f"{raw_nonce!r}",
            )


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
