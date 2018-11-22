(* ledger_extras_intf.ml -- adds functionality to Base_ledger_intf.S *)

module type S = sig
  include Merkle_ledger_intf.S

  val set_at_addr_exn : t -> Addr.t -> account -> unit

  val key_of_index : t -> index -> key option

  val key_of_index_exn : t -> index -> key

  val recompute_tree : t -> unit
end
