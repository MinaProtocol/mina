open Nanobit_base
open Snark_params

type t

val proof : t -> Tock.Proof.t

module Keys : sig
  type t
  [@@deriving bin_io]

  val dummy :  unit -> t

  val create : unit -> t
end

module Make (K : sig val keys : Keys.t end) : sig
  val of_transaction
    : Ledger.t
    -> Transaction.t
    -> t

  val merge : t -> t -> t
end
