(** A ledger table maps ledger hashes to ledgers *)

open Mina_base

type t

include Intf.Extension_intf with type t := t and type view = unit

val lookup : t -> Ledger_hash.t -> Mina_ledger.Ledger.t option
