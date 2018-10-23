open Core
open Snark_params

include Coda_spec.Ledger_intf.Hash.S
  with module Account = Account

(*
type t = private Tick.Pedersen.Digest.t
[@@deriving sexp, hash, compare, bin_io, eq]

val merge : height:int -> t -> t -> t

val of_digest : Tick.Pedersen.Digest.t -> t *)
