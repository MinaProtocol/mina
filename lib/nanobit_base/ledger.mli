open Core
open Import

type t [@@deriving sexp]

module Addr : Merkle_address.S

module Path : Merkle_ledger.Merkle_path.S with type hash := Merkle_hash.t

include Merkle_ledger.Merkle_tree_intf.S
        with type root_hash := Ledger_hash.t
         and type hash := Merkle_hash.t
         and type account := Account.t
         and type addr := Addr.t
         and type t := t
         and type path = Path.t

type key = Public_key.Compressed.t

val create : unit -> t

val get : t -> key -> Account.t option

val set : t -> Account.t -> unit

val get_at_index_exn : t -> int -> Account.t

val set_at_index_exn : t -> int -> Account.t -> unit

val index_of_key_exn : t -> key -> int

val merkle_root : t -> Ledger_hash.t

val merkle_path : t -> key -> Path.t option

val merkle_path_at_index_exn : t -> int -> Path.t

val copy : t -> t

module Undo : sig
  type transaction =
    { transaction: Transaction.t
    ; previous_receipt_chain_hash: Receipt.Chain_hash.t }
  [@@deriving sexp]

  type t =
    | Transaction of transaction
    | Fee_transfer of Fee_transfer.t
    | Coinbase of Coinbase.t
  [@@deriving sexp]
end

val apply_super_transaction : t -> Super_transaction.t -> Undo.t Or_error.t

val undo : t -> Undo.t -> unit Or_error.t

val merkle_root_after_transaction_exn :
  t -> Super_transaction.transaction -> Ledger_hash.t
