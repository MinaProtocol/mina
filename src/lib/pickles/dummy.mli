(** [Ipa] *)
module Ipa : sig
  module Wrap : sig
    val challenges :
      ( (int64, Pickles_types.Nat.N2.n) Pickles_types.Vector.t
        Import.Scalar_challenge.t
        Composition_types.Bulletproof_challenge.t
      , Pickles_types.Nat.z Backend.Tock.Rounds.plus_n )
      Pickles_types.Vector.t

    val challenges_computed :
      ( Backend.Tock.Field.t
      , Pickles_types.Nat.z Backend.Tock.Rounds.plus_n )
      Pickles_types.Vector.t

    val sg : (Pasta_bindings.Fp.t * Pasta_bindings.Fp.t) lazy_t
  end

  module Step : sig
    val challenges :
      ( (int64, Pickles_types.Nat.N2.n) Pickles_types.Vector.t
        Import.Scalar_challenge.t
        Composition_types.Bulletproof_challenge.t
      , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
      Pickles_types.Vector.t

    val challenges_computed :
      ( Backend.Tick.Field.t
      , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
      Pickles_types.Vector.t

    val sg : (Pasta_bindings.Fq.t * Pasta_bindings.Fq.t) lazy_t
  end
end

(* (\** [wrap_domains ~proofs_verified] *\)
   val wrap_domains : proofs_verified:int -> Import.Domains.t *)

(** {2 Constants} *)

(** [evals] is a constant *)
val evals :
  ( Backend.Tock.Field.t
  , Backend.Tock.Field.t array )
  Pickles_types.Plonk_types.All_evals.t

(** [evals_combined] is a constant *)
val evals_combined :
  ( Backend.Tock.Field.t
  , Backend.Tock.Field.t )
  Pickles_types.Plonk_types.All_evals.t
