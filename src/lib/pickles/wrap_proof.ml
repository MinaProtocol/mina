open Pickles_types
open Import
open Backend

type dlog_opening =
  ( Tock.Curve.Affine.t
  , Tock.Field.t )
  Types.Pairing_based.Openings.Bulletproof.t

type t =
  dlog_opening
  * ( Tock.Curve.Affine.t
    , Tock.Curve.Affine.t Or_infinity.t )
    Dlog_plonk_types.Messages.t

open Step_main_inputs

type var =
  ( Inner_curve.t
  , Impls.Step.Other_field.t Shifted_value.t )
  Types.Pairing_based.Openings.Bulletproof.t
  * ( Inner_curve.t
    , Impls.Step.Boolean.var * Inner_curve.t )
    Dlog_plonk_types.Messages.t

open Impls.Step

let typ : (var, t) Typ.t =
  let shift = Shifted_value.Shift.create (module Tock.Field) in
  Typ.tuple2
    (Types.Pairing_based.Openings.Bulletproof.typ
       ~length:(Nat.to_int Tock.Rounds.n)
       ( Typ.transport Other_field.typ
           ~there:(fun x ->
             (* When storing, make it a shifted value *)
             match Shifted_value.of_field (module Tock.Field) ~shift x with
             | Shifted_value x ->
                 x )
           ~back:(fun x ->
             Shifted_value.to_field
               (module Tock.Field)
               ~shift (Shifted_value x) )
       (* When reading, unshift *)
       |> Typ.transport_var
          (* For the var, we just wrap the now shifted underlying value. *)
            ~there:(fun (Shifted_value.Shifted_value x) -> x)
            ~back:(fun x -> Shifted_value x) )
       Inner_curve.typ)
    (Dlog_plonk_types.Messages.typ ~bool:Boolean.typ
       ~dummy:Inner_curve.Params.one
       ~commitment_lengths:
         (Dlog_plonk_types.Evals.map
            ~f:(fun x -> Vector.[x])
            (Commitment_lengths.of_domains ~max_degree:Common.Max_degree.wrap
               Common.wrap_domains))
       Inner_curve.typ)
