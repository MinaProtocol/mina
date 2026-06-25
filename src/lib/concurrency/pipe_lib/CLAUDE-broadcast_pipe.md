# Broadcast_pipe

## What it solves

A single-writer, **multiple-reader** pipe. Always seeded with an initial value.
Every new reader sees the **current cached value** immediately, then all
subsequent writes. Writers block until all downstream consumers have processed
the value.

## Key semantics

### Internal architecture

Uses a single `root_pipe` + one sub-pipe per reader (created in `prepare_pipe`).
Writes go to `root_pipe`; a background `don't_wait_for (Pipe.iter ...)` fans out
each value to all sub-pipes in **parallel** (`Deferred.List.iter ~how:\`Parallel`).

### Write is synchronous (blocks callers)

`Writer.write` blocks until all downstream consumers have called
`Pipe.Consumer.values_sent_downstream` AND their pipes are `downstream_flushed`.
This means slow readers block the writer.

### Exception behavior

- **`Reader.iter`** delegates to `Pipe.iter` with a trivial consumer.
  Default `continue_on_error` is not explicitly set, so exceptions propagate.
- **`Reader.fold`** same pattern.
- If a sub-pipe write fails (e.g. closed reader), the fan-out loop's
  `Deferred.List.iter` may fail and propagate to the monitor (via
  `don't_wait_for`).

### Close semantics

`Writer.close` closes `root_pipe`, then closes and removes all sub-pipes.
Writes after close raise `Broadcast_pipe.Already_closed`. Reads after close
see `Eof`.

## Common pitfalls

1. **Slow readers block writers**: the `Writer.write` blocks on ALL consumers
   flushing. A stuck reader stalls the entire broadcast.
2. **`Already_closed`**: writing/peeking after close raises — check `is_closed`
   or wrap in try/with.
3. **Initial value seeding**: `create a` seeds the pipe with `a`, which is
   immediately visible to all new readers via `peek` and as the first `iter`
   element.

## Source files

- `src/lib/concurrency/pipe_lib/broadcast_pipe.ml`
- `src/lib/concurrency/pipe_lib/broadcast_pipe.mli`
