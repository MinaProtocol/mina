open Core
open Async
open Nanobit_base

type t

val cancel : t -> unit

(* TODO: Need a mechanism for preventing malleability
   of transaction bundle (so no one can steal fees).
   One idea is to have a "drain" snark at the end that
   takes the built up fees and transfers them into one
   account. *)
val create : Ledger.t -> Transaction.t list -> t

val snark : t -> Transaction_snark.t option Deferred.t
