open Core
open Async
open Nanobit_base

module type S0 = sig
  type proof
  type t

  val cancel : t -> unit

  (* TODO: Need a mechanism for preventing malleability
    of transaction bundle (so no one can steal fees).
    One idea is to have a "drain" snark at the end that
    takes the built up fees and transfers them into one
    account. *)
  val create
    : conf_dir:string -> Ledger.t -> Transaction.With_valid_signature.t list
    -> Public_key.Compressed.t
    -> t

  val target_hash : t -> Ledger_hash.t

  val result : t -> proof option Deferred.t
end

module type S = sig
  include S0

  module Sparse_ledger : sig
    open Snark_params.Tick

    type t
    [@@deriving sexp]

    val merkle_root : t -> Ledger_hash.t

    val path_exn : t -> int -> [ `Left of Pedersen.Digest.t | `Right of Pedersen.Digest.t ] list

    val apply_transaction_exn : t -> Transaction.t -> t

    val of_ledger_subset : Ledger.t -> Public_key.Compressed.t list -> t

    val handler : t -> Handler.t Staged.t
  end
end

include S with type proof := Transaction_snark.t
