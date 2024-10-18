import csv
import argparse
import subprocess


parser = argparse.ArgumentParser(description='Calculate actual benchmark values against influx db')
parser.add_argument('--infile',
                    help='input csv file with actual benchmark')
parser.add_argument('--red-threshold',
                    help='value above which app return exit 1')
parser.add_argument('--yellow-threshold',
                    help='value above which app return warning',
                    )
args = parser.parse_args()

with open(args.infile, newline='') as csvfile:
    rows = list(csv.reader(csvfile))

    headers_rows = rows[1]
    name_pos = [ i for i,x in enumerate(headers_rows) if x == "Name"][0]
    branch_pos = [ i for i,x in enumerate(headers_rows) if x == "gitbranch"][0]

    for items in rows[2:]:
        name = items[name_pos]
        branch = items[branch_pos]
        output = subprocess.run(["influx", "query", f'from(bucket: "mina-benchmarks") |>  range(start: -10d)   |> filter (fn: (r) => (r._tag["gitbranch"] == "{branch}" ) and r._measurement == "{name}") |> keep(columns: ["_value"]) |> movingAverage(n:1) ']).stdout.read()
        print(output)