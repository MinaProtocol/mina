(* maskable_merkle_tree_intf.ml *)
(* the type of a Merkle tree that can have associated mask children *)

module type S = sig
  include Base_merkle_tree_intf.S

  module Masking_tree :
    Masking_merkle_tree_intf.S
    with type location := location
     and type key := key
     and type hash := hash
     and type account := account
     and type parent := t

  (* registering a mask makes it an active child of the parent Merkle tree 
     - reads to the mask that fail are delegated to the parent
     - writes to the parent notify the child mask
   *)

  val register_mask : t -> Masking_tree.t -> unit

  val unregister_mask : Masking_tree.t -> unit
end
