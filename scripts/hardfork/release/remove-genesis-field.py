#!/usr/bin/env python3
"""Copy a runtime config without its top-level "genesis" field.

Token symbols and zkApp URIs are arbitrary bytes, so a runtime config is not
always valid UTF-8. jq replaces such bytes with U+FFFD and so changes the
ledger; surrogateescape keeps every byte.

Usage: remove-genesis-field.py <input.json> <output.json>
"""
import json
import sys

src, dst = sys.argv[1:]
with open(src, encoding="utf-8", errors="surrogateescape") as f:
    config = json.load(f)
config.pop("genesis", None)
with open(dst, "w", encoding="utf-8", errors="surrogateescape") as f:
    json.dump(config, f, ensure_ascii=False)
