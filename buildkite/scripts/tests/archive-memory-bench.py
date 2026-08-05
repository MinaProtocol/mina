#!/usr/bin/env python3
"""Archive-node end-to-end memory benchmark (CI runner).

Replays a static, zkApp-heavy corpus of precomputed blocks
(src/test/archive/sample_zkapp_heavy) through the REAL archive insert path
(archive_blocks --precomputed -> Processor.add_block_aux_precomputed -> the
Mina_caqti helpers) directly into PostgreSQL, and samples the resident memory of
both sides while it runs:

  * the archive_blocks OCaml process (Caqti prepared-statement cache growth)
  * the serving PostgreSQL backend (server-side plan cache / CacheMemoryContext)

A leaking build grows the backend's RSS roughly with the number of blocks and
zkApp events/actions ingested; a fixed build keeps it flat. The result is
written as InfluxDB line protocol so buildkite/scripts/bench/send.sh uploads it,
using the same measurement/tag convention as the mina_caqti micro-benchmark.

The PostgreSQL instance -- with the archive schema already loaded -- is provided
by RunWithPostgres, which exports POSTGRES_URI / POSTGRES_DB.
"""

import argparse
import os
import shlex
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path

# archive_blocks is still initialising below this RSS; those samples would
# understate the growth, so they are dropped before the metrics are computed.
STARTUP_RSS_KIB = 50_000

CURVE_HEADER = "elapsed_s,blocks_done,ab_rss_kib,pg_rss_kib"


def repo_root():
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        check=True,
        capture_output=True,
        text=True,
    )
    return Path(out.stdout.strip())


def parse_args():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "--corpus",
        type=Path,
        default=Path("src/test/archive/sample_zkapp_heavy/precomputed_blocks.tar.xz"),
        help="corpus archive to replay, relative to the repository root",
    )
    parser.add_argument(
        "--perf-file",
        type=Path,
        default=Path(
            os.environ.get("PERF_OUTPUT_FILE", "/workdir/archive_memory_bench.perf")
        ),
        help="where to write the InfluxDB line protocol",
    )
    parser.add_argument(
        "--sample-interval",
        type=float,
        default=float(os.environ.get("ARCHIVE_BENCH_SAMPLE_SEC", "1")),
        help="seconds between memory samples",
    )
    parser.add_argument(
        "--measurement",
        default=os.environ.get("ARCHIVE_BENCH_MEASUREMENT", "archive_memory_bench"),
        help="InfluxDB measurement name",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="replay only the first N blocks of the corpus (0 = all)",
    )
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="assume archive_blocks.exe is already built",
    )
    return parser.parse_args()


def load_build_env():
    """Apply `opam env` to this process, as `eval $(opam config env)` would.

    archive_blocks reaches mina_base, whose kimchi bindings need the Rust
    toolchain, so the cargo directory joins PATH as well.
    """
    os.environ["PATH"] = "/home/opam/.cargo/bin:" + os.environ.get("PATH", "")
    out = subprocess.run(
        ["opam", "env", "--shell=sh"], check=True, capture_output=True, text=True
    )
    for statement in out.stdout.split(";"):
        statement = statement.strip()
        if not statement or statement.startswith("export"):
            continue
        name, _, value = statement.partition("=")
        if not value:
            continue
        os.environ[name.strip()] = " ".join(shlex.split(value))


def read_vm_rss_kib(pid):
    """VmRSS of a process in KiB, or 0 if it is gone."""
    try:
        with open(f"/proc/{pid}/status", encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("VmRSS:"):
                    return int(line.split()[1])
    except (OSError, ValueError, IndexError):
        pass
    return 0


class Postgres:
    """The psql queries this benchmark needs."""

    def __init__(self, uri, database):
        self.uri = uri
        self.database = database

    def query(self, sql):
        result = subprocess.run(
            ["psql", "-tAq", self.uri, "-c", sql],
            capture_output=True,
            text=True,
            check=False,
        )
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]

    def client_backend_pids(self):
        return self.query(
            "select pid from pg_stat_activity "
            f"where datname='{self.database}' and backend_type='client backend' "
            "and pid<>pg_backend_pid()"
        )

    def backend_rss_kib(self):
        total = 0
        for pid in self.client_backend_pids():
            try:
                total += read_vm_rss_kib(int(pid))
            except ValueError:
                continue
        return total


def unpack_corpus(archive, destination, limit=0):
    with tarfile.open(archive) as tar:
        try:
            tar.extractall(destination, filter="data")
        except TypeError:
            # the filter argument only exists from Python 3.12
            tar.extractall(destination)
    blocks = sorted(str(p) for p in destination.rglob("*.json"))
    return blocks[:limit] if limit > 0 else blocks


def count_lines(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return 0


def feed_and_sample(archive_blocks, blocks, postgres, workdir, sample_interval):
    """Run archive_blocks over the corpus, sampling both sides once a second.

    Returns (curve, ingest_seconds, successes, failures, log path). Each curve
    row is (elapsed_s, blocks_done, archive_rss_kib, pg_backend_rss_kib).
    """
    successful = workdir / "successful"
    failed = workdir / "failed"
    successful.touch()
    failed.touch()
    log = workdir / "archive_blocks.log"

    with log.open("w", encoding="utf-8") as handle:
        process = subprocess.Popen(
            [
                str(archive_blocks),
                "--archive-uri",
                postgres.uri,
                "--precomputed",
                "--successful-files",
                str(successful),
                "--failed-files",
                str(failed),
                "--log-successful",
                "false",
                *blocks,
            ],
            stdout=handle,
            stderr=subprocess.STDOUT,
        )

        curve = []
        started = time.monotonic()
        while process.poll() is None:
            curve.append(
                (
                    int(time.monotonic() - started),
                    count_lines(successful),
                    read_vm_rss_kib(process.pid),
                    postgres.backend_rss_kib(),
                )
            )
            time.sleep(sample_interval)
        ingest_seconds = int(time.monotonic() - started)

    if process.returncode != 0:
        print("archive_blocks failed:")
        print(log.read_text(encoding="utf-8", errors="replace"))
        sys.exit(1)

    return curve, ingest_seconds, count_lines(successful), count_lines(failed), log


def compute_metrics(curve):
    """Archive RSS growth, PG-backend RSS peak and the tail-average of it.

    The pre-init startup samples are dropped, then the archive's growth is
    measured across the remaining ones. The tail average covers the final third
    of the run -- the sustained level once the zkApp-heavy tail is ingested.
    Peak and tail-mean both track the leak monotonically.
    """
    steady = [row for row in curve if row[2] > STARTUP_RSS_KIB]
    archive_growth = steady[-1][2] - steady[0][2] if steady else 0

    backend = [row[3] for row in steady if row[3] > 0]
    peak = max(backend, default=0)
    tail = backend[2 * len(backend) // 3 :]
    if backend:
        tail_average = sum(tail) // len(tail) if tail else peak
    else:
        tail_average = 0
    return archive_growth, peak, tail_average


def sanitize(value):
    """Line-protocol tag values carry no unescaped spaces, commas or equals."""
    return "".join("_" if c in " ,=" else c for c in str(value))


def influx_line(measurement, fields, tags):
    tag_text = ",".join(f"{k}={sanitize(v)}" for k, v in tags.items())
    field_text = ",".join(f"{k}={v}" for k, v in fields.items())
    return f"{sanitize(measurement)},{tag_text} {field_text} {time.time_ns()}"


def main():
    args = parse_args()
    root = repo_root()
    os.chdir(root)

    postgres_uri = os.environ.get("POSTGRES_URI")
    if not postgres_uri:
        sys.exit("POSTGRES_URI must be set")
    database = os.environ.get("POSTGRES_DB")
    if not database:
        sys.exit("POSTGRES_DB must be set")
    postgres = Postgres(postgres_uri, database)

    archive_blocks = root / "_build/default/src/app/archive_blocks/archive_blocks.exe"
    if not args.skip_build:
        load_build_env()
        print("Building archive_blocks...")
        subprocess.run(
            ["dune", "build", "src/app/archive_blocks/archive_blocks.exe"], check=True
        )

    print("Unpacking the static zkApp-heavy corpus...")
    workdir = Path(tempfile.mkdtemp())
    blocks = unpack_corpus(root / args.corpus, workdir, args.limit)
    print(f"  {len(blocks)} precomputed blocks")

    print("Feeding blocks and sampling memory...")
    curve, ingest_seconds, blocks_ok, blocks_failed, _log = feed_and_sample(
        archive_blocks, blocks, postgres, workdir, args.sample_interval
    )
    archive_growth, backend_peak, backend_tail_average = compute_metrics(curve)
    blocks_per_sec = blocks_ok / ingest_seconds if ingest_seconds > 0 else 0.0

    line = influx_line(
        args.measurement,
        {
            "blocks_ok": f"{blocks_ok}i",
            "blocks_failed": f"{blocks_failed}i",
            "archive_rss_growth_kib": f"{archive_growth}i",
            "pg_backend_rss_peak_kib": f"{backend_peak}i",
            "pg_backend_rss_tail_avg_kib": f"{backend_tail_average}i",
            "ingest_seconds": f"{ingest_seconds}i",
            "blocks_per_sec": f"{blocks_per_sec:.3f}",
        },
        {
            "variant": os.environ.get("MINA_BENCH_VARIANT", "ci"),
            "git_branch": os.environ.get(
                "BUILDKITE_BRANCH", os.environ.get("GIT_BRANCH", "unknown")
            ),
            "git_commit": os.environ.get(
                "BUILDKITE_COMMIT", os.environ.get("GIT_COMMIT", "unknown")
            ),
        },
    )

    args.perf_file.parent.mkdir(parents=True, exist_ok=True)
    args.perf_file.write_text(line + "\n", encoding="utf-8")

    print("=== growth curve ===")
    print(CURVE_HEADER)
    for row in curve:
        print(",".join(str(value) for value in row))
    print("=== summary ===")
    print(f"  blocks_ok={blocks_ok} blocks_failed={blocks_failed}")
    print(f"  archive_blocks RSS growth   : {archive_growth} KiB")
    print(
        f"  pg backend RSS peak         : {backend_peak} KiB "
        f"({backend_peak // 1024} MiB)"
    )
    print(
        f"  pg backend RSS tail average : {backend_tail_average} KiB "
        f"({backend_tail_average // 1024} MiB)"
    )
    print(f"  ingest time                 : {ingest_seconds} s")
    print(f"  throughput                  : {blocks_per_sec:.3f} blocks/s")
    print(f"=== influxdb line protocol -> {args.perf_file} ===")
    print(line)


if __name__ == "__main__":
    main()
