# Tracing mina daemons

We have support for a very limited async-integrated tracing profiler!
When starting a daemon with `-tracing` or using `mina client start-tracing`,
it will write `*.trace` files into its config directory. They can grow
quite fast, but for the most part they grow no faster than 5MB/minute.

Most of the integration tests (including full-test) support a `MINA_TRACING`
environment variable that specifies the directory the integration tests
will put their trace files in. If you leave it empty, no tracing will
occur.

Once you have a `.trace` file, it needs to be turned into JSON for the
Chrome trace-viewer to view. You can do this with `src/app/trace-tool`.
Using it is simple if you have Rust installed: `cd src/app/trace-tool; cargo run --release /path/to/1234.trace > trace.json`.
Then you can load the file from `chrome://tracing`.

Each row correponds to a "task" as created by either `O1trace.trace_task` or
`O1trace.trace_recurring_task`. A recurring task starts with `R&`. Internally
it works by doing one `trace_task` per call, and the `trace-tool` knows how
to collapse them all into one row.

![screenshot of trace-viewer showing nested measure calls](./res/tracing-example.png)

In the screenshot, the top green bar represents the root of a recurring task.
The bars underneath it each correspond to a `measure` call - which can be nested.
The very thin lines correspond to a `trace_event` call - these are labeled instantaneous
events. Think of like a `printf` that shows up in the trace.
