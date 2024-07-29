open Core_kernel
open Snark_params.Tick

[%%versioned:
module Stable : sig
  module V1 : sig
    type t = Sgn_type.Sgn.Stable.V1.t = Pos | Neg
    [@@deriving sexp, hash, compare, equal, yojson]
  end
end]

type t = Stable.Latest.t = Pos | Neg

val to_field : t -> Field.t

val of_field_exn : Field.t -> t

val gen : t Quickcheck.Generator.t

val negate : t -> t

type var = private Field.Var.t

val typ : (var, t) Typ.t

module Checked : sig
  val constant : t -> var

  val neg : var

  val pos : var

  val is_pos : var -> Boolean.var

  val is_neg : var -> Boolean.var

  val pos_if_true : Boolean.var -> var

  val neg_if_true : Boolean.var -> var

  val negate : var -> var

  val if_ : Boolean.var -> then_:var -> else_:var -> var Checked.t
end
