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

We'd like to have a way for other parts of the system to incrementally build up datastructures based on events that are happening in the frontier.

Other uses for such an abstraction:
  - managing the transaction pool
  - tracking information for consensus optimization
  - Handling persistence for the transition frontier

## Detailed design

[detailed-design]: #detailed-design

This design is based on the introduction of the following event type to `Protocols.coda_transition_frontier`:
```ocaml
module Transition_frontier_diff = struct
  type 'a t =
    (* Added a node to the existing best tip without creating a new root *)
    | Extend_best_tip of 'a
    (* Added a node to the a new best tip without creating a new root *)
    | New_best_tip of {old_best_tip: 'a; new_best_tip: 'a}
    (* If triggered by a new best tip, the old one will be in old_best_tip *)
    | New_root of
        { old_root: 'a
        ; new_root: 'a
        ; added: 'a
        ; garbage: 'a list
        ; old_best_tip: 'a option }
    | Destroy
end
```

`Transition_frontier` is split into `Transition_frontier0`, which does all core Transition_frontier logic (everything that `Transition_frontier` used to do), and a new `Transition_frontier`, which wraps `Transition_frontier0`, and adds handling for the extensions. The new `Transition_frontier` will call `handle_diff` on all extensions whenever a frontier diff event (defined above) is triggered by `add_breadcrumb_exn`.

For instance, in the snark pool example, the reference count could be incremented for all Work referenced by the added breadcrumb when `Extend_best_tip` is triggered, and the reference count for the removed work could be decremented when `New_root` fires.

## Drawbacks
[drawbacks]: #drawbacks

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

  - Potentially out of scope of this listener api RFC, but in the snark pool manager, it is unclear how to obtain the work from the breadcrumb.
