open Backend
open Pickles_types
open Import
module Impl = Impls.Step
module One_hot_vector = One_hot_vector.Make (Impl)

(* Let F, K be the two fields (either (Fp, Fq) or (Fq, Fp)).
   Each proof over F has an accumulator state which contains
   - a set of IPA challenges c_0, ..., c_{k-1}, which can be interpreted as F elements.
   - a polynomial commitment challenge_polynomial_commitment, which has coordinates in K.

   This part of the accumulator state is finalized by checking that challenge_polynomial_commitment
   is a commitment to the polynomial

   f_c := prod_{i = 0}^{k-1} (1 + c_i x^{2^{k-1 - i}})

   When incrementally-verifying such a proof in a K-circuit (since we need K-arithmetic to perform
   the group operations on the F-polynomial-commitments that constitute the proof),
   instead of checking this, we get an evaluation E_c at a random point zeta and check
   that challenge_polynomial_commitment opens to E_c at zeta. Then we will need to check that
   E_c = f_c(zeta) = prod_{i = 0}^{k-1} (1 + c_i zeta^{2^{k-1 - i}}).

   However, because we are then in a K-circuit, we cannot actually compute f_c(zeta), which requires
   F-arithmetic.

   Therefore, after incrementally verifying the F-proof, the challenges (c_0, ..., c_{k-1}) which are
   part of the accumulator of the F-proof we just incrementally verified, must remain part of
   the accumulator of the K-proof, along with E_c (or at least some kind of commitment to it, which is
   what we actually do).

   Then, when we incrementally verify that K-proof in an F-circuit, we will check that E_c was
   computed correctly using c_0, ..., c_{k-1} and they along with E_c can be discarded.

   So, to summarize, the accumulator state for each proof P (corresponding to an F-circuit)
   contains
   - a set of IPA challenges (thought of as K-elements) for every proof that it incrementally verified inside its circuit
   - a challenge_polynomial_commitment (coordinates in F) for every proof that it incrementally verified inside its circuit
   - a challenge_polynomial_commitment (coordinates in K) corresponding to P's own inner-product argument
   - a set of IPA challenges (thought of as F-elements) corresponding to P's own inner-product argument
*)

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
      ( Challenge.Make(Impl).t
      , Challenge.Make(Impl).t Scalar_challenge.t
      , Impl.Field.t Shifted_value.Type1.t
      , ( ( Challenge.Make(Impl).t Scalar_challenge.t
          , Impl.Field.t Shifted_value.Type1.t )
          Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
        , Impl.Boolean.var )
        Plonk_types.Opt.t
      , Step_verifier.Make(Step_main_inputs).Other_field.t
      , unit
      , Digest.Make(Impl).t
      , Challenge.Make(Impl).t Scalar_challenge.t Types.Bulletproof_challenge.t
        Types.Step_bp_vec.t
      , Impl.field Branch_data.Checked.t )
      Types.Wrap.Proof_state.In_circuit.t
        (** The accumulator state corresponding to the above proof. Contains
      - `deferred_values`: The values necessary for finishing the deferred "scalar field" computations.
      That is, computations which are over the "step" circuit's internal field that the
      previous "wrap" circuit was unable to verify directly, due to its internal field
      being different.
      - `sponge_digest_before_evaluations`: the sponge state: TODO
      - me_only
  *)
  ; prev_proof_evals :
      ( Impl.Field.t
      , Impl.Field.t array
      , Impl.Boolean.var )
      Plonk_types.All_evals.In_circuit.t
        (** The evaluations from the step proof that this proof wraps *)
  ; prev_challenges :
      ((Impl.Field.t, Tick.Rounds.n) Vector.t, 'max_proofs_verified) Vector.t
        (** The challenges c_0, ... c_{k - 1} corresponding to each W_i. *)
  ; prev_challenge_polynomial_commitments :
      (Step_main_inputs.Inner_curve.t, 'max_proofs_verified) Vector.t
        (** The commitments to the "challenge polynomials" \prod_{i = 0}^k (1 + c_{k - 1 - i} x^{2^i})
      corresponding to each of the "prev_challenges".
  *)
  }
[@@deriving hlist]

module No_app_state = struct
  type nonrec (_, 'max_proofs_verified, 'num_branches) t =
    (unit, 'max_proofs_verified, 'num_branches) t
end

module Constant = struct
  open Kimchi_backend

  type ('statement, 'max_proofs_verified, _) t =
    { app_state : 'statement
    ; wrap_proof : Wrap_proof.Constant.t
    ; proof_state :
        ( Challenge.Constant.t
        , Challenge.Constant.t Scalar_challenge.t
        , Tick.Field.t Shifted_value.Type1.t
        , ( Challenge.Constant.t Scalar_challenge.t
          , Tick.Field.t Shifted_value.Type1.t )
          Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.Lookup.t
          option
        , Tock.Field.t
        , unit
        , Digest.Constant.t
        , Challenge.Constant.t Scalar_challenge.t Types.Bulletproof_challenge.t
          Types.Step_bp_vec.t
        , Branch_data.t )
        Types.Wrap.Proof_state.In_circuit.t
    ; prev_proof_evals :
        (Tick.Field.t, Tick.Field.t array) Plonk_types.All_evals.t
    ; prev_challenges :
        ((Tick.Field.t, Tick.Rounds.n) Vector.t, 'max_proofs_verified) Vector.t
    ; prev_challenge_polynomial_commitments :
        (Tick.Inner_curve.Affine.t, 'max_proofs_verified) Vector.t
    }
  [@@deriving hlist]

  module No_app_state = struct
    type nonrec (_, 'max_proofs_verified, 'num_branches) t =
      (unit, 'max_proofs_verified, 'num_branches) t
  end
end

open Core_kernel

let lookup_config : Plonk_types.Lookup_config.t = { lookup = No; runtime = No }

let typ (type n avar aval m) ~lookup (statement : (avar, aval) Impls.Step.Typ.t)
    (max_proofs_verified : n Nat.t) (branches : m Nat.t) :
    ((avar, n, m) t, (aval, n, m) Constant.t) Impls.Step.Typ.t =
  let module Sc = Scalar_challenge in
  let open Impls.Step in
  let open Step_main_inputs in
  let open Step_verifier in
  Snarky_backendless.Typ.of_hlistable ~var_to_hlist:to_hlist
    ~var_of_hlist:of_hlist ~value_to_hlist:Constant.to_hlist
    ~value_of_hlist:Constant.of_hlist
    [ statement
    ; Wrap_proof.typ
    ; Types.Wrap.Proof_state.In_circuit.typ
        (module Impl)
        ~challenge:Challenge.typ ~scalar_challenge:Challenge.typ ~lookup
        ~dummy_scalar:(Shifted_value.Type1.Shifted_value Field.Constant.zero)
        ~dummy_scalar_challenge:(Sc.create Limb_vector.Challenge.Constant.zero)
        (Shifted_value.Type1.typ Field.typ)
        Other_field.typ
        (Snarky_backendless.Typ.unit ())
        Digest.typ
        (Branch_data.typ
           (module Impl)
           ~assert_16_bits:(Step_verifier.assert_n_bits ~n:16) )
    ; Plonk_types.All_evals.typ (module Impl) lookup_config
    ; Vector.typ (Vector.typ Field.typ Tick.Rounds.n) max_proofs_verified
    ; Vector.typ Inner_curve.typ max_proofs_verified
    ]
