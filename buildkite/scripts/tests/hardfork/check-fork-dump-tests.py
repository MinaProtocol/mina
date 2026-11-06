#!/usr/bin/env python3
"""Tests for scripts/hardfork/release/check-fork-dump.py."""
import gzip
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[4]
SCRIPT = REPO_ROOT / "scripts/hardfork/release/check-fork-dump.py"
TOKEN = "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf"
OTHER_TOKEN = "xBxjFpJkbWpbGua7Lf36S1NLhffFoEChyP3pz6SYKnx7dFCTwg"


def account(balance, symbol="", token=TOKEN):
    return {"pk": "B62q", "token": token, "balance": balance, "token_symbol": symbol}


def fork_config():
    return {
        "proof": {
            "fork": {"state_hash": "3Nfork", "blockchain_length": 7, "global_slot_since_genesis": 9}
        },
        "ledger": {"hash": "jwledger", "accounts": [account("1")]},
        "epoch_data": {
            "staking": {
                "seed": "s",
                "accounts": [account("1.5"), account("2"), account("100", token=OTHER_TOKEN)],
            },
            "next": {"seed": "n", "accounts": [account("4")]},
        },
    }


def fork_block():
    return {
        "data": {
            "protocol_state": {
                "body": {
                    "blockchain_state": {
                        "staged_ledger_hash": {"non_snark": {"ledger_hash": "jwledger"}}
                    },
                    "consensus_state": {
                        "blockchain_length": "7",
                        "global_slot_since_genesis": "9",
                        "staking_epoch_data": {
                            "seed": "s",
                            "ledger": {"total_currency": "3500000000"},
                        },
                        "next_epoch_data": {
                            "seed": "n",
                            "ledger": {"total_currency": "4000000000"},
                        },
                    },
                }
            }
        }
    }


class CheckForkDump(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = pathlib.Path(self.tmp.name)

    def run_check(self, config, block=None):
        dump = self.dir / "dump.json.gz"
        text = json.dumps(config, ensure_ascii=False)
        dump.write_bytes(gzip.compress(text.encode("utf-8", "surrogateescape")))
        (self.dir / "net-7-3Nfork.json").write_text(json.dumps(block or fork_block()))
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--config-url",
                dump.as_uri(),
                "--block-prefix",
                (self.dir / "net").as_uri(),
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    def assert_fails(self, result, message):
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(message, result.stderr)

    def test_good_dump_passes(self):
        result = self.run_check(fork_config())
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_raw_byte_is_legitimate(self):
        config = fork_config()
        config["ledger"]["accounts"][0]["token_symbol"] = "\udcff"
        result = self.run_check(config)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_replacement_character_fails(self):
        config = fork_config()
        config["ledger"]["accounts"][0]["token_symbol"] = "�"
        self.assert_fails(self.run_check(config), "1 U+FFFD")

    def test_supply_one_nanomina_off_fails(self):
        block = fork_block()
        state = block["data"]["protocol_state"]["body"]["consensus_state"]
        state["next_epoch_data"]["ledger"]["total_currency"] = "4000000001"
        self.assert_fails(self.run_check(fork_config(), block), "next ledger total currency")

    def test_wrong_seed_fails(self):
        config = fork_config()
        config["epoch_data"]["staking"]["seed"] = "other"
        self.assert_fails(self.run_check(config), "staking seed")

    def test_wrong_ledger_hash_fails(self):
        config = fork_config()
        config["ledger"]["hash"] = "other"
        self.assert_fails(self.run_check(config), "ledger hash")

    def test_wrong_fork_slot_fails(self):
        config = fork_config()
        config["proof"]["fork"]["global_slot_since_genesis"] = 8
        self.assert_fails(self.run_check(config), "global slot since genesis")


if __name__ == "__main__":
    unittest.main()
