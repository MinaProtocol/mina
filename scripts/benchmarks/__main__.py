"""
    Mina benchmark runner

    Capable of running,parsing to csv, comparing with historical data stored in influx and uploading to influx.

    Requirements:

    all INFLUX_* env vars need to be defined (INFLUX_HOST,INFLUX_TOKEN,INFLUX_BUCKET_NAME,INFLUX_ORG)

"""

import argparse
from pathlib import Path

from lib import *

parser = argparse.ArgumentParser(description='Executes mina benchmarks')
subparsers = parser.add_subparsers(dest="cmd")
run_bench = subparsers.add_parser('run')
run_bench.add_argument("--outfile", required=True, help="output file")
run_bench.add_argument("--benchmark", type= BenchmarkType, help="benchmark to run")
run_bench.add_argument("--influx", action='store_true', help = "Required only if --format=csv. Makes csv complaint with influx csv ")
run_bench.add_argument("--format", type=Format, help="output file format [text,csv]", default=Format.text)
run_bench.add_argument("--path", help="override path to benchmark")
run_bench.add_argument("--branch", default="test", help="Required only if --format=csv. Add branch name to csv file")
run_bench.add_argument("--genesis-ledger-path")

parse_bench = subparsers.add_parser('parse',help="parse textual benchmark output to csv")
parse_bench.add_argument("--benchmark", type= BenchmarkType, help="benchmark to run")
parse_bench.add_argument("--infile",help="input file")
parse_bench.add_argument("--influx", action='store_true', help="assure output file is compliant with influx schena")
parse_bench.add_argument("--branch", help="adds additional colum in csv with branch from which benchmarks where built")
parse_bench.add_argument("--outfile", help="output file")

compare_bench = subparsers.add_parser('compare', help="compare current data with historical downloaded from influx db")
compare_bench.add_argument("--benchmark", type= BenchmarkType, help="benchmark to run")
compare_bench.add_argument("--infile", help="input file")
compare_bench.add_argument("--yellow-threshold",help="defines how many percent current measurement can exceed average so app will trigger warning",
                           type=float,
                           choices=[Range(0.0, 1.0)],
                           default=0.1)
compare_bench.add_argument("--red-threshold",help="defines how many percent current measurement can exceed average so app will exit with error",
                           type=float,
                           choices=[Range(0.0, 1.0)],
                           default=0.2)

upload_bench = subparsers.add_parser('upload')
upload_bench.add_argument("--infile")

test_bench = subparsers.add_parser('test', help="Performs entire cycle of operations from run till upload")
test_bench.add_argument("--benchmark", type=BenchmarkType, help="benchmark to test")
test_bench.add_argument("--tmpfile", help="temporary location of result file")
test_bench.add_argument("--path")
test_bench.add_argument("--yellow-threshold",
                        help="defines how many percent current measurement can exceed average so app will trigger warning",
                        type=float,
                        choices=[Range(0.0, 1.0)],
                        default=0.1)
test_bench.add_argument("--red-threshold",
                        help="defines how many percent current measurement can exceed average so app will exit with error",
                        type=float,
                        choices=[Range(0.0, 1.0)],
                        default=0.2)
test_bench.add_argument("--branch", help="branch which was used in tests")
test_bench.add_argument("--genesis-ledger-path", help="Applicable only for ledger-export benchmark. Location of genesis config file")
test_bench.add_argument('-m','--mainline-branches', action='append', help='Defines mainline branch. If values of \'--branch\' parameter is among mainline branches then result will be uploaded')


upload_bench = subparsers.add_parser('ls')

args = parser.parse_args()

logging.basicConfig(level=logging.DEBUG)

default_mainline_branches = ["develop", "compatible", "master"]


def select_benchmark(kind):
    if kind == BenchmarkType.mina_base:
        return MinaBaseBenchmark()
    elif kind == BenchmarkType.zkapp:
        return ZkappLimitsBenchmark()
    elif kind == BenchmarkType.heap_usage:
        return HeapUsageBenchmark()
    elif kind == BenchmarkType.snark:
        return SnarkBenchmark()
    elif kind == BenchmarkType.ledger_export:
        if args.genesis_ledger_path is None:
            print(
                "--genesis-ledger-path need to be provided when running ledger export benchmark"
            )
            exit(1)
        return LedgerExportBenchmark(args.genesis_ledger_path)

if args.cmd == "ls":
    benches = [str(b) for b in BenchmarkType]
    print("\n".join(benches))
    exit(0)

if args.benchmark is None:
    print("benchmark not selected")
    exit(1)

bench = select_benchmark(args.benchmark)

if args.cmd == "run":
    output = bench.run(path=args.path)
    if args.format == "text":
        with open(args.outfile, 'w') as file:
            file.write(output)
    else:
        files = ",".join(
            bench.parse(output, args.outfile, args.influx, args.branch))
        print(f"produced files: {files}")

if args.cmd == "parse":
    files = bench.parse(Path(args.infile).read_text(), args.outfile, args.influx, args.branch)
    print(f'Parsed files: \n{",".join(files)}')


if args.cmd == "compare":
    bench.compare(args.infile, args.yellow_threshold, args.red_threshold)

if args.cmd == "upload":
    bench.upload(args.infile)

if args.cmd == "test":
    output = bench.run(path=args.path)
    files = bench.parse(output,
                        args.tmpfile,
                        influxdb=True,
                        branch=args.branch)

    [
        bench.compare(file, args.yellow_threshold, args.red_threshold)
        for file in files
    ]

    mainline_branches = default_mainline_branches if args.mainline_branches is None else args.mainline_branches

    if args.branch in mainline_branches:
        for file in files:
            bench.upload(file)