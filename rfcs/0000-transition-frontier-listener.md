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

This design is based on the introduction of a new signature in `Protocols.coda_transition_frontier` as follows.:
```ocaml
module type Transition_frontier_listener_intf = sig
  type t
  val add_breadcrumb : t -> Breadcrumb.t -> unit;
  val remove_breadcrumb : t -> Breadcrumb.t -> unit;
end
```

The transition frontier would then expose a function for registering listeners. We probably have to do some sort of GADT/ first-class module magic to make this work (???)
```
val add_frontier_listener : (module Transition_frontier_listener_intf with type t = 'a) -> 'a -> unit
```
The transition frontier will call `add/remove_breadcrumb` on everything in the list of registered listeners
whenever it adds or removes a breadcrumb from the frontier (in `Transition_frontier.add_breadcrumb_exn`).

In the example of the snark pool reference count, the snark pool itself could implement the `add/remove_breadcrumb` functions.
The `add_breadcrumb` would get all the `Work` from the breadcrumb and increment the references for each of them.
In `remove_breadcrumb`, they would be correspondingly decremented. When the reference count for a given piece of
`Work` goes to zero, its entry in the table of snark proofs can also be removed.

For other pieces of data that may need to be accessed from many components, the `Mvar` containing the transition frontier
could be changed to contain a record with the frontier as well as several widgets that implement the "listener" signature
in order to keep themselves up to date.

## Drawbacks
[drawbacks]: #drawbacks

  - This API more or less assumes that `Transition_frontier_listener_intf.t` is mutable. In the case of the snark pool refcount, this seems to be alright.
  - If the `add/remove_breadcrumb` are slow, this could slow down the transition frontier.
  - Adding the calculation to the frontier itself would avoid adding an abstraction, though this listener is fairly simple as described.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

  - Alternative: Calculate values on-demand by iterating over all transitions in the frontier -- this is more expensive
  - Alternative: Add incremental calculation to the transition frontier itself -- this adds unrelated complexity to the frontier code
  - This design allows for more data to be incrementally calculated based on activity in the transition frontier
  while adding minimal complexity to the frontier itself.
  
  An alternative implementation of this "Listener" solution would have the transition frontier hold a list of listener functions that have signature `Breadcrumb.t -> unit`, so the `t` is embedded in the closure of the listener. This is much simpler from a types perspective but may be less clear/explicit.

## Prior art
[prior-art]: #prior-art

  - The old `Ledger_builder_controller` was more complex than the current transition frontier design, and we'd
  like to avoid adding more complexity to this component.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

  - Should the listener also support a `clear/destroy` call for when the transition frontier is thrown away/reset/synced? We assume that the only way to create a transition frontier is to create an empty one and then fill it by adding breadcrumbs.
  - Potentially out of scope of this listener api RFC, but in the snark pool manager, it is unclear how to obtain the work from the breadcrumb, and how important it is to get all future work from a breadcrumb rather than just the available work.
  - In the snark pool garbage collection case, do we want to remove from the pool when a breadcrumb pointing at the data leaves the transition frontier completely, or just when it ceases to be a leaf? If the latter, we may need to rethink when the `remove_breadcrumb` fires, or add a third function.
