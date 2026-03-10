# Benchmarks

Python app for running all major mina benchmarks of various type

- mina-benchmarks
- snark-profiler
- heap-usage
- zkapp-limits
- ledger-export

It requires all underlying app to be present on os By default app uses
official name (like mina, mina-heap-usage etc.).

In order to upload files to influx db all 4 influx env vars need to be defined:
- INFLUX_BUCKET_NAME
- INFLUX_ORG
- INFLUX_TOKEN
- INFLUX_HOST

More details here:
https://docs.influxdata.com/influxdb/cloud/reference/cli/influx/#credential-precedence

## Installation

Project depends on Python in version 3+


```commandline
pip install -r ./scripts/benchmarks/requirements.txt
```

## Usage

python3 ./scripts/benchmarks run --benchmark mina-base --path _build/default/src/app/benchmarks/benchmarks.exe --influx --branch compatible --format csv --outfile mina_base.csv

## Commands

### ls
    
Prints all supported benchmarks

```commandline
 python3 scripts/benchmarks ls
```

### run

runs benchmark. 

INFO: each benchmark can have its own set of additional parameters

example:
```commandline
python3 scripts/benchmarks run --benchmark snark --path _build/default/src/app/cli/src/mina.exe  --branch compatible --outfile zkap_limits.csv
```

### parse

Parses textual output of benchmark to csv

```commandline
python3 scripts/benchmarks parse --benchmark mina-base --influx --branch compatible --infile output.out --outfile mina_base.csv
```


### compare

Compare result against moving average from influx db

```commandline
python3 scripts/benchmarks compare --infile vrf_lib_tests_mina_base.csv --yellow-threshold 0.1 --red-threshold 0.2
```

### upload

Uploads data to influx db

```commandline
python3 scripts/benchmarks upload --infile mina_base_mina_base.csv
```

### test

Aggregates all above commands with logic to only upload data if branch is amongst mainline branches

```commandline
python3 scripts/benchmarks test --benchmark snark --path _build/default/src/app/cli/src/mina.exe  --branch compatible --tmpfile zkap_limits.csv
```


## Further work

Application is meant to be run in CI. Currently it exits when values exceeds moving average. 
Some process need to be agreed how to handle situation where increase in value is expected and values should be uploaded to 
influx db. One proposal is to add env var which can bypass comparison + additional logic which will allow value which exceeds
moving average but does not exceed highest one 
(as we may end up in situation that moving average won't allow further values and we need to bypass them as well until avg will catchup with expected increase)
