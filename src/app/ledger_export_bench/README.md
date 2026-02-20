Ledger export benckmark
=======================

This package provides a couple of simple benchmarks for the most
resource-consuming parts of the ledger export process, namely:
* serialising and de-serialising a large runtime config;
* converting accounts between runtime config format and ledger format.

These benchmarks depend on a sufficiently large runtime config file
supplied from outside, because creating one within a benchmark,
while useful, is too involved, as it basically requires connecting
to a live network. Besides, such a benchmark would be unreliable,
as its results wouldn't be reproducible.

Sadly, a runtime config containing realistic mainnet data is too
large to store it in git (~400MB), so users of the benchmark need to
provide it themselves. The file's path should be given by environment
variable `RUNTIME_CONFIG` provide to the benchmark process. If that
variable is absent, the benchmark will not work.

In order to run the benchmark, type:

    $ RUNTIME_CONFIG=$HOME/mainnet.json dune exec src/app/ledger_export_bench/ledger_export_benchmark.exe
