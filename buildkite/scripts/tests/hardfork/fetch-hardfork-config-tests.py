#!/usr/bin/env python3
"""Tests for buildkite/scripts/hardfork/release/fetch-hardfork-config.sh.

An archive comes from outside this build, and its tarballs are uploaded
publicly. So every refused archive is also checked to reach neither the upload
nor the build cache.
"""
import copy
import gzip
import io
import json
import os
import pathlib
import stat
import subprocess
import tarfile
import tempfile
import unittest

REPO_ROOT = pathlib.Path(__file__).resolve().parents[4]
SCRIPT = REPO_ROOT / "buildkite/scripts/hardfork/release/fetch-hardfork-config.sh"

CACHE_STUB = """#!/bin/bash
# buildkite-cache-manager write <file>... <dest>
shift
args=("$@")
dest="${args[-1]}"
unset 'args[-1]'
mkdir -p "$STUB_CACHE/$dest"
cp "${args[@]}" "$STUB_CACHE/$dest"
"""

AWS_STUB = """#!/bin/bash
if [[ "$1 $2" == "s3 cp" ]]; then
  echo "$3" >> "$STUB_UPLOADS"
fi
"""


def config(prefix, next_s3=None):
    return {
        "proof": {
            "fork": {"state_hash": "3Nfork", "blockchain_length": 7, "global_slot_since_genesis": 9}
        },
        "ledger": {"hash": f"{prefix}L", "s3_data_hash": f"{prefix}ls3"},
        "epoch_data": {
            "staking": {"seed": "s", "hash": f"{prefix}S", "s3_data_hash": f"{prefix}ss3"},
            "next": {"seed": "n", "hash": f"{prefix}N", "s3_data_hash": next_s3 or f"{prefix}ns3"},
        },
    }


class Archive:
    """The directory the daemon writes, as tar members."""

    TARBALLS = ("genesis_ledger_a.tar.gz", "epoch_ledger_b.tar.gz", "epoch_ledger_c.tar.gz")

    def __init__(self):
        self.members = {"activated": b""}
        self.members["daemon.json"] = json.dumps(config("new")).encode()
        self.members["fork_validation/legacy/daemon.json"] = json.dumps(config("old")).encode()
        for directory in ("genesis", "fork_validation/legacy/genesis"):
            for name in self.TARBALLS:
                self.members[f"{directory}/{name}"] = b"ledger"
        self.special = []

    def write(self, path):
        with tarfile.open(path, "w:gz") as tar:
            for name, data in self.members.items():
                info = tarfile.TarInfo(name)
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
            for info in self.special:
                tar.addfile(info)


def special(name, kind, target=""):
    info = tarfile.TarInfo(name)
    info.type = kind
    info.linkname = target
    return info


class FetchHardforkConfig(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = pathlib.Path(self.tmp.name)
        self.bin = self.dir / "bin"
        self.bin.mkdir()
        self.cache = self.dir / "cache"
        self.cache.mkdir()
        self.uploads = self.dir / "uploads"
        for name, body in (("buildkite-cache-manager", CACHE_STUB), ("aws", AWS_STUB)):
            stub = self.bin / name
            stub.write_text(body)
            stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
        self.secret = self.dir / "secret"
        self.secret.write_text("aws_secret_access_key=SUPERSECRET")
        # The dump holds the chain's ledger, which the legacy side of the
        # archive must be.
        self.dump = self.dir / "dump.json.gz"
        self.write_dump(config("old"))

    def write_dump(self, dump):
        self.dump.write_bytes(gzip.compress(json.dumps(dump).encode()))

    def fetch(self, archive):
        path = self.dir / "config.tar.gz"
        archive.write(path)
        env = dict(
            os.environ,
            PATH=f"{self.bin}:{os.environ['PATH']}",
            STUB_CACHE=str(self.cache),
            STUB_UPLOADS=str(self.uploads),
            MINA_LEDGER_S3_BUCKET="https://s3-us-west-2.amazonaws.com/test-bucket",
            GENESIS_TIMESTAMP="2026-11-06T18:00:00Z",
        )
        return subprocess.run(
            [
                "bash",
                str(SCRIPT),
                "--network",
                "mainnet",
                "--url",
                path.as_uri(),
                "--config-json-gz-url",
                self.dump.as_uri(),
            ],
            cwd=REPO_ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )

    def assert_refused(self, result, message):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stderr)
        self.assertFalse(self.uploads.exists(), "nothing may be uploaded")
        self.assertEqual(list(self.cache.iterdir()), [], "nothing may reach the cache")

    def test_good_archive(self):
        result = self.fetch(Archive())
        self.assertEqual(result.returncode, 0, result.stderr)
        new_config = json.loads((self.cache / "hardfork/new_config.json").read_text())
        self.assertEqual(new_config["ledger"]["hash"], "newL")
        self.assertEqual(new_config["genesis"]["genesis_state_timestamp"], "2026-11-06T18:00:00Z")
        self.assertEqual(new_config["daemon"]["network_id"], "mainnet")
        legacy = json.loads((self.cache / "hardfork/legacy/legacy_hashes.json").read_text())
        self.assertEqual(legacy["ledger"]["hash"], "oldL")
        self.assertEqual(len(list((self.cache / "hardfork/ledgers").glob("*.tar.gz"))), 3)
        self.assertEqual(len(list((self.cache / "hardfork/legacy").glob("*.tar.gz"))), 3)
        self.assertEqual(len(self.uploads.read_text().splitlines()), 3)

    def test_symlink_tarball_is_refused(self):
        archive = Archive()
        del archive.members["genesis/epoch_ledger_c.tar.gz"]
        archive.special.append(
            special("genesis/epoch_ledger_c.tar.gz", tarfile.SYMTYPE, str(self.secret))
        )
        result = self.fetch(archive)
        self.assert_refused(result, "entries other than files and directories")
        self.assertNotIn("SUPERSECRET", result.stdout + result.stderr)

    def test_symlink_config_is_refused(self):
        archive = Archive()
        del archive.members["daemon.json"]
        archive.special.append(special("daemon.json", tarfile.SYMTYPE, str(self.secret)))
        self.assert_refused(self.fetch(archive), "entries other than files and directories")

    def test_hard_link_is_refused(self):
        archive = Archive()
        del archive.members["genesis/epoch_ledger_c.tar.gz"]
        archive.special.append(
            special("genesis/epoch_ledger_c.tar.gz", tarfile.LNKTYPE, "activated")
        )
        self.assert_refused(self.fetch(archive), "entries other than files and directories")

    def test_fifo_is_refused(self):
        archive = Archive()
        archive.special.append(special("genesis/pipe", tarfile.FIFOTYPE))
        self.assert_refused(self.fetch(archive), "entries other than files and directories")

    def test_directory_in_place_of_a_file_is_refused(self):
        archive = Archive()
        del archive.members["activated"]
        archive.special.append(special("activated", tarfile.DIRTYPE))
        self.assert_refused(self.fetch(archive), "missing: activated")

    def test_missing_hash_is_refused(self):
        archive = Archive()
        broken = config("new")
        del broken["ledger"]["hash"]
        archive.members["daemon.json"] = json.dumps(broken).encode()
        self.assert_refused(self.fetch(archive), "does not hold the hash")

    def test_missing_legacy_tarball_hash_is_refused(self):
        archive = Archive()
        broken = copy.deepcopy(config("old"))
        broken["epoch_data"]["next"]["s3_data_hash"] = ""
        archive.members["fork_validation/legacy/daemon.json"] = json.dumps(broken).encode()
        self.assert_refused(self.fetch(archive), "does not hold the hash")

    def test_other_fork_block_is_refused(self):
        other = config("old")
        other["proof"]["fork"]["state_hash"] = "3Nother"
        self.write_dump(other)
        self.assert_refused(self.fetch(Archive()), "not from the same fork block")

    def test_legacy_ledger_other_than_the_dump_is_refused(self):
        self.write_dump(config("x"))
        self.assert_refused(
            self.fetch(Archive()), "legacy genesis ledger of the hardfork config is not the ledger"
        )

    def test_dump_without_ledger_hash_is_refused(self):
        dump = config("old")
        del dump["ledger"]["hash"]
        self.write_dump(dump)
        self.assert_refused(self.fetch(Archive()), "state dump holds no ledger hash")

    def test_shared_epoch_tarball_is_accepted(self):
        archive = Archive()
        archive.members["daemon.json"] = json.dumps(config("new", next_s3="newss3")).encode()
        del archive.members["genesis/epoch_ledger_c.tar.gz"]
        result = self.fetch(archive)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_tarball_is_refused(self):
        archive = Archive()
        del archive.members["genesis/epoch_ledger_c.tar.gz"]
        self.assert_refused(self.fetch(archive), "holds 2 ledger tarballs, expected 3")


if __name__ == "__main__":
    unittest.main()
