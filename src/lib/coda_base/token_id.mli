open Core_kernel
open Snark_params
open Tick

[%%versioned:
module Stable : sig
  module V1 : sig
    type t [@@deriving version, sexp, eq, hash, compare, yojson]
  end
end]

type t = Stable.Latest.t [@@deriving sexp, compare]

type var

val to_input : t -> (Field.t, bool) Random_oracle.Input.t

val typ : (var, t) Typ.t

val var_of_t : t -> var

(** The default token ID, associated with the native coda token.

    This key should be used for fee and coinbase transactions.
*)
val default : t

val gen : t Quickcheck.Generator.t

val unpack : t -> bool list

include Comparable.S with type t := t

module Checked : sig
  val to_input : var -> (Field.Var.t, Boolean.var) Random_oracle.Input.t

  val equal : var -> var -> (Boolean.var, _) Checked.t

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  module Assert : sig
    val equal : var -> var -> (unit, _) Checked.t
  end
end
