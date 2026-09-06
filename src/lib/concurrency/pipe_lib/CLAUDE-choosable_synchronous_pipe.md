# Choosable_synchronous_pipe

## What it solves

A CSP-style pipe designed to work with `Deferred.choose`. Reading is
**idempotent** (calling `read` on the same handle returns the same result).
Writing happens **only after a read is initiated** — no buffering.
The pipe is synchronous (no background processing).

## Key semantics

### Immutable-handle pattern

Every `read` and `write_choice` returns a **new handle**. The old handle
remains functional (for reads, it returns the same value; for writes,
reusing it raises `Pipe_handle_used`).

```ocaml
val read : 'a reader_t -> [ `Eof | `Ok of 'a * 'a reader_t ] Deferred.t
val write_choice : on_chosen:('a writer_t -> 'b) -> 'a writer_t -> 'a -> 'b Deferred.Choice.t
val write : 'a writer_t -> 'a -> 'a writer_t Deferred.t
```

### `write_choice` semantics

Does NOT block. Returns a `Choice.t` for `Deferred.choose`. The write only
executes if the choice is selected AND a concurrent `read` has been initiated.
`on_chosen` receives the new writer handle. If the choice is not selected,
the write is silently dropped and `on_chosen` is never called.

### Exception behavior

- `write` / `write_choice` / `close` after the pipe is closed: raises
  `Pipe_closed`.
- Reusing a writer handle after a completed write/close: raises
  `Pipe_handle_used`.
- `read` on a closed pipe returns `` `Eof ``.
- `iter` uses `Deferred.repeat_until_finished` — if `f` raises, the exception
  propagates through the `iter` deferred.

### Thread safety

Safe for `iter` and `read` in parallel (same handle returns same value).
Safe for `write` and `write_choice` in parallel (but only one write completes).

## Common pitfalls

1. **Stale handles**: forgetting to use the new handle returned by `read`
   or `write_choice` means subsequent reads/writes see the same state (or
   raise `Pipe_handle_used`).
2. **`write_choice` silently drops**: if the choice is not selected (by
   `Deferred.choose`), the write is lost. No error, no warning.
3. **Deadlock**: `write` blocks until a reader calls `read`. If no reader
   exists, `write` hangs forever.

## Source files

- `src/lib/concurrency/pipe_lib/choosable_synchronous_pipe.ml`
- `src/lib/concurrency/pipe_lib/choosable_synchronous_pipe.mli`
