(* maskable_merkle_tree_intf.ml *)

(** the type of a Merkle tree that can have associated mask children *)
module type S = sig
  include Base_merkle_tree_intf.S

  type unattached_mask

  type attached_mask

  type accumulated_t

  type maps_t

  val append_maps : attached_mask -> maps_t -> unit

  val get_maps : attached_mask -> maps_t

  (* registering a mask makes it an active child of the parent Merkle tree
     - reads to the mask that fail are delegated to the parent
  *)

  val register_mask :
    ?accumulated:accumulated_t -> t -> unattached_mask -> attached_mask

  val unsafe_preload_accounts_from_parent :
    attached_mask -> account_id list -> unit

  (** Detaches the mask from its parent and orphans it, so that every holder
      of it, including the masks attached to it, fails on its next use. *)
  val unregister_mask_exn : loc:string -> attached_mask -> unattached_mask

  module Debug : sig
    (** Write a graph of the given masks, each with its children. *)
    val visualize :
      filename:string -> (attached_mask * attached_mask list) list -> unit
  end
end
