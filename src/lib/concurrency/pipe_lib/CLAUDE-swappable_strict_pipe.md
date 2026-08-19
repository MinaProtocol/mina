# Swappable_strict_pipe

## What it solves

Wraps a `Strict_pipe` with **short-lived reader swapping**. The long-lived
writer feeds a persistent `Strict_pipe`; a background thread reads from it
and forwards data to the current "short-lived" `Choosable_synchronous_pipe`.
Calling `swap_reader` creates a new short-lived reader; the old reader's
unconsumed data is passed to the new one. Guarantees no data loss or
duplication across swaps.

## Key semantics

### Background thread (`O1trace.background_thread`)

A single `Deferred.repeat_until_finished` loop processes one event per async
cycle via `Deferred.choose`:
1. If `termination_signal` is set → cleanup and exit.
2. If a new short-lived pipe is available → swap to it.
3. If no short-lived sink → wait for one.
4. If data is available from long-lived reader → read it into `data_unconsumed`.
5. If both unconsumed data and a sink exist → write to short-lived sink.

### `swap_reader` behavior

- Creates a new `Choosable_synchronous_pipe` and signals the background thread
  to swap via `next_short_lived_pipe` Ivar.
- Returns immediately closed reader if pipe is terminated or another swap is
  in-flight (at most one pending swap).
- The old short-lived reader remains open until the background thread processes
  the swap signal.

### `write` behavior

Delegates directly to the underlying `Strict_pipe.Writer.write`. Does not
interact with the short-lived pipes.

### Termination (`kill`)

Fills `termination_signal` Ivar. The background thread then kills the
long-lived writer, closes remaining short-lived pipes, and exits.

## Common pitfalls

1. **Write is not buffered by the swappable layer**: `write` goes straight
   to the long-lived `Strict_pipe`. Overflow behavior is determined by the
   `Strict_pipe.type_` used at creation.
2. **Concurrent `swap_reader`**: second caller gets immediately closed reader.
   No error raised.
3. **`swap_reader` after `kill`**: returns immediately closed reader (no error).

## Source files

- `src/lib/concurrency/pipe_lib/swappable_strict_pipe.ml`
- `src/lib/concurrency/pipe_lib/swappable_strict_pipe.mli`
