import re
from abc import ABC

import parse
from pathlib import Path
import io
import os
from enum import Enum
import logging
from lib.utils import isclose, assert_cmd
from lib.influx import *

import csv
import abc

logger = logging.getLogger(__name__)


class Benchmark(abc.ABC):
    """
        Abstract class which aggregate all necessary operations
        (run,parse) which then are implemented by children.
        Moreover, for all general and common operations like upload it has concrete implementation

    """

    def __init__(self, kind):
        self.kind = kind
        self.influx_client = Influx()

    def headers_to_influx(self, headers):
        return "#datatype " + ",".join(
            [header.influx_kind for header in headers])

    @abc.abstractmethod
    def default_path(self):
        pass

    @abc.abstractmethod
    def name_header(self):
        pass

    @abc.abstractmethod
    def branch_header(self):
        pass

    def headers_to_name(self, headers):
        return list(map(lambda x: x.name, headers))

    @abc.abstractmethod
    def headers(self):
        pass

    @abc.abstractmethod
    def fields(self):
        pass

    @abc.abstractmethod
    def run(self, path):
        pass

    @abc.abstractmethod
    def parse(self, content, output_filename, influxdb, branch):
        pass

    def compare(self, result_file, yellow_threshold, red_threshold):
        with open(result_file, newline='') as csvfile:
            reader = csv.reader(csvfile, delimiter=',')
            for i in range(2):
                next(reader)
            for row in reader:
                for field in self.fields():
                    value = float(row[field.pos])
                    name = row[self.name_header().pos]
                    branch = row[self.branch_header().pos]
                    result = self.influx_client.query_moving_average(
                        name, branch, str(field), self.branch_header())

                    if not any(result):
                        logger.warning(
                            f"Skipping comparison for {name} as there are no historical data available yet"
                        )
                    else:
                        average = float(result[-1].records[-1]["_value"])

                        current_red_threshold = average * red_threshold
                        current_yellow_threshold = average * yellow_threshold

                        logger.debug(
                            f"calculated thresholds: [red={current_red_threshold},yellow={current_yellow_threshold}]"
                        )

                        if isclose(value + red_threshold, average):
                            logger.error(
                                f"{name} measurement exceeds time greatly ({value + current_red_threshold} against {average}). failing the build"
                            )
                            exit(1)
                        elif isclose(value + yellow_threshold, average):
                            logger.warning(
                                f"WARNING: {name} measurement exceeds expected time ({value + current_yellow_threshold} against {average})"
                            )
                        else:
                            logger.info(
                                f"comparison succesful for {name}. {value} is less than threshold [yellow={average + current_yellow_threshold},red={average + current_red_threshold}]"
                            )

    def upload(self, file):
        self.influx_client.upload_csv(file)


class BenchmarkType(Enum):
    mina_base = 'mina-base'
    snark = 'snark'
    heap_usage = 'heap-usage'
    zkapp = 'zkapp'
    ledger_export = 'ledger-export'

    def __str__(self):
        return self.value


class JaneStreetBenchmark(Benchmark, ABC):
    """
        Abstract class for native ocaml benchmarks which has the same format

    """
    name = MeasurementColumn("Name", 0)
    time_per_runs = FieldColumn("Time/Run", 1, "us")
    cycles_per_runs = FieldColumn("Cycls/Run", 2, "kc")
    minor_words_per_runs = FieldColumn("mWd/Run", 3, "w")
    major_words_per_runs = FieldColumn("mjWd/Run", 4, "w")
    promotions_per_runs = FieldColumn("Prom/Run", 5, "w")
    branch = TagColumn("gitbranch", 6)

    def __init__(self, kind):
        Benchmark.__init__(self, kind)

    def headers(self):
        return [
            MinaBaseBenchmark.name, MinaBaseBenchmark.time_per_runs,
            MinaBaseBenchmark.cycles_per_runs,
            MinaBaseBenchmark.minor_words_per_runs,
            MinaBaseBenchmark.major_words_per_runs,
            MinaBaseBenchmark.promotions_per_runs, MinaBaseBenchmark.branch
        ]

    def fields(self):
        return [
            MinaBaseBenchmark.time_per_runs, MinaBaseBenchmark.cycles_per_runs,
            MinaBaseBenchmark.minor_words_per_runs,
            MinaBaseBenchmark.major_words_per_runs,
            MinaBaseBenchmark.promotions_per_runs
        ]

    def name_header(self):
        return self.name

    def branch_header(self):
        return self.branch

    def export_to_csv(self, lines, filename, influxdb, branch):
        with open(filename, 'w') as csvfile:

            csvwriter = csv.writer(csvfile)

            if influxdb:
                csvfile.write(self.headers_to_influx(self.headers()) + "\n")

            for line in lines:
                if line.startswith('│'):

                    rows = list(map(lambda x: x.strip(), line.split('│')))
                    rows = list(filter(lambda x: x, rows))

                    if rows[0].startswith(MinaBaseBenchmark.name.name):
                        rows[
                            1] += " " + MinaBaseBenchmark.time_per_runs.format_unit(
                            )
                        rows[
                            2] += " " + MinaBaseBenchmark.cycles_per_runs.format_unit(
                            )
                        rows[
                            3] += " " + MinaBaseBenchmark.minor_words_per_runs.format_unit(
                            )
                        rows[
                            4] += " " + MinaBaseBenchmark.major_words_per_runs.format_unit(
                            )
                        rows[
                            5] += " " + MinaBaseBenchmark.promotions_per_runs.format_unit(
                            )
                        rows.append("gitbranch")

                    else:
                        # remove [.*] from name
                        rows[0] = re.sub('\[.*?\]', '', rows[0]).strip()
                        time = rows[1]
                        # remove units from values
                        if not time.endswith("us"):
                            if time.endswith("ns"):
                                time = float(time[:-2]) * 1_000
                                rows[1] = time
                            else:
                                raise Exception(
                                    "Time can be expressed only in us or ns")
                        else:
                            # us
                            rows[1] = time[:-2]
                            # kc
                            rows[2] = rows[2][:-2]
                            # w
                            rows[3] = rows[3][:-1]
                            # w
                            rows[4] = rows[4][:-1]
                            # w
                            rows[5] = rows[5][:-1]
                            rows.append(branch)

                    csvwriter.writerow(rows[:])

    def parse(self, content, output_filename, influxdb, branch):
        buf = io.StringIO(content)
        lines = buf.readlines()

        starts = []
        ends = []
        files = []
        for i, e in enumerate(lines):
            if "Running" in e:
                starts.append(i)

        if not any(starts):
            self.export_to_csv(lines, output_filename, influxdb, branch)
        else:
            for start in starts[1:]:
                ends.append(start)

            ends.append(len(lines) - 1)

            for start, end in zip(starts, ends):
                name = parse.parse('Running inline tests in library "{}"',
                                   lines[start].strip())[0]
                file = f'{name}_{output_filename}'
                logger.info(f"exporting {file}..")
                self.export_to_csv(lines[start:end], f'{file}', influxdb,
                                   branch)
                files.append(file)

        return files


class MinaBaseBenchmark(JaneStreetBenchmark):

    def __init__(self):
        JaneStreetBenchmark.__init__(self, BenchmarkType.mina_base)

    def run(self, path=None):
        path = self.default_path() if path is None else path
        cmd = [
            path, "time", "cycles", "alloc", "-clear-columns", "-all-values",
            "-width", "1000", "-run-without-cross-library-inlining",
            "-suppress-warnings"
        ]
        envs = os.environ.copy()
        envs["BENCHMARKS_RUNNER"] = "TRUE"
        envs["X_LIBRARY_INLINING"] = "true"

        return assert_cmd(cmd, envs)

    def default_path(self):
        return "mina-benchmarks"


class LedgerExportBenchmark(JaneStreetBenchmark):

    def __init__(self, genesis_ledger_path):
        JaneStreetBenchmark.__init__(self, BenchmarkType.ledger_export)
        self.genesis_ledger_path = genesis_ledger_path

    def run(self, path=None):
        path = self.default_path() if path is None else path
        cmd = [
            path, "time", "cycles", "alloc", "-clear-columns", "-all-values",
            "-width", "1000"
        ]
        envs = os.environ.copy()
        envs["RUNTIME_CONFIG"] = self.genesis_ledger_path

        return assert_cmd(cmd, envs)

    def default_path(self):
        return "mina-ledger-export-benchmark"


class ZkappLimitsBenchmark(Benchmark):

    name = MeasurementColumn("Name", 0)
    proofs_updates = FieldColumn("proofs updates",  1, "")
    signed_updates = FieldColumn("signed updates",  2, "")
    pairs_of_signed = FieldColumn("pairs of signed", 3, "")
    total_account_updates = FieldColumn("total account updates", 4, "")
    cost = FieldColumn("cost", 5, "")
    category = TagColumn("category", 6)
    branch = TagColumn("gitbranch", 7)

    def __init__(self):
        Benchmark.__init__(self, BenchmarkType.zkapp)

    def default_path(self):
        return "mina-zkapp-limits"

    def fields(self):
        return [
            self.proofs_updates, self.pairs_of_signed,
            self.total_account_updates, self.cost
        ]

    def name_header(self):
        return self.name

    def branch_header(self):
        return self.branch

    def headers(self):
        return [
            ZkappLimitsBenchmark.name, ZkappLimitsBenchmark.proofs_updates,
            ZkappLimitsBenchmark.signed_updates,
            ZkappLimitsBenchmark.pairs_of_signed,
            ZkappLimitsBenchmark.total_account_updates,
            ZkappLimitsBenchmark.cost, ZkappLimitsBenchmark.category,
            ZkappLimitsBenchmark.branch
        ]

    def parse(self, content, output_filename, influxdb, branch):

        buf = io.StringIO(content)
        lines = buf.readlines()

        stats = [list(map(lambda x: x.name, self.headers()))]

        for line in lines:
            if line == '':
                continue

            syntax = "Proofs updates=(?P<proofs_updates>\d+)  Signed/None updates=(?P<signed_updates>\d+)  Pairs of Signed/None updates=(?P<pairs_of_signed_updates>\d+): Total account updates: (?P<total_account_updates>\d+) Cost: (?P<cost>[0-9]*[.]?[0-9]+)"

            match = re.match(syntax, line)

            if match:
                proofs_updates = int(match.group("proofs_updates"))
                signed_updates = int(match.group("signed_updates"))
                pairs_of_signed_updates = int(
                    match.group("pairs_of_signed_updates"))
                total_account_updates = int(
                    match.group("total_account_updates"))
                cost = float(match.group(ZkappLimitsBenchmark.cost.name))
                name = f"P{proofs_updates}S{signed_updates}PS{pairs_of_signed_updates}TA{total_account_updates}"
                tag = "zkapp"
                stats.append((name, proofs_updates, signed_updates,
                              pairs_of_signed_updates, total_account_updates,
                              cost, tag, branch))

            with open(output_filename, 'w') as csvfile:
                if influxdb:
                    csvfile.write(
                        self.headers_to_influx(self.headers()) + "\n")
                csvwriter = csv.writer(csvfile)
                csvwriter.writerows(stats)

        return [output_filename]

    def run(self, path=None):
        path = self.default_path() if path is None else path
        return assert_cmd([path])


class SnarkBenchmark(Benchmark):

    name = MeasurementColumn("name", 0)
    proofs_updates = FieldColumn("proofs updates", 1, "")
    nonproofs_pairs = FieldColumn("non-proof pairs", 2, "")
    nonproofs_singles = FieldColumn("non-proof singles", 3, "")
    verification_time = FieldColumn("verification time", 4, "[s]")
    proving_time = FieldColumn("value", 5, "[s]")
    category = TagColumn("category", 6)
    branch = TagColumn("gitbranch", 7)

    k = 1
    max_num_updates = 4
    min_num_updates = 2

    def name_header(self):
        return self.name

    def branch_header(self):
        return self.branch

    def __init__(self):
        Benchmark.__init__(self, BenchmarkType.snark)

    def headers(self):
        return [
            SnarkBenchmark.name, SnarkBenchmark.proofs_updates,
            SnarkBenchmark.nonproofs_pairs, SnarkBenchmark.nonproofs_singles,
            SnarkBenchmark.verification_time, SnarkBenchmark.proving_time,
            SnarkBenchmark.category, SnarkBenchmark.branch
        ]

    def fields(self):
        return [
            SnarkBenchmark.proofs_updates, SnarkBenchmark.nonproofs_pairs,
            SnarkBenchmark.nonproofs_singles, SnarkBenchmark.verification_time, SnarkBenchmark.proving_time
        ]

    def parse(self, content, output_filename, influxdb, branch):
        buf = io.StringIO(content)
        lines = buf.readlines()
        rows = []
        category = "snark"
        rows.append(list(map(lambda x: x.name, self.headers())))

        for line in lines:
            if line.startswith("|"):
                if "--" in line:
                    continue
                elif line.startswith("| No.|"):
                    continue
                else:
                    cols = line.split("|")
                    cols = list(map(lambda x: x.strip(), cols))
                    cols = list(filter(lambda x: x, cols))

                    #| No.| Proof updates| Non-proof pairs| Non-proof singles| Mempool verification time (sec)| Transaction proving time (sec)|Permutation|
                    proof_update = cols[1]
                    non_proof_pairs = cols[2]
                    non_proof_singles = cols[3]
                    verification_time = cols[4]
                    proving_time = cols[5]
                    name = cols[6]

                    rows.append((name,proof_update,non_proof_pairs,non_proof_singles,verification_time,proving_time,
                                   category,branch))

        with open(output_filename, 'w') as csvfile:
            if influxdb:
                csvfile.write(self.headers_to_influx(self.headers()) + "\n")

            csvwriter = csv.writer(csvfile)
            csvwriter.writerows(rows)

        return [ output_filename ]

    def default_path(self):
        return "mina"

    def run(self, path=None):
        path = self.default_path() if path is None else path
        return assert_cmd([
            path, "transaction-snark-profiler", "--zkapps", "--k",
            str(self.k), "--max-num-updates",
            str(self.max_num_updates), "--min-num-updates",
            str(self.min_num_updates)
        ])


class HeapUsageBenchmark(Benchmark):

    name = MeasurementColumn("Name", 0)
    heap_words = FieldColumn("heap words", 1, "")
    bytes = FieldColumn("bytes", 2, "")
    category = TagColumn("category", 3)
    branch = TagColumn("gitbranch", 4)

    def __init__(self):
        Benchmark.__init__(self, BenchmarkType.heap_usage)

    def name_header(self):
        return self.name

    def branch_header(self):
        return self.branch

    def headers(self):
        return [
            HeapUsageBenchmark.name, HeapUsageBenchmark.heap_words,
            HeapUsageBenchmark.bytes, HeapUsageBenchmark.category,
            HeapUsageBenchmark.branch
        ]

    def fields(self):
        return [
            HeapUsageBenchmark.heap_words,
            HeapUsageBenchmark.bytes
        ]

    def parse(self, content, output_filename, influxdb, branch):
        buf = io.StringIO(content)
        lines = buf.readlines()
        rows = []
        rows.append(self.headers_to_name(self.headers()))

        for i, line in enumerate(lines):
            if line.startswith("Data of type"):
                sanitized_line = line.replace(" ", "").strip()
                row = list(
                    parse.parse("Dataoftype{}uses{}heapwords={}bytes",
                          sanitized_line))
                row.extend(("heap_usage", branch))
                rows.append(row)

        with open(output_filename, 'w') as csvfile:
            if influxdb:
                csvfile.write(self.headers_to_influx(self.headers()) + "\n")
            csvwriter = csv.writer(csvfile)
            csvwriter.writerows(rows)
        return [output_filename]

    def default_path(self):
        return "mina-heap-usage"

    def run(self, path=None):
        path = self.default_path() if path is None else path
        return assert_cmd([path])
