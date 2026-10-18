# Linear_pipe

## What it solves

Wraps Jane Street's `Async_kernel.Pipe` with **single-reader enforcement** (`bracket`
pattern). Prevents the same `Reader.t` from being consumed concurrently — attempting
to do so raises `failwith "Linear_pipe.bracket: the same reader has been used
multiple times"`.

The `Writer` is just `Pipe.Writer.t` (no extra wrapper).

## Key semantics

### Exception behavior: `iter` / `iter_unordered`

`iter` delegates to `Pipe.iter` with `?continue_on_error` passthrough.
**Default is `continue_on_error=false`**, which means:

- If the callback `f` raises (returns a failed `Deferred.t`), iteration **stops**
  and the exception **propagates** to whoever awaited the `iter` deferred.
- The pipe is **not** read further — upstream writers will accumulate pushback.

With `~continue_on_error:true`, the exception is suppressed and iteration continues.

`iter_unordered` has **no** `continue_on_error` option — exceptions always
propagate (it calls `Deferred.all_unit` which fails on any child failure).

### `don't_wait_for` + `iter`

A common pattern in Mina:

```ocaml
don't_wait_for (Linear_pipe.iter reader ~f:callback)
```

The `iter` deferred's error flows to Async's **current monitor**. If nothing
handles it locally (no `Monitor.try_with`), it propagates to the daemon's
top-level `Monitor.detach_and_iter_errors` handler in `mina_run.ml`, which
logs the crash and calls `Stdlib.exit 1`.

### `bracket` and read operations

`read`, `read_now`, `fold`, `scan`, `map`, `filter_map`, `transfer`, etc. all
enforce the single-reader invariant. `read_now` and `scan`/`map`/`filter_map`
use `set_has_reader` (sets the flag without clearing on completion — the caller
owns the read side afterward).

### Close semantics

- `close_read` closes the reader; `close` closes the writer.
- `force_write_maybe_drop_head ~capacity` drops the oldest element if the pipe
  exceeds `capacity`.
- `write_or_exn ~capacity` raises `Linear_pipe.Overflow` if the pipe exceeds
  `capacity`.

## Common pitfalls

1. **`iter` default `continue_on_error=false`**: an uncaught exception in
   `f` kills the pipe consumer and propagates. If the `iter` was `don't_wait_for`-ed,
   the error becomes an unhandled Async monitor exception → daemon crash.
2. **`scan` / `map` / `filter_map` permanently consume the reader**: they call
   `set_has_reader` — the source `Reader` can never be used again.
3. **`write_without_pushback_if_open` returns `unit` immediately** — no deferred
   to catch write errors.

## Source files

- `src/lib/concurrency/pipe_lib/linear_pipe.ml`
- `src/lib/concurrency/pipe_lib/linear_pipe.mli`
