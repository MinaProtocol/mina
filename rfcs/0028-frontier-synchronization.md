## Summary
[summary]: #summary

This RFC proposes a new access system for the transition frontier, designed to ensure that transition frontier reads are safe from race conditions that cause various pieces of state tied to the transition frontier to desynchronize.

## Motivation
[motivation]: #motivation

We have recently identified a few (>1) bugs in our code related to desynchronization of the frontier's breadcrumbs, the frontier's persistent root, and the frontier's extensions. These bugs are caused by the fact that the current frontier's interface synchronously and immediately access the frontier's data structure, even if we may be in the middle of updating the frontier. Similarly, arbitrary reads of extensions may have a similar issue in that the frontier may have just been updated but the extensions have not been fully updated yet. This is a systemic issue in the code base, not something that should be fixed on a case by case basis, so a mild reworking of the frontier logic is required to address it not just now, but into the future as well.

## Detailed design
[detailed-design]: #detailed-design

This design centers around a new synchronization cycle for the frontier which creates a sort of read/write lock system around the contents of the frontier. Additionally, some extra improvements are made around references to data that is inside (or related to) the frontier's state, so as to bugs in later accesses of data structures read from the frontier.

#### Diagram

![](res/frontier_synchronization.conv.tex.png)

#### Frontier Synchronization Cycle

While the frontier is active, there is a single "thread" (chain of deferreds) which runs through a synchronization cycle for the frontier. The algorithm for this cycles goes:

1. Execute all reads available. Continue executing reads until a write is available.
2. Execute a single write from the write queue. This step can be done in parallel to executing reads in #1, but once a write is being processed, no more reads should be added to the current batch.
3. Once all the deferreds in #1 resolve, transmute the write action returned by the write deferred into a list of diffs
4. Apply all the diffs from #2 to the full frontier
5. Write the diffs from #2 into the persistent frontier sync diff buffer asynchronously
6. Update each frontier extension with the diffs from #2
7. Notify frontier extension subscribers of any frontier extension changes

#### Full/Partial Breadcrumbs + Any Refs

The new synchronization cycle addresses synchronization issues between the state of the full frontier datastructure, the persistent root database, and the transition frontier extensions, but there is still a remaining synchronization issue regarding breadcrumbs. Reading breadcrumbs from the transition frontier is synchronized within the new synchronization cycle, but staged ledger mask accesses cannot be sanely synchonized within that same cycle. In order to address this issue, breadcrumbs are now separated into two types: full breadcrumbs (which contain staged ledger's with masks attached to the frontier's persistent root, directly or indirectly) and partial breadcrumbs (which only contain the staged ledger's scan state and not the full data structure with the mask). Reading a breadcrumb from the frontier will return neither a full or partial breadcrumb, but instead will return a `Breadcrumb.Any.Ref.t`, which is a reference to either a full or partial breadcrumb. This value can be safely passed back from outside the `'a Transition_frontier.Read.t` monad and the "staged state" (either the staged ledger or scan state depending on the status of the breadcrumb) can be safely queried at an arbitrary time in the future. The downside of this technique is that only immediate (and synchronous) reads from the breadcrumb's staged ledger mask are safe under this interface, disallowing certain actions. For instance, under this system, it is not safe to use a breacrumb's staged ledger mask as a target for the syncable ledger (which probably isn't safe anyway for other reasons).

#### Detached Mask State Management

In the current system, when a mask is destroyed, all of it's children masks are also destroyed. Masks will now additionally provide the ability to attach "destruction hooks". This will be used to cleanup full breadcrumbs and downgrade them to partial breadcrumbs if the breadcrumb's parent mask chain becomes inaccessible. This allows code outside of synchronized frontier reads to continue to query breadcrumbs from the frontier and build successor breadcrumbs off of them safely. This is important in the context of catchup since new subtrees of breadcrumbs are built asynchronously to the frontier being updated. If a subtree is built off of a breadcrumb which is later removed from the frontier (thus having it's mask destroyed), then that subtree will subsequently be marked as partial and any masks in it will be destroyed and inaccessible.

IMPLEMENTATION NOTE: The entire chain of mask destruction hooks needs to be executed synchronously within a single async cycle in order to update breadcrumb subtrees without fear of race conditions.

#### Frontier Read Monad

A new monad is introduced for specifying reads from the transition frontier (see [alternatives section](#alternatives) for explanation on why). All existing read functions on the transition frontier will instead by turned into functions which do not take in a transition frontier and return a result wrapped in the `'a Transition_frontier.Read.t` monad. This monad is used to build up a list of computations which will be performed during the read phase. The monad is designed to interact with deferreds so that async programming is still accessible during reads when necessary.

#### New Frontier Interface

Below is a partial signature for what the new transition frontier interface would look like. Note that all base read/write functions from the transition frontier are removed, and instead, only the read monad and write actions are accessible. The only way to interact with the transition frontier thus becomes the `read` and `write` functions.

```ocaml
module Transition_frontier : sig
  module Breadcrumb : sig
    module Full : sig
      type t
      val block : t -> Block.Validated.t
      val staged_ledger : t -> Staged_ledger.t
    end

    module Partial : sig
      type t
      val block : t -> Block.Validated.t
      val scan_state : t -> Transaction_snark_scan_state.t
    end

    type full
    type partial

    type 'typ t =
      | Full : Full.t -> full t
      | Partial : Partial.t -> partial t
    type 'typ breadcrumb = 'typ t

    val external_transition : t -> External_transition.Validated.t

    module Any : sig
      type t = T : _ breadcrumb -> t
      type any = t

      val wrap : _ breadcrumb -> t

      module Ref : sig
        (* intentionally left abstract to enforce synchronous access *)
        type t

        val wrap : any -> t
        (* downgrades a full to a partial; returns error if already a partial *)
        val downgrade : t -> unit Or_error.t

        val external_transition : t -> External_transition.Validated.t
        val staged_state :
             t
          -> [ `Staged_ledger of Staged_ledger.t
             | `Scan_state of Transaction_snark_scan_state.t ]
      end
    end
  end

  module Extensions : sig
    type t

    (* ... *)
  end

  module Read : sig
    include Monad.S

    (* to wrap computations in the monad *)
    val deferred : 'a Deferred.t -> 'a t

    val find : State_hash.t -> Breadcrumb.Any.Ref.t option t

    (* necessary extension access will be provided here, Extensions.t will not be directly accessible here *)

    (* ... *)
  end

  type t

  (* Actions are representations of mutations (writes) to perform on
   * the frontier. There is only one action that can be performed on
   * a frontier right now, adding breadcrumbs, but we can add either
   * a single breadcrumb, or a subtree of breadcrumbs. Future actions
   * can also be added as needed *)
  type action =
    | Add_breadcrumb of Breadcrumb.Full.t
    | Add_subtree of Breadcrumb.Full.t Rose_tree.t

  val read :
       t
    -> f:('a Read.t)
    -> 'a Deferred.t

  val write :
       t
    -> f:(Action.t Read.t)
    -> unit Deferred.t
end
```

#### Usage Notes

It's important that computations described in `'a Read.t` monad need to be short (in terms of execution time). Having long cycles ocurr when handling reads or writes will have a significant effect on the overall delay for updating the frontier. As such, code should be designed to return whatever values you want from the `'a Read.t` monad as early as possible, and to continue using those values outside of calls to `Transition_frontier.read`.

## Drawbacks
[drawbacks]: #drawbacks

- current design does not address breadcrumb specific desync bugs fully
- adds more complexity overhead to all frontier interactions
- will have performance impact on the speed at which we update the frontier
- may open up new vectors for adversarial DDoS attacks
  - for instance, adversary selectively delays rebroadcasting blocks to target, then triggers multiple catchups (enqueuing many writes at once when the catchups jobs finish), and then flood the target read requests to make the writes as slow as possible (all this combined could take the target's stake offline for a period of time)
- places new importance on reads being short (ideally synchronous) operations
- read monad needs to be updated to expose new read functionalities for extensions
  - preferrably, adding new extensions or functions to access extensions would not require changes to the read monad to expose them, but without higher kinded types, it's can't be done in a reasonable way
    - e.g. w/ generalized polymorphic variants, extension ref type could be `type 'intf extension = ... constraint 'intf = _ [> ]` and then the function to access could be `val read_extension : ('result 'intf) extension -> 'result 'intf -> 'result t` and could be read like `let%bind x = read_extension Root_history (`Lookup y) in ...`

## Alternatives
[alternatives]: #alternatives

#### Full Breadcrumb Pool + Ledger Mask Locks

An alternative approach to mask destruction hooks which downgrade subtrees of full breadcrumbs as necessary would be to maintain a ref counted pool of full breadcrumbs which lock the ledger masks they control. This would require adding backwards chaining (copy on write) as a capability to masks as the frontier would need to support masks which are behind the persistent root. This method could also easily introduce memory leaks.

#### Alternative Misread Protection (no read monad)
[alternative-misread]: #alternative-misread

To protect against misreads, all reads have to be expressed in a monad (`'a Transition_frontier.Read.t`). The `Transition_frontier.read` function interprets this monad when the read is performed.

An alternative approach would be to have a `Transition_frontier.Readable.t` type which and have the type signature of `Transition_frontier.read` be `t -> f:(Readable.t -> 'a Deferred.t) -> 'a Deferred.t`. Every instance of `Readable.t` will be uniquely created for each pass of reads. When the pass of reads completes, the `Readable.t` instance will be marked as "closed". If any reads are attempted on a `Readable.t` instance, a runtime exception will be thrown. This helps prevent code like the following from being written:

```ocaml
let open Deferred.Let_syntax in
let%bind readable = Transition_frontier.read frontier ~f:(fun r _ -> return r) in
(* ... *)
```

But, the cost of this strategy is that misuse of the interface will cause runtime exceptions. As such, while the monad is slightly more complex, it is worthwhile to avoid the possible bugs that can be introduced by misunderstandings.

#### Alternative Read Monad Design

The read monad interfaces with `'a Deferred.t` computations by providing the function `val deferred : 'a Deferred.t -> 'a t`. This allows the monad to mix both non-deferred and eferred computations, reducing the task scheduling overhead (and thus the overall delay caused by reads) at the cost of making the code a bit uglier. A prettier way to do this would be to give the bind (and map) functions for the `'a Read.t` monad a type signature like `'a Deferred.t Read.t -> f:('a -> 'b Read.t Deferred.t) -> 'b Deferred.t Read.t`. I think the overall cost of having every segment of the `'a Read.t` monad computations be put into their individual async scheduler job cycles to be not worth this minor change in the DSL.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- Brought up by @cmr: should queue reads be bucketed by most recent write at the time of the read call?
  - For instance, say some write (WA) is the most recently enqueue write. We enqueue 2 reads, (RA) and (RB), then another write, (WB), and some more reads, (RC) and (RD). Only reads (RA) and (RB) would trigger when write (WA) is handled, and reads (RC) and (RD) would not trigger until after (WB) is handled.
- Is the write queue necessary? How does it interact with the current architecture of the Transition Frontier Processor? The Processor already acts as a write queue, with more logic in place for how to write.
