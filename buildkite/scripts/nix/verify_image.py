#!/usr/bin/env python3
"""Assert a docker-archive tarball contains the paths the runtime contract needs.

Reads the tarball on stdin and writes it back out on stdout byte-for-byte, so it
can sit in the middle of a pipeline:

    ./result-mina-daemon-nix -t img:tag | verify_image.py daemon | zstd -o out

Why a pass-through filter and not `docker run`: the nix job runs inside the
nixos container, which has no docker socket (buildkite/src/Lib/Cmds.dhall mounts
only /var/storagebox, /var/secrets, /shared and the checkout). The images are
streamed straight from the nix store into the CI cache without a docker daemon
ever seeing them, so the contract has to be checked on the byte stream instead.

A docker-archive is a tar of uncompressed per-layer tars plus manifest.json, so
the check is a nested tar walk: collect every member name in every layer, then
assert the required paths turned up somewhere.
"""

import sys
import tarfile

# The daemon falls back on this file to resolve its proof level when MINA_PROFILE
# is unset, so an image whose binaries and whose hint disagree is a live trap --
# and one the mainnet-labelled, dev-profile mina-image-full walked straight into.
# Worth asserting the contents, not just that the file is there.
PROFILE_HINT = "etc/coda/build_config/PROFILE"

# A config file sitting in the image gets picked up implicitly by every node,
# and a fork element in it has broken the integration tests before. The images
# are supposed to ship binaries only and let the tests pass the runtime config
# on the command line, so assert that rather than trust it: no config of any
# kind in the image root. Store paths are exempt -- those are dependencies
# (python's stdlib and friends carry their own json files), not image config.
STORE_PREFIX = "nix/store/"

# What test_executive's docker engine drives: the entrypoint plus the puppeteer
# wrapper it uses to control the daemon lifecycle. mina-daemon-scripts in
# nix/docker.nix copies dockerfiles/puppeteer-context/* in -- assert it rather
# than assume, since these images are not routinely built.
CONTRACTS = {
    "daemon": [
        "entrypoint.sh",
        "start.sh",
        "stop.sh",
        "mina_daemon_puppeteer.py",
        "find_puppeteer.sh",
        "healthcheck/utilities.sh",
        "bin/mina",
        PROFILE_HINT,
    ],
    "archive": [
        "entrypoint.sh",
        "healthcheck/utilities.sh",
        "bin/mina-archive",
    ],
}


class Tee:
    """Read-only file object that copies everything it reads to `sink`."""

    def __init__(self, source, sink):
        self.source = source
        self.sink = sink

    def read(self, size=-1):
        chunk = self.source.read(size)
        if chunk:
            self.sink.write(chunk)
        return chunk


def normalise(name):
    """"./bin/mina", "/bin/mina" and "bin/mina" all name the same entry."""
    if name.startswith("./"):
        name = name[2:]
    return name.lstrip("/")


def collect(stream):
    """Walk the outer tar and every nested layer tar.

    Returns the set of names *inside the layers*, plus whatever PROFILE hints
    were found. Outer members are deliberately not collected: a docker-archive
    carries its own manifest.json and image-config json, which are metadata
    about the image rather than files in it, and would otherwise trip the
    no-config check below.

    The customisation layer holds /etc/coda/build_config/PROFILE as a symlink
    into the store, so the readable copy is the one in the store layer -- match
    on the suffix to catch it wherever it lands.
    """
    names = set()
    profiles = set()
    with tarfile.open(fileobj=stream, mode="r|") as outer:
        for member in outer:
            if not member.isfile() or not member.name.endswith(".tar"):
                continue
            layer = outer.extractfile(member)
            if layer is None:
                continue
            # A layer is an uncompressed tar; read it off the same stream.
            with tarfile.open(fileobj=layer, mode="r|") as inner:
                for entry in inner:
                    names.add(normalise(entry.name))
                    if entry.isfile() and entry.name.endswith(PROFILE_HINT):
                        hint = inner.extractfile(entry)
                        if hint is not None:
                            profiles.add(hint.read().decode().strip())
    return names, profiles


def main():
    if len(sys.argv) not in (2, 3) or sys.argv[1] not in CONTRACTS:
        sys.stderr.write(
            "Usage: %s {%s} [expected-profile]\n"
            % (sys.argv[0], "|".join(CONTRACTS))
        )
        return 2

    contract = sys.argv[1]
    expected_profile = sys.argv[2] if len(sys.argv) == 3 else None
    required = CONTRACTS[contract]
    stdin = sys.stdin.buffer
    stdout = sys.stdout.buffer

    try:
        names, profiles = collect(Tee(stdin, stdout))

        # Drain whatever trailing padding tarfile did not consume, so the image
        # we hand downstream is the whole stream and not a truncated prefix.
        while True:
            rest = stdin.read(1 << 20)
            if not rest:
                break
            stdout.write(rest)
        stdout.flush()
    except BrokenPipeError:
        # Whatever consumes the image (zstd) died. Its own failure is the real
        # error; report ours as a one-liner rather than a traceback.
        sys.stderr.write("ERROR: image consumer closed the pipe early\n")
        return 1

    missing = [path for path in required if path not in names]
    if missing:
        sys.stderr.write(
            "ERROR: %s image is missing required paths: %s\n"
            % (contract, ", ".join("/" + m for m in missing))
        )
        return 1

    configs = sorted(
        n
        for n in names
        if n.endswith(".json") and not n.startswith(STORE_PREFIX)
    )
    if configs:
        sys.stderr.write(
            "ERROR: %s image ships config in its root, which every node would "
            "load implicitly: %s\n"
            % (contract, ", ".join("/" + c for c in configs))
        )
        return 1

    if expected_profile is not None and profiles != {expected_profile}:
        sys.stderr.write(
            "ERROR: %s image should declare profile %r, found %s\n"
            % (
                contract,
                expected_profile,
                ", ".join(sorted(repr(p) for p in profiles)) or "nothing",
            )
        )
        return 1

    sys.stderr.write(
        "Runtime contract OK for %s image (%d paths checked, %d entries seen, "
        "no config in image root%s)\n"
        % (
            contract,
            len(required),
            len(names),
            ", profile %s" % expected_profile if expected_profile else "",
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
