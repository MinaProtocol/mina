module SC = Scalar_challenge
open Pickles_types
open Marlin_plonk_bindings
open Import

(* The endo coefficients used by the wrap proof system *)
module Dee = struct
  let base : Backend.Tick.Field.t = Tweedle_dee.endo_base ()

  let scalar : Backend.Tock.Field.t = Tweedle_dee.endo_scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) :
      Backend.Tock.Field.t =
    SC.to_field_constant (module Backend.Tock.Field) ~endo:scalar t
end

(* The endo coefficients used by the step proof system *)
module Dum = struct
  let base : Backend.Tock.Field.t = Tweedle_dum.endo_base ()

  let scalar : Backend.Tick.Field.t = Tweedle_dum.endo_scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) :
      Backend.Tick.Field.t =
    SC.to_field_constant (module Backend.Tick.Field) ~endo:scalar t
end
