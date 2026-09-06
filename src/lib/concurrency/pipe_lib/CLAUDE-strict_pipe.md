# Strict_pipe

## What it solves

A pipe with **overflow behavior** control and **downstream tracking**. Unlike
`Linear_pipe`, it has its own `Reader` and `Writer` types (not just a thin
wrapper over `Pipe`). Provides CSP-style pushback: writers block until
readers consume.

Supports three modes via GADT `type_`:

| Mode | Behavior on overflow |
|------|---------------------|
| `Synchronous` | No buffering; write returns a `unit Deferred.t` (pushback until read) |
| `Buffered (\`Capacity n, \`Overflow Crash)` | Raises `Strict_pipe.Overflow` |
| `Buffered (\`Capacity n, \`Overflow (Drop_head f))` | Drops oldest, calls `f` on it |
| `Buffered (\`Capacity n, \`Overflow (Call f))` | Calls `f data`, returns `Some (f data)` |

## Key semantics

### Exception behavior

- **`fold` / `iter`**: enforce single-reader (like `Linear_pipe.bracket`).
  Reader's `read` calls `enforce_single_reader`. If callback `f` raises,
  the exception propagates through the deferred (stops pipe consumption).
- **`iter_without_pushback`**: delegates to `Pipe.iter_without_pushback`;
  has optional `?continue_on_error` (default `false` — exceptions propagate).
- **`Merge.iter`**: same — callback exceptions propagate.
- No `Monitor.try_with` wrapping in Strict_pipe itself.

### Downstream tracking

When you `map`, `filter_map`, `Fork`, or `partition_map3` a `Reader`,
the source keeps a linked list `downstreams` of created readers. On `close`
or `kill`, all downstreams are `close_read` (cascading close).

### Fork semantics (CSP)

`Reader.Fork.n` uses `Pipe.iter` (WITH pushback) internally. The `don't_wait_for`
background thread blocks writers until all downstream forks take the value.

### `transfer` / `transfer_while_writer_alive`

`transfer` links upstream reader to downstream writer (sets `downstreams` chain).
`transfer_while_writer_alive` keeps transferring while the destination is open
(no downstream link — checks `Pipe.is_closed` each iteration).

## Common pitfalls

1. **Synchronous mode deadlock**: if no reader calls `read`, `write` blocks
   forever (pushback). Use `Buffered` if readers may lag.
2. **`Drop_head` + `warn_on_drop:true`**: logs a warning on overflow. Set
   `~warn_on_drop:false` for expected overflow.
3. **`kill` vs `close`**: `kill` first clears the pipe buffer, then closes
   writer and downstreams. `close` does not clear the buffer.
4. **Exception in `fold`/`iter` callback kills the pipe and propagates**
   (same pattern as `Linear_pipe`).

## Source files

- `src/lib/concurrency/pipe_lib/strict_pipe.ml`
- `src/lib/concurrency/pipe_lib/strict_pipe.mli`
