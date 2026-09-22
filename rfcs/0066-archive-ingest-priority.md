## Summary
[summary]: #summary

The archive node writes blocks it is given. It never looks for a block itself. When a block is
missing, a separate tool, `mina-missing-blocks-guardian`, finds the gap and fills it from a bucket of
*precomputed blocks* (a JSON document holding one block together with the account data the archive
needs to store it).

This RFC proposes to move that tool inside the archive node, and then to let the archive be fed from
a source other than the daemon. It sets one requirement above all others:

> **Serving the daemon must never wait for background work.** The daemon holds a block until the
> archive answers. If the archive answers too slowly, the daemon drops the block. A dropped block is
> a gap, and a gap is what the background work exists to repair. That loop must be impossible by
> construction, not avoided by tuning.

The RFC describes four changes, in the order they should land, and states what each one may and may
not assume.

## Motivation
[motivation]: #motivation

Three facts, established by reading the code, decide the whole design.

**1. The archive already accepts blocks from anyone.** `src/app/archive/lib/rpc.ml` declares three
RPCs — `Send_archive_diff`, `Send_precomputed_block` and `Send_extensional_block` — and all three are
implemented on the archive's server port in `Processor.setup_server`. `mina advanced archive-blocks`
already uses the second one. A new feeder therefore needs no change to the archive node at all.

**2. The daemon feed carries nothing extra that the archive uses.**
`Archive_lib.Diff.Transition_frontier.Breadcrumb_added` carries the block, `accounts_accessed`,
`accounts_created`, `tokens_used` and `sender_receipt_chains_from_parent_ledger`. The `run` loop
destructures it as `{ block; accounts_accessed; accounts_created; tokens_used; _ }` — the receipt
chains are discarded — and `Root_transitioned` and `Bootstrap` fall into a branch that returns
`Deferred.unit`. A precomputed block carries exactly the four fields that are used. Feeding the
archive from precomputed blocks is therefore not a reduced mode; it is the same information over a
different transport.

**3. Canonicity does not come from the daemon.** `Processor.Block.update_chain_status` works from
block height and `genesis_constants.protocol.k` alone. Its only external input is a seed: when
`get_highest_canonical_block_opt` returns `None` it does nothing at all. The seed is the genesis
block, which `add_genesis_accounts` inserts as canonical from `--config-file`. An archive that starts
from genesis, or from a hard-fork block, and is then fed from a bucket, marks its own chain canonical
with no daemon present.

Against those three facts stands one hazard, which is the reason for the ordering below.

**The sender waits.** `Send_archive_diff` is implemented as a write to a `Strict_pipe` created
`Synchronous`. A `Synchronous` write is `Pipe.write`, which is not acknowledged until the reader has
taken the value, and the reader runs one block to completion before reading again. So the daemon's
RPC call is held for as long as the archive takes. The ceiling is the RPC heartbeat timeout of 60
seconds (`Node_config_unconfigurable_constants.rpc_heartbeat_timeout_sec`). After that,
`Archive_client.dispatch` retries five times with no backoff and then logs
`Could not send breadcrumb to archive` and **drops the breadcrumb**. There is no durable queue on the
daemon side.

Note also that the archive already runs three writers concurrently: the three pipe readers are
started with `don't_wait_for` and each calls `add_block_aux` independently. Adding a fourth writer is
what would make the hazard real. The design below adds a queue instead of a writer.

## Detailed design
[detailed-design]: #detailed-design

### Stage 1 — measure what the sender waits for

A histogram, `Mina_Archive_ingest_duration_ms`, labelled by the source that sent the block
(`diff`, `precomputed`, `extensional`), recording the span from the moment the archive accepts an
ingest call to the moment it answers.

This is deliberately not the database write time. It is the span the sender experiences, which
includes queueing behind work the archive was already doing. That makes it the one number that
states the requirement, and every later stage is judged against it.

It is worth having on its own, before anything else changes: it says whether the guardian you run as
a sidecar today is already costing you ingest latency.

### Stage 2 — one writer, live blocks first

Fold the three reader loops into one loop that drains the three pipes in a fixed order, the daemon
diff first. The order is enforced with a non-blocking read:

```
loop ():
  match Pipe.read_now live with
  | `Ok block          -> write block; loop ()
  | `Nothing_available -> choose [ live becomes readable ; another source has a block ]
```

`Pipe.read_now` answers "is a live block waiting?" without yielding, so a lower-priority block is
taken only when the answer is no.

This stage contains no new feature and no guardian. It stands on its own merit:

- it removes write concurrency that exists today;
- with it, one instance of the `SELECT`-then-`INSERT` dedup race (PR #19404, issue #19449) becomes
  impossible between these sources, because they are no longer concurrent;
- Stage 1's histogram proves it did no harm.

**Guarantee established.** A live block waits for at most **one** lower-priority insert: the one
already in flight. Not a queue of them, not a batch, not a pass. That one insert is bounded further
by `SET LOCAL statement_timeout` on the background transaction, which the archive's migration scripts
already use.

### Stage 3 — the guardian inside the archive node

`mina-missing-blocks-guardian` is already a thin executable over
`src/app/missing_blocks_guardian/lib`, and `Guardian.repair` takes
`~pool ~logger ~genesis_constants ~constraint_constants ~proof_cache_db` — every one of which is
already in scope in `setup_server`. `Ingest.add` already calls
`Processor.add_block_aux_precomputed`, the same function the precomputed-block handler calls. So this
is a library call, not a subprocess, and there is no channel to build.

Split the guardian's work across the boundary Stage 2 created:

| Stage of work | Where it runs | Cost |
| --- | --- | --- |
| audit, fetch, decode | guardian loop, off the write path | network, CPU |
| writing the block | the single writer, lowest priority | database |

The decode is the one place where the guardian can truly stall the scheduler:
`Precomputed.Stable.of_yojson_to_latest` is synchronous OCaml with no await point. Keeping it in the
guardian stage takes it off the write path; `Scheduler.yield_every`, or `run_in_thread` if
measurement calls for it, keeps it from holding the scheduler. Note that OCaml 4.14 has a single
runtime lock, so a thread gives interleaving at safepoints, not parallelism.

One new flag, `--missing-blocks-source URI`. The other guardian settings are not flags here, because
the archive knows them better than an operator does:

| Guardian flag | Inside the archive |
| --- | --- |
| `--min-height` | derived from `runtime_config_opt`: the archive knows its own fork point |
| `--network` | derived from the configuration, for the block file name |
| `--block-format` | precomputed, for a bucket |

`--max-blocks` and `--interval` stay, but they change meaning: they are a throughput control for the
guardian, not a safety control. Stage 2 provides the safety. Setting them badly makes the guardian
slow; it does not make the daemon wait.

There is deliberately **no** maximum gap size. A long outage is handled by batching — some blocks,
then a pause, then some more — not by refusing to start. The audit already measures the gap in
`Sql.Missing_blocks_gap`; that number is reported as a warning with an estimate, so that an operator
can choose to restore a dump instead, but it never blocks the attempt.

Two things must be written down for operators:

1. **It changes what the archive is.** Today the archive writes only what it is given. With the flag
   set, it reaches out to the network on its own initiative. That is why the flag defaults to off,
   and why the standalone binary keeps working from the same library: a deployment migrates when it
   chooses to.
2. **One guardian per database.** The priority queue is per process. Two archive nodes on one
   database, both with the guardian enabled, reintroduce exactly the concurrency Stage 2 removed.

### Stage 4 — ask a peer archive instead of guessing a file name

The guardian locates a block by building the name `<network>-<height>-<state hash>.json`. A wrong
network name produces a 404 that is indistinguishable from a block the bucket does not hold. That has
already caused a repair loop to spin without saying why.

An archive database holds everything needed to rebuild a block in extensional form:
`mina-extract-blocks` does it today, `accounts_accessed`, `accounts_created` and `tokens_used`
included. And `Ingest.add` already accepts the extensional format. So one request/response RPC is
enough:

```
Get_extensional_block : state_hash -> Extensional.Block.t option
```

served by the archive, called by the guardian as a third `Block_source` variant beside `Http_source`
and `Directory_source`. There is no name to get wrong, and "I do not hold it" is an explicit `None`.

A daemon cannot serve this for historical blocks: building the account data needs the ledger at that
block (`Precomputed_block.of_block` reads `Staged_ledger.ledger`), and a daemon holds ledgers only
for the blocks in its transition frontier. For backfill the peer must be an archive.

**Versioning.** `src/app/archive/lib/diff.ml` states that the archive RPC types are unversioned and
that the daemon and the archive must be built from the same sources. The two block RPCs are better
but still pin `Stable.Latest`. A peer-to-peer RPC is called across version boundaries precisely when
it is most needed — during a hard fork, or when backfilling from an older archive. It must accept
older versions, the way the file path does with `of_yojson_to_latest`.

### Stage 5 — a feeder, outside the archive

By fact 1 above, a process that reads a bucket, or subscribes to a topic, and pushes
`Send_precomputed_block` needs no archive change. By fact 3, such an archive still marks its own
chain canonical, provided it was started from a genesis or hard-fork block.

The hard part is discovery, not the database. The guardian's lookup works because an orphan row gives
it both the parent height and the parent hash. Going forward, neither the next height's hash nor its
existence is known, so the feeder needs a listing by prefix, an index object, or a notification.

Two limits to state rather than discover:

- **Lag.** Bucket upload lags the tip, and `k` confirmations lag on top of that. A bucket-fed archive
  is structurally behind a daemon-fed one.
- **Trust.** The daemon feed comes from a node that verified the block. `add_block_aux_precomputed`
  does not verify the proof. Today the operator chooses the bucket, so this is acceptable; it becomes
  a stated assumption once the bucket is the primary path.

## Drawbacks
[drawbacks]: #drawbacks

Stage 2 changes the ingest path of a production archive node for no user-visible benefit. It is
justified only as the precondition for Stage 3, and by the write concurrency it removes.

Stages 3 to 5 each widen what the archive process does. An archive that fetches its own blocks is
harder to reason about during an incident than one that only writes what it is handed. Stage 1 exists
partly to make that reasoning possible from metrics rather than from guesses.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

**The canonicity seed.** Every stage above still leaves a block `pending` until
`update_chain_status` has a canonical block to measure from. An archive restored from a dump that
does not reach genesis has no such seed, and the only answer today is the operator's `--min-height`.
This is a prerequisite for all of the above and is not solved here.

**What is not proposed.** No schema change, no change to the existing RPC surface, and no change to
the daemon. That is worth keeping true: it is what makes each stage reviewable by the people who
operate archive nodes.

## Testing
[testing]: #testing

The requirement in the Summary is testable, and Stage 1 is what makes it so. Run a backfill of a few
thousand blocks against an archive that is also receiving a live feed, and assert that the p99 of
`Mina_Archive_ingest_duration_ms{source="diff"}` does not move.

That is the test to write for Stage 3. It is the test that would fail if any of the reasoning in this
RFC is wrong.
