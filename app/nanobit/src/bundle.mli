open Core
open Async
open Nanobit_base

module type S = sig
  type proof
  type t

  val cancel : t -> unit

  (* TODO: Need a mechanism for preventing malleability
    of transaction bundle (so no one can steal fees).
    One idea is to have a "drain" snark at the end that
    takes the built up fees and transfers them into one
    account. *)
  val create : conf_dir:string -> Ledger.t -> Transaction.With_valid_signature.t list -> t

  val target_hash : t -> Ledger_hash.t

  val result : t -> proof option Deferred.t
end

include S with type proof := Transaction_snark.t
