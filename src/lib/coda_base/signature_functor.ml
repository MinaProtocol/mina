open Snarky_intf

module Make (Impl : Tick_S) = struct
  open Impl

  type t = Field.t * Inner_curve.Scalar.t [@@deriving sexp, eq, compare, hash]

  type var = Field.Var.t * Inner_curve.Scalar.var

  let dummy = (Field.one, Inner_curve.Scalar.one)
end
