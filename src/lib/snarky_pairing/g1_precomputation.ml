module Make
    (Fqe : Snarky_field_extensions.Intf.S) (Params : sig
        val twist : Fqe.Unchecked.t
    end) =
struct
  module Impl = Fqe.Impl
  module Fqe = Fqe
  open Impl

  type g1 = Field.Var.t * Field.Var.t

  type t = {p: g1; py_twist_squared: Fqe.t}

  let create p =
    let _, y = p in
    let twist_squared = Fqe.Unchecked.square Params.twist in
    { p
    ; py_twist_squared=
        Fqe.map_ twist_squared ~f:(fun c -> Field.Var.scale y c) }
end
