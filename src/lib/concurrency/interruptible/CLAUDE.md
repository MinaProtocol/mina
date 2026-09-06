# Interruptible

## What it solves

A monad for computations that can be **cancelled by an external signal**.
`('a, 's) t` represents a computation producing `'a` that can be interrupted
by a signal of type `'s`. Once interrupted, the computation and all dependent
computations (via `bind`, `map`) resolve as "interrupted" and their results
are discarded.

## Key semantics

### Internal type

```ocaml
type ('a, 's) t =
  { interruption_signal : 's Ivar.t
  ; d : ('a, 's) Deferred.Result.t
  }
```

Two key states:
- `Ivar` not full → computation not yet interrupted
- `Ivar` full → interruption signal received; `d` resolves to `Error signal`

### `bind` / `map` interruption propagation

When a signal arrives:
- If the bound computation has **already resolved**, it is not interrupted
  (other dependents may still need it), but the *result* of the `bind` becomes
  interrupted.
- If bound computation has **not resolved**, its internal `interruption_signal`
  is filled, interrupting it too.

`map` always prefers the interruption signal over the resolved value: if the
signal fires after resolution but before the `map` callback runs, the result
is still `Error signal`.

### `lift d interrupt` vs `uninterruptible d`

- `lift`: the computation becomes interruptible when `interrupt` resolves.
- `uninterruptible`: creates an interruptible with a **never-filled** Ivar.
  The computation runs to completion. But if a parent `bind` propagates an
  interruption, the result is still discarded via the `bind` logic.

### `finally x ~f`

`f ()` runs after `x` finishes, regardless of interruption. The final
result is unchanged.

### `force`

Returns `('a, 's) Deferred.Result.t`. Prefers interruption even if the
underlying `d` has already resolved OK — it runs through `map` which
checks the signal.

### `don't_wait_for`

Ignores both the result and interruption. Equivalent to:
```ocaml
don't_wait_for (Deferred.map d ~f:(function Ok () -> () | Error _ -> ()))
```

## Common pitfalls

1. **`uninterruptible` still discards results**: if a parent bind interrupts,
   the uninterruptible block's result is discarded even though it ran to
   completion. Use `force` to retrieve it.
2. **Interruption is one-shot**: once the `Ivar` is filled, there's no
   "un-interrupt". All dependent computations immediately see the error.
3. **`don't_wait_for` ignores errors**: if a computation raises (not
   interrupted), the exception is swallowed.

## Source files

- `src/lib/concurrency/interruptible/interruptible.ml`
- `src/lib/concurrency/interruptible/interruptible.mli`
