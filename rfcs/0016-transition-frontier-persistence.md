# Transition Frontier Persistence

## Summary
[summary]: #summary

This RFC proposes a new system for persisting the transition frontier's state to the filesystem efficiently.

## Motivation
[motivation]: #motivation

The Transition Frontier is too large of a data structure to just blindly serialize and write to disk. Under non optimal network scenarios, we expect the upper bound of the data structure to be >100Gb. Even if the structure were smaller, we cannot write the structure out to disk every time we mutate it as the speed of the transition frontier data structure is critical to the systems ability to prevent DDoS attacks. Therefore, a more robust and effecient system is required to persist the Transition Frontier to disk without negatively effecting the speed of operations on the in memory copy of the Transition Frontier.

## Detailed design
[detailed-design]: #detailed-design

### Persistent Transition Frontier
[detailed-design-persistent-transition-frontier]: #detailed-design-persistent-transition-frontier

The persistent copy of the Transition Frontier is stored in a RocksDB database. Overall, the structure is similar to that of the full in memory Transition Frontier in that the data for each state is stored in a key value fashion where the key is the protocol state hash of that state. However, the persistent version does not store as much information at each state as the in memory one. In particular, the in memory data structure stores a staged ledger at each state, but this takes a lot of space and can be recomputed from the root if needed. Therefore, each state in the persistent Transition Frontier only needs to store the external transition, along with a single staged ledger scan state at the root state. When the persistent Transition Frontier is loaded from disk, the necessary intermediate data is reconstructed using the staged ledger diffs from the external transitions, the root snarked ledger, and the root staged ledger scan state.

Updates to the persistent Transition Frontier happen in bulk over a time interval. As such, the `Persistent_transition_frontier` module provides an interface for flushing Transition Frontier diffs to the RocksDB database. The details of the mechanism which performs this action are discussed in the next section.

### Transition Frontier Persistence Extension
[detailed-design-transition-frontier-extension]: #detailed-design-transition-frontier-extension

As actions are performed on the Transition Frontier, diffs are emitted and stored in a buffer. More specifically, an extension will be added to the frontier which performs these diff buffering and flushing activities called `Transition_frontier_persistence_ext`. Once the buffer of diffs is either full or a timeout interval has occurred, the `Transition_frontier_persistence_ext` will flush all of its diffs to the `Persistent_transition_frontier`.

### Incremental Hash
[detailed-design-incremental-hash]: #detailed-design-incremental-hash

Having two different mechanisms for writing the same data can be tricky as there can be bugs in one of the two mechanisms that would cause the data structures to become desynchronized. In order to help prevent this, we can introduce an incremental hash on top of the Transition Frontier which can be updated upon each diff application. This hash will give a direct and easy way to compare the structural equality of the two data structures. Being incremental, however, also means that the order of diff application needs to be the same across both data structures, so care needs to be taken with that ordering. Therefore, in a sense, this hash will represent the structure and content of the data structure, as well as the order in which actions were taken to get there. We only care about the former in our case, and the latter is just a consequence of the hash being incremental.

In order to calculate this hash correctly, we need to introduce a new concept to a diff, which is that of a diff mutant. Each diff represents some mutation to perform on the Transition Frontier, however not every diff will contain the enough information by itself to encapsulate the state of the data structure after the mutation occurs. For example, setting a balance on an account in two implementations of the data structure does not guarantee that the accounts in each a equal as there are other fields on the account besides that. This is where the concept of a diff mutant comes in. The mutant of a diff is the set of all modified values in the data structure after the diff has been applied. Using this, we can create a proper incremental diff which will truly ensure our data structures are in sync.

These hashes will be Sha256 as there is no reason to use the Pedersen hashing algorithm we use in the rest of our code since none of this information needs to be snarked. The formula for calculating a new hash `h'` given an old hash `h` and a diff `diff` is as follows: `h' = sha256 h diff (Diff.mutant diff)`.

### Diff Application and Incremental Hash Pseudo-code
[detailed-design-diff-application-and-incremental-hash-pseudo-code]: #detailed-design-diff-application-and-incremental-hash-pseudo-code

Here is some pseudo code which models the `Diff.t` type as a GADT where the parameter type is the type of the mutant the diff returns. This only models a few of the diff types and most likely needs to be updated as this was first drafted before the Transition Frontier Extension RFC landed.

```ocaml
module Diff = struct
  module T = struct
    type 'mutant t =
      | AddAccount : Public_key.Compressed.t * Account.t -> (Path.t * Account.t) t
      | SetHash : Path.t * Hash.t -> Hash.t t
      | SetBalance : Public_key.Compressed.t * Balance.t -> Account.t t
    [@@deriving hash, eq, sexp]
  end

  include T

  module Hlist = Hlist.Make (T)

  let map_mutant
      (diff : 'mutant t)
      (mutant : 'mutant) 
      ~(add_account : Path.t -> Account.t -> 'result)
      ~(set_hash : Hash.t -> 'result)
      ~(set_balance : Account.t -> 'result)
      : 'result
  = fun diff mutant ~add_account ~set_hash ~set_balance ->
    match diff, mutant with
    | AddAccount _, (path, account) -> add_account path account
    | SetHash _, hash -> set_hash hash
    | SetBalance _, account -> set_balance account
end

let apply_diff (t : t) (diff : 'mutant Diff.t) : 'mutant =
  match diff with
  | AddAccount (pk, account) ->
      let path = allocate_account t pk in
      set t path account;
      (path, account)
  | SetHash (path, h) ->
      set t path h;
      h
  | SetBalance (pk, balance) ->
      let path = path_of_public_key t pk in
      let account = Account.set_balance (get t path) balance in
      set t path account;
      account

let update (t : t) (ls : 'a Diff.Hlist.t) : unit =
  Diff.Hlist.fold_left ls ~init:(get_incremental_hash t) ~f:(fun ihash diff ->
      let mutant = apply_diff t diff in
      let diff_hash = Diff.hash diff in
      let mutant_hash =
        Diff.map_mutant diff mutant
          ~add_account:(fun path account ->
              Hash.merge (Path.hash path) (Account.hash account))
          ~set_hash:Fn.id
          ~set_balance:Account.hash
      in
      Hash.merge ihash (Hash.merge diff mutant_hash)
```

## Drawbacks
[drawbacks]: #drawbacks

The primary drawback to this system is that it creates additional complexity in that we have 2 different methods of representing the same data structure and content. This can lead to odd bugs that can be difficult to trace. However, introducing the incremental hash helps to mitigate this issue.

## Prior art
[prior-art]: #prior-art

In the past, before we replaced the Ledger Builder Controller with the Transition Frontier, we would `bin_io` the entire Ledger Builder Controller out to the filesystem on every update. This was slow and wasteful and would have needed to be replaced anyway.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

Is the incremental hash overkill? Could we restructure the diffs such that the `diff_mutant` is not required for hashing? Is there something else we can do that doesn't tie the order of diff application to the value of the hash?
