module Constant : sig
  type t =
    ( Import.Challenge.Constant.t
    , Import.Challenge.Constant.t Import.Scalar_challenge.t
    , Backend.Tock.Field.t Pickles_types.Shifted_value.Type2.t
    , ( Import.Challenge.Constant.t Import.Scalar_challenge.t
      , Backend.Tock.Field.t Pickles_types.Shifted_value.Type2.t )
      Import.Types.Step.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
      option
    , ( Import.Challenge.Constant.t Import.Scalar_challenge.t
        Import.Bulletproof_challenge.t
      , Backend.Tock.Rounds.n )
      Pickles_types.Vector.t
    , Import.Digest.Constant.t
    , bool )
    Import.Types.Step.Proof_state.Per_proof.In_circuit.t

  (* val shift : Backend.Tock.Field.t Pickles_types.Shifted_value.Type2.Shift.t *)

  val dummy : t Lazy.t
end

type t =
  ( Impls.Step.Field.t
  , Impls.Step.Field.t Import.Scalar_challenge.t
  , Impls.Step.Other_field.t Pickles_types.Shifted_value.Type2.t
  , ( ( Impls.Step.Field.t Import.Scalar_challenge.t
      , Impls.Step.Other_field.t Pickles_types.Shifted_value.Type2.t )
      Import.Types.Step.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
    , Impls.Step.Boolean.var )
    Pickles_types.Plonk_types.Opt.t
  , ( Impls.Step.Field.t Import.Scalar_challenge.t Import.Bulletproof_challenge.t
    , Backend.Tock.Rounds.n )
    Pickles_types.Vector.t
  , Impls.Step.Field.t
  , Impls.Step.Boolean.var )
  Import.Types.Step.Proof_state.Per_proof.In_circuit.t

val typ :
     wrap_rounds:'a
  -> uses_lookup:Composition_types.Opt.Flag.t
  -> (t, Constant.t) Impls.Step.Typ.t
