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

  (* Get all of the accounts that is in a subtree of the underlying merkle tree where it's root is `address`. 
    The accounts are ordered from their address in the merkle tree *)
  val get_all_accounts_rooted_at_exn : t -> addr -> (addr * account) list

  val merkle_root : t -> root_hash

  val make_space_for : t -> int -> unit
end
