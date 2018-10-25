(* masking_merkle_tree_intf.ml *)
(* the type of a Merkle tree mask associated with a parent Merkle tree *)

module type S = sig
  type t

  type unattached = t

  type parent

  type account

  type location

  type hash

  type key

  module Addr : Merkle_address.S

  (* create a mask with no parent *)

  val create : unit -> t

  module Attached : sig
    include Base_merkle_tree_intf.S
            with type account := account
             and type location := location
             and type hash := hash
             and type key := key

    (** get hash from mask, if present, else from its parent *)

    val get_hash : t -> Addr.t -> hash option

    (** commit all state to the parent, flush state locally *)

    val commit : t -> unit

    (** remove parent *)

    val unset_parent : t -> unattached

    (** get mask parent *)

    val get_parent : t -> parent

    (** called when parent sets an account; update local state *)

    val parent_set_notify : t -> location -> account -> Path.t -> unit

    (** already have module For_testing from include above *)

    module For_testing : sig
      val location_in_mask : t -> location -> bool

      val address_in_mask : t -> Addr.t -> bool
    end
  end

  (** tell mask about parent *)

  val set_parent : unattached -> parent -> Attached.t
end
