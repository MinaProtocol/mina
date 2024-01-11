## Summary

[summary]: #summary

Refactoring the existing ledger-builder-controller to a new simpler set of
components we're calling the transition-frontier-controller. At the top level,
we'll connect these components together in a similar manner to `mina_lib` --
just wiring together pipes. The new transition-frontier-controller includes the
merkle-mask and a safer history-catchup mechanism in addition to simplifying
asynchronous logic. The goal is to end up with a simple set of components that
will be robust towards future requirements changing and easy to trace dataflow
and test and debug.

## Motivation

[motivation]: #motivation

We are refactoring the existing ledger-builder-controller in order to make it
easier to reason about the async control flow of information in the system. The
old system was not designed carefully taking asynchronous transactions and
network delays into account. These involved lots of concurrency, and so it's
very hard to trace information and there are subtle bugs.

Since refactoring the control flow requires a rewrite, we decided to think
carefully about more of the other pieces as well now that we know more about
the design of the rest of the protocol code.

The new transition-frontier-controller is responsible for handling incoming
transitions created by proposers either locally or remotely by: (a) validating
them, (b) adding them to a `Transition_frontier` as described below if
possible, if not, (c) carefully triggering a sync-ledger catchup job to
populate more information in our transition-frontier and completing the
add. It is also responsible for handling sync-ledger answers that catchup
jobs started by other nodes trigger via sending queries.

The expected outcome is to have something with feature parity to the existing
ledger-builder-controller from the outside. Internally, aside from having
rigor around the async control flow, we also will take advantage of merkle
masks to remove a large chunk of complex logic from the existing
ledger-builder-controller code.

It should also be much easier to unit-test and trace the flow of information
for debugging purposes.

## Detailed design

[detailed-design]: #detailed-design

### Introduction

`Ledger_builder_controller` was far too big in its scope. In this rewrite,
we're not only breaking apart the code into more modules, but also breaking it
up across several libraries.

There will be a new top-level `Transition_frontier_controller` module that will
just wire the pipes together for the new components:

- [Transition Handler](#transition-handler)
- [Transition Frontier](#transition-frontier)
- [Ledger Catchup](#ledger-catchup)
- [Query Handler](#query-handler)

Note that all components communicate between each other solely through the use
of pipes. By solely using pipes to connect components we can be more explicit about the [Async Control Flow](#async-control-flow).

After describing all the components, we'll cover the specific behavior of
the [Async Control Flow](#async-control-flow) holistically.

Before covering any of the components it's worth going over some fundamental
changes in behavior and structure in more detail in [big Changes](#big-changes)

<a href="big-changes"></a>

### Big Changes

Major differences in behavior between this component and the existing ledger-
builder-controller are as follows:

1. We only sync-ledger to the locked-ledger (if necessary) and do a new
   [History sync](#history-sync) for catchup jobs

Rationale: Without history sync, we are vulnerable to believing an invalid
state: Certain parts of the staged-ledger state are not checked in a SNARK and
so we must get enough info to go back to the locked state (where we know we've
achieved consensus).

2. There is now a notion of a `Breadcrumb.t` which contains an
   `External_transition.t` and a now light-weight `Staged_ledger.t` it also has a
   notion of the prior breadcrumb. We take advantage of the merkle-mask to put
   these breadcrumbs in each node of the transition-tree. See
   [RFC-0008](0008-persistent-ledger-builder-controller.md) for more info on merkle
   masks, and [Transition frontier](#transition-frontier) for more info about how
   these masks are configured.

Rationale: The frequent operation of answering sync-ledger queries no longer
require materializing staged-ledgers. We should optimize for operations that
occur frequently.

3. The `Ktree.t` is mutable and exposes an $O(1)$ `lookup : State_hash.t -> node_entry` where `node_entry` contains (in our case) a `Breadcrumb.t`.

Rationale: We perform `lookup` and `add` frequently on this structure and `add` can be $O(1)$ in the presence of this `lookup` too. `lookup` also lets us traverse the tree forwards and backwards without explicit backedges in our [rose tree](https://en.wikipedia.org/wiki/Rose_tree) -- further simplifying the `Ktree.t` implementation.

<a href="transition-handler"></a>

### Transition Handler

The transition handler is broken down into two main components: Validator and
Processor

#### Validator

- Input: `External_transition.t`
- Output: `External_transition.t` (we should consider making an
  `External_transition.Validated.t` for output here)

The validator receives as input external transitions from the network and
performs a series of checks on the transition before passing it off to be
processed. For simplicity it can also receive transitions created by the local
proposer. In the future, we can consider skipping this step.

Particularly, we validate transitions with the following checks (in this order):

1. Checking for existence in the breadcrumb tree (we've already seen it)
2. Checking for consensus errors
3. Verifying the included SNARK

This order is chosen because it's cheaper computationally to perform (1) and
(2). So if we get lucky we can short-circuit before getting to the SNARK step.

We also should rebroadcast validated transitions over the network to our
neighbors.

#### Processor

- Input: `External_transition.t` (from validator) and `Breadcrumb.t list` (from catchup)
- Outputs: `External_transition.t` (to ledger catchup); modifying transition frontier

The processor receives a single validated external transitions from the
validator and then attempts to add the transition to the breadcrumb tree. The
processor is the only "thread" allowed to write changes to the
[Transition Frontier](#transition-frontier). All other threads must delegate to
the processor.

[Ledger Catchup](#ledger-catchup) needs to add a batch of transitions all at
once, so it shares some of the add section and constructs the underlying
breadcrumbs in such a way that only requires adding to transition frontier's
table and not applying an staged-ledger-diffs.

#### Adding to Transition Frontier

The add process runs in two phases:

1. Perform a `lookup` on the `Transition_frontier` for the previous `State_hash.t` of this transition. If it is absent, send to [catchup scheduler](#catchup-scheduler). If present, continue.
2. Derive a mask from the parent retrieved in (1) and apply the `Staged_ledger_diff.t` of the breadcrumb to that new mask. See [Transition Frontier](#transition-frontier) for more.
3. Construct the new `Breadcrumb.t` from the new mask and transition, and attempt a true mutate-add to the underlying [Transition Frontier](#transition-frontier) data.

<a href="catchup-scheduler"></a>

#### Catchup Scheduler

The catchup scheduler is responsible for waiting a bit before initiating a long
catchup job. The idea here is to mitigate out-of-order messages since it is much
quicker to avoid such catchups if possible. This will be a module that waits on
a small timeout before yielding to the ledger catchup component. And can be
preempted by some transition/breadcrumb that allows this transition to be
connected to the existing tree.

<a href="transition-frontier"></a>

### Transition Frontier

The Transition Frontier is essentially a root `Breadcrumb.t` with some
metadata. The root has a merkle database corresponding to the snarked ledger.
This is needed for consensus with proof-of-stake. It then has the first mask
layer exposing the staged-database and staged-ledger for the locked-tip. Each
subsequent breadcrumb contains a light-weight staged-ledger with a masked
merkle database built off of the breadcrumb prior. We store a hashtable of
breadcrumb children and keep references to the root and best-tip hashes (which
we can lookup later in the table).

It's two orders of magnitude more computationally expensive to constantly
coalesce masked merkle databases in the worst case than to just keep them
separated (back of napkin math). Moreover, we are able to in $O(1)$ time answer
sync ledger queries if we have staged ledgers at every position.

<a href="ledger-catchup"></a>

### Ledger Catchup

Input: `External_transition.t` (from catchup scheduler)
Output: `Breadcrumb.t list` (to processor)

Ledger catchup runs a single catchup worker job at a time. Whenever catchup
scheduler decides it's time for a new catchup job to start, it will send
something on the pipe.

#### Catchup worker

A worker is responsible for performing a history sync.

In the future, we will support multiple catchup workers at once. This prevents
a potential DoS attack where we're forced to catchup between two different forks
and can never complete anything.

New jobs handed to the same worker cause a retargeting action where we don't
throw out existing data, but start again getting data from the source.

<a href="history-sync"></a>

#### History Sync

History sync is a new process that is not yet implemented in the current
ledger-builder-controller.

`history_sync transition` asynchronously walks backwards downloading each
external transition until either (1) it reconnects with some existing breadcrumb
or (2) it passes the locked slot without reconnecting. In either case, we then
walk forwards doing `Path_traversal` logic materializing masked staged-ledgers
all the way up the path. The materialized breadcrumb list gets sent to the
processor.

The details of this download process are TBD. It will likely make sense to ask
for a manifest of locations for the transitions all at once and to do some sort
of torrenting solution. In the short term, we'll just naively download one
transition at a time.

If we do pass the locked slot without reconnecting, we need to perform an
additional step of invoking the sync ledger process.

#### Post Attachment

We may receive additional external transitions that would connect to the
existing catchup job in process. Rather than dropping those we can buffer
them in a post-attachment pool. When a catchup job finishes we can dispatch
a post attachment job that can breadcrumbify these transitions.

This should not block catchup breadcrumbs from being added to the
transition-frontier, however.

<a href="query-handler"></a>

### Query Handler

Input: Sync ledger queries (from network); history sync queries (from network)
Output: Sync answers; history answers

The query handler is responsible for handling sync ledger queries and history
sync queries coming from other nodes performing catchup. This component reads
state from the transition frontier in order to answer the questions. Given the
new underlying data structure, all answers will occur in $O(1)$ time.

<a href="async-control-flow"></a>

### Async Control Flow

As part of this redesign we've carefully considered the asynchronous control
flow of the full system in an attempt to make it very easy to trace data flow.

Consult the following diagram:

![](../docs/res/transition_frontier_controller.dot.png)

Blue arrows represent pipes and asynchronous boundaries of the system. Each
arrow is annotated with the behavior when overflow of the pipe occurs.

- `exception` means raise an exception if pipe buffer overflows (`write_exn`)
- `blocking` means push back on a deffered if the buffer is full (`write`)
- `drop old` means the buffer should drain oldest first when new data comes in

Red arrows represent synchronous lines of access. Red components represent data
and not processes.

### Non-synchronous modification of the Transition Frontier

This will be fleshed out here later, or in a separate RFC. @bkase has thought
about this, but we're not prioritizing this yet. This is required to prevent
against an adversary forcing us to switch between catching up of two forks. Always preempting and cancelling one another.

## Drawbacks

[drawbacks]: #drawbacks

This will take a decent amount of engineering time to implement. Additionally,
this design does not consider persisting parts of the frontier to disk.

We are moving away from a functional representation of the underlying ktree to a
mutable one. This will require more careful managing of changes to the tree.
However, since we are taking care to think carefully about asynchronous
processes we shouldn't have a problem here.

## Rationale and alternatives

[rationale-and-alternatives]: #rationale-and-alternatives

The main rationale for doing this redesign is to ease the difficulty of
debugging asynchronous control. And to avoid debugging all the edge-cases
we've never explored in the existing ledger-builder-controller (what happens in
the presense of particular looking forks).

One alternative is to instead prioritize in investing in debugging
infrastructure such as visualizations and logging tooling to get through these
asynchronous bugs. However, we will need to do a medium-sized refactor anyway to integrate the
merkle masks properly and the new correct history catchup anyway, so we're not
actually saving much work.

This seems to be a good point to do a full-rewrite given that we have these new
components we wish to hook in and we also are running into debugging issues and
new bugs.

## Prior art

[prior-art]: #prior-art

The main piece of prior art is the existing Ledger-builder-controller
component. Ledger-builder-controller as is supports the same external interface
and a lot of similar behavior, but in a more adhoc way. The existing
ledger-builder-controller handles incoming transitions by spawning one of two
types of asynchronous jobs, a catchup and a path traversal. As a short-cut,
catchup did not differentiate between the "from nothing" case and the "small
miss" case, and was vulnerable to an attack. Path traversal was the process of
materializing a staged-ledger along a path in the ktree. This had to be
asynchronous because we didn't yet have a notion of a masked ledger. The
ledger-builder-controller kept only one async job running at a time for
simplicity as well, and only cancelled in-progress jobs when another should
replace the existing one. Upon the completion of a job, the
ledger-builder-controller would replace it's ktree and update annotated tip
entities that have materialized staged-ledgers in them.
Ledger-builder-controller also handled sync-ledger answers as it had to access
the path traversal logic and the current transition logic state.

This component grew organically and did not have any rigorous design
thought put behind it as we did not realize how central such a component would
be in our system until it was too late.

Moreover, we did not think carefully about the flow of information through this
component and the implications of various async points from getting backed up.

The bits we'll keep: We have separate and well-unit-tested component for the
`ktree` and have some decent integration-esque tests around the
ledger-builder-controller as a whole that we should be able to mostly reuse.
We're also reusing the only-one-at-a-time shortcut for our async jobs for now.

## Unresolved questions

[unresolved-questions]: #unresolved-questions

### High-throughput

If we want to support throughput higher than ~10tps we'll need to change
breadcrumb storage to be backed by some sort of disk-backed store.

This is not expected to be resolved before landing this RFC.

### History catchup

We do not specify the mechanism by which efficient downloading should occur.
This is a performance optimization and can be implemented later. We plan on
postponing implementation of this component as long as possible. If everything
is working properly, nodes in integration tests and test networks will not need
this function unless they are late joiners.

### Miscellanea

The implementation of this feature before the first merge will omit the mutable
transition frontier implementation (if we can pass integration tests by wrapping
the existing ktree)
