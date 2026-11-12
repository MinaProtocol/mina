#!/usr/bin/env python3
"""Check a state dump before any hardfork artifact is built from it.

Needs only the dump and the fork block, so it can run first and fail within
seconds. It compares:

  - the bytes: no U+FFFD. Token symbols and zkApp URIs are arbitrary bytes, and
    a text-only JSON tool replaces the ones that are not UTF-8 with U+FFFD. The
    account then hashes differently, and the rebuilt ledger is not the chain's.
  - the fork point, the epoch seeds and the ledger hash, with the fork block.
  - the staking and next epoch ledgers: the default-token balances must sum to
    the block's total currency exactly. The staged ledger is left out: the
    block's total currency for it is that of the snarked ledger, which lags.

The dump is read byte for byte, as bytes that are not UTF-8 are legitimate.

The fork block comes from --block-prefix, by default from the bucket the
hardfork verifier falls back to.

Usage: check-fork-dump.py --network NAME --config-url URL [--block-prefix gs://bucket/network]
"""
import argparse
import gzip
import json
import sys
import urllib.request

REPLACEMENT_CHARACTER = "�".encode("utf-8")
DEFAULT_TOKEN = "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf"


def fetch(url):
    with urllib.request.urlopen(url) as response:
        return response.read()


def block_url(prefix, length, state_hash):
    prefix = prefix.replace("gs://", "https://storage.googleapis.com/", 1)
    return f"{prefix}-{length}-{state_hash}.json"


def nanomina(amount):
    whole, _, fraction = str(amount).partition(".")
    return int(whole) * 10**9 + int((fraction + "0" * 9)[:9])


def default_token_supply(accounts):
    return sum(
        nanomina(account.get("balance", 0))
        for account in accounts
        if account.get("token", DEFAULT_TOKEN) == DEFAULT_TOKEN
    )


def compare_with_block(config, block):
    body = block["data"]["protocol_state"]["body"]
    state = body["consensus_state"]
    fork = config["proof"]["fork"]
    epochs = config["epoch_data"]
    yield (
        "ledger hash",
        config["ledger"]["hash"],
        body["blockchain_state"]["staged_ledger_hash"]["non_snark"]["ledger_hash"],
    )
    yield "blockchain length", fork["blockchain_length"], state["blockchain_length"]
    yield (
        "global slot since genesis",
        fork["global_slot_since_genesis"],
        state["global_slot_since_genesis"],
    )
    for name, block_name in (("staking", "staking_epoch_data"), ("next", "next_epoch_data")):
        yield f"{name} seed", epochs[name]["seed"], state[block_name]["seed"]
        yield (
            f"{name} ledger total currency",
            default_token_supply(epochs[name]["accounts"]),
            state[block_name]["ledger"]["total_currency"],
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--network", required=True)
    parser.add_argument("--config-url", required=True)
    parser.add_argument("--block-prefix")
    args = parser.parse_args()

    dump = gzip.decompress(fetch(args.config_url))
    failures = []

    replaced = dump.count(REPLACEMENT_CHARACTER)
    print(f"{len(dump)} bytes, {replaced} U+FFFD, {dump.count(bytes([0xff]))} raw 0xff")
    if replaced:
        failures.append(f"the dump holds {replaced} U+FFFD: a text-only tool has rewritten it")

    config = json.loads(dump.decode("utf-8", "surrogateescape"))

    prefix = args.block_prefix or f"gs://mina_network_block_data/{args.network}"
    fork = config["proof"]["fork"]
    url = block_url(prefix, fork["blockchain_length"], fork["state_hash"])
    print(f"fork block: {url}")
    block = json.loads(fetch(url))
    for name, in_dump, in_block in compare_with_block(config, block):
        if str(in_dump) != str(in_block):
            failures.append(f"{name}: dump {in_dump}, fork block {in_block}")

    for failure in failures:
        print(f"Error: {failure}", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
