(* transaction_union_tag.ml *)

[%%import "/src/config.mlh"]

open Core_kernel

[%%ifdef consensus_mechanism]

open Snark_params.Tick

[%%endif]

type t = Payment | Stake_delegation | Mint | Fee_transfer | Coinbase
[@@deriving enum, eq, sexp]

val gen : t Quickcheck.Generator.t

val to_bits : t -> bool list

val to_input : t -> (Field.t, bool) Random_oracle.Input.t

[%%ifdef consensus_mechanism]

module Bits : sig
  (** Bits-only representation. To be used for hashing, where the actual value
      is not relevant to the computation.
  *)
  type var

  val to_bits : var -> Boolean.var list

  val to_input : var -> (Field.Var.t, Boolean.var) Random_oracle.Input.t
end

val bits_of_t : t -> Bits.var

val bits_typ : (Bits.var, t) Typ.t

module Unpacked : sig
  (** Full representation. This pre-computes all of the tag variables, but may
      still cheaply be convered to bits.
  *)
  type var

  val is_payment : var -> Boolean.var

  val is_stake_delegation : var -> Boolean.var

  val is_mint : var -> Boolean.var

  val is_fee_transfer : var -> Boolean.var

  val is_coinbase : var -> Boolean.var

  val is_user_command : var -> Boolean.var

  module Checked : sig
    val to_bits : var -> (Boolean.var list, _) Checked.t

    val to_input :
      var -> ((Field.Var.t, Boolean.var) Random_oracle.Input.t, _) Checked.t
  end
end

val unpacked_of_t : t -> Unpacked.var

val unpacked_typ : (Unpacked.var, t) Typ.t

[%%endif]
