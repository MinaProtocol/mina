## Summary

We propose a regime for ban scoring to supplement the ban mechanism
proposed in RFC 0001-blacklisting. We take Bitcoin's scoring mechanism
as a starting point, since the Bitcoin network is subject to many of the
same transgressions as the Coda network.

## Motivation

There are several points in the code marked *TODO:punish*, but to
date, there hasn't been a systematic review of how the behaviors at
those points should contribute to ban scoring. A good scoring system
should minimize the bad effects of malicious or buggy nodes, while
allowing honest nodes to remain active in the network.

## Detailed design

# Bitcoin

In Bitcoin, certain kinds of misbehavior increase a node's ban score.
If a nodes score exceeds a threshold, by default equal to 100, the
node is banned from the network. A node can be whitelisted, exempting
it from such banning.  A node can also be manually blacklisted even in
the absence of observable misbehavior.

In the Bitcoin C++ implementation, there's an API "Misbehaving" to
increment the ban score, and set a ban flag if the score exceeds the
threshold. In some cases, the ban score is incremented by a fixed
amount. In other cases, the score is incremented by the value of a
"DoS" value associated with a peer. There's a separate API for
incrementing the DoS value when rejecting a transaction.

At the time of writing (commit d6e700e), the Misbehaving API is called for certain
behaviors with fixed ban score increments. These behaviors have a score of 100,
resulting in an immediate ban:

- invalid block, invalid compact block, nonmatching block transactions
- invalid Bloom filter version, too-large Bloom filter,
- too-large data item to add to Bloom filter, add to missing Bloom filter
- invalid orphan tx, out-of-bounds tx indices

One misbehavior has a score of 50:

- message too large for buffer

For a score of 20:

- too many unconnecting headers
- too-big message "addr", "inventory", or "getdata" message sizes
- too many headers, non-continuous headers

And a score of of 1:

 - missing "version" or "verack" messages, duplicate "version" message

In several places in the code, the "DoS" value is checked, and if
positive, it's added to the ban score.  The DoS score can be
incremented when a transaction is rejected. Many reasons for rejecting
a transaction add 100 to the DoS value (too many to enumerate
here). Those include items like transaction fees out of range, missing
or already-spent inputs, incorrect proof of work, and an invalid
Merkle root.

Some reasons for rejecting a transaction increment the DoS value a
lesser amount. For instance, and invalid hash such that the proof of
work fails, increments DoS by 50. A previous-block-not-found rejection
increments DoS by 10. In several cases, transactions are rejected, but
the DoS is not incremented, such as the "mempool-full" condition.

# Coda at the moment

Bitcoin is a mature codebase, so there are many places where ban scoring has been
used. Nonetheless, Bitcoin uses a relatively coarse ban scoring system; only
a few ban score increment values are used. In Coda, we could reify scores into a
datatype:

```ocaml
  module Ban_score = struct
    type t =
        | Severe
	| Moderate
	| Trivial
  end
```
A slightly finer gradation could be used, if desired. The blacklisting system
could translate these constructors into numerical scores. Let's call these
constructors SEV, MOD, and TRV.

In a number of places, the Coda codebase has comments indicating that
a peer should be punished, either via a `TODO` or call to `Logger.faulty_peer`.
Let's classify those places where punishment has been flagged, and annotate
them with suggested constructors:

- in `bootstrap_controller.ml`, for bad proofs (SEV), and a validation error when
    building a breadcrumb (SEV)
- in `coda_networking.ml`, when an invalid staged ledger hash is received (SEV), or
    when a transition sender does not return ancestors (MOD)
- in `ledger_catchup.ml`, when a root hash can't be found (SEV), or a peer returns an empty list
    of transitions (instead of `None`) (TRV)
- in `linked_tree.ml`, for peers requesting nonexistent ancestor paths (MOD)
- in `parallel_scan.ml`, in `update_new_job` for unneeded merges (?) (SEV)
- in `staged_ledger.ml`, when a bad signature is encountered when applying a pre-diff (SEV)
- in `syncable_ledger.ml`, in `num_accounts`, when a content hash doesn't match a stored root hash (SEV),
    and in `main_loop`, when a child hash can't be added (MOD)
- in `catchup_scheduler.ml` and `processor.ml`, when a breadcrumb can't be built from a
    transition (SEV) (same failure as in `bootstrap_controller.ml`, above)
- in `ledger_catchup.ml`, a transition could not be validated (SEV)
- in `transaction_pool.ml`, a payment check fails (SEV)

At these points in the code, the blacklist API would be called with these constructors. The
API should take a severity argument and a string indicating the nature of the
bad behavior.

## Drawbacks

A banning system in necessary to preserve the integrity of the
network. The only drawback would be if the system is ineffective.

In this RFC, we don't consider how to make the ban scoring persistent,
which will be required, since nodes stop and re-start.

## Rationale and alternatives

The locations in the code mentioned above are only those already
flagged with `TODO` or `faulty_peer`. There may be other code
locations where punishment is warranted.

In the current code, there are often calls to the logger where
punishment is mentioned in a `TODO`.  There could be an API that calls
the logger and the blacklist API, to guarantee there's an inspectible
history leading to a ban score.

## Prior art

There is existing code in Coda to maintain a set of peers banned by IP address.

See the discussion above of how Bitcoin computes ban scores.

RFC-0010 mentions a trust scoring system, where bad behavior decrements trust, but positive
behavior increases trust. The ban scoring system here only mentions bad behavior, but could
be integrated with a trust system.

## Unresolved questions

- Is there a principled way to decide the severity of transgressions by peers?
- Can a peer too-easily circumvent the system?
- What are the numerical values associated with the constructors above?
- What is the ban threshold?
