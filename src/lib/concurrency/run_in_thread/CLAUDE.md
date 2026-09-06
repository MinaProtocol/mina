# Run_in_thread

## What it solves

Minimal interface providing `run_in_thread` (run blocking OCaml code in a
thread pool) and `block_on_async_exn` (block until an async computation
completes).

```ocaml
val run_in_thread : (unit -> 'a) -> 'a Async_kernel.Deferred.t
val block_on_async_exn : (unit -> 'a Async_kernel.Deferred.t) -> 'a
```

## Key semantics

### `run_in_thread`

On native: delegates to `Async.Thread_safe.run_in_thread` (or just
`In_thread.run` in the "fake" variant). The function runs in a system
thread managed by Async's thread pool. The returned deferred resolves
when the function returns or raises (exception is captured).

### `block_on_async_exn`

On native: delegates to `Async.Thread_safe.block_on_async_exn`. **Must NOT
be called inside the Async scheduler** (deadlock). Used primarily in tests
and CLI entry points to bridge async and sync code. If the deferred raises,
the exception propagates to the caller.

### Two implementations

- `native/run_in_thread.ml` — uses Async's `In_thread` module
- `fake/run_in_thread.ml` — used in non-async contexts; `run_in_thread`
  calls `In_thread.run` with a fake thread pool

## Common pitfalls

1. **`block_on_async_exn` inside the scheduler** → hard deadlock. Only
   use from non-async code.
2. **`run_in_thread` for long-running code**: ties up a thread from the
   pool. For CPU-intensive work, consider offloading to a separate process.
3. **GC interaction**: OCaml's GC stops-the-world. Long `run_in_thread`
   calls that allocate heavily can stall other async threads.
4. **Exception in `run_in_thread` callback**: captured into the deferred
   as a failed deferred. Handle with `try_with` or `.Or_error` patterns.

## Source files

- `src/lib/concurrency/run_in_thread/run_in_thread.mli`
- `src/lib/concurrency/run_in_thread/native/run_in_thread.ml`
- `src/lib/concurrency/run_in_thread/fake/run_in_thread.ml`
