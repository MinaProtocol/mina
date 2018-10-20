(* masking_merkle_tree_intf.ml *)
(* the type of a Merkle tree mask associated with a parent Merkle tree *)

module type S = sig
  include Base_merkle_tree_intf.S

  (* get hash from mask, if present, else from its parent *)

  val get_hash : t -> Addr.t -> hash option

  (* commit all state to the parent, flush state locally *)

  val commit : t -> unit

  (* called when parent sets an account; update local state *)

  val parent_set_notify : t -> location -> account -> Path.t -> unit
end
