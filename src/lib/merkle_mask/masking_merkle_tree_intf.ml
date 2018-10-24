(* masking_merkle_tree_intf.ml *)
(* the type of a Merkle tree mask associated with a parent Merkle tree *)

module type S = sig
  include Base_merkle_tree_intf.S

  type parent

  (* for testing *)

  val location_in_mask : t -> location -> bool

  (* for testing *)

  val address_in_mask : t -> Addr.t -> bool

  (* get hash from mask, if present, else from its parent *)

  val get_hash : t -> Addr.t -> hash option

  (* commit all state to the parent, flush state locally *)

  val commit : t -> unit

  (* tell mask about parent *)

  val set_parent : t -> parent -> unit

  (* remove parent *)

  val unset_parent : t -> unit

  (* get mask parent *)

  val get_parent_exn : t -> parent

  (* called when parent sets an account; update local state *)

  val parent_set_notify : t -> location -> account -> Path.t -> unit
end
