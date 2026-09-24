#!/usr/bin/env python3
"""Summarize Mina internal-tracing JSONL files.

The parser accepts the JSONL shape emitted by src/lib/internal_tracing and the
checkpoint-array display shape used by proof-system internal-tracing strings.
It does not require jq and intentionally preserves stream context semantics.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, DefaultDict, Iterable


@dataclass
class Checkpoint:
    file: str
    line: int
    tag: str
    timestamp: float
    block: str | None
    call_id: int | None
    call_tag: str | None


@dataclass
class FileSummary:
    path: Path
    lines: int = 0
    malformed: int = 0
    checkpoints: int = 0
    metadata: int = 0
    controls: Counter[str] = None  # type: ignore[assignment]
    tags: Counter[str] = None  # type: ignore[assignment]
    first_ts: float | None = None
    last_ts: float | None = None

    def __post_init__(self) -> None:
        self.controls = Counter()
        self.tags = Counter()


def context_key(cp: Checkpoint, mode: str) -> tuple[Any, ...]:
    if mode == "global":
        return ("global",)
    if mode == "block":
        return ("block", cp.block)
    if mode == "call":
        return ("call", cp.call_id, cp.call_tag)
    if mode == "block-call":
        return ("block-call", cp.block, cp.call_id, cp.call_tag)
    raise ValueError(f"unknown context mode: {mode}")


def update_time(summary: FileSummary, timestamp: float) -> None:
    if summary.first_ts is None or timestamp < summary.first_ts:
        summary.first_ts = timestamp
    if summary.last_ts is None or timestamp > summary.last_ts:
        summary.last_ts = timestamp


def parse_file(path: Path) -> tuple[FileSummary, list[Checkpoint]]:
    summary = FileSummary(path)
    checkpoints: list[Checkpoint] = []
    current_block: str | None = None
    current_call_id: int | None = None
    current_call_tag: str | None = None

    with path.open("r", encoding="utf-8") as handle:
        for lineno, raw_line in enumerate(handle, start=1):
            summary.lines += 1
            line = raw_line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                summary.malformed += 1
                continue

            if (
                isinstance(event, list)
                and len(event) == 2
                and isinstance(event[0], str)
                and isinstance(event[1], (int, float))
            ):
                timestamp = float(event[1])
                cp = Checkpoint(
                    file=str(path),
                    line=lineno,
                    tag=event[0],
                    timestamp=timestamp,
                    block=current_block,
                    call_id=current_call_id,
                    call_tag=current_call_tag,
                )
                checkpoints.append(cp)
                summary.checkpoints += 1
                summary.tags[cp.tag] += 1
                update_time(summary, timestamp)
                continue

            if isinstance(event, dict):
                for key, value in event.items():
                    summary.controls[key] += 1
                    if key == "metadata":
                        summary.metadata += 1
                    elif key == "current_block":
                        current_block = str(value) if value is not None else None
                    elif key == "current_call_id":
                        current_call_id = int(value) if isinstance(value, int) else None
                    elif key == "current_call_tag":
                        current_call_tag = str(value) if value is not None else None
                    elif key in ("internal_tracing_enabled", "internal_tracing_disabled"):
                        if isinstance(value, (int, float)):
                            update_time(summary, float(value))
                if "current_call_id" in event and "current_call_tag" not in event:
                    current_call_tag = None
                continue

            summary.malformed += 1

    return summary, checkpoints


def format_seconds(seconds: float) -> str:
    if seconds >= 1.0:
        return f"{seconds:.3f}s"
    return f"{seconds * 1000.0:.3f}ms"


def compute_gaps(
    checkpoints: Iterable[Checkpoint], mode: str
) -> list[tuple[float, Checkpoint, Checkpoint, tuple[Any, ...]]]:
    grouped: DefaultDict[tuple[Any, ...], list[Checkpoint]] = defaultdict(list)
    for cp in checkpoints:
        grouped[context_key(cp, mode)].append(cp)

    gaps: list[tuple[float, Checkpoint, Checkpoint, tuple[Any, ...]]] = []
    for key, cps in grouped.items():
        cps.sort(key=lambda cp: cp.timestamp)
        for before, after in zip(cps, cps[1:]):
            delta = after.timestamp - before.timestamp
            if delta >= 0:
                gaps.append((delta, before, after, key))
    gaps.sort(key=lambda item: item[0], reverse=True)
    return gaps


def print_file_summary(summary: FileSummary, top_tags: int) -> None:
    print(f"\n== {summary.path} ==")
    print(f"lines: {summary.lines}")
    print(f"checkpoints: {summary.checkpoints}")
    print(f"metadata lines: {summary.metadata}")
    print(f"malformed lines: {summary.malformed}")
    if summary.first_ts is not None and summary.last_ts is not None:
        print(
            "time range: "
            f"{summary.first_ts:.6f} .. {summary.last_ts:.6f} "
            f"({format_seconds(summary.last_ts - summary.first_ts)})"
        )
    if summary.controls:
        controls = ", ".join(
            f"{key}={count}" for key, count in summary.controls.most_common()
        )
        print(f"controls: {controls}")
    if summary.tags:
        print("top checkpoint tags:")
        for tag, count in summary.tags.most_common(top_tags):
            print(f"  {count:6d}  {tag}")


def print_gap_summary(
    checkpoints: list[Checkpoint], mode: str, top_gaps: int
) -> None:
    gaps = compute_gaps(checkpoints, mode)
    print(f"\n== top adjacent gaps by {mode} context ==")
    if not gaps:
        print("no adjacent checkpoint gaps found")
        return
    for delta, before, after, key in gaps[:top_gaps]:
        key_text = ", ".join("<none>" if item is None else str(item) for item in key)
        print(
            f"{format_seconds(delta):>12}  "
            f"{before.tag} -> {after.tag}  "
            f"context=({key_text})  "
            f"at {after.file}:{after.line}"
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path, help="JSONL trace files")
    parser.add_argument(
        "--context",
        choices=["global", "block", "call", "block-call"],
        default="block-call",
        help="context grouping for adjacent gap calculation",
    )
    parser.add_argument("--top-gaps", type=int, default=20)
    parser.add_argument("--top-tags", type=int, default=20)
    args = parser.parse_args()

    all_checkpoints: list[Checkpoint] = []
    had_missing = False
    for path in args.files:
        if not path.exists():
            print(f"\n== {path} ==")
            print("missing file")
            had_missing = True
            continue
        summary, checkpoints = parse_file(path)
        print_file_summary(summary, args.top_tags)
        all_checkpoints.extend(checkpoints)

    print_gap_summary(all_checkpoints, args.context, args.top_gaps)
    return 1 if had_missing else 0


if __name__ == "__main__":
    raise SystemExit(main())
