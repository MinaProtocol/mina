## Summary
[summary]: #summary

Allow properties based the transition frontier to be efficiently tracked.

## Motivation

[motivation]: #motivation

There are several properties that we might want to obtain from the data in the transition frontier that
are too expensive to calculate by iterating over all its transitions. However, we don't want to add complexity
to the transition frontier by having it keep track of these values that are not strictly necessary for its
operation and are only used externally.

As an example, the snark pool never has elements removed and requires some system of garbage collection.
One way to do this would be to track a reference count for each piece of `Work` in the table of proofs, but this
table of references probably shouldn't be part the transition frontier itself as it's completely unrelated.

We'd like to have a way for other parts of the system to incrementally build up datastructures based on the
breadcrumbs that are being added and removed to the frontier.

Other uses for such an abstraction:
  - managing the transaction pool
  - tracking information for consensus optimization
  - Handling persistence for the transition frontier

## Detailed design

[detailed-design]: #detailed-design

This design is based on the introduction of the following types to `Protocols.coda_transition_frontier`:
```ocaml
module type Transition_frontier_extension_intf = sig
  type t
  val create : unit -> t
  val handle_diff : t -> Breadcrumb.t -> unit
end

module type Transition_frontier_diff = sig
  type 'a change = {
    new: 'a,
    old: 'a
  }
  
  type 'a t =
    | Add of 'a
    | New_root of 'a change
    | New_best_tip of 'a change
    | Destroy
end

module type Transition_frontier_extensions = sig
  type t = 
  { snark_pool_refcount: Snark_pool_refcount.t
  ; transaction_pool_refcount: Transaction_pool_refcount.t
  ; frontier_persister: Frontier_persister.t
  ... } [@@deriving fields]
end
```

Each of the fields of `Transition_frontier_extensions.t` satisfy the `Transition_frontier_extension_intf` signature.
The transition frontier will hold an instance of `Transition_frontier_extensions.t` and use `Transition_frontier_extensions.Fields.iter` to call `handle_diff` on all fields in 
whenever it adds or removes a breadcrumb from the frontier (in `Transition_frontier.add_breadcrumb_exn`).

In the example of the snark pool reference count, the snark pool would look at `Transition_frontier.t.snark_pool_refcount` to determine whether it should be storing certain proofs from snark workers. The `Add` would get all the `Work` from the breadcrumb and increment the references for each of them. When receiving `Remove`, they would be correspondingly decremented. When the reference count for a given piece of `Work` goes to zero, its entry in the table of snark proofs can also be removed.

## Drawbacks
[drawbacks]: #drawbacks

  - This API more or less assumes that `Transition_frontier_extension_intf.t` is mutable. In the case of the snark pool refcount, this seems to be alright.
  - If the `add/remove_breadcrumb` are slow, this could slow down the transition frontier.
  - Adding the calculation to the frontier itself would avoid adding an abstraction, though this listener is fairly simple as described.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

  - This design allows for more data to be incrementally calculated based on activity in the transition frontier
  while adding minimal complexity to the frontier itself.
  - Alternative: Calculate values on-demand by iterating over all transitions in the frontier -- this is more expensive
  - Alternative: Add incremental calculation to the transition frontier itself -- this adds unrelated complexity to the frontier code
  
  An alternative implementation of this "Listener" solution would have the transition frontier hold a list of listener functions that have signature `Breadcrumb.t -> unit`, so the `t` is embedded in the closure of the listener. This is potentially simpler but less explicit.

## Prior art
[prior-art]: #prior-art

  - The old `Ledger_builder_controller` was more complex than the current transition frontier design, and we'd
  like to avoid adding more complexity to this component.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

  - Potentially out of scope of this listener api RFC, but in the snark pool manager, it is unclear how to obtain the work from the breadcrumb, and how important it is to get all future work from a breadcrumb rather than just the available work.
  - In the snark pool garbage collection case, do we want to remove from the pool when a breadcrumb pointing at the data leaves the transition frontier completely, or just when it ceases to be a leaf? If the latter, we may need to rethink when the `remove_breadcrumb` fires.
