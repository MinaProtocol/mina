import csv
import argparse
import re
from parse import *
from pathlib import Path

from enum import Enum


class Benchmark(Enum):
    tabular = 'tabular'
    snark = 'snark'
    heap_usage = 'heap-usage'
    zkapp = 'zkapp'

    def __str__(self):
        return self.value


def export_to_csv(lines, filename, influxdb, branch):
    with open(filename, 'w') as csvfile:

        csvwriter = csv.writer(csvfile)

        if influxdb:
            csvfile.write("#datatype measurement,double,double,double,double,tag\n")

        for line in lines:
            if line.startswith('│'):

                rows = list(map(lambda x: x.strip(), line.split('│')))
                rows = list(filter(lambda x: x, rows))

                if rows[0].startswith("Name"):
                    rows[1] += " [us]"
                    rows[2] += " [kc]"
                    rows[3] += " [w]"
                    rows[4] += " [w]"
                    rows.append("gitbranch")
                
                else:
                    # remove [.*] from name
                    rows[0] = re.sub('\[.*?\]', '', rows[0]).strip()
                    time = rows[1]
                    # remove units from values
                    if not time.endswith("us"):
                        if time.endswith("ns"):
                           time = float(time[:-2])* 1_000
                           rows[1] = time
                        else:
                            raise Exception("Time can be expressed only in us or ns")
                    else:
                        # us
                        rows[1] = time[:-2]
                        # kc
                        rows[2] = rows[2][:-2]
                        # w
                        rows[3] = rows[3][:-1]
                        # w
                        rows[4] = rows[4][:-1]

                        rows.append(branch)

                csvwriter.writerow(rows[:])


def parse_zkapp_limits(input_filename, output_filename, influxdb, branch):
    with open(input_filename, 'r', encoding='UTF-8') as file:
        lines = file.readlines()
        stats = []
        header = ["proofs updates", "signed updates", "pairs of signed", "total account updates", "cost" , "gitbranch"]
        stats.append(header)

        for line in lines:
            if line == '':
                continue

            syntax = "Proofs updates=(?P<proofs_updates>\d+)  Signed/None updates=(?P<signed_updates>\d+)  Pairs of Signed/None updates=(?P<pairs_of_signed_updates>\d+): Total account updates: (?P<total_account_updates>\d+) Cost: (?P<cost>[0-9]*[.]?[0-9]+)"

            match = re.match(syntax, line)

            if match:
                proofs_updates = int(match.group('proofs_updates'))
                signed_updates = int(match.group('signed_updates'))
                pairs_of_signed_updates = int(match.group('pairs_of_signed_updates'))
                total_account_updates = int(match.group('total_account_updates'))
                cost = float(match.group('cost'))
                name = f"P{proofs_updates}S{signed_updates}PS{pairs_of_signed_updates}TA{total_account_updates}"
                tag = "zkapp"
                stats.append((name,proofs_updates, signed_updates, pairs_of_signed_updates, total_account_updates, cost, tag, branch))

        with open(output_filename, 'w') as csvfile:
            if influxdb:
                csvfile.write("#datatype measurement,double,double,double,double,double,tag\n")
            csvwriter = csv.writer(csvfile)
            csvwriter.writerows(stats)


def parse_snark_format(input_filename, output_filename, influxdb, branch):
    with open(input_filename, 'r', encoding='UTF-8') as file:
        lines = file.readlines()
        stats = []
        zkapps = []

        header = ["measurement", "proof updates", "nonproofs", "value", "tag", "gitbranch"]
        stats.append(header)

        for line in lines:
            if line == '':
                continue

            syntax = 'Generated zkapp transactions with (?P<updates>\d+) updates and (?P<proof>\d+) proof updates in (?P<time>[0-9]*[.]?[0-9]+) secs'

            match = re.match(syntax, line)

            if match:
                updates = int(match.group('updates'))
                proof = int(match.group('proof'))
                time = float(match.group('time'))
                name = f"{updates} Updates {proof} Proofs"
                tag = "generated zkapp transactions"

                stats.append((name, updates, proof, time, tag, branch))

            if line.startswith("|"):
                if "--" in line:
                    continue
                else:
                    cols = line.split("|")
                    cols = list(map(lambda x: x.strip(), cols))
                    cols = list(filter(lambda x: x, cols))
                    zkapps.append(cols[1:])
                    zkapps.append(branch)

        with open(f"{Path(output_filename).stem}_stats.csv", 'w') as csvfile:
            if influxdb:
                csvfile.write("#datatype measurement,double,double,double,tag,tag\n")

            csvwriter = csv.writer(csvfile)
            csvwriter.writerows(stats)

        with open(f"{Path(output_filename).stem}_zkapp.csv", 'w') as csvfile:
            if influxdb:
                csvfile.write("#datatype double,double,double,double,double,measurement,tag\n")

            csvwriter = csv.writer(csvfile)
            csvwriter.writerows(zkapps)


def parse_tabular_format(input_filename, output_filename, influxdb, branch):
    with open(input_filename, 'r', encoding='UTF-8') as file:
        lines = file.readlines()

    starts = []
    ends = []
    for i, e in enumerate(lines):
        if "Running" in e:
            starts.append(i)

    if not any(starts):
        export_to_csv(lines, output_filename, influxdb, branch)
    else:
        for start in starts[1:]:
            ends.append(start)

        ends.append(len(lines) - 1)

        for start, end in zip(starts, ends):
            name = parse('Running inline tests in library "{}"', lines[start].strip())[0]
            file = f'{name}_{output_filename}'
            print(f"exporting {file}..")
            export_to_csv(lines[start:end], f'{file}', influxdb, branch)


def parse_heap_usage_format(input_filename, output_filename, influxdb, branch):
    with open(input_filename, 'r', encoding='UTF-8') as file:
        rows = []

        header = ["Name", "heap words", "bytes", "category", "gitbranch"]
        rows.append(header)

        for i, line in enumerate(file.readlines()):
            if line.startswith("Data of type"):
                sanitized_line = line.replace(" ", "").strip()
                row = list(parse("Dataoftype{}uses{}heapwords={}bytes", sanitized_line))
                row.append("heap_usage")
                rows.append(row)

        with open(output_filename, 'w') as csvfile:
            if influxdb:
                csvfile.write("#datatype measurement,double,double,tag,tag\n")
            csvwriter = csv.writer(csvfile)
            csvwriter.writerows(rows)


parser = argparse.ArgumentParser(description='Parse various mina benchmark outputs')
parser.add_argument('--benchmark',
                    help='type of benchmark', type=Benchmark, choices=list(Benchmark))
parser.add_argument('--infile',
                    help='input file with benchmark output')
parser.add_argument('--outfile',
                    help='output file with benchmark output as csv')
parser.add_argument('--influxdb',
                    help='convert output file to be compliant with influxdb standard. See more at: https://docs.influxdata.com/influxdb/cloud/write-data/developer-tools/csv/',
                    action='store_true')
parser.add_argument('--branch',
                    help='Adds additional tag to csv file with source git branch')

args = parser.parse_args()

if args.benchmark == Benchmark.tabular:
    parse_tabular_format(args.infile, args.outfile, args.influxdb, args.branch)
elif args.benchmark == Benchmark.snark:
    parse_snark_format(args.infile, args.outfile, args.influxdb, args.branch)
elif args.benchmark == Benchmark.zkapp:
    parse_zkapp_limits(args.infile, args.outfile, args.influxdb, args.branch)
else:
    parse_heap_usage_format(args.infile, args.outfile, args.influxdb, args.branch)
