open Pickles_types
open Import
open Backend

type dlog_opening =
  (Tock.Curve.Affine.t, Tock.Field.t) Types.Step.Openings.Bulletproof.t

type t = dlog_opening * Tock.Curve.Affine.t Plonk_types.Messages.t

open Step_main_inputs

type var =
  ( Inner_curve.t
  , Impls.Step.Other_field.t Shifted_value.Type2.t )
  Types.Step.Openings.Bulletproof.t
  * Inner_curve.t Plonk_types.Messages.t

open Impls.Step

let typ : (var, t) Typ.t =
  let shift = Shifted_value.Type2.Shift.create (module Tock.Field) in
  Typ.tuple2
    (Types.Step.Openings.Bulletproof.typ ~length:(Nat.to_int Tock.Rounds.n)
       ( Typ.transport Other_field.typ
           ~there:(fun x ->
             (* When storing, make it a shifted value *)
             match
               Shifted_value.Type2.of_field (module Tock.Field) ~shift x
             with
             | Shifted_value x ->
                 x)
           ~back:(fun x ->
             Shifted_value.Type2.to_field
               (module Tock.Field)
               ~shift (Shifted_value x))
       (* When reading, unshift *)
       |> Typ.transport_var
          (* For the var, we just wrap the now shifted underlying value. *)
            ~there:(fun (Shifted_value.Type2.Shifted_value x) -> x)
            ~back:(fun x -> Shifted_value x) )
       Inner_curve.typ)
    (Plonk_types.Messages.typ ~bool:Boolean.typ ~dummy:Inner_curve.Params.one
       ~commitment_lengths:(Commitment_lengths.create ~of_int:(fun x -> x))
       Inner_curve.typ)
