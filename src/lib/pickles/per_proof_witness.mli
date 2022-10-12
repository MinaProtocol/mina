(* *)

module Impl = Impls.Step

module One_hot_vector : module type of One_hot_vector.Make (Impls.Step)

type challenge = Import.Challenge.Make(Impls.Step).t

type scalar_challenge = challenge Import.Scalar_challenge.t

(** Represents a proof (along with its accumulation state) which wraps a
    "step" proof S on the other curve.

    To have some notation, the proof S itself comes from a circuit that verified
    up to 'max_proofs_verified many wrap proofs W_0, ..., W_max_proofs_verified.
*)
type ('app_state, 'max_proofs_verified, 'num_branches) t =
  { app_state : 'app_state
        (** The user-level statement corresponding to this proof. *)
  ; wrap_proof : Wrap_proof.Checked.t
        (** The polynomial commitments, polynomial evaluations, and opening proof corresponding to
      this latest wrap proof.
  *)
  ; proof_state :
      ( challenge
      , scalar_challenge
      , Impl.Field.t Pickles_types.Shifted_value.Type1.t
      , ( ( scalar_challenge
          , Impl.Field.t Pickles_types.Shifted_value.Type1.t )
          Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.Lookup
          .t
        , Impl.Boolean.var )
        Pickles_types.Plonk_types.Opt.t
      , unit
      , Import.Digest.Make(Impl).t
      , scalar_challenge Import.Bulletproof_challenge.t
        Import.Types.Step_bp_vec.t
      , Impl.field Import.Branch_data.Checked.t )
      Import.Types.Wrap.Proof_state.In_circuit.t
        (** The accumulator state corresponding to the above proof. Contains
      - `deferred_values`: The values necessary for finishing the deferred "scalar field" computations.
      That is, computations which are over the "step" circuit's internal field that the
      previous "wrap" circuit was unable to verify directly, due to its internal field
      being different.
      - `sponge_digest_before_evaluations`: the sponge state: TODO
      - `messages_for_next_wrap_proof`
  *)
  ; prev_proof_evals :
      ( Impl.Field.t
      , Impl.Field.t array
      , Impl.Boolean.var )
      Pickles_types.Plonk_types.All_evals.In_circuit.t
        (** The evaluations from the step proof that this proof wraps *)
  ; prev_challenges :
      ( (Impl.Field.t, Backend.Tick.Rounds.n) Pickles_types.Vector.t
      , 'max_proofs_verified )
      Pickles_types.Vector.t
        (** The challenges c_0, ... c_{k - 1} corresponding to each W_i. *)
  ; prev_challenge_polynomial_commitments :
      ( Step_main_inputs.Inner_curve.t
      , 'max_proofs_verified )
      Pickles_types.Vector.t
        (** The commitments to the "challenge polynomials" \prod_{i = 0}^k (1 + c_{k - 1 - i} x^{2^i})
      corresponding to each of the "prev_challenges".
  *)
  }
[@@deriving hlist]

module No_app_state : sig
  type nonrec (_, 'max_proofs_verified, 'num_branches) t =
    (unit, 'max_proofs_verified, 'num_branches) t
end

module Constant : sig
  type challenge = Import.Challenge.Constant.t

  type scalar_challenge = challenge Import.Scalar_challenge.t

  type ('statement, 'max_proofs_verified, _) t =
    { app_state : 'statement
    ; wrap_proof : Wrap_proof.Constant.t
    ; proof_state :
        ( challenge
        , scalar_challenge
        , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
        , ( scalar_challenge
          , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t )
          Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.Lookup
          .t
          option
        , unit
        , Import.Digest.Constant.t
        , scalar_challenge Import.Bulletproof_challenge.t
          Import.Types.Step_bp_vec.t
        , Import.Branch_data.t )
        Import.Types.Wrap.Proof_state.In_circuit.t
    ; prev_proof_evals :
        ( Backend.Tick.Field.t
        , Backend.Tick.Field.t array )
        Pickles_types.Plonk_types.All_evals.t
    ; prev_challenges :
        ( (Backend.Tick.Field.t, Backend.Tick.Rounds.n) Pickles_types.Vector.t
        , 'max_proofs_verified )
        Pickles_types.Vector.t
    ; prev_challenge_polynomial_commitments :
        ( Backend.Tick.Inner_curve.Affine.t
        , 'max_proofs_verified )
        Pickles_types.Vector.t
    }

  module No_app_state : sig
    type nonrec (_, 'max_proofs_verified, 'num_branches) t =
      (unit, 'max_proofs_verified, 'num_branches) t
  end
end

val typ :
     lookup:Pickles_types.Plonk_types.Opt.Flag.t
  -> ('avar, 'aval) Impl.Typ.t
  -> 'n Pickles_types.Nat.t
  -> 'm Pickles_types.Nat.t
  -> (('avar, 'n, 'm) t, ('aval, 'n, 'm) Constant.t) Impl.Typ.t
