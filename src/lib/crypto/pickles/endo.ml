module SC = Scalar_challenge

type t = Import.Challenge.Constant.t Import.Scalar_challenge.t

module Wrap_inner_curve = struct
  let base : Backend.Tock.Field.t = Pasta_bindings.Vesta.endo_base ()

  let scalar : Backend.Tick.Field.t = Pasta_bindings.Vesta.endo_scalar ()

  let to_field (t : t) : Backend.Tick.Field.t =
    SC.to_field_constant (module Backend.Tick.Field) ~endo:scalar t
end

module Step_inner_curve = struct
  let base : Backend.Tick.Field.t = Pasta_bindings.Pallas.endo_base ()

  let scalar : Backend.Tock.Field.t = Pasta_bindings.Pallas.endo_scalar ()

  let to_field (t : t) : Backend.Tock.Field.t =
    SC.to_field_constant (module Backend.Tock.Field) ~endo:scalar t
end
