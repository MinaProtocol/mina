(* ledger_extras_intf.ml -- adds functionality to Base_ledger_intf.S *)

module type S = sig
  include Merkle_ledger_intf.S

  val with_ledger : f:(t -> 'a) -> 'a

  val set_at_addr_exn : t -> Addr.t -> account -> unit

  val account_id_of_index : t -> index -> account_id option

  val account_id_of_index_exn : t -> index -> account_id

  val recompute_tree : t -> unit
end
