# Promise

## What it solves

A platform-abstracted promise type (`'a t`) with native (`Async.Deferred`)
and JS implementations. Provides a minimal `Monad` interface plus `run_in_thread`,
`block_on_async_exn`, `upon`, `peek`, `value_exn`, `to_deferred`.

## Key semantics

### `run_in_thread : (unit -> 'a) -> 'a t`

Runs a synchronous function in a thread pool. In the native backend this
delegates to `In_thread.run`; in JS it runs in a Web Worker.

### `block_on_async_exn : (unit -> 'a t) -> 'a`

Blocks the current (non-async) thread until the promise resolves. On native
this is `Thread_safe.block_on_async_exn`; on JS this is `Async_js.block`.

### `create : (('a -> unit) -> unit) -> 'a t`

Lower-level: the callback receives a "resolve" function. Mirrors JavaScript's
`new Promise(resolve => ...)`.

### `to_deferred : 'a t -> 'a Deferred.t`

Converts to an `Async.Deferred`. On native this is identity; on JS it bridges
the JS promise to Async.

### Monad interface

Includes `return`, `bind` (`>>=`), `map` (`>>|`), `both`, etc. via
`include Base.Monad.S`.

## Common pitfalls

1. **`block_on_async_exn` must NOT be called inside an Async scheduler**
   (thread — deadlock risk). Only call from non-async contexts like tests.
2. **`peek` returns `None` if not yet determined** — not an error.
   Contrast with `value_exn` which raises if not determined.
3. **`upon` vs `>>=`**: `upon` is fire-and-forget (returns `unit`); `>>=` is
   monadic bind (returns new promise). Don't confuse them.

## Source files

- `src/lib/concurrency/promise/promise.mli`
- `src/lib/concurrency/promise/native/promise.ml`
- `src/lib/concurrency/promise/js/promise.ml`
