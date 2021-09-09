module SC = Scalar_challenge
open Pickles_types
open Marlin_plonk_bindings
open Import

(* The endo coefficients used by the step proof system *)
module Wrap_inner_curve = struct
  let base : Backend.Tock.Field.t = Pasta_vesta.endo_base ()

  let scalar : Backend.Tick.Field.t = Pasta_vesta.endo_scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) :
      Backend.Tick.Field.t =
    SC.to_field_constant (module Backend.Tick.Field) ~endo:scalar t
end

(* The endo coefficients used by the wrap proof system *)
module Step_inner_curve = struct
  let base : Backend.Tick.Field.t = Pasta_pallas.endo_base ()

  let scalar : Backend.Tock.Field.t = Pasta_pallas.endo_scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) :
      Backend.Tock.Field.t =
    SC.to_field_constant (module Backend.Tock.Field) ~endo:scalar t
end
