# influxdb_line_protocol

Writes benchmark results as InfluxDB line protocol, so they can be stored and
compared from build to build.

## InfluxDB

[InfluxDB](https://docs.influxdata.com/influxdb/v2/) is a time-series
database. Each record is a *point*: a measurement name, tags that identify the
series, numeric fields, and a timestamp. A benchmark writes one or more points
per run, tagged for example with the branch, the commit and the variant, so a
regression shows as a change in the series.

## Line protocol

The text format InfluxDB reads, one point per line:

```
measurement,tag=value,tag=value field=value,field=value timestamp
```

```
my_bench,branch=compatible,commit=a0ba151,variant=baseline rows=288965i,median_ms=16.3 1700000000000000000
```

- the timestamp is in nanoseconds since the Unix epoch
- `5i` is an integer field; a number without `i` is a float
- in a tag value, `,`, `=` and spaces are escaped with `\`

Reference: [line protocol](https://docs.influxdata.com/influxdb/v2/reference/syntax/line-protocol/).

## Use

```ocaml
let point =
  Influxdb_line_protocol.(
    create
      ~tags:[ ("branch", branch); ("commit", commit) ]
      ~measurement:"my_bench"
      [ ("rows", Int rows); ("median_ms", Float median_ms) ])
in
Influxdb_line_protocol.write_file path [ point ]
```

`create` checks the point and raises `Invalid_argument` when it is not valid,
so a bad point fails where it is built, not when InfluxDB reads it:

- fields are numbers only: `Int`, or a finite `Float`
- names (the measurement, tag keys, field keys) are set in code: non-empty,
  of `[A-Za-z0-9_.-]`, and not starting with `_`, which InfluxDB reserves
- tag values are strings, non-empty and on one line
- no key is given twice, and there is at least one field
