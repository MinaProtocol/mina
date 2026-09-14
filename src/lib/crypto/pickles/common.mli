(** {1 Common - Shared Utilities for Pickles}

    This module provides shared utilities, constants, and helper functions
    used throughout the Pickles proof system. It includes domain configuration,
    IPA (Inner Product Argument) helpers, field shifts, and public input
    conversion functions. *)

(** {2 Domain Configuration} *)

(** [wrap_domains ~proofs_verified] computes the circuit domain configuration
    for wrap circuits based on the number of proofs being verified.
    The domain size affects the maximum circuit complexity.

    @param proofs_verified must be 0, 1, or 2
    @raise Assert_failure if [proofs_verified] is not in [0, 1, 2] *)
val wrap_domains : proofs_verified:int -> Import.Domains.Stable.V2.t

(** [actual_wrap_domain_size ~log_2_domain_size] returns the proofs verified
    count that corresponds to a given domain size (as log base 2). *)
val actual_wrap_domain_size :
  log_2_domain_size:int -> Pickles_base.Proofs_verified.t

(** {2 Profiling} *)

(** [when_profiling profiling default] returns [profiling] when environment
    variable [PICKLES_PROFILING] is set to anything else than [0] or [false],
    [default] otherwise.

    TODO: This function should use labels to avoid mistakenly interverting
    profiling and default cases.
 *)
val when_profiling : 'a -> 'a -> 'a

(** [time label f] times function [f] and prints the measured time to [stdout]
    prepended with [label], when profiling is set (see {!val:when_profiling}).

    Otherwise, it just runs [f].
 *)
val time : string -> (unit -> 'a) -> 'a

(** {2 FFT Coset Shifts} *)

(** [tick_shifts ~log2_size] computes the coset shifts for FFT operations
    on the Tick (Vesta) curve for a domain of size [2^log2_size]. *)
val tick_shifts : log2_size:int -> Pasta_bindings.Fp.t array

(** [tock_shifts ~log2_size] computes the coset shifts for FFT operations
    on the Tock (Pallas) curve for a domain of size [2^log2_size]. *)
val tock_shifts : log2_size:int -> Pasta_bindings.Fq.t array

(** {2 Utility Functions} *)

(** [group_map (module F) ~a ~b] creates a staged function that maps field
    elements to curve points using the group map algorithm. The curve is
    defined by parameters [a] and [b] (for y^2 = x^3 + ax + b). *)
val group_map :
     (module Group_map.Field_intf.S_unchecked with type t = 'a)
  -> a:'a
  -> b:'a
  -> ('a -> 'a * 'a) Core.Staged.t

(** [bits_to_bytes bits] converts a list of booleans to a byte string.
    Each group of 8 bits is packed into a character. *)
val bits_to_bytes : bool list -> string

(** [finite_exn v] returns [(a, b)] when [v] is {!val:Finite(a,b)},
    [Invalid_argument] otherwise.*)
val finite_exn : 'a Kimchi_types.or_infinity -> 'a * 'a

(** {2 PLONK Commitment Operations} *)

(** [ft_comm ~add ~scale ~negate ~verification_key ~plonk ~t_comm] computes
    the commitment to the linearization polynomial (called ft in the codebase)
    used in PLONK verification. This combines verification key commitments with
    PLONK challenges and the T polynomial commitment.

    @param add Group addition operation
    @param scale Scalar multiplication operation
    @param negate Group negation operation
    @param verification_key The verification key commitments
    @param plonk The PLONK challenges and deferred values
    @param t_comm The T polynomial commitment *)
val ft_comm :
     add:('comm -> 'comm -> 'comm)
  -> scale:('comm -> 'scalar -> 'comm)
  -> negate:('comm -> 'comm)
  -> verification_key:'comm array Pickles_types.Plonk_verification_key_evals.t
  -> plonk:
       ( 'd
       , 'e
       , 'scalar
       , 'g
       , 'f
       , 'bool )
       Import.Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit.t
  -> t_comm:'comm array
  -> 'comm

(** [combined_evaluation (module Impl) ~xi evaluations] combines multiple
    polynomial evaluations using powers of the challenge [xi]. This is used
    to batch multiple polynomial openings into a single check.

    @param xi The batching challenge
    @param evaluations List of optional evaluation arrays to combine *)
val combined_evaluation :
     (module Snarky_backendless.Snark_intf.Run
        with type field = 'f
         and type field_var = 'v )
  -> xi:'v
  -> ('v, 'v Snarky_backendless.Boolean.t) Pickles_types.Opt.t array list
  -> 'v

(** {2 Polynomial Degree Limits} *)

(** Maximum polynomial degrees for circuits. These constants define the
    upper bounds on polynomial complexity in step and wrap circuits. *)
module Max_degree : sig
  (** Log base 2 of the maximum degree for wrap circuits. *)
  val wrap_log2 : int

  (** Maximum degree for step circuits. *)
  val step : int

  (** Log base 2 of the maximum degree for step circuits. *)
  val step_log2 : int
end

(** {2 Field Shifts} *)

(** Shift constants for encoding field elements across circuit types.
    These shifts are used in the shifted value representation to avoid
    certain problematic values. *)
module Shifts : sig
  (** Shift for Type1 encoding of Tick field elements (used in wrap circuits). *)
  val tick1 : Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.Shift.t

  (** Shift for Type2 encoding of Tock field elements (used in step circuits). *)
  val tock2 : Backend.Tock.Field.t Pickles_types.Shifted_value.Type2.Shift.t
end

(** {2 Inner Product Argument (IPA)} *)

(** IPA helper functions for computing challenges and verifying accumulators.
    The Inner Product Argument is the polynomial commitment opening protocol
    used by Pickles (also known as Bulletproofs).

    {3 Challenge Polynomial Commitment (sg)}

    In the IPA protocol, the prover and verifier engage in a logarithmic-round
    protocol where each round produces a challenge [u_i]. These challenges
    define the {b challenge polynomial}:

    {v b(X) = prod_i (1 + u_i * X^{2^{n-1-i}}) v}

    where [n] is the number of rounds (equal to [log2(domain_size)]).

    The {b challenge polynomial commitment}, commonly called [sg] in the
    codebase, is a commitment to this polynomial [b(X)] using the structured
    reference string (SRS). It serves as an {b accumulator} that carries the
    IPA verification state across recursive proof steps.

    In recursive proving, rather than fully verifying each inner proof's IPA,
    we defer the expensive final check. The [sg] commitment summarizes all the
    challenges from a proof's IPA, allowing the next proof layer to:
    - Inherit and verify the accumulated challenges
    - Combine multiple [sg] commitments when verifying multiple proofs

    The [sg] is computed via the Kimchi bindings:
    - [Kimchi_bindings.Protocol.SRS.Fp.b_poly_commitment] for Tick/Vesta
    - [Kimchi_bindings.Protocol.SRS.Fq.b_poly_commitment] for Tock/Pallas

    The final [accumulator_check] verifies that the [sg] commitments are
    consistent with their claimed challenge vectors, completing the deferred
    IPA verifications in a single batch.

    This deferred IPA verification / accumulator technique is described in
    {{: https://eprint.iacr.org/2020/499.pdf} Proof-Carrying Data from
    Accumulation Schemes (ePrint 2020/499)}, specifically the accumulation
    scheme in Section 4.

    {3 Scalar Challenges}

    Scalar challenges are 128-bit values derived from the Fiat-Shamir transcript
    during the IPA protocol. They are represented as [Challenge.Constant.t
    Scalar_challenge.t] where the inner [Challenge.Constant.t] holds the 128-bit
    value as a pair of 64-bit limbs. The [endo_to_field] functions convert these
    scalar challenges to full field elements using the curve's endomorphism.

    {3 Type Parameters}

    The IPA module uses two type parameters throughout:

    - ['a] is a type-level natural number representing the vector length
      (number of IPA rounds). This is typically instantiated with
      [Backend.Tick.Rounds.n] or [Backend.Tock.Rounds.n]. Using a type
      parameter allows the same code to work both inside circuits (where
      lengths must be statically known for constraint generation) and outside
      circuits (for concrete computations).

    - ['b] is the field type for curve point coordinates. This is instantiated
      with [Pasta_bindings.Fp.t] for Tock/Pallas points or [Pasta_bindings.Fq.t]
      for Tick/Vesta points. *)
module Ipa : sig
  (** A vector of bulletproof challenges from the IPA protocol.
      Each challenge is derived from a scalar challenge produced during
      one round of the IPA reduction.

      @param 'a type-level natural for the vector length (number of rounds) *)
  type 'a challenge :=
    ( Import.Challenge.Constant.t Import.Scalar_challenge.t
      Import.Bulletproof_challenge.t
    , 'a )
    Pickles_types.Vector.t

  (** Function type for computing the challenge polynomial commitment [sg]
      from bulletproof challenges. Given a vector of challenges [u_0, ..., u_{n-1}],
      computes a commitment to b(X) = prod_i (1 + u_i * X^{2^{n-1-i}}).
      Returns the (x, y) coordinates of the commitment point.

      @param 'a type-level natural for challenge vector length
      @param 'b field type for point coordinates (Fp or Fq) *)
  type ('a, 'b) compute_sg := 'a challenge -> 'b * 'b

  (** IPA functions for wrap circuits (operating over Tock/Pallas). *)
  module Wrap : sig
    (** Compute a single IPA challenge from a scalar challenge. *)
    val compute_challenge :
         Import.Challenge.Constant.t Import.Scalar_challenge.t
      -> Backend.Tock.Field.t

    (** Convert an endomorphism-encoded scalar challenge to a field element. *)
    val endo_to_field :
         Import.Challenge.Constant.t Import.Scalar_challenge.t
      -> Backend.Tock.Field.t

    (** Compute all IPA challenges from bulletproof challenge vector. *)
    val compute_challenges :
      'a challenge -> (Backend.Tock.Field.t, 'a) Pickles_types.Vector.t

    (** Compute the challenge polynomial commitment [sg] for wrap circuits.
        This commits to b(X) = prod_i (1 + u_i * X^{2^{n-1-i}}) using the Tock SRS.
        Returns point coordinates in Fp (Tick's base field, since Tock/Pallas
        curve points have Fp coordinates). *)
    val compute_sg : ('a, Pasta_bindings.Fp.t) compute_sg
  end

  (** IPA functions for step circuits (operating over Tick/Vesta). *)
  module Step : sig
    (** Compute a single IPA challenge from a scalar challenge. *)
    val compute_challenge :
         Import.Challenge.Constant.t Import.Scalar_challenge.t
      -> Backend.Tick.Field.t

    (** Convert an endomorphism-encoded scalar challenge to a field element. *)
    val endo_to_field :
         Import.Challenge.Constant.t Import.Scalar_challenge.t
      -> Backend.Tick.Field.t

    (** Compute all IPA challenges from bulletproof challenge vector. *)
    val compute_challenges :
      'a challenge -> (Backend.Tick.Field.t, 'a) Pickles_types.Vector.t

    (** Compute the challenge polynomial commitment [sg] for step circuits.
        This commits to b(X) = prod_i (1 + u_i * X^{2^{n-1-i}}) using the Tick SRS.
        Returns point coordinates in Fq (Tock's base field, since Tick/Vesta
        curve points have Fq coordinates). *)
    val compute_sg : ('a, Pasta_bindings.Fq.t) compute_sg

    (** Verify a list of IPA accumulators in batch. Each accumulator consists of:
        - A point [(x, y)]: the [sg] commitment (challenge polynomial commitment)
        - A vector of challenges: the IPA challenges [u_0, ..., u_{n-1}]

        This performs the deferred IPA verification by checking that each [sg]
        is indeed a valid commitment to the challenge polynomial
        b(X) = prod_i (1 + u_i * X^{2^{n-1-i}}) derived from its challenge vector.

        Returns [true] if all accumulators are valid. This is the final step
        that completes the recursive proof verification by validating all
        accumulated IPA states. *)
    val accumulator_check :
         ( (Pasta_bindings.Fq.t * Pasta_bindings.Fq.t)
         * (Pasta_bindings.Fp.t, 'a) Pickles_types.Vector.t )
         list
      -> bool Promise.t
  end
end

(** {2 Proof Message Hashing} *)

(** [hash_messages_for_next_step_proof ~app_state messages] computes a hash
    digest of the messages passed to the next step proof. This digest is
    used to minimize public input size by hashing verification key commitments,
    application state, challenge polynomial commitments, and bulletproof
    challenges into a single field element.

    @param app_state Function to convert application state to field elements
    @param messages The messages structure containing VK, app state, and challenges *)
val hash_messages_for_next_step_proof :
     app_state:('a -> Kimchi_pasta.Basic.Fp.Stable.Latest.t Core.Array.t)
  -> ( Backend.Tock.Curve.Affine.t array
     (* the type for the verification key *)
     , 'a
     (* the state of the application *)
     , ( Kimchi_pasta.Basic.Fp.Stable.Latest.t
         * Kimchi_pasta.Basic.Fp.Stable.Latest.t
       , 'n )
       Pickles_types.Vector.t
     (* challenge polynomial commitments. We use the full parameter type to
        restrict the size of the vector to be the same than the one for the next
        parameter which are the bulletproof challenges *)
     , ( (Kimchi_pasta.Basic.Fp.Stable.Latest.t, 'm) Pickles_types.Vector.t
       , 'n
       (* size of the vector *) )
       Pickles_types.Vector.t
     (* bulletproof challenges *) )
     Import.Types.Step.Proof_state.Messages_for_next_step_proof.t
  -> Import.Types.Digest.Constant.t

(** {2 Public Input Conversion} *)

(** [tick_public_input_of_statement ~max_proofs_verified statement] converts
    a step circuit statement into a list of Tick field elements for use as
    the circuit's public input.

    @param max_proofs_verified Type-level natural for padding
    @param statement The step statement to convert *)
val tick_public_input_of_statement :
     max_proofs_verified:'max_proofs_verified Pickles_types.Nat.t
  -> 'max_proofs_verified Impls.Step.statement
  -> Backend.Tick.Field.Vector.elt list

(** [tock_public_input_of_statement ~feature_flags statement] converts a wrap
    circuit statement into a list of Tock field elements for use as the
    circuit's public input. The output is padded to the expected size.

    @param feature_flags Flags indicating which optional features are enabled
    @param statement The wrap statement to convert *)
val tock_public_input_of_statement :
     feature_flags:
       Pickles_types.Opt.Flag.t Pickles_types.Plonk_types.Features.Full.t
  -> ( Limb_vector.Challenge.Constant.t
     , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
       option
     , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
       option
     , bool
     , Import.Types.Digest.Constant.t
     , Import.Types.Digest.Constant.t
     , Import.Types.Digest.Constant.t
     , ( Limb_vector.Challenge.Constant.t
         Kimchi_backend_common.Scalar_challenge.t
         Composition_types.Bulletproof_challenge.t
       , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
     , Composition_types.Branch_data.t )
     Import.Types.Wrap.Statement.In_circuit.t
  -> Backend.Tock.Field.Vector.elt list

(** [tock_unpadded_public_input_of_statement ~feature_flags statement] converts
    a wrap circuit statement into a list of Tock field elements without padding.
    Use this when the actual unpadded size is needed.

    @param feature_flags Flags indicating which optional features are enabled
    @param statement The wrap statement to convert *)
val tock_unpadded_public_input_of_statement :
     feature_flags:
       Pickles_types.Opt.Flag.t Pickles_types.Plonk_types.Features.Full.t
  -> ( Limb_vector.Challenge.Constant.t
     , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
     , Impls.Wrap.Other_field.Constant.t Pickles_types.Shifted_value.Type1.t
       option
     , Limb_vector.Challenge.Constant.t Composition_types.Scalar_challenge.t
       option
     , bool
     , Import.Types.Digest.Constant.t
     , Import.Types.Digest.Constant.t
     , Import.Types.Digest.Constant.t
     , ( Limb_vector.Challenge.Constant.t
         Kimchi_backend_common.Scalar_challenge.t
         Composition_types.Bulletproof_challenge.t
       , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
     , Composition_types.Branch_data.t )
     Import.Types.Wrap.Statement.In_circuit.t
  -> Backend.Tock.Field.Vector.elt list
