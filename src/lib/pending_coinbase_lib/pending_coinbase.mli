(*module type S = sig

  module Ordered_collection = Sparse_ledger_lib.Sparse_ledger.Make
    (*type 'a t
    [@@deriving eq]
  
    val modify : 'a t -> Index.t -> ('a -> 'a) -> 'a t
  end = ...*)
  
  module Stack : sig
    type 'a t
    [@@deriving eq]
  
    val push : 'a t -> 'a -> 'a t
  end (*= struct
    type 'a t = Pedersen.Digest.t
  
    let equal = Pedersen.Digest.equal
  
    let push t x = hash (to_bits t @ to_bits x)
  end*)
  
  module T : sig
    type t
    (* semantics: multiset of (Public_key.t * Amount.t) *)
  
    val push
      : t -> 'a -> t
    (* semantics: multiset add *)
  
    val subtract
      : t -> t -> t
    (* semantics:
      multiset subtraction, failing if the second argument is not a subset of
      the first. *)
  
    val to_bits
      : t -> bool list
    (* This is just for hashing. The only semantics are that this function should
       be semantically injective *)
  end (*= struct
    type t = Pedersen.Digest.t Ordered_collection.t
  
    let push t elt =
      (* Actually, the index can also be computed correctly. *)
      let index = exists Index.typ in
      Ordered_collection.modify t index (fun s -> Stack.push s elt)
  
    (* This is more complicated and dependent on the implementation of Ordered_collection *)
    let subtract = ...*)
  end*)
