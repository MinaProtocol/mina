Benchmarks
==========

The `benchmarks` tool runs performance benchmarks for various libraries within
the Mina codebase. It executes inline benchmarks defined in the source code,
providing performance metrics that help developers identify bottlenecks and
measure improvements over time.

Features
--------

- Executes inline benchmarks from specific libraries or across the entire codebase
- Provides statistical analysis of benchmark results
- Supports controlled benchmark selection via environment variables
- Presents results in a readable format with min/max/median timings

Prerequisites
------------

No special prerequisites are needed to run this tool, as it executes benchmark
code that's already embedded in the Mina libraries.

Compilation
----------

To compile the `benchmarks` executable, run:

```shell
$ dune build src/app/benchmarks/benchmarks.exe --profile=dev
```

or use the built-in make target:

```shell
$ make benchmarks
```

The executable will be built at:
`_build/default/src/app/benchmarks/benchmarks.exe`

Usage
-----

The basic syntax for running the benchmarks is:

```shell
$ benchmarks
```

By default, this will run all available benchmarks across all libraries.

### Controlling Which Libraries to Benchmark

You can control which libraries are benchmarked using the environment variable
`BENCHMARK_LIBRARIES`, which accepts either "all" or a comma-delimited list of
libraries:

```shell
$ BENCHMARK_LIBRARIES=mina_base benchmarks
```

```shell
$ BENCHMARK_LIBRARIES=vrf_lib_tests,mina_base benchmarks
```

If the variable is not set, empty, or set to "all", benchmarks for all libraries
will be executed.

### Available Libraries

Currently, the following libraries have inline benchmarks:

- `vrf_lib_tests`: Benchmarks for VRF (Verifiable Random Function) operations
- `mina_base`: Benchmarks for core Mina blockchain data structures

Output Format
------------

For each benchmark, the tool will display statistics including:

- Name: The name of the benchmark
- Time/Run: The average time per execution
- mWd/Run: Minor words allocated per run
- mjWd/Run: Major words allocated per run
- Percentage: Relative performance compared to other benchmarks

Example output:

```
Running inline tests in library "mina_base"
Benchmarking with analysis...

Name                                     Time/Run   mWd/Run   mjWd/Run   Percentage
-------------------------------------  ----------  --------  ---------  -----------
Ledger_hash.merge_var                     17.52ns     9.00w       0.00w      21.31%
Pending_coinbase.merkle_root var          82.29ns    32.00w       0.00w     100.00%
...
```

Examples
--------

Run all available benchmarks:

```shell
$ benchmarks
```

Run benchmarks only for the mina_base library:

```shell
$ BENCHMARK_LIBRARIES=mina_base benchmarks
```

Run benchmarks for multiple specific libraries:

```shell
$ BENCHMARK_LIBRARIES=vrf_lib_tests,mina_base benchmarks
```

Save benchmark results to a file for comparison:

```shell
$ benchmarks > benchmarks_results_$(date +%Y%m%d).txt
```

Run with time measurement for overall execution:

```shell
$ time benchmarks
```

Technical Notes
--------------

- The benchmarks use Jane Street's `core_bench` library to perform reliable
  timing measurements with statistical analysis.

- Inline benchmarks are defined in the source code using the `let%bench` syntax.

- The tool links with `-linkall` to ensure all benchmarks are discoverable,
  even if the functions they're testing aren't otherwise used.

- The benchmarks run in native code mode for the most accurate performance
  measurements.

- For consistent results, it's recommended to run benchmarks on a quiet system
  without other CPU-intensive tasks running.

Adding New Benchmarks
--------------------

To add benchmarks for a new library:

1. Add inline benchmarks to your library code using `let%bench` or
   `let%bench_fun`.

2. Add your library name to the `available_libraries` list in
   `benchmarks.ml`.

3. Add your library to the `libraries` section in the dune file.

Example of adding a benchmark in library code:

```ocaml
let%bench "my_function performance" =
  my_function arg1 arg2
```

Related Tools
------------

- `main`: The public name of the benchmark executable.

- Various profiling tools like `perf` can be used alongside benchmarks to get
  more detailed performance insights.