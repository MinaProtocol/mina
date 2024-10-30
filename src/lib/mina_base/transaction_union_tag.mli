(* transaction_union_tag.ml *)
open Core_kernel
open Snark_params.Tick

type t = Payment | Stake_delegation | Fee_transfer | Coinbase
[@@deriving enum, equal, sexp]

val to_string : t -> string

val gen : t Quickcheck.Generator.t

val to_bits : t -> bool list

val to_input_legacy : t -> (Field.t, bool) Random_oracle.Input.Legacy.t

module Bits : sig
  (** Bits-only representation. To be used for hashing, where the actual value
      is not relevant to the computation.
  *)
  type var

  val to_bits : var -> Boolean.var list

  val to_input_legacy :
    var -> (Field.Var.t, Boolean.var) Random_oracle.Input.Legacy.t
end

val bits_of_t : t -> Bits.var

val bits_typ : (Bits.var, t) Typ.t

module Unpacked : sig
  (** Full representation. This pre-computes all of the tag variables, but may
      still be convered to bits without adding any constraints.
  *)
  type var

  val is_payment : var -> Boolean.var

  val is_stake_delegation : var -> Boolean.var

  val is_fee_transfer : var -> Boolean.var

  val is_coinbase : var -> Boolean.var

  val is_user_command : var -> Boolean.var

  val to_bits : var -> Boolean.var list

  val to_input_legacy :
    var -> (Field.Var.t, Boolean.var) Random_oracle.Input.Legacy.t
end

val unpacked_of_t : t -> Unpacked.var

val unpacked_typ : (Unpacked.var, t) Typ.t
