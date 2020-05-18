open Snarky_bn382_backend
module SC = Scalar_challenge
open Pickles_types
open Snarky_bn382.Endo

(* The endo coefficients used by the dlog based proof system *)
module Dlog = struct
  open Dlog

  let base : Fp.t = base ()

  let scalar : Fq.t = scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) : Fq.t =
    SC.to_field_constant (module Fq) ~endo:scalar t
end

module Pairing = struct
  open Pairing

  let base : Fq.t = base ()

  let scalar : Fp.t = scalar ()

  let to_field (t : Challenge.Constant.t Scalar_challenge.t) : Fp.t =
    SC.to_field_constant (module Fp) ~endo:scalar t
end
