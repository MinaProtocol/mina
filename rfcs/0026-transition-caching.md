# Transition Caching

## Summary
[summary]: #summary

A new transition caching logic for the transition router which aims to track transitions which are still being processed as well as transitions which have failed validation.

## Motivation
[motivation]: #motivation

Within the transition router system, the only check for duplicate transitions is performed by the transition validator, and each transition is only checked against the transitions which are currently in the transition frontier. However, there are two types of duplicate transitions which are not being checked for: transitions which are still being processed by the system (either in the processor pipe or in the catchup scheduler and catchup thread), and transitions which have been determined to be invalid. In the case of the former, the system ends up processing more transitions than necessary, and the number of duplicated processing increases along with the networks size. In the case of the latter, the system is opened up for DDoS attacks since an adversary could continuously send transitions with valid proofs but invalid staged ledger diffs, causing each node to spend a significant enough amount of time before invalidating the transition each time it recieves it.

NOTE: This RFC has been re-scoped to only address duplicate transitions already being processed and not transitions which were previously determined to be invalid.

## Detailed design
[detailed-design]: #detailed-design

The goal here is to introduce a new cache to the system: the `Unprocessed_transition_cache`.

`Unprocessed_transition_cache` is scoped explicitly to the `Transition_frontier_controller`. The set stored in this cache represents the set of transitions which have been read from the network but have not yet been processed and added to the transition frontier. Since the lifetime of elements in the set are finite, the `Unprocessed_transition_cache` can be represented as a hash set. It will be the responsibility of the transition validator to add items to this cache, and the responsibility of the processor to invalidate the cache once transitions are added to the transition frontier. Transitions which are determined to be invalid need to also be invalidated.

In order to assist in ensuring that items in the cache are properly invalidated, I recommend the introduction of a `'a Cached.t` type which will track the state of the item in one or more caches. The `Cached` module would provide an interface for performing cache related actions and would track a boolean value representing whether or not the required actions have been performed. What's special about the `'a Cached.t` type is that it will have a custom finalization handler which will throw an exception if no cache actions have been performed by the time it is garbage collected. This exception is toggled by a debug flag. When the debug flag is off, the finalization handler will nearly log a message.

## Drawbacks
[drawbacks]: #drawbacks

- Proper cache invalidation is difficult to maintain full state on. Hopefully the `Cached` abstraction will be enough to alleviate this pain.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- This cachs is small and simple in its scope scope.
- `Cached` enforces that our architecture correctly invalidates the `Unprocessed_transition_cache`, avoiding cache leaks.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- `Cached` will throw errors only at run time. Perhaps a GADT would be better, but I'm unsure how to model this in a way with a GADT that would 100% assert that we perform some kind of cache action.
