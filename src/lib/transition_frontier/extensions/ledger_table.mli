(** A ledger table maps ledger hashes to ledgers *)

open Coda_base

type t

include Intf.Extension_intf with type t := t and type view = unit

val lookup : t -> Ledger_hash.t -> Ledger.t option
