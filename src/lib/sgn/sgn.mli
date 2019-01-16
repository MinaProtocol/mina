open Core_kernel
open Snark_params.Tick

type t = Sgn_type.Sgn.t = Pos | Neg
[@@deriving sexp, bin_io, hash, compare, eq, to_yojson]

val to_field : t -> Field.t

val gen : t Quickcheck.Generator.t

type var = private Field.Checked.t

val typ : (var, t) Typ.t

val negate : t -> t

module Checked : sig
  val constant : t -> var

  val neg : var

  val pos : var

  val is_pos : var -> Boolean.var

  val is_neg : var -> Boolean.var

  val pos_if_true : Boolean.var -> var

  val neg_if_true : Boolean.var -> var

  val negate : var -> var

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t
end
