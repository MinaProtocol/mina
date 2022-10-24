module SC = Scalar_challenge
open Pickles_types
open Import

(* The endo coefficients used by the step proof system *)
module Wrap_inner_curve = struct
  let base : Backend.Wrap.Field.t = Pasta_bindings.Vesta.endo_base ()

  let scalar : Backend.Step.Field.t = Pasta_bindings.Vesta.endo_scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) :
      Backend.Step.Field.t =
    SC.to_field_constant (module Backend.Step.Field) ~endo:scalar t
end

(* The endo coefficients used by the wrap proof system *)
module Step_inner_curve = struct
  let base : Backend.Step.Field.t = Pasta_bindings.Pallas.endo_base ()

  let scalar : Backend.Wrap.Field.t = Pasta_bindings.Pallas.endo_scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) :
      Backend.Wrap.Field.t =
    SC.to_field_constant (module Backend.Wrap.Field) ~endo:scalar t
end
