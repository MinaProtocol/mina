open Core
open Nanobit_base
open Snark_params.Tick

type t [@@deriving bin_io, sexp]

val merkle_root : t -> Ledger_hash.t

val path_exn :
  t -> int -> [`Left of Merkle_hash.t | `Right of Merkle_hash.t] list

val apply_transaction_exn : t -> Transaction.t -> t

val apply_transition_exn : t -> Transaction_snark.Transition.t -> t

val of_ledger_subset_exn : Ledger.t -> Public_key.Compressed.t list -> t

val handler : t -> Handler.t Staged.t
