open Pickles_types
open Import
open Backend

type dlog_opening =
  ( Tock.Curve.Affine.t
  , Tock.Field.t )
  Types.Pairing_based.Openings.Bulletproof.t

type t =
  dlog_opening
  * (Tock.Curve.Affine.t, Tock.Field.t) Dlog_marlin_types.Messages.t

open Step_main_inputs

type var =
  ( Inner_curve.t
  , Impls.Step.Other_field.t )
  Types.Pairing_based.Openings.Bulletproof.t
  * (Inner_curve.t, Impls.Step.Other_field.t) Dlog_marlin_types.Messages.t

open Impls.Step

let typ : (var, t) Typ.t =
  Typ.tuple2
    (Types.Pairing_based.Openings.Bulletproof.typ
       ~length:(Nat.to_int Backend.Rounds.n)
       Other_field.typ Inner_curve.typ)
    (Dlog_marlin_types.Messages.typ ~dummy:Inner_curve.Params.one
       ~commitment_lengths:
         (Dlog_marlin_types.Evals.map
            ~f:(fun x -> Vector.[x])
            (Commitment_lengths.of_domains Common.wrap_domains))
       Other_field.typ Inner_curve.typ)
