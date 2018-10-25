(* maskable_merkle_tree_intf.ml *)

(** the type of a Merkle tree that can have associated mask children *)
module type S = sig
  include Base_merkle_tree_intf.S

  type unattached_mask

  type attached_mask

  (* registering a mask makes it an active child of the parent Merkle tree 
     - reads to the mask that fail are delegated to the parent
     - writes to the parent notify the child mask
   *)

  val register_mask : t -> unattached_mask -> attached_mask

  val unregister_mask_exn : attached_mask -> unattached_mask
  (** raises an exception if mask is not registered *)
end
