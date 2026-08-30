#!/usr/bin/env python3
"""Ledger patching tool driven by a JSON spec.

Usage:
    python patch-ledger/__main__.py --spec '{"source": ..., "transforms": [...]}'
    python patch-ledger/__main__.py --spec spec.json
    python patch-ledger/__main__.py --spec -          # read from stdin
"""

from __future__ import annotations

import json
import logging
import os
import random
import sys
import time
from decimal import Decimal
from datetime import datetime
from typing import Annotated, Literal, NoReturn

import fire
import requests
from pydantic import BaseModel, BeforeValidator, Field, PlainSerializer

log = logging.getLogger("patch-ledger")

GCS_BUCKET = "mina-staking-ledgers"
NANOMINA = 10**9

KeyList = Annotated[list[str], Field(min_length=1)]

import re

MINA_KEY_RE = re.compile(r"^B62q[1-9A-HJ-NP-Za-km-z]{51}$")


# ── Balance Type ──────────────────────────────────────────────────────────


def _parse_mina(v: str | int | float | Decimal) -> Decimal:
    return Decimal(str(v))


def _serialize_mina(v: Decimal) -> str:
    nanomina = int(v * NANOMINA)
    whole, frac = divmod(abs(nanomina), NANOMINA)
    sign = "-" if nanomina < 0 else ""
    if frac == 0:
        return f"{sign}{whole}"
    frac_str = f"{frac:09d}".rstrip("0")
    return f"{sign}{whole}.{frac_str}"


Mina = Annotated[
    Decimal,
    BeforeValidator(_parse_mina),
    PlainSerializer(_serialize_mina, return_type=str),
]


# ── Utilities ──────────────────────────────────────────────────────────────


def fatal(msg: str, code: int = 1) -> NoReturn:
    log.error(msg)
    sys.exit(code)


# ── Account ───────────────────────────────────────────────────────────────


class Account(BaseModel, extra="allow"):
    pk: str
    balance: Mina = Decimal(0)
    delegate: str = ""
    receipt_chain_hash: str | None = None


Ledger = list[Account]


# ── Spec Types ────────────────────────────────────────────────────────────


MAINNET_START = 1717545600  # 2024-06-05T00:00:00Z
SLOTS_PER_EPOCH = 7140
SLOT_TIME_SECONDS = 180


def current_epoch_prefix() -> str:
    epoch = int((time.time() - MAINNET_START) / (SLOTS_PER_EPOCH * SLOT_TIME_SECONDS))
    return f"staking-{epoch}"


class GcsEpochSource(BaseModel):
    type: Literal["gcs-epoch"]
    prefix: str | None = None
    exit_on_old_ledger: bool = False


class EmptySource(BaseModel):
    type: Literal["empty"]


class LocalFileSource(BaseModel):
    type: Literal["local-file"]
    path: str


Source = Annotated[
    GcsEpochSource | EmptySource | LocalFileSource, Field(discriminator="type")
]


class RemoveAccountsTransform(BaseModel):
    type: Literal["remove-accounts"]
    keys: KeyList


class CutoffDelegationTransform(BaseModel):
    """Reassign delegation using even or norm strategy, skipping accounts below cutoff."""
    type: Literal["reassign-delegation"]
    strategy: Literal["even", "norm"] = "even"
    to: KeyList
    delegation_cutoff: Mina = Decimal("100000")


class ReplaceTopDelegationTransform(BaseModel):
    """Replace the top N delegates (by total stake) with the target keys 1:1."""
    type: Literal["replace-top-delegation"]
    to: KeyList


class AddAccountEntry(BaseModel):
    pk: str
    balance: Mina
    delegate: str | None = None


class AddAccountsTransform(BaseModel):
    type: Literal["add-accounts"]
    entries: Annotated[list[AddAccountEntry], Field(min_length=1)]


class StripReceiptChainHashTransform(BaseModel):
    type: Literal["strip-receipt-chain-hash"]
    delegate_keys: KeyList


class BoostLastTransform(BaseModel):
    type: Literal["boost-last"]
    count: Annotated[int, Field(ge=1)]
    balance: Mina


Transform = Annotated[
    RemoveAccountsTransform
    | CutoffDelegationTransform
    | ReplaceTopDelegationTransform
    | AddAccountsTransform
    | StripReceiptChainHashTransform
    | BoostLastTransform,
    Field(discriminator="type"),
]


class Spec(BaseModel):
    source: Source
    transforms: list[Transform] = []
    aliases: dict[str, str] = {}


# ── Alias Resolution ──────────────────────────────────────────────────────


def resolve_aliases_in_spec(spec: Spec) -> Spec:
    aliases = spec.aliases
    if not aliases:
        return spec

    def r(k: str) -> str:
        return aliases.get(k, k)

    resolved: list[Transform] = []
    for t in spec.transforms:
        if isinstance(t, RemoveAccountsTransform):
            resolved.append(t.model_copy(update={"keys": [r(k) for k in t.keys]}))
        elif isinstance(t, (CutoffDelegationTransform, ReplaceTopDelegationTransform)):
            resolved.append(t.model_copy(update={"to": [r(k) for k in t.to]}))
        elif isinstance(t, AddAccountsTransform):
            resolved.append(t.model_copy(update={
                "entries": [
                    e.model_copy(update={
                        "pk": r(e.pk),
                        "delegate": r(e.delegate) if e.delegate else None,
                    })
                    for e in t.entries
                ]
            }))
        elif isinstance(t, StripReceiptChainHashTransform):
            resolved.append(
                t.model_copy(update={"delegate_keys": [r(k) for k in t.delegate_keys]})
            )
        elif isinstance(t, BoostLastTransform):
            resolved.append(t)

    return spec.model_copy(update={"transforms": resolved, "aliases": {}})


def validate_key_prefixes(spec: Spec) -> None:
    keys = collect_all_keys(spec)
    bad = [k for k in keys if not MINA_KEY_RE.match(k)]
    if bad:
        fatal(f"Invalid keys (expected base58 B62q...): " + ", ".join(bad))


# ── Stake Distribution ────────────────────────────────────────────────────


def collect_all_keys(spec: Spec) -> set[str]:
    keys: set[str] = set()
    for t in spec.transforms:
        if isinstance(t, RemoveAccountsTransform):
            keys.update(t.keys)
        elif isinstance(t, (CutoffDelegationTransform, ReplaceTopDelegationTransform)):
            keys.update(t.to)
        elif isinstance(t, AddAccountsTransform):
            keys.update(e.pk for e in t.entries)
        elif isinstance(t, StripReceiptChainHashTransform):
            keys.update(t.delegate_keys)
    return keys


def print_stake_distribution(ledger: Ledger, keys: list[str]) -> None:
    key_set = set(keys)
    total = sum(a.balance for a in ledger)
    if total == 0:
        return
    log.info("Total accounts: %d, balance: %s", len(ledger), total)

    delegated: dict[str, Decimal] = {}
    for a in ledger:
        if a.delegate in key_set:
            delegated[a.delegate] = delegated.get(a.delegate, Decimal(0)) + a.balance

    all_pct = float(sum(delegated.values()) / total * 100)
    log.info("Stake distribution:")
    log.info("  all: %.2f%%", all_pct)
    for k in sorted(delegated, key=lambda x: delegated[x], reverse=True):
        pct = float(delegated[k] / total * 100)
        log.info("  %s: %.2f%%", k, pct)


# ── Source Loaders ────────────────────────────────────────────────────────


def parse_ledger(raw: list[dict[str, str]]) -> Ledger:
    return [Account.model_validate(a) for a in raw]


def load_gcs_epoch(source: GcsEpochSource) -> Ledger:
    prefix = source.prefix or current_epoch_prefix()
    ledger_file = f"{prefix}.json"

    if os.path.isfile(ledger_file):
        log.info("Using cached ledger: %s", ledger_file)
        with open(ledger_file) as f:
            return parse_ledger(json.load(f))

    log.info("Using ledger with prefix: %s", prefix)
    list_url = (
        f"https://storage.googleapis.com/storage/v1/b/{GCS_BUCKET}/o"
        f"?maxResults=1000&prefix={prefix}"
    )
    log.info("%s", list_url)

    resp = requests.get(list_url, timeout=60)
    resp.raise_for_status()
    listing = resp.json()

    items: list[dict[str, str]] | None = listing.get("items")
    if not items:
        fatal(f"Couldn't find ledger with prefix {prefix}", code=2)

    best = max(items, key=lambda x: int(x.get("size", "0")))
    media_link = best["mediaLink"]

    if source.exit_on_old_ledger:
        created = best.get("timeCreated", "")
        try:
            ts = datetime.fromisoformat(created.replace("Z", "+00:00")).timestamp()
        except (ValueError, AttributeError):
            ts = 0.0
        one_year_ago = time.time() - 365 * 24 * 3600
        if ts < one_year_ago:
            fatal(f"Ledger is older than 1 year (timestamp: {created})", code=2)

    log.info("Downloading ledger...")
    resp = requests.get(media_link, timeout=300)
    resp.raise_for_status()
    data = resp.content

    # GCS bucket returns this literal text (not JSON) when the ledger isn't ready
    not_finalized_msg = "Ledger not found: next staking ledger is not finalized yet"
    if data[: len(not_finalized_msg)].decode("utf-8", errors="ignore") == not_finalized_msg:
        fatal("Next ledger not finalized yet", code=2)

    ledger = parse_ledger(resp.json())

    with open(ledger_file, "w") as f:
        json.dump([a.model_dump() for a in ledger], f)

    return ledger


def load_local_file(source: LocalFileSource) -> Ledger:
    if not os.path.isfile(source.path):
        fatal(f"File not found: {source.path}")
    with open(source.path) as f:
        return parse_ledger(json.load(f))


def load_source(source: Source) -> Ledger:
    match source:
        case GcsEpochSource():
            return load_gcs_epoch(source)
        case EmptySource():
            return []
        case LocalFileSource():
            return load_local_file(source)


# ── Transforms ────────────────────────────────────────────────────────────


def _warn_missing_keys(ledger: Ledger, keys: set[str], context: str) -> None:
    ledger_pks = {a.pk for a in ledger}
    missing = keys - ledger_pks
    if missing:
        log.warning("%s: keys not in ledger: %s", context, ", ".join(sorted(missing)))


def apply_remove_accounts(ledger: Ledger, t: RemoveAccountsTransform) -> Ledger:
    keys = set(t.keys)
    _warn_missing_keys(ledger, keys, "remove-accounts")
    return [a for a in ledger if a.pk not in keys]


def apply_replace_top_delegation(ledger: Ledger, t: ReplaceTopDelegationTransform) -> Ledger:
    keys = t.to
    _warn_missing_keys(ledger, set(keys), "replace-top-delegation")
    num_keys = len(keys)
    groups: dict[str, Decimal] = {}
    for a in ledger:
        groups[a.delegate] = groups.get(a.delegate, Decimal(0)) + a.balance
    top_delegates = sorted(groups, key=lambda x: groups[x], reverse=True)[:num_keys]
    top_map = dict(zip(top_delegates, keys))
    return [
        a.model_copy(update={"delegate": top_map[a.delegate]})
        if a.delegate in top_map
        else a
        for a in ledger
    ]


def apply_cutoff_delegation(ledger: Ledger, t: CutoffDelegationTransform) -> Ledger:
    keys = t.to
    _warn_missing_keys(ledger, set(keys), "reassign-delegation")
    cutoff = t.delegation_cutoff
    num_keys = len(keys)
    num_accounts = len(ledger)

    result = list(ledger)
    for i, key in enumerate(keys):
        if t.strategy == "norm":
            interval = max(
                1,
                int((random.random() + random.random() + random.random()) * num_keys / 3) + 1,
            )
        else:
            interval = num_keys

        idx = i
        while idx < num_accounts:
            if result[idx].balance > cutoff:
                result[idx] = result[idx].model_copy(update={"delegate": key})
            idx += interval

    return result


def apply_add_accounts(ledger: Ledger, t: AddAccountsTransform) -> Ledger:
    delegate_keys = {e.delegate for e in t.entries if e.delegate and e.delegate != e.pk}
    if delegate_keys:
        _warn_missing_keys(ledger, delegate_keys, "add-accounts")
    result = list(ledger)
    for entry in t.entries:
        result.append(Account(
            pk=entry.pk,
            balance=entry.balance,
            delegate=entry.delegate if entry.delegate else entry.pk,
        ))
    return result


def apply_strip_receipt_chain_hash(
    ledger: Ledger, t: StripReceiptChainHashTransform,
) -> Ledger:
    delegate_keys = set(t.delegate_keys)
    ledger_delegates = {a.delegate for a in ledger}
    missing = delegate_keys - ledger_delegates
    if missing:
        log.warning("strip-receipt-chain-hash: delegate keys not in ledger: %s",
                     ", ".join(sorted(missing)))
    return [
        a.model_copy(update={"receipt_chain_hash": None})
        if a.delegate in delegate_keys and a.receipt_chain_hash is not None
        else a
        for a in ledger
    ]


def apply_boost_last(ledger: Ledger, t: BoostLastTransform) -> Ledger:
    result = list(ledger)
    if t.count > len(result):
        log.warning("boost-last: count %d exceeds ledger size %d", t.count, len(result))
    for i in range(max(0, len(result) - t.count), len(result)):
        result[i] = result[i].model_copy(update={"balance": t.balance})
    return result


def apply_transform(ledger: Ledger, t: Transform) -> Ledger:
    match t:
        case RemoveAccountsTransform():
            return apply_remove_accounts(ledger, t)
        case CutoffDelegationTransform():
            return apply_cutoff_delegation(ledger, t)
        case ReplaceTopDelegationTransform():
            return apply_replace_top_delegation(ledger, t)
        case AddAccountsTransform():
            return apply_add_accounts(ledger, t)
        case StripReceiptChainHashTransform():
            return apply_strip_receipt_chain_hash(ledger, t)
        case BoostLastTransform():
            return apply_boost_last(ledger, t)


# ── Main ──────────────────────────────────────────────────────────────────


def run_spec(spec: Spec) -> Ledger:
    spec = resolve_aliases_in_spec(spec)
    validate_key_prefixes(spec)

    source_name = type(spec.source).__name__
    ledger = load_source(spec.source)
    log.info("Loaded %d accounts from %s", len(ledger), source_name)

    all_keys = collect_all_keys(spec)

    for t in spec.transforms:
        ledger = apply_transform(ledger, t)
        transform_name = type(t).__name__.replace("Transform", "")
        log.info("Applied %s: %d accounts", transform_name, len(ledger))

    total = sum(a.balance for a in ledger)
    if total == 0:
        fatal("Total balance is zero after transforms")

    if all_keys:
        print_stake_distribution(ledger, sorted(all_keys))

    return ledger


def main(spec: dict[str, str], output: str) -> None:
    """Patch a Mina ledger according to a JSON spec.

    Args:
        spec: JSON spec (fire handles parsing from inline JSON, file, etc).
        output: Output file path for the patched ledger JSON.
    """
    logging.basicConfig(
        level=logging.INFO,
        format="%(message)s",
        stream=sys.stderr,
    )
    parsed = Spec.model_validate(spec)
    ledger = run_spec(parsed)
    with open(output, "w") as f:
        json.dump(
            [a.model_dump(exclude_none=True) for a in ledger],
            f,
            indent=2,
        )
        f.write("\n")


if __name__ == "__main__":
    fire.Fire(main)
