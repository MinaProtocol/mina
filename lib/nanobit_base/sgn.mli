open Core
open Snark_params.Tick

type t = Pos | Neg [@@deriving sexp, bin_io]

val to_field : t -> Field.t

type var = private Field.Checked.t

val typ : (var, t) Typ.t

module Checked : sig
  val neg : var

  val pos : var

  val is_pos : var -> Boolean.var

  val is_neg : var -> Boolean.var

  val pos_if_true : Boolean.var -> var

  val neg_if_true : Boolean.var -> var
end
