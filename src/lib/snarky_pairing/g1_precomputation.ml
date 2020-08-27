module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  module Fqe : Snarky_field_extensions.Intf.S with module Impl = Impl

  open Impl

  type t = {p: Field.Var.t * Field.Var.t; py_twist_squared: Fqe.t}

  val create : Field.Var.t * Field.Var.t -> t
end

module Make
    (Impl : Snarky_backendless.Snark_intf.S)
    (Fqe : Snarky_field_extensions.Intf.S with module Impl = Impl)
                                                                 (Params : sig
        val twist : Fqe.Unchecked.t
    end) =
struct
  module Impl = Impl
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
