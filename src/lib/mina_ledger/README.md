# Mina Ledger

The `mina_ledger` library is the central ledger implementation for Mina. It
instantiates the generic [Merkle ledger abstraction](../merkle_ledger/README.md)
with Mina-specific account and hash types, and provides the core data structures
and operations used throughout the daemon for reading and writing account state.

## Overview

A Mina ledger is a fixed-depth binary Merkle tree whose leaves hold
[`Account.t`](../mina_base/account.ml) values. Internal nodes store hashes that
allow the ledger's entire state to be summarised by a single `Ledger_hash.t`
(the Merkle root). Multiple ledger "views" can be layered on top of each other
using *masks*, making it cheap to speculatively apply or discard batches of
account updates.

The library exposes several modules that together cover the full lifecycle of
ledger data:

| Module | Purpose |
|---|---|
| `Ledger` | Maskable in-memory/on-disk ledger (the main entry point) |
| `Root` | Persistent root ledger backed by a RocksDB database |
| `Sparse_ledger` | Space-efficient ledger representation for Merkle proofs |
| `Sync_ledger` | Network synchronisation of ledger state from peers |
| `Ledger_transfer` | Bulk copy of accounts between ledger implementations |
| `Mask_maps` | Serialisable snapshots of mask state (accounts, hashes, token owners) |

## Architecture

```
        ┌───────────────────────────────────────────────┐
        │          Staged Ledger / Transition Frontier   │
        │   (applies diffs; reads/writes via Ledger.t)  │
        └────────────────────┬──────────────────────────┘
                             │
                  ┌──────────▼──────────┐
                  │    Ledger (mask)    │  ← Mask.Attached.t (= Ledger.t)
                  │  in-memory delta    │
                  └──────────┬──────────┘
                             │ commit / unregister
                  ┌──────────▼──────────┐
                  │    Maskable root    │  ← Any_ledger.witness
                  │  (Db or Any_ledger) │
                  └──────────┬──────────┘
                             │
                  ┌──────────▼──────────┐
                  │     Root ledger     │  ← Root.t  (RocksDB)
                  │  (snarked state /   │
                  │   epoch snapshots)  │
                  └─────────────────────┘
```

### Masks

The key design principle in `mina_ledger` is the *mask*. A mask is a thin
overlay that records account updates without touching the underlying ledger.
When the block producer decides to extend the canonical chain, the mask is
*committed* and its changes flow down to the parent. When a fork is abandoned,
the mask is simply discarded.

```
┌───────────────────────────────────────────────────┐
│  parent ledger (Db.t or another Mask.Attached.t)  │
└──────────────────────────┬────────────────────────┘
                           │  register_mask
             ┌─────────────▼─────────────┐
             │  Mask.Attached.t (= t)    │
             │  tracks: account writes,  │
             │  new account ids, hashes  │
             └─────┬───────────┬─────────┘
          commit   │           │  unregister_mask_exn
            ───────▼───        │  (mask dropped; parent unchanged)
```

Key operations:

- `register_mask parent mask` – attach an unattached mask to a parent ledger;
  returns the mask in its attached (usable) form.
- `commit attached_mask` – flush the mask's deltas into its parent and
  re-attach it as an empty mask on the same parent.
- `unregister_mask_exn ~loc attached_mask` – detach the mask from its parent
  without committing.
- `copy t` – create a fresh empty mask on top of `t`.

### Database backends

`Ledger.Db` is a RocksDB-backed Merkle ledger. Three flavours exist to handle
serialisation format differences across protocol versions:

| Module | Account type | Use case |
|---|---|---|
| `Db` | `Account.t` | Normal operation |
| `Unstable_db` | `Account.Unstable.t` | Backward-compatible reads |
| `Hardfork_db` | `Account.Hardfork.t` | Hardfork migration |

`Any_ledger` provides a dynamic-dispatch wrapper so that code dealing with
ledgers does not need to be parameterised over the concrete implementation.

## Module Reference

### `Ledger` (`ledger.ml`)

The central module. Its type `t = Mask.Attached.t` is the everyday ledger
handle used throughout the daemon.

**Creating ledgers**

```ocaml
(* Ephemeral in-memory ledger (useful in tests) *)
val create_ephemeral : depth:int -> unit -> t
val with_ephemeral_ledger : depth:int -> f:(t -> 'a) -> 'a

(* On-disk ledger, placed at [directory_name] *)
val create : ?directory_name:string -> depth:int -> unit -> t

(* Wrap an existing database *)
val of_database : Db.t -> t

(* Resource-safe scoped ledger *)
val with_ledger : depth:int -> f:(t -> 'a) -> 'a
```

**Account access**

```ocaml
val get : t -> Location.t -> Account.t option
val set : t -> Location.t -> Account.t -> unit
val get_or_create : t -> Account_id.t -> (account_state * Account.t * Location.t) Or_error.t
val location_of_account : t -> Account_id.t -> Location.t option
val merkle_root : t -> Ledger_hash.t
val num_accounts : t -> int
```

**Applying transactions**

```ocaml
val merkle_root_after_user_command_exn :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> txn_global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> t -> Signed_command.With_valid_signature.t -> Ledger_hash.t

val merkle_root_after_zkapp_command_exn :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> global_slot:Mina_numbers.Global_slot_since_genesis.t
  -> txn_state_view:Zkapp_precondition.Protocol_state.View.t
  -> t -> Zkapp_command.Valid.t -> Ledger_hash.t
```

These functions apply a single command to the ledger and return the new Merkle
root, raising an exception if the command is invalid. They are used primarily
in tests and tooling; the block-production and block-application paths go
through `Staged_ledger`.

### `Root` (`root.ml`)

A `Root.t` represents the fully-proven ledger state (a *snarked* ledger – one
whose transactions have all been certified by zero-knowledge proofs) or an epoch
snapshot. It is backed by one or more RocksDB databases on disk and is the
base of the mask stack maintained by the transition frontier.

Root ledgers are **not** masks themselves; they are wrapped by `as_masked` /
`as_unmasked` before being handed to code that expects a `Ledger.t` or an
`Any_ledger.witness`.

Key operations:

```ocaml
val create : logger:Logger.t -> config:Config.t -> depth:int -> ?assert_synced:bool -> unit -> t
val merkle_root : t -> Ledger_hash.t
val as_masked : t -> Ledger.t
val as_unmasked : t -> Ledger.Any_ledger.witness
val create_checkpoint : t -> config:Config.t -> unit -> t
val make_converting :
     hardfork_slot:Mina_numbers.Global_slot_since_genesis.t
  -> t -> t Async.Deferred.t
```

`Config.backing_type` selects the on-disk format:

- `Stable_db` – the standard format used during normal operation.
- `Converting_db slot` – used when migrating across a hard fork at `slot`; reads
  from a `Hardfork_db` alongside the primary `Db`.

### `Sparse_ledger` (`sparse_ledger.ml`)

A `Sparse_ledger.t` stores only the accounts and Merkle siblings that are
needed to verify or apply a specific set of transactions. The rest of the tree
is represented by hash placeholders. This makes it suitable for passing to
snark workers, which need Merkle witnesses for the accounts they touch but do
not need the entire ledger.

```ocaml
(* Build from a full ledger, keeping only the listed accounts *)
val of_ledger_subset_exn : Ledger.t -> Account_id.t list -> t

(* Build from the full ledger for a given set of leaf indexes *)
val of_ledger_index_subset_exn : Ledger.Any_ledger.witness -> int list -> t

(* Get/set an account by its leaf index in the sparse tree *)
val get_exn : t -> int -> Account.t
val set_exn : t -> int -> Account.t -> t

(* Merkle root of the sparse tree *)
val merkle_root : t -> Ledger_hash.t
```

### `Sync_ledger` (`sync_ledger.ml`)

Instantiates `Syncable_ledger.Make` for two target types:

| Sub-module | Target ledger type |
|---|---|
| `Sync_ledger.Any_ledger` | `Ledger.Any_ledger.M.t` |
| `Sync_ledger.Root` | `Root.t` |

The synchronisation protocol downloads a remote ledger subtree-by-subtree: the
syncing node queries peers for child hashes or account contents, and the
protocol terminates when the local Merkle root matches the target. See
[`syncable_ledger`](../syncable_ledger/syncable_ledger.ml) for the full
protocol implementation.

### `Ledger_transfer` (`ledger_transfer.ml`)

Provides functors for copying account data between two ledger implementations
that share the same address type:

```ocaml
module Make (Source : Base_ledger_intf) (Dest : Base_ledger_intf with type Addr.t = Source.Addr.t) : sig
  val transfer_accounts : src:Source.t -> dest:Dest.t -> Dest.t Or_error.t
end

module From_sparse_ledger (Dest : Base_ledger_intf) : sig
  val transfer_accounts : src:Sparse_ledger.t -> dest:Dest.t -> Dest.t Or_error.t
end
```

After copying, both functions verify that the Merkle roots of `src` and `dest`
agree, returning an error if they do not.

## Relationship to Other Ledger Libraries

```
mina_ledger          ← this library; Mina-specific instantiation
    ├── merkle_ledger    generic Merkle-tree interfaces & database backend
    ├── merkle_mask      mask overlay logic
    └── syncable_ledger  peer-to-peer sync protocol

staged_ledger        sits above mina_ledger; applies diffs to Ledger.t
genesis_ledger       creates the initial Ledger.t at chain start
ledger_proof         transaction snark that certifies a Ledger_hash.t
sparse_ledger_lib    base types reused by mina_ledger's Sparse_ledger
```

## Related Documentation

- [Staged Ledger README](../staged_ledger/README.md) – how blocks are applied
  to produce new ledger states and how snark work is tracked.
- [Merkle Ledger README](../merkle_ledger/README.md) – the generic Merkle tree
  abstraction: addresses, locations, paths and roots.
- [Ledger Catchup README](../ledger_catchup/README.md) – how the daemon
  downloads and validates missing blocks and their associated ledger state.
- [Syncable Ledger](../syncable_ledger/syncable_ledger.ml) – the subtree-hash
  synchronisation protocol used by `Sync_ledger`.
- [RFC 0010](../../../rfcs/0010-decompose-ledger-builder.md) – decomposition of
  the original ledger builder into staged ledger and scan state.
