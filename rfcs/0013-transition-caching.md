# Transition Caching

## Summary
[summary]: #summary

A new transition caching logic for the transition router which aims to track transitions which are still being processed as well as transitions which have failed validation.

## Motivation
[motivation]: #motivation

Within the transition router system, the only check for duplicate transitions is performed by the transition validator, and each transition is only checked against the transitions which are currently in the transition frontier. However, there are two types of duplicate transitions which are not being checked for: transitions which are still being processed by the system (either in the processor pipe or in the catchup scheduler and catchup thread), and transitions which have been determined to be invalid. In the case of the former, the system ends up processing more transitions than necessary, and the number of duplicated processing increases along with the networks size. In the case of the latter, the system is opened up for DDoS attacks since an adversary could continously send transitions with valid proofs but invalid staged ledger diffs, causing each node to spend a significant enough amount of time before invalidating the transition each time it recieves it.

## Detailed design
[detailed-design]: #detailed-design

The goal here is to introduce 2 new caches to the system: the `Invalid_transition_cache`, and the `Unprocessed_transition_cache`.

`Invalid_transition_cache` would be a bloom filter based cache which is updated whenever any form of validation fails on a transition. A bloom filter is a good fit since it remains a constant size while giving a probablistic check to see if an item is in the set or not. A bloom filter can produce false negatives for the existence of an item in the set, but this is considered ok since we are still performing validation on the transition after the `Invalid_transition_cache` is check. The check for this cache would be hoisted up to the toplevel `Transition_router` layer of the transition handling system, as this check is equally shared across both `Bootstrap_controller` and `Transition_frontier_controller`. The `Invalid_transition_cache` should also be persisted to disk. Depending on the cost of writing it to disk, it will either be written out on every update, or written out on an interval.

`Unprocessed_transition_cache` is scoped more explicitly to the `Transition_frontier_controller`. The set stored in this cache represents the set of transitions which have been read from the network but have not yet been processed and added to the transition frontier. Since the lifetime of elements in the set are finite, the `Unprocessed_transition_cache` can be represented as a hash set. It will be the responsiblity of the transition validator to add items to this cache, and the responsibility of the processor to invalidate the cache once transitions are added to the transition frontier. Transitions which are determined to be invalid need to also be invalidated.

In order to assist in ensuring that items in the cache are properly invalidated, I recommend the introduction of a `'a Cached.t` type which will track the state of the item in one or more caches. The `Cached` module would provide an interface for performing cache related actions and would track a boolean value representing whether or not the required actions have been performed. What's special about the `'a Cached.t` type is that it will have a custom finalization handler which will throw an exception if no cache actions have been performed by the time it is garbage collected. This exception is toggled by a debug flag. When the debug flag is off, the finalization handler will nearly log a message.

## Drawbacks
[drawbacks]: #drawbacks

- Proper cache invalidation is difficult to maintain full state on, and this will introduce 2 new caches, which only make that harder. Hopefully the `Cached` abstraction will be enough to alleviate this pain.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- Each of these 2 caches are small and simple in their scope.
- `Cached` enforces that our architecture correctly invalidates the `Unprocessed_transition_cache`, avoiding cache leaks.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- `Cached` will throw errors only at run time. Perhaps a GADT would be better, but I'm unsure how to model this in a way with a GADT that would 100% assert that we perform some kind of cache action.
- Is there an existing bloom filter library we can use, either in OCaml or in Rust?
- Can we properly use a bloom filter on our transition hashes (pedersen hashes)? Or would we need to convert it to integer space or Sha256 the hash or something to bring it into a reasonable scope?
