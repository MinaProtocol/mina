#!/usr/bin/env python3
"""Archive-node end-to-end memory benchmark (CI runner).

Replays a static, zkApp-heavy corpus of precomputed blocks
(src/test/archive/sample_zkapp_heavy) through the REAL archive insert path
(archive_blocks --precomputed -> Processor.add_block_aux_precomputed -> the
Mina_caqti helpers) directly into PostgreSQL, and samples the resident memory of
both sides while it runs:

  * the archive_blocks OCaml process (Caqti prepared-statement cache growth)
  * the serving PostgreSQL backend (server-side plan cache / CacheMemoryContext)

Caqti keys its per-connection prepared-statement cache by request object, so a
helper that builds a fresh request per call leaves one more prepared statement
on the backend every time it runs. The leak is therefore *per connection*, and
it only accumulates while that one connection stays open.

Two things are done so the samples can show it:

  * The Caqti pool is pinned to a single connection that is never recycled (see
    CAQTI_POOL_ENV). Without this, archive_blocks spreads the ingest over
    several backends and Caqti drops each one after CAQTI_POOL_MAX_USE_COUNT
    uses -- 100 by default -- which discards the accumulated plan cache and
    turns the curve into a sawtooth that hides the leak.
  * Growth is reported as a least-squares slope against the number of zkApp
    arrays actually inserted, not against elapsed time. The corpus is a chain,
    so its zkApp-heavy blocks all arrive near the end; measured against time,
    "the heavy blocks started" is indistinguishable from "memory is leaking".
    Measured against inserted arrays, workload composition cancels out and a
    non-zero slope is the leak itself.

No baseline or threshold is applied. The archive is known to leak; this job
measures how much, it does not decide whether to fail.

The result is written as InfluxDB line protocol so buildkite/scripts/bench/send.sh
uploads it, using the same measurement/tag convention as the mina_caqti
micro-benchmark.

The PostgreSQL instance -- with the archive schema already loaded -- is provided
by RunWithPostgres, which exports PG_CONN (the URI of the archive database),
POSTGRES_URI (the same server, but with no database in its path) and
POSTGRES_DB. See resolve_archive_uri below for how the three are reconciled.
"""

import argparse
import os
import shlex
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

CURVE_HEADER = "elapsed_s,blocks_done,zkapp_arrays,ab_rss_kib,pg_rss_kib,pg_backends"

# how many lines of the archive_blocks log to print when blocks fail to insert
LOG_TAIL_LINES = 60

# Caqti reads these when connect_pool calls Caqti_pool_config.default_from_env,
# and they win over the ?max_size argument (connect_pool merges the environment
# config to the left). Together they give the ingest exactly one PostgreSQL
# backend that lives for the whole run:
#
#   MAX_SIZE / MAX_IDLE_SIZE = 1  one connection, kept in the pool between uses
#   MAX_IDLE_AGE   = none         never closed for being idle
#   MAX_USE_COUNT  = none         never recycled after N uses (the default, 100,
#                                 exists precisely because state accumulates on
#                                 the server side -- which is what is measured
#                                 here, so it must not be discarded)
CAQTI_POOL_ENV = {
    "CAQTI_POOL_MAX_SIZE": "1",
    "CAQTI_POOL_MAX_IDLE_SIZE": "1",
    "CAQTI_POOL_MAX_IDLE_AGE": "none",
    "CAQTI_POOL_MAX_USE_COUNT": "none",
}


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
        default=float(os.environ.get("ARCHIVE_BENCH_SAMPLE_SEC", "0.5")),
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
        "--max-failed-blocks",
        type=int,
        default=0,
        help="publish nothing if more blocks than this fail to insert",
    )
    parser.add_argument(
        "--no-pin-pool",
        action="store_true",
        help="do not pin the Caqti pool to one connection (the curve then "
        "mixes several backends and hides the leak; for comparison only)",
    )
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="assume archive_blocks.exe is already built",
    )
    return parser.parse_args()


def load_build_env():
    """Apply `opam env` to this process, as `eval $(opam config env)` would.

    The toolchain image already carries the Go and Rust directories in PATH,
    but not the opam switch: the image sets no opam variables, and the job
    overrides the entrypoint, so nothing sources them.
    """
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


def resolve_archive_uri():
    """The URI of the database the archive schema was loaded into.

    RunWithPostgres exports two URIs that differ: PG_CONN names the archive
    database, while POSTGRES_URI carries no database in its path, so libpq
    falls back to `dbname = user` and archive_blocks would reach the empty
    `postgres` database instead. PG_CONN is therefore preferred; a bare
    POSTGRES_URI is joined with POSTGRES_DB.
    """
    for name in ("PG_CONN", "POSTGRES_URI"):
        uri = os.environ.get(name)
        if not uri:
            continue
        parts = urlsplit(uri)
        if parts.path.strip("/"):
            return uri
        database = os.environ.get("POSTGRES_DB")
        if not database:
            sys.exit(f"{name} names no database and POSTGRES_DB is not set")
        return urlunsplit(parts._replace(path=f"/{database}"))
    sys.exit("PG_CONN or POSTGRES_URI must be set")


class Sample:
    """One point of the growth curve."""

    def __init__(self, elapsed, blocks, arrays, archive_rss, backend_rss, pids):
        self.elapsed = elapsed
        self.blocks = blocks
        self.arrays = arrays
        self.archive_rss = archive_rss
        self.backend_rss = backend_rss
        self.pids = pids

    def row(self):
        return (
            self.elapsed,
            self.blocks,
            self.arrays,
            self.archive_rss,
            self.backend_rss,
            len(self.pids),
        )


class Postgres:
    """The psql queries this benchmark needs."""

    def __init__(self, uri):
        self.uri = uri

    def query(self, sql):
        result = subprocess.run(
            ["psql", "-tAq", self.uri, "-c", sql],
            capture_output=True,
            text=True,
            check=False,
        )
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]

    def database(self):
        names = self.query("select current_database()")
        return names[0] if names else "unknown"

    def server_version_num(self):
        """The server version as an integer, e.g. 140012, or 0 if unknown."""
        rows = self.query("show server_version_num")
        try:
            return int(rows[0])
        except (IndexError, ValueError):
            return 0

    def has_archive_schema(self):
        """Whether create_schema.sql was loaded into the database in use."""
        return self.query("select to_regclass('public.blocks') is not null") == ["t"]

    def sample(self):
        """(blocks stored, zkApp arrays stored, RSS in KiB, backend pids).

        Everything comes from a single psql call: each call opens a backend of
        its own, and a second call racing the first one's exit would count that
        dying backend in the RSS. psql connects with the same URI as
        archive_blocks, so current_database() is by construction the database
        being benchmarked. The sampler's own backend is excluded by pid, and
        the backend of a previous sample that has not finished exiting is
        excluded by application_name: psql sets it, libpq under Caqti leaves it
        empty, so what remains is the ingest.

        The zkApp array count is the number of rows in the two variable-width
        array tables, zkapp_field_array and zkapp_events. Those are the inserts
        that drive the leaking helpers, so they -- not elapsed time and not the
        block count, 93% of which carry no zkApp command at all -- are the
        quantity memory growth is measured against.
        """
        rows = self.query(
            "select (select count(*) from blocks), "
            "(select count(*) from zkapp_field_array) "
            "+ (select count(*) from zkapp_events), "
            "coalesce(string_agg(pid::text, ' '), '') from pg_stat_activity "
            "where datname=current_database() and backend_type='client backend' "
            "and pid<>pg_backend_pid() "
            "and coalesce(application_name, '') <> 'psql'"
        )
        if not rows:
            return 0, 0, 0, []
        fields = rows[0].split("|")
        if len(fields) != 3:
            return 0, 0, 0, []
        pids = []
        rss = 0
        for pid in fields[2].split():
            try:
                pids.append(int(pid))
            except ValueError:
                continue
            rss += read_vm_rss_kib(pids[-1])
        try:
            blocks = int(fields[0])
        except ValueError:
            blocks = 0
        try:
            arrays = int(fields[1])
        except ValueError:
            arrays = 0
        return blocks, arrays, rss, pids


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
    """Lines in a file, or 0 if it is not there.

    archive_blocks buffers its --successful-files / --failed-files lists until
    it exits, so these counts are the final verdict, not live progress.
    """
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return sum(1 for _ in handle)
    except OSError:
        return 0


def print_log_tail(log, lines=LOG_TAIL_LINES):
    """Print the last lines of the archive_blocks log, for diagnosis."""
    try:
        text = log.read_text(encoding="utf-8", errors="replace")
    except OSError as error:
        print(f"could not read {log}: {error}")
        return
    tail = text.splitlines()[-lines:]
    print(f"=== last {len(tail)} lines of {log} ===")
    for line in tail:
        print(line)


def ingest_env(pin_pool):
    """The environment archive_blocks runs under."""
    env = dict(os.environ)
    if pin_pool:
        env.update(CAQTI_POOL_ENV)
    return env


def feed_and_sample(archive_blocks, blocks, postgres, workdir, args):
    """Run archive_blocks over the corpus, sampling both sides as it goes.

    Returns (curve, ingest_seconds, successes, failures, log path), where the
    curve is a list of Sample.
    """
    successful = workdir / "successful"
    failed = workdir / "failed"
    successful.touch()
    failed.touch()
    log = workdir / "archive_blocks.log"
    # progress is read from the database, so start from whatever it already holds
    blocks_before, arrays_before, _, _ = postgres.sample()

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
            env=ingest_env(not args.no_pin_pool),
        )

        curve = []
        started = time.monotonic()
        while process.poll() is None:
            archive_rss = read_vm_rss_kib(process.pid)
            blocks_stored, arrays_stored, backend_rss, pids = postgres.sample()
            curve.append(
                Sample(
                    round(time.monotonic() - started, 1),
                    blocks_stored - blocks_before,
                    arrays_stored - arrays_before,
                    archive_rss,
                    backend_rss,
                    pids,
                )
            )
            time.sleep(args.sample_interval)
        ingest_seconds = int(time.monotonic() - started)

    if process.returncode != 0:
        print(f"archive_blocks exited with {process.returncode}")
        print_log_tail(log)
        sys.exit(1)

    return curve, ingest_seconds, count_lines(successful), count_lines(failed), log


def steady_samples(curve):
    """The samples taken after archive_blocks has finished starting up.

    Ingestion begins at the first sample that reports a block written; the
    samples before it cover process start-up, whose ramp would be counted as
    growth. Deciding this from the curve itself -- rather than from a fixed
    RSS threshold -- keeps the baseline correct whatever the binary's
    footprint becomes. A run too short for any sample to catch a block falls
    back to the first sample with a known RSS.
    """
    for index, sample in enumerate(curve):
        if sample.blocks > 0:
            return curve[index:]
    return [sample for sample in curve if sample.archive_rss > 0]


def linear_fit(points):
    """(slope, r_squared) of a least-squares line through (x, y) points.

    Returns (0.0, 0.0) when there is nothing to fit or x does not vary, so a
    run that inserted no zkApp array reports no growth rather than failing.
    """
    if len(points) < 2:
        return 0.0, 0.0
    n = float(len(points))
    mean_x = sum(x for x, _ in points) / n
    mean_y = sum(y for _, y in points) / n
    var_x = sum((x - mean_x) ** 2 for x, _ in points)
    if var_x == 0:
        return 0.0, 0.0
    covariance = sum((x - mean_x) * (y - mean_y) for x, y in points)
    slope = covariance / var_x
    var_y = sum((y - mean_y) ** 2 for _, y in points)
    r_squared = (covariance**2) / (var_x * var_y) if var_y > 0 else 0.0
    return slope, r_squared


def growth_slope(samples, value):
    """(KiB per 1000 zkApp arrays, r_squared) of `value` over the samples.

    Only the samples in which zkApp arrays are actually being inserted are
    fitted: before the first array lands there is no leaking work to attribute
    memory to, and including that stretch would flatten the slope towards zero.
    """
    points = [
        (sample.arrays, value(sample))
        for sample in samples
        if sample.arrays > 0 and value(sample) > 0
    ]
    slope, r_squared = linear_fit(points)
    return slope * 1000.0, r_squared


def compute_metrics(curve):
    """Everything the summary and the perf line report.

    The start-up samples are dropped first. Growth is then reported two ways:
    the plain end-to-end difference, which is easy to read but confounded with
    the corpus becoming zkApp-heavy near its end, and the slope against
    inserted zkApp arrays, which is not.
    """
    steady = steady_samples(curve)
    if not steady:
        return {
            "archive_growth": 0,
            "archive_slope": 0.0,
            "backend_peak": 0,
            "backend_tail_average": 0,
            "backend_slope": 0.0,
            "backend_slope_r2": 0.0,
            "arrays": 0,
            "pid_changes": 0,
            "max_backends": 0,
        }

    archive_growth = steady[-1].archive_rss - steady[0].archive_rss
    archive_slope, _ = growth_slope(steady, lambda sample: sample.archive_rss)
    backend_slope, backend_slope_r2 = growth_slope(
        steady, lambda sample: sample.backend_rss
    )

    backend = [sample.backend_rss for sample in steady if sample.backend_rss > 0]
    peak = max(backend, default=0)
    tail = backend[2 * len(backend) // 3 :]
    tail_average = sum(tail) // len(tail) if tail else 0

    # A pinned pool keeps one backend for the whole ingest. Any change of pid
    # means the connection was recycled and the plan cache it held was thrown
    # away, so the growth numbers understate the leak.
    seen = [tuple(sample.pids) for sample in steady if sample.pids]
    pid_changes = sum(1 for a, b in zip(seen, seen[1:]) if a != b)
    max_backends = max((len(pids) for pids in seen), default=0)

    return {
        "archive_growth": archive_growth,
        "archive_slope": archive_slope,
        "backend_peak": peak,
        "backend_tail_average": tail_average,
        "backend_slope": backend_slope,
        "backend_slope_r2": backend_slope_r2,
        "arrays": steady[-1].arrays,
        "pid_changes": pid_changes,
        "max_backends": max_backends,
    }


def sanitize(value):
    """Line-protocol tag values carry no unescaped spaces, commas or equals."""
    return "".join("_" if c in " ,=" else c for c in str(value))


def influx_line(measurement, fields, tags):
    tag_text = ",".join(f"{k}={sanitize(v)}" for k, v in tags.items())
    field_text = ",".join(f"{k}={v}" for k, v in fields.items())
    return f"{sanitize(measurement)},{tag_text} {field_text} {time.time_ns()}"


def check_ingest(blocks_ok, blocks_failed, max_failed, log):
    """Refuse to publish a result that measured nothing.

    archive_blocks exits 0 even when every block fails to insert: a per-block
    error is logged and the file is appended to --failed-files. Without this
    gate such a run publishes zeroed metrics, which read on the dashboards as
    a leak-free build.
    """
    if blocks_failed:
        print_log_tail(log)
    if not blocks_ok:
        sys.exit(
            f"no block was ingested ({blocks_failed} failed); "
            "refusing to publish a zero measurement"
        )
    if blocks_failed > max_failed:
        sys.exit(
            f"{blocks_failed} blocks failed to insert, more than the "
            f"{max_failed} allowed; refusing to publish"
        )


def main():
    args = parse_args()
    root = repo_root()
    os.chdir(root)

    postgres = Postgres(resolve_archive_uri())
    database = postgres.database()
    version = postgres.server_version_num()
    print(f"Benchmarking against database '{database}' (server_version_num={version})")
    if version and version < 140000:
        # Not fatal: the RSS samples this benchmark publishes come from /proc
        # and work on any server. It is the mina_caqti micro-benchmark that
        # needs pg_backend_memory_contexts, and a stale image here is worth
        # saying out loud.
        print(
            "  warning: PostgreSQL 14+ is expected; "
            "pg_backend_memory_contexts is unavailable on this server"
        )
    if not postgres.has_archive_schema():
        sys.exit(
            f"database '{database}' carries no archive schema; "
            "load src/app/archive/create_schema.sql into the database "
            "PG_CONN points at"
        )

    archive_blocks = root / "_build/default/src/app/archive_blocks/archive_blocks.exe"
    if not args.skip_build:
        load_build_env()
        print("Building archive_blocks...")
        subprocess.run(
            ["dune", "build", "src/app/archive_blocks/archive_blocks.exe"], check=True
        )

    if args.no_pin_pool:
        print("Caqti pool NOT pinned; the curve will mix several backends")
    else:
        print(
            "Pinning the Caqti pool to one never-recycled connection: "
            + " ".join(f"{k}={v}" for k, v in CAQTI_POOL_ENV.items())
        )

    print("Unpacking the static zkApp-heavy corpus...")
    workdir = Path(tempfile.mkdtemp())
    try:
        blocks = unpack_corpus(root / args.corpus, workdir, args.limit)
        print(f"  {len(blocks)} precomputed blocks")

        print("Feeding blocks and sampling memory...")
        curve, ingest_seconds, blocks_ok, blocks_failed, log = feed_and_sample(
            archive_blocks, blocks, postgres, workdir, args
        )
        check_ingest(blocks_ok, blocks_failed, args.max_failed_blocks, log)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    metrics = compute_metrics(curve)
    blocks_per_sec = blocks_ok / ingest_seconds if ingest_seconds > 0 else 0.0

    line = influx_line(
        args.measurement,
        {
            "blocks_ok": f"{blocks_ok}i",
            "blocks_failed": f"{blocks_failed}i",
            "zkapp_arrays": f"{metrics['arrays']}i",
            "archive_rss_growth_kib": f"{metrics['archive_growth']}i",
            "archive_rss_kib_per_1k_arrays": f"{metrics['archive_slope']:.3f}",
            "pg_backend_rss_peak_kib": f"{metrics['backend_peak']}i",
            "pg_backend_rss_tail_avg_kib": f"{metrics['backend_tail_average']}i",
            "pg_backend_rss_kib_per_1k_arrays": f"{metrics['backend_slope']:.3f}",
            "pg_backend_rss_slope_r2": f"{metrics['backend_slope_r2']:.3f}",
            "pg_backend_changes": f"{metrics['pid_changes']}i",
            "pg_backends_max": f"{metrics['max_backends']}i",
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
    for sample in curve:
        print(",".join(str(value) for value in sample.row()))
    print("=== summary ===")
    print(f"  blocks_ok={blocks_ok} blocks_failed={blocks_failed}")
    print(f"  zkApp arrays inserted       : {metrics['arrays']}")
    print(f"  archive_blocks RSS growth   : {metrics['archive_growth']} KiB")
    print(
        f"  archive_blocks RSS slope    : "
        f"{metrics['archive_slope']:.3f} KiB / 1000 arrays"
    )
    print(
        f"  pg backend RSS peak         : {metrics['backend_peak']} KiB "
        f"({metrics['backend_peak'] // 1024} MiB)"
    )
    print(
        f"  pg backend RSS tail average : {metrics['backend_tail_average']} KiB "
        f"({metrics['backend_tail_average'] // 1024} MiB)"
    )
    print(
        f"  pg backend RSS slope        : "
        f"{metrics['backend_slope']:.3f} KiB / 1000 arrays "
        f"(r2={metrics['backend_slope_r2']:.3f})"
    )
    print(
        f"  pg backends                 : at most "
        f"{metrics['max_backends']}, changed {metrics['pid_changes']} times"
    )
    if metrics["max_backends"] > 1 or metrics["pid_changes"] > 0:
        print(
            "  note: the ingest did not run on one stable backend, so the "
            "growth numbers understate the leak"
        )
    print(f"  ingest time                 : {ingest_seconds} s")
    print(f"  throughput                  : {blocks_per_sec:.3f} blocks/s")
    print(f"=== influxdb line protocol -> {args.perf_file} ===")
    print(line)


if __name__ == "__main__":
    main()
