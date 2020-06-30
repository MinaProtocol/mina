open Zexe_backend
module SC = Scalar_challenge
open Pickles_types
open Snarky_bn382.Tweedle.Endo
open Import

(* The endo coefficients used by the wrap proof system *)
module Dee = struct
  open Dee

  let base : Backend.Tick.Field.t = base ()

  let scalar : Backend.Tock.Field.t = scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) :
      Backend.Tock.Field.t =
    SC.to_field_constant (module Backend.Tock.Field) ~endo:scalar t
end

(* The endo coefficients used by the step proof system *)
module Dum = struct
  open Dum

  let base : Backend.Tock.Field.t = base ()

  let scalar : Backend.Tick.Field.t = scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) :
      Backend.Tick.Field.t =
    SC.to_field_constant (module Backend.Tick.Field) ~endo:scalar t
end
