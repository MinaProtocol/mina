# Pipe_lib async primitives

This directory contains Mina's custom pipe primitives built on
`Async_kernel.Pipe`. Each has its own CLAUDE doc:

| Primitive | File | Summary |
|-----------|------|---------|
| [Linear_pipe](./CLAUDE-linear_pipe.md) | `linear_pipe.ml` | Single-reader pipe with `bracket` enforcement |
| [Strict_pipe](./CLAUDE-strict_pipe.md) | `strict_pipe.ml` | Pipe with overflow behavior (Crash/Drop_head/Call) and downstream tracking |
| [Broadcast_pipe](./CLAUDE-broadcast_pipe.md) | `broadcast_pipe.ml` | Single-writer, multi-reader with cached value |
| [Choosable_synchronous_pipe](./CLAUDE-choosable_synchronous_pipe.md) | `choosable_synchronous_pipe.ml` | CSP-style pipe for `Deferred.choose` with idempotent reads |
| [Swappable_strict_pipe](./CLAUDE-swappable_strict_pipe.md) | `swappable_strict_pipe.ml` | Strict_pipe with swappable short-lived readers |

See also the root `CLAUDE.md` for the repo build system and other conventions.
