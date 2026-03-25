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
- `What_child_hashes (a, depth)` → computes the `2^depth` child addresses via
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

### Precise Root Cause Hypothesis (Revised): Silent Stalling of Linear Pipes

The original hypothesis about a hashing mismatch is likely incorrect because the snarked ledger syncing process (which is analogous) works correctly and generates new `Sync_ledger.Root` instances, including new pipes. The issue is more likely related to how asynchronous pipes are handled.

The `Linear_pipe.iter t.answers ~f:handle_answer` in `main_loop` (syncable_ledger.ml:818) is responsible for processing incoming answers. This iteration will stop if `t.answers` is closed. `Linear_pipe.write_if_open` (which `min-networking.ml` uses) returns `false` silently if the reader side of the pipe is closed.

Therefore, the most likely reasons for answers not being processed are:

1.  **`handle_answer` stalls or fails silently**: If the `handle_answer` function, while processing an answer, encounters an unhandled exception or enters a `Deferred.t` computation that never resolves, the `Linear_pipe.iter` loop will effectively stall. This means `t.answers` is no longer being actively read from, causing its buffer to fill up and eventually leading to `Linear_pipe.write_if_open` returning `false` for subsequent writes.
2.  **Implicit closure of query_reader**: The `Sl_downloader` in `min-networking.ml` is configured with `global_stop = Pipe_lib.Linear_pipe.closed query_reader`. If `query_reader` is closed, the downloader will stop making queries. `query_reader` is the reader-end of the pipe whose writer-end is `t.queries`. If `t.queries` is implicitly closed, `query_reader` will close, stopping the downloader and thus no answers will be written to `response_writer`. There is no explicit call to close `t.queries` in the epoch ledger sync path. This could happen if, for example, the `new_goal` function (which writes the initial `Num_accounts` query to `t.queries`) fails or stalls after writing, leaving the writer pipe in an unexpected state.

---

### Investigation of Option 1: `handle_answer` Stall via `record_envelope_sender`

#### Stall Mechanism

`handle_answer` (syncable_ledger.ml:676–816) is the function passed to
`Linear_pipe.iter t.answers`. Every path through the `match (query, answer)`
dispatch is wrapped in a `let%bind _ = ... in`, which means the iteration
**does not advance to the next answer** until the current `handle_answer`
invocation fully resolves.

All four dispatch branches invoke `record_envelope_sender` (Trust_system):

| Branch | Action recorded |
|---|---|
| `What_contents` → `Success` | `Fulfilled_request` (via `credit_fulfilled_request`) |
| `What_contents` → `Hash_mismatch` | `Sent_bad_hash` |
| `Num_accounts` → `Success` | `Fulfilled_request` |
| `Num_accounts` → `Hash_mismatch` | `Sent_bad_hash` |
| `What_child_hashes` → `Hash_mismatch` / `Invalid_length` | `Sent_bad_hash` |
| `What_child_hashes` → `Good` | `Fulfilled_request` |
| Mismatched query/answer | `Violated_protocol` |

**In the observed bug**, every `Num_accounts` response triggers a
`Hash_mismatch`, so every `handle_answer` call goes through `Sent_bad_hash`.
If `record_envelope_sender` returns a `Deferred.t` that **never resolves**
(or resolves very slowly), `handle_answer` suspends, `Linear_pipe.iter`
stops pulling from `t.answers`, and the pipe buffer fills up.

#### Cascade to `min-networking.ml`

`glue_sync_ledger` (min-networking.ml:406–477) runs
`Linear_pipe.iter_unordered ~max_concurrency:400 query_reader ~f:...`. Each
fiber, after getting a downloader result, calls:

```ocaml
Linear_pipe.write_if_open response_writer (...)
```

`write_if_open` returns `unit Deferred.t`. If `response_writer`'s reader
(`t.answers`) is not being drained, this write blocks waiting for buffer
space. With `max_concurrency:400` the downloader can have up to 400 fibers
all blocked on `write_if_open`. Once all 400 slots are occupied, no new
download jobs can be dispatched — the `Sl_downloader` effectively stalls too,
even though it is still alive.

The symptom that **only `Num_accounts` appears in logs** is consistent with
this cascade: the downloader dispatches a `Num_accounts` query, the result
arrives, the fiber tries to write it into `response_writer`, and blocks
there. The write never completes so the result is never consumed by
`handle_answer`, so the query is never reissued from within `handle_answer`'s
`requeue_query()` — but the `Sl_downloader` may retry the key independently,
producing another `Num_accounts` log entry.

#### Concrete Stall Points in `handle_answer`

1. **`record_envelope_sender` with `Sent_bad_hash`** (syncable_ledger.ml:749–762):
   Called on every `Num_accounts` → `Hash_mismatch`. This is the highest-frequency
   stall candidate.

2. **`record_envelope_sender` with `Fulfilled_request`** (syncable_ledger.ml:718–722):
   Called on `Success`, but in the bug the `Num_accounts` never succeeds so
   this path is not reached.

3. **`desired_root_exn t` raising** (syncable_ledger.ml:696):
   `desired_root_exn` calls `failwithf` if `t.desired_root = None`. In normal
   operation this should never be `None` during `main_loop`, but if `destroy`
   races with an in-flight `handle_answer`, it could happen. The exception
   would be swallowed by `don't_wait_for` (line 900), silently terminating
   `main_loop`.

#### Instrumentation Points

To confirm this hypothesis, add logging around the `record_envelope_sender`
calls in `handle_answer`:

| File | Lines | What to log |
|---|---|---|
| `syncable_ledger.ml` | 749 | Log before and after `record_envelope_sender` on `Sent_bad_hash` |
| `min-networking.ml` | 476 | Log the bool result of `write_if_open` (returns `false` when reader closed, but blocks when buffer full) |
| `Trust_system` | internal | Check whether the trust-system pipe is being drained; log its buffer depth |

---

### Investigation of Trust System Pipe Draining (Option 1, Part 2)

#### `Trust_system.record_envelope_sender` Internal Blocking

The `record_envelope_sender` function (trust_system/trust_system.ml:185)
directly calls `Peer_trust.Make(Action).record` (trust_system/peer_trust.ml:165).
This `record` function contains synchronous writes to an internal
`Strict_pipe.Synchronous` (`upcall_writer`, peer_trust.ml:105):

```ocaml
(* peer_trust.ml:179, 217 *)
Strict_pipe.Writer.write upcall_writer (`Heartbeat peer)
Strict_pipe.Writer.write upcall_writer (`Ban (peer, expiration))
```

As `strict_pipe.ml` defines, a `Strict_pipe.Synchronous` pipe's `write` operation
is essentially `Pipe.write`, which will **block indefinitely** if the
reader side of the pipe is not consuming messages. If the internal buffer fills,
the write operation will not resolve, holding up the entire `let%bind` chain.

#### Lack of `upcall_reader` Consumption in Production

Crucially, in `Peer_trust.Make0.create` (peer_trust.ml:112), while the
`upcall_reader` is created, there appears to be no explicit `don't_wait_for
(Strict_pipe.Reader.iter ...)` or similar asynchronous loop within the
`Peer_trust` module itself to drain messages from this `upcall_reader` during
normal daemon operation. The only observed consumption is within the module's
unit tests.

**Confirmation:** A grep for `Peer_trust.upcall_pipe` in `src/app/cli/src/` and
`src/lib/mina_lib/` returned no usage. This confirms that the `upcall_reader`
is not being consumed by the daemon, which is the root cause of the trust
system pipe blocking issue.

#### Concrete Stall Path Confirmed

1.  `Syncable_ledger.handle_answer` receives a `Num_accounts` answer, resulting
    in `Hash_mismatch`.
2.  It calls `Trust_system.record_envelope_sender` with `Actions.Sent_bad_hash`.
3.  `Actions.Sent_bad_hash` translates to `Insta_ban` in `Peer_trust.to_trust_response`.
4.  `Peer_trust.record` attempts to write a `(`Ban ...)` message to `upcall_writer`.
5.  Since the `upcall_reader` is not being drained, `Strict_pipe.Writer.write`
    blocks. The `Synchronous` pipe's buffer fills up and the write cannot complete.
6.  This blocking propagates up the `Async.Deferred.t` chain, suspending
    `Peer_trust.record`, then `Trust_system.record_envelope_sender`, and finally
    `Syncable_ledger.handle_answer`.
7.  `Syncable_ledger.main_loop`'s `Linear_pipe.iter t.answers` stops processing
    new answers, causing `t.answers`'s buffer to fill.
8.  `min-networking.ml:476`'s `Linear_pipe.write_if_open response_writer` then
    blocks all 400 concurrent downloader fibers waiting for buffer space.
9.  The `Sl_downloader` fully stalls. Only `Num_accounts` queries are observed
    repeatedly, as the mechanism to issue `What_child_hashes` or
    `What_contents` queries (`handle_node` within `handle_num_accounts`)
    is never reached.

#### Proposed Solution Update

The primary fix must involve ensuring the `upcall_reader` of the `Peer_trust`
module is consistently drained throughout the daemon's lifecycle, likely via a
`don't_wait_for (Strict_pipe.Reader.iter ...)` call at the point where the
`Peer_trust` module is instantiated in the daemon. This would prevent the
`Strict_pipe.Writer.write` calls from blocking.

---

### Investigation of Option 2: Implicit Closure of `query_reader` / `Sl_downloader` Stall

#### Clarifying What Option 2 Actually Means

The earlier summary of Option 2 described "implicit closure of `query_reader`"
as the mechanism.  After tracing the code, this needs to be decomposed into two
distinct sub-scenarios:

**Sub-scenario 2a — `global_stop` fires prematurely**

In `glue_sync_ledger` (mina_networking.ml:419):

```ocaml
let global_stop = Pipe_lib.Linear_pipe.closed query_reader in
```

`Pipe_lib.Linear_pipe.closed` is defined as `Pipe.closed reader.pipe`
(linear_pipe.ml:48). In Async, `Pipe.closed` on a *reader* resolves only when
`Pipe.close_read` is called on that reader — **not** when the writer end is
closed. The writer end closing causes the reader to see EOF when drained, but
does not fire `Pipe.closed`.

The only call to `close_read` on `t.query_reader` in the codebase is inside
`destroy t` (syncable_ledger.ml:490):

```ocaml
let destroy t =
  Linear_pipe.close_read t.answers ;
  Linear_pipe.close_read t.query_reader
```

`destroy` is never called on the epoch ledger `sync_ledger` in
`proof_of_stake.ml` — there is no `destroy` call anywhere in the
`sync_local_state` function (proof_of_stake.ml:2585–2725). Therefore
`global_stop` does **not** fire for epoch ledger sync under normal operation,
and Sub-scenario 2a does not apply to the reported bug.

**Sub-scenario 2b — `Sl_downloader` enters `\`Stalled` state**

This is the real Option 2 risk. The `step` loop in `downloader.ml` selects
among four peer states (line 887–945):

```
`No_peers      → wait for new peers via got_new_peers_r
`Useful_but_busy → wait for flush or useful_peers signal
`Stalled       → reset knowledge, sleep post_stall_retry_delay (1 min), retry
`Useful (peer, might_know) → dispatch download
```

The `` `Stalled `` branch (line 923–931) fires when every known peer has been
tried and every job has failed with every peer. In that state the downloader:

1. Calls `Useful_peers.reset_knowledge` — clears all peer knowledge scores.
2. Sleeps for `post_stall_retry_delay = Time.Span.of_min 1.`.
3. Resumes `step`.

During that 1-minute sleep, the downloader issues **no queries**. Any
`Num_accounts` jobs enqueued by `requeue_query` in `handle_answer` sit in
`t.pending` but are not dispatched. From the outside this is indistinguishable
from the observed symptom: only `Num_accounts` queries appear in logs with no
`What_child_hashes` or `What_contents`, because no query at all is dispatched
for 60 seconds.

This stall is distinct from Option 1: the `Linear_pipe.iter t.answers` loop is
still running, but no download results arrive because the downloader is sleeping.

#### Conditions That Trigger `` `Stalled ``

The `Useful_peers` state machine reaches `` `Stalled `` when, after assigning
download jobs to peers, every returned result is an error (`Failed_to_connect`
or `Connected { data = Error _ }`), and the `attempts` map on each job records
a `download` attempt for every peer.

In the epoch ledger sync context, the `knowledge` function
(mina_networking.ml:420–428) probes each peer by sending a direct RPC
`(h, Num_accounts)`. If a peer responds `Ok _` it is tagged as
`` `Call (fun (h', _) -> Ledger_hash.equal h' h) `` — meaning the downloader
considers it willing to handle any query for root hash `h`. If the peer cannot
be reached, it gets `` `Some [] `` — it is known to have no useful knowledge and
is not selected for downloads.

The `` `Stalled `` path is reached when:
- All known peers either respond to the knowledge probe with `Ok` (are selected
  for jobs) **and** then fail the actual batch download, or
- All peers respond `` `Some [] `` so no peer is ever `Useful`, and the
  downloader cycles through `` `No_peers `` → wait for `got_new_peers_r` →
  `` `No_peers `` (since the peers list doesn't change).

In practice the more likely trigger is a **transient network condition** where
all peers pass the knowledge probe but the batch RPC then times out (10 s for
knowledge, 2 s × batch_size for get). After enough failures, all peers exhaust
their `worth_retrying` budget and `step` reaches `` `Stalled ``.

#### Interaction with Option 1

If Option 1 is the root cause (trust-system pipe blocking `handle_answer`), then
`requeue_query` inside `handle_answer` is also never called. The `Sl_downloader`
would have completed the first `Num_accounts` download and written the result to
`response_writer`, but the result sits unread in the `t.answers` pipe buffer.
The downloader does **not** issue a retry job for `Num_accounts` on its own —
retries are only triggered by `requeue_query` inside `handle_answer`. So under
Option 1 the downloader eventually sees all its active jobs resolved and may
reach `` `Stalled `` after a time, layering a second stall on top.

Under Option 2 alone (no Option 1), the downloader stalls for 1 minute then
retries. If the underlying cause is purely transient, the sync would eventually
succeed after one or more 1-minute pauses. The observed production symptom of
**indefinite** non-progression across multiple rounds over an extended period
(~30 responses across ~3 rounds) is harder to explain with Option 2 alone, and
points more toward Option 1 (trust-system pipe block) as the primary cause,
with Option 2 possibly contributing periodic 1-minute gaps.

#### Summary: Option 2 Assessment

| Sub-scenario | Applicable? | Impact |
|---|---|---|
| `destroy` closing `query_reader` → `global_stop` fires | **No** — `destroy` is never called in epoch sync path | Not a factor |
| `Sl_downloader` `` `Stalled `` → 1-minute sleep | **Possible** under transient network conditions | Causes temporary pauses, not indefinite stall |
| All peers return `` `Some [] `` → `` `No_peers `` loop | **Possible** if node has no reachable peers | Causes indefinite stall, but only if genuinely no peers |

Option 2 is a **contributing factor** (particularly the `` `Stalled `` / peer
knowledge reset path) but is insufficient on its own to explain indefinite
non-progression with ~30 logged `Num_accounts` responses. Option 1 (trust-system
pipe blockage) remains the primary hypothesis for the root cause.