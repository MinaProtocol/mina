module type S = sig
  type root_hash

  type hash

  type account

  type addr

  type t [@@deriving sexp]

  type path

  val depth : int

  val num_accounts : t -> int

  val merkle_path_at_addr_exn : t -> addr -> path

  val get_inner_hash_at_addr_exn : t -> addr -> hash

  val set_inner_hash_at_addr_exn : t -> addr -> hash -> unit

  val set_all_accounts_rooted_at_exn : t -> addr -> account list -> unit

  val set_batch_accounts : t -> (addr * account) list -> unit

  val get_all_accounts_rooted_at_exn : t -> addr -> (addr * account) list
  (** Get all of the accounts that are in a subtree of the underlying Merkle
    tree rooted at `address`. The accounts are ordered by their addresses. *)

  val has_unset_slots : t -> bool
  (** In some ledgers, it's possible to preallocate account slots before filling
      them in. Returns true if there are any unset slots, false otherwise. *)

  val merkle_root : t -> root_hash
  (** Get the root hash of the ledger. May throw if there are unset slots. *)

  val make_space_for : t -> int -> unit
end
