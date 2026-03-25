# `syncable_ledger` — Code Structure and Bug Report

## 1. Module Overview

`syncable_ledger` implements a protocol for synchronizing a local, potentially
incomplete or stale Merkle-tree ledger from remote peers. The node traverses
the remote tree top-down, downloading only the subtrees that differ from what
it already holds locally.

**Files**

| File | Role |
|---|---|
| `syncable_ledger.ml` | Core implementation — protocol, state machine, responder |
| `test/test.ml` | Inline tests across multiple ledger back-ends and subtree-depth configurations |
| `dune` | Build descriptor; library name `syncable_ledger` |

---

## 2. Wire Protocol (`Query` and `Answer`)

Two versioned, polymorphic message types are defined at the top of the file.

### `Query.t` (V2, current)

```
Num_accounts
  Ask the peer: how many accounts exist, and what is the hash of the
  smallest subtree containing all of them?

What_child_hashes (addr, depth)
  Ask the peer: give me the hashes of the 2^depth leaves of the subtree
  rooted at addr.

What_contents addr
  Ask the peer: give me the accounts stored under addr.
  Only issued for addresses at or below account_subtree_height from the
  bottom of the tree.
```

V1 exists for backward compatibility; `What_child_hashes` in V1 always
requests depth=1 (two immediate children). `Query.V1.to_latest` upgrades it
to V2 automatically.

### `Answer.t` (V2, current)

```
Num_accounts (n, content_root_hash)
Child_hashes_are hashes   (* array, length must be a power of 2, >= 2 *)
Contents_are accounts     (* list of Account.t *)
```

V1 `Child_hashes_are` held exactly two hashes; V1 → V2 is a straight
wrapping into an array. Downgrade (V2 → V1) is provided for peers that
speak V1 only; it fails for wide (depth > 1) responses.

---

## 3. Module Signature (`S`)

`Make(Inputs)` produces a module satisfying `S`. External callers interact
via:

| Function | Description |
|---|---|
| `create mt ~context ~trust_system` | Allocate a syncer backed by local ledger `mt` |
| `new_goal t hash ~data ~equal` | Set the target root hash; starts a fresh sync |
| `fetch t hash ~data ~equal` | Convenience: `new_goal` then `wait_until_valid` |
| `wait_until_valid t hash` | Block until the local tree matches `hash` |
| `valid_tree t` | Block until any goal is achieved; returns tree and auxiliary data |
| `peek_valid_tree t` | Non-blocking check for a currently-valid tree |
| `answer_writer t` | Sink for peer answers (network layer writes here) |
| `query_reader t` | Source of queries to send to peers (network layer reads here) |
| `destroy t` | Close the internal pipes |

---

## 4. The `Responder` Sub-module

`Responder` is the peer side of the protocol. Given a fully-populated
`MT.t`, it implements `answer_query`, which fields incoming queries by
reading from its local ledger:

- `Num_accounts` → reads `MT.num_accounts`, computes the content-root
  address via `funpow`, returns `Num_accounts (n, hash)`.
- `What_child_hashes (a, depth)` → computes the `2^depth` addresses via
  `intermediate_range`, reads each inner hash, returns `Child_hashes_are`.
- `What_contents a` → reads all accounts under `a` via
  `MT.get_all_accounts_rooted_at_exn`, validates compactness, returns
  `Contents_are`.

Malformed queries (empty subtree, invalid depth, non-compact accounts)
result in a trust-system `Violated_protocol` record rather than a crash.

---

## 5. The Syncer State (`'a t`)

One value of type `'a t` exists per ledger being synced. The type parameter
`'a` is opaque auxiliary data (e.g. the epoch the ledger belongs to).

```
desired_root      : Root_hash.t option   -- current sync target
auxiliary_data    : 'a option            -- caller-supplied tag
tree              : MT.t                 -- the local ledger being filled in
trust_system      : Trust_system.t
answers           : Linear_pipe.Reader   -- incoming peer answers
answer_writer     : Linear_pipe.Writer   -- (exposed to network layer)
queries           : Linear_pipe.Writer   -- outgoing queries
query_reader      : Linear_pipe.Reader   -- (exposed to network layer)
waiting_parents   : Hash.t Addr.Table   -- addr -> expected hash, for in-flight
                                         --   What_child_hashes requests
waiting_content   : Hash.t Addr.Table   -- addr -> expected hash, for in-flight
                                         --   What_contents requests
validity_listener : Ivar.t              -- filled when sync completes or goal
                                         --   changes
context           : (module CONTEXT)    -- logger + daemon_config
```

---

## 6. Internal Functions

### `new_goal` (line 811)

Called externally to start or redirect a sync. If the new hash differs from
the current goal it:
1. Fills `validity_listener` with `` `Target_changed `` (unblocking any
   waiters on the old goal).
2. Replaces `validity_listener` with a fresh `Ivar`.
3. Updates `desired_root` and `auxiliary_data`.
4. Writes a `Num_accounts` query to kick off the new sync.

**Notable**: it does **not** clear `waiting_parents` or `waiting_content`.
Those tables are only cleared inside `handle_num_accounts`, but only when the
hash check passes (see bug below).

---

### `handle_num_accounts` (line 648)

The entry point for the sync proper. Called from `main_loop` when a
`Num_accounts` answer arrives.

```
1. Extract content_hash and n from the peer answer.
2. height := Int.ceil_log2 n
3. actual := complete_with_empties content_hash height (MT.depth t.tree)
   -- reconstructs the full-tree root hash by padding the content subtree
   -- upward with empty-node hashes
4. If actual = desired_root:
     clear waiting_parents, clear waiting_content
     handle_node t (Addr.root ()) rh   <-- starts the top-down walk
     return `Success
   Else:
     return `Hash_mismatch (rh, actual)
```

On `` `Hash_mismatch ``, `main_loop` calls `requeue_query ()`, which
re-emits the same `Num_accounts` query. There is **no other code path** that
calls `handle_node`; if `handle_num_accounts` never succeeds the syncer
loops on `Num_accounts` forever.

---

### `handle_node` (line 634)

Decides what to ask next for a given address:

- If `Addr.depth addr >= MT.depth t.tree - account_subtree_height`:
  → `expect_content` (add to `waiting_content`) + emit `What_contents addr`
- Otherwise:
  → `expect_children` (add to `waiting_parents`) + emit
    `What_child_hashes (addr, default_subtree_depth)`

---

### `add_subtree` (line 560)

Called when a `Child_hashes_are` answer arrives.

1. Validates the length is a power of 2, ≥ 2, and ≤ 2^requested_depth.
2. Merges the hashes up to their common ancestor via `merge_many`.
3. Compares the merged hash against the `waiting_parents` entry for `addr`.
4. On match: computes the `2^depth` child addresses, zips with hashes,
   **filters out children whose local hash already matches** (no need to
   re-download), and returns `Good subtrees_to_fetch`.
5. `main_loop` calls `handle_node` on each element of `subtrees_to_fetch`.

---

### `add_content` (line 509)

Called when a `Contents_are` answer arrives.

1. Looks up expected hash from `waiting_content`.
2. Writes accounts into local ledger via `MT.set_all_accounts_rooted_at_exn`.
3. Reads back the resulting hash and compares; on mismatch `requeue_query`.

---

### `main_loop` (line 665)

An Async loop (`Linear_pipe.iter`) over the `answers` pipe. For each
`(root_hash, query, envelope)`:

1. Discards the answer if `root_hash ≠ desired_root` or already done.
2. Dispatches to the appropriate handler based on `(query, answer)` shape.
3. Mismatched `(query, answer)` pairs → trust penalty + `requeue_query`.
4. After every answer, checks if `MT.merkle_root t.tree = desired_root`; if
   so calls `all_done` → fills `validity_listener` with `` `Ok ``.

---

### Hash helper functions

```
empty_hash_at_height h
  Computes the hash of an empty subtree of height h by repeated
  Hash.merge of empty_account with itself.

complete_with_empties content_hash start_height result_height
  Pads a content-subtree hash upward to the full tree height by
  repeatedly merging with an empty subtree of the same height,
  then doubling the empty subtree for the next level.

merge_many nodes height subtree_depth
  Reduces an array of 2^k hashes to their single common ancestor
  by repeated pairwise merging (merge_siblings), starting from
  height - subtree_depth.
```

---

## 7. Test Coverage (`test/test.ml`)

Tests are parameterised over two dimensions:

- **Ledger back-end**: `Db` (on-disk `Merkle_ledger.Database`) and `Mask`
  (in-memory mask over a database, with up to 2 mask layers).
- **Subtree depth configuration**: combinations of `max_subtree_depth` ∈
  {3, 6, 8} and `default_subtree_depth` ∈ {0, 1, 2, 6, 8}.

Two test scenarios are run for each configuration:

| Test | What it covers |
|---|---|
| `full_sync_entirely_different` | Sync a 1-account ledger up to an N-account target; verify root hash matches |
| `new_goal_soon` | Change the sync target halfway through; verify the final ledger matches the new goal |

Edge-case tests (`Make_test_edge_cases`) check that a responder correctly
rejects a `What_child_hashes` request with `depth = 0` (invalid).

---

## 8. Bug Report: Mid-Sync Stall in Epoch Ledger Synchronization

### Symptom

A node that has loaded its frontier from disk (i.e. after a restart following
a long-running session) enters `bootstrap` → epoch ledger sync, successfully
exchanges `Num_accounts` queries with all peers (~30 responses across ~3
rounds), but **never emits a `What_child_hashes` or `What_contents` query**.
The node loops on `Num_accounts` indefinitely and never exits bootstrap.

Confirmed in production (ITN testnet, 2026-03-25) across 5 nodes. All
`Downloader` results in the logs are `Num_accounts`; no other query type
appears.

### Root Cause: `handle_num_accounts` hash reconstruction fails for disk-loaded trees

The gate condition in `handle_num_accounts` (line 656) is:

```ocaml
let actual = complete_with_empties content_hash height (MT.depth t.tree) in
if Hash.equal actual rh then ...
```

`complete_with_empties` reconstructs the expected full-tree root by:

1. Taking `content_hash` (the peer-reported hash of the smallest non-empty
   subtree) at height `Int.ceil_log2 n`.
2. Padding it upward with empty-node hashes to `MT.depth t.tree`.

The computation is fully determined by three values: `content_hash`, `n`
(account count), and `MT.depth t.tree` (the depth of the **local** ledger
object). For this to produce `desired_root`, the local ledger's depth must
agree with the depth the peer used when it computed its `content_root_addr`
in `Responder.answer_query`:

```ocaml
(* Responder side *)
let content_root_addr =
  funpow (MT.depth mt - height) (fun a -> Addr.child_exn ... Left) (Addr.root ())
```

The peer computes `content_root_addr` using **its own** `MT.depth mt`.

After a restart, the local epoch ledger object (`t.tree`) is the one restored
from disk. Its `MT.depth` equals the **old epoch ledger's depth** (or the
depth the ledger was created with at node startup for the snarked ledger). If
this does not match the depth the peer uses for the same computation, the two
sides compute different paddings and the hash check fails.

More concretely: in the epoch ledger sync path, the syncer is given a fresh
ledger object of some fixed depth to fill in. The depth is chosen by the
bootstrap code, not by the syncer. If the peer and the local node use
different depth values (e.g. one uses 35, the other was initialised with a
different depth at some point in the startup sequence), `complete_with_empties`
produces a different root hash than the peer intended, `Hash_mismatch` is
returned, `requeue_query` is called, and the loop begins.

Because `handle_num_accounts` is the **only function** that calls
`handle_node`, and `handle_node` is the **only function** that enqueues
`What_child_hashes` or `What_contents`, a permanent `Hash_mismatch` from all
peers results in an infinite `Num_accounts` loop with no forward progress.

### Secondary Issue: `new_goal` does not clear `waiting_parents` / `waiting_content`

`new_goal` (line 811) replaces `desired_root` and emits a new `Num_accounts`
but does **not** clear `waiting_parents` or `waiting_content`. If a goal
change happens mid-sync, stale entries from the previous goal remain in both
tables. Should `handle_num_accounts` later succeed, `add_subtree` and
`add_content` will `find_exn` into those stale entries for addresses from the
old goal that happen to share the same address value, producing either a
silent hash mismatch (wrong expected hash) or an exception
(`Option.value_exn` failure at line 579: "Forgot to wait for a node").

### Affected Code Locations

| File | Lines | Issue |
|---|---|---|
| `syncable_ledger.ml` | 648–663 | `handle_num_accounts`: hash check can permanently fail for disk-restored trees; no escape path other than infinite `requeue_query` |
| `syncable_ledger.ml` | 655 | `complete_with_empties` uses `MT.depth t.tree` of the local (potentially mismatched) ledger |
| `syncable_ledger.ml` | 811–834 | `new_goal`: does not clear `waiting_parents` / `waiting_content` on goal change |

### Proposed Fix

**Primary fix** — in `handle_num_accounts`, if no peer's `Num_accounts`
response produces a matching root hash after a reasonable number of attempts,
log clearly and surface the failure rather than looping forever. The
underlying cause (depth mismatch between the local ledger object and the
epoch ledger the peers hold) must be found in the bootstrap path that creates
or restores the ledger object passed to the syncer.

Concretely, the depth of the `MT.t` passed to `Syncable_ledger.create` at
epoch-ledger-sync time must match the depth the peer uses to compute
`content_root_addr`. Both sides must derive depth from the same source of
truth (e.g. the compile-time `ledger_depth` constant) rather than from the
local ledger object's stored depth.

**Secondary fix** — `new_goal` should clear `waiting_parents` and
`waiting_content` when the goal changes, for the same reason
`handle_num_accounts` clears them on success: once the target root changes,
any in-flight expectations for the old goal are invalid.

```ocaml
(* new_goal, inside the `if not should_skip` branch, before writing Num_accounts *)
Hashtbl.clear t.waiting_parents ;
Hashtbl.clear t.waiting_content ;
```

This mirrors the clear already done inside `handle_num_accounts` and ensures
the tables never contain stale entries from a prior goal.
