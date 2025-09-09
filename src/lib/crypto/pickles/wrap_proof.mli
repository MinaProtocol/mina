type dlog_opening =
  ( Backend.Tock.Curve.Affine.t
  , Backend.Tock.Field.t )
  Import.Types.Step.Bulletproof.t

module Constant : sig
  (* Out-of-circuit type for wrap proofs *)
  type t =
    { messages :
        Backend.Tock.Curve.Affine.t Pickles_types.Plonk_types.Messages.t
    ; opening : dlog_opening
    }
  [@@deriving hlist]
end

module Checked : sig
  (* In-circuit type for wrap proofs *)
  type t =
    { messages :
        ( Step_main_inputs.Inner_curve.t
        , Step_main_inputs.Impl.Boolean.var )
        Pickles_types.Plonk_types.Messages.In_circuit.t
    ; opening :
        ( Step_main_inputs.Inner_curve.t
        , Impls.Step.Other_field.t Pickles_types.Shifted_value.Type2.t )
        Import.Types.Step.Bulletproof.t
    }
  [@@deriving hlist]
end

val typ : (Checked.t, Constant.t) Impls.Step.Typ.t
