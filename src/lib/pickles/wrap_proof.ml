open Pickles_types
open Import
open Backend

type dlog_opening =
  ( Tock.Curve.Affine.t
  , Tock.Field.t )
  Types.Pairing_based.Openings.Bulletproof.t

type t =
  dlog_opening
  * (Tock.Curve.Affine.t, Tock.Field.t) Dlog_plonk_types.Messages.t

open Step_main_inputs

type var =
  ( Inner_curve.t
  , Impls.Step.Other_field.t )
  Types.Pairing_based.Openings.Bulletproof.t
  * (Inner_curve.t, Impls.Step.Other_field.t) Dlog_plonk_types.Messages.t

open Impls.Step

let typ : (var, t) Typ.t =
  Typ.tuple2
    (Types.Pairing_based.Openings.Bulletproof.typ
       ~length:(Nat.to_int Tock.Rounds.n) Other_field.typ Inner_curve.typ)
    (Dlog_plonk_types.Messages.typ
       ~dummy:Inner_curve.Params.one
       ~commitment_lengths:
         (Dlog_plonk_types.Evals.map
            ~f:(fun x -> Vector.[x])
            (Commitment_lengths.of_domains ~max_degree:Common.Max_degree.wrap
               Common.wrap_domains))
       Inner_curve.typ )
