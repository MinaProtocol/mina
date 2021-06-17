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

  (** raises an exception if mask is not registered *)
  val unregister_mask_exn :
       ?grandchildren:
         [ `Check | `Recursive | `I_promise_I_am_reparenting_this_mask ]
    -> loc:string
    -> attached_mask
    -> unattached_mask

  (**
   *              o
   *             /
   *            /
   *   o --- o -
   *   ^     ^  \
   *  parent |   \
   *        mask  o
   *            children
   *
   * Removes the attached mask from its parent and attaches the children to the
   * parent instead. Raises an exception if the merkle roots of the mask and the
   * parent are not the same.
  *)
  val remove_and_reparent_exn : t -> attached_mask -> unit

  module Debug : sig
    val visualize : filename:string -> unit
  end
end
