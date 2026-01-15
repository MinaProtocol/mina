(** {1 Wrap Verifier - Verification Logic for Wrap Circuits}

    This module provides the verification logic used within wrap circuits
    to verify step proofs and finalize deferred computations.

    {2 Overview}

    The wrap verifier is responsible for:
    1. Incrementally verifying step proofs (group operations + IPA)
    2. Finalizing deferred scalar-field checks from step's unfinalized proofs
    3. Computing challenge polynomials for IPA verification
    4. Managing branch selection for multi-rule proof systems

    {2 Context: Wrap Circuit Verification}

    When a wrap circuit verifies a step proof:
    - Group operations (curve additions, scalar mults) are performed directly
    - Scalar-field operations in Tick's scalar field are native (efficient)
    - The IPA is verified incrementally, producing new challenges

    {2 Key Functions}

    - {!val:incrementally_verify_proof}: Main verification function for step
      proofs
    - {!val:finalize_other_proof}: Completes deferred checks from step's
      unfinalized proofs
    - {!val:challenge_polynomial}: Computes b(X) = prod_i (1 + u_i X^{2^i})
    - {!val:choose_key}: Selects verification key based on branch

    {2 Challenge Polynomial}

    The challenge polynomial is:

    {v
    b(X) = prod_{i=0}^{k-1} (1 + chals[i] * X^{2^{k-1-i}})
    v}

    where [chals] are the IPA/bulletproof challenges. This polynomial is
    evaluated at zeta and zeta*omega as part of the IPA verification.

    {2 Implementation Notes for Rust Port}

    - Uses [Impl] (Wrap implementation) for field operations
    - [Other_field.Packed] refers to Tick's base field (= Tock's scalar)
    - [Shifted_value.Type1] handles field element representation
    - [One_hot_vector] encodes branch selection efficiently
    - The [Opt] sponge handles optional absorptions for feature flags

    @see <../GLOSSARY.md> for terminology definitions
    @see {!Wrap_main} for the wrap circuit entry point
    @see {!Step_verifier} for the corresponding step-side verifier
*)

module Impl := Impls.Wrap

(** [challenge_polynomial (module F) chals] returns a staged function that
    evaluates the challenge polynomial at a given point.

    The challenge polynomial is:
    {v b(X) = prod_{i=0}^{k-1} (1 + chals[i] * X^{2^{k-1-i}}) v}

    @param (module F) Field implementation with arithmetic operations
    @param chals Array of IPA challenges
    @return Staged function [pt -> b(pt)]

    Note: Uses Horner-like evaluation for efficiency. The staged structure
    allows computing X^{2^i} powers once and reusing.
*)
val challenge_polynomial :
     (module Pickles_types.Shifted_value.Field_intf with type t = 'a)
  -> 'a array
  -> ('a -> 'a) Core_kernel.Staged.t

type ('a, 'a_opt) index' =
  ('a, 'a_opt) Pickles_types.Plonk_verification_key_evals.Step.t

module Challenge : module type of Import.Challenge.Make (Impl)

module Digest : module type of Import.Digest.Make (Impl)

module Scalar_challenge :
    module type of
      Scalar_challenge.Make
        (Wrap_main_inputs.Impl)
        (Wrap_main_inputs.Inner_curve)
        (Challenge)
        (Endo.Wrap_inner_curve)

module Other_field : sig
  module Packed : sig
    type t = Impl.Other_field.t

    val typ : (Impl.Impl.Field.t, Backend.Tick.Field.t) Impls.Wrap_impl.Typ.t
  end
end

module One_hot_vector : module type of One_hot_vector.Make (Impl)

module Pseudo : module type of Pseudo.Make (Impl)

module Opt : sig
  include module type of
      Opt_sponge.Make (Impl) (Wrap_main_inputs.Sponge.Permutation)
end

val all_possible_domains :
  ( unit
  , ( Pickles_base.Domain.Stable.V1.t
    , Wrap_hack.Padded_length.n Pickles_types.Nat.s )
    Pickles_types.Vector.t )
  Core_kernel.Memo.fn

val num_possible_domains :
  Wrap_hack.Padded_length.n Pickles_types.Nat.s Pickles_types.Nat.t

(** [assert_n_bits ~n x] asserts that field element [x] fits in [n] bits.

    Uses scalar challenge conversion for efficient bit-length checking.
*)
val assert_n_bits : n:int -> Impl.Field.t -> unit

(** [incrementally_verify_proof] is the main verification function for step
    proofs within wrap circuits.

    This function performs "incremental" verification: it verifies most of
    the proof but defers certain computations for efficiency. The result
    includes new bulletproof challenges that will be used in the next
    recursion layer.

    {3 Verification Steps}

    1. Select step domain based on which_branch
    2. Compute public input commitment from packed statement
    3. Reconstruct Fiat-Shamir transcript, absorbing:
       - Verification key commitments
       - Public input
       - Prover messages (witness, z, t commitments)
    4. Squeeze PLONK challenges (beta, gamma, alpha, zeta, xi)
    5. Verify PLONK equation via batched opening
    6. Run IPA verification with bullet_reduce
    7. Return sponge digest and bulletproof challenges

    {3 Key Parameters}

    @param max_proofs_verified Module witnessing the maximum proof count
    @param actual_proofs_verified_mask Boolean vector indicating which
      predecessor slots contain real proofs (vs. dummies)
    @param step_domains Domain configurations for each branch
    @param srs Structured Reference String
    @param verification_key Step circuit verification key (commitments)
    @param xi Polynomial batching challenge (from statement)
    @param sponge The Fiat-Shamir sponge (Opt variant for optional absorbs)
    @param public_input The step statement, packed for the circuit
    @param sg_old Old challenge polynomial commitments
    @param advice Contains [b] and [combined_inner_product] from statement
    @param messages Prover's commitments during the protocol
    @param which_branch One-hot encoding of which rule was used
    @param openings_proof The IPA opening proof
    @param plonk PLONK deferred values from the statement

    @return Tuple of:
    - Sponge digest before evaluations (for consistency check)
    - Tuple of (success boolean, new bulletproof challenges)

    BEWARE: The [actual_proofs_verified_mask] must match the [branch_data]
    in the statement, or verification will fail.
*)
val incrementally_verify_proof :
     (module Pickles_types.Nat.Add.Intf with type n = 'b)
  -> actual_proofs_verified_mask:
       ( Wrap_main_inputs.Impl.Field.t Snarky_backendless.Boolean.t
       , 'b )
       Pickles_types.Vector.t
  -> step_domains:(Import.Domains.t, 'a) Pickles_types.Vector.t
  -> srs:Kimchi_bindings.Protocol.SRS.Fp.t
  -> verification_key:
       ( Wrap_main_inputs.Inner_curve.t array
       , ( Wrap_main_inputs.Inner_curve.t array
         , Impl.Boolean.var )
         Pickles_types.Opt.t )
       Pickles_types.Plonk_verification_key_evals.Step.t
  -> xi:Scalar_challenge.t
  -> sponge:Opt.t
  -> public_input:
       [ `Field of
         Wrap_main_inputs.Impl.Field.t * Wrap_main_inputs.Impl.Boolean.var
       | `Packed_bits of Wrap_main_inputs.Impl.Field.t * int ]
       array
  -> sg_old:
       ( Wrap_main_inputs.Impl.Field.t * Wrap_main_inputs.Impl.Field.t
       , 'b )
       Pickles_types.Vector.t
  -> advice:
       Other_field.Packed.t Pickles_types.Shifted_value.Type1.t
       Import.Types.Step.Bulletproof.Advice.t
  -> messages:
       ( Wrap_main_inputs.Impl.Field.t * Wrap_main_inputs.Impl.Field.t
       , Wrap_main_inputs.Impl.Boolean.var )
       Pickles_types.Plonk_types.Messages.In_circuit.t
  -> which_branch:'a One_hot_vector.t
  -> openings_proof:
       ( Wrap_main_inputs.Inner_curve.t
       , Other_field.Packed.t Pickles_types.Shifted_value.Type1.t )
       Pickles_types.Plonk_types.Openings.Bulletproof.t
  -> plonk:
       ( Wrap_main_inputs.Impl.Field.t
       , Wrap_main_inputs.Impl.Field.t Import.Scalar_challenge.t
       , Wrap_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
       , ( Wrap_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
         , Wrap_main_inputs.Impl.Boolean.var )
         Pickles_types.Opt.t
       , ( Wrap_main_inputs.Impl.Field.t Import.Scalar_challenge.t
         , Wrap_main_inputs.Impl.Boolean.var )
         Pickles_types.Opt.t
       , Wrap_main_inputs.Impl.Boolean.var )
       Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
  -> Wrap_main_inputs.Impl.Field.t
     * ( [> `Success of Wrap_main_inputs.Impl.Boolean.var ]
       * Scalar_challenge.t Import.Bulletproof_challenge.t Core_kernel.Array.t
       )

(** [finalize_other_proof] completes deferred scalar-field checks from
    step circuits.

    When a step circuit partially verifies wrap proofs, it defers certain
    scalar operations (in Tick's scalar field = Tock's base field). The
    wrap circuit calls this function to complete those checks.

    {3 Process}

    1. Absorb polynomial evaluations into the sponge
    2. Squeeze IPA challenges
    3. Compute challenge polynomial evaluation at zeta
    4. Verify [combined_inner_product] matches the expected value
    5. Verify [b] (challenge polynomial eval) matches

    @param max_proofs_verified Module witnessing max predecessor count
    @param domain Domain object with generator, shifts, and vanishing poly
    @param sponge Fiat-Shamir sponge (already initialized with prior state)
    @param old_bulletproof_challenges Challenges from previous recursion
    @param deferred_values The values deferred from step's partial verify
    @param evals Polynomial evaluations at zeta and zeta*omega

    @return Tuple of:
    - Boolean indicating if finalization succeeded
    - Vector of new bulletproof challenges

    Note: Uses [Shifted_value.Type2] for field elements, which splits into
    high bits and low bit for efficient range checking.
*)
val finalize_other_proof :
     (module Pickles_types.Nat.Add.Intf with type n = 'b)
  -> domain:
       < generator : Wrap_main_inputs.Impl.Field.t
       ; shifts : Wrap_main_inputs.Impl.Field.t array
       ; vanishing_polynomial : Impl.Field.t -> Impl.Field.t
       ; .. >
  -> sponge:Wrap_main_inputs.Sponge.t
  -> old_bulletproof_challenges:
       ( (Wrap_main_inputs.Impl.Field.t, 'a) Pickles_types.Vector.t
       , 'b )
       Pickles_types.Vector.t
  -> ( Impl.Field.t
     , Impl.Field.t Import.Scalar_challenge.t
     , Impl.Field.t Pickles_types.Shifted_value.Type2.t
     , ( Impl.Field.t Import.Scalar_challenge.t Import.Bulletproof_challenge.t
       , 'c )
       Pickles_types.Vector.t )
     Import.Types.Step.Proof_state.Deferred_values.In_circuit.t
  -> ( Wrap_main_inputs.Impl.Field.t
     , Wrap_main_inputs.Impl.Field.t Array.t
     , Wrap_main_inputs.Impl.Boolean.var )
     Pickles_types.Plonk_types.All_evals.In_circuit.t
  -> Wrap_main_inputs.Impl.Boolean.var
     * (Impl.Field.t, 'c) Pickles_types.Vector.t

(** [choose_key which_branch keys] selects the verification key for the
    active branch.

    Uses the one-hot encoding of [which_branch] to linearly combine
    all verification keys, effectively selecting the active one.

    @param which_branch One-hot vector indicating which branch is active
    @param keys Vector of verification keys, one per branch
    @return The verification key for the active branch

    Note: This uses scalar multiplication by the boolean indicators,
    resulting in the selected key. Inactive keys are zeroed out.
*)
val choose_key :
  'n.
     'n One_hot_vector.t
  -> ( ( Wrap_main_inputs.Inner_curve.t array
       , ( Wrap_main_inputs.Inner_curve.t array
         , Impl.Boolean.var )
         Pickles_types.Opt.t )
       index'
     , 'n )
     Pickles_types.Vector.t
  -> ( Wrap_main_inputs.Inner_curve.t array
     , ( Wrap_main_inputs.Inner_curve.t array
       , Impl.Boolean.var )
       Pickles_types.Opt.t )
     index'
