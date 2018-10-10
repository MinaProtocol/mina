# Sparse Account DB Mask

A sparse account db mask is a data structure which enables the ability to arbitrarily "copy" an account db and perform reads/writes without effecting the underlying account db. The sparse account db mask can then be applied back into the account db which it is created from. In order to ensure that sparse account db masks do not leak memory, as new writes trigger in the underlying account db, those writes are propogated into the sparse account db mask in order to invalidate it's representation. For example, if a write sets a value in the underlying account db to be the same as the value in the sparse account db mask, when the hook is called in the sparse account db mask for propogating that change, the sparse account db mask will remove that information from itself since it is now in sync with the underlying account db. Sparse account db masks also have the property that they can be masks representing either an older copy of an account db or a newer copy.

## Goals

- maximally compact memory representation of changes to an account db
- maximally performant queries which propogate to the parent on misses
- composable across any implementation of an account db
- bidirectional (can mask backwards/forwards)

## Implementation

In order to implement this best with static typing, there should be two tables: one for accounts at the bottom of the tree, and one for hashes. Given some path to either a hash or an account (which one must be specified by the interface), the data structure can then lookup the correct table to see if there is an entry or not.

The account table can be implemented as either a `Hashtbl.t` of tree paths (represented as 32 bit integers with the first 30 bits set to represent left/right traversals) to accounts, or as an `Account.t array` where tree paths are mapped into the range by `path mod (float_of_int (2**30))`. While the second one makes some guarantees about distribution, it also makes the clustering of values deterministic, which an adversary may be able to use to their advantage. The hash table can be implemented as a `Hashtbl.t` mapping a tuple of the length and the tree path to intermediate hashes. The tree paths for intermediate hashes need to always have the lower bits (bits after the length) set to 0 so that any two paths always hash the same. This table could also potentially have a custom hash operation into an array, but designing this hash function would be significantly more complex.

(note: I will discuss the hashing stuff with Izzy soon and update this info once a decision is made)

Each account db will need to keep a list of references to child masks. Every mask must keep one reference back to it's parent account db. Whenever writes happen to an account db, it will call a hook in each of it's children masks. This hook will give the mask a chance to garbage collect duplicate information. Each mask needs to propogate this hook to all of it's children so that masks can be chained correctly (it may not need to propogate the hook call if it already garbage collected one of it's own nodes). Whenever a read occurs on a mask for which there is no node stored in the mask, the mask will propogate that read back to it's parent account db.

## Construction

Here is a mock up of the interfaces and the modules involved. This is not a direct representation of how it will end up being implemented in the codebase.

```
module type Merkle_tree0_intf = sig
  module Key : sig
  end

  module Data : sig
  end

  type data_location
  type hash
  type t

  val create : unit -> t

  val data_location_of_key : t -> Key.t -> data_location
  val get_data : t -> data_location -> Data.t option
  val get_hash : t -> Merkle_tree_path.t -> hash
  val set_data : t -> data_location -> Data.t -> unit
end

module Sparse_merkle_tree_mask0 = struct
end

module type Merkle_tree_intf = sig
  include Merkle_tree0_intf

  val register_mask : t -> Sparse_merkle_tree_mask0.t
  val unregister_mask : t -> Sparse_merkle_tree_mask0.t -> unit
end

module Sparse_merkle_tree_mask0 : Merkle_tree_intf = struct
  let mask = ...
end
```
