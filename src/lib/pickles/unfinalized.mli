(** {1 Unfinalized - Deferred Proof Data for Wrap Verification}

    This module defines the structure of "unfinalized" proof data that flows
    from step circuits to wrap circuits. It contains deferred computations
    that the wrap circuit will finalize.

    {2 Overview}

    When a step circuit verifies a wrap proof, certain scalar-field operations
    cannot be performed efficiently (they would require non-native arithmetic).
    These operations are "deferred" and stored in the unfinalized proof.

    {2 What Gets Deferred}

    The unfinalized proof contains:
    - Deferred values (PLONK linearization scalars, combined_inner_product, b)
    - Sponge digest checkpoint for Fiat-Shamir consistency
    - Polynomial evaluations from the wrap proof
    - Bulletproof challenges for IPA verification

    {2 Constant vs Variable}

    - [Constant.t]: The concrete values (used in the prover)
    - [t]: Circuit variables (used in the circuit)

    {2 Usage Flow}

    {v
    Step Circuit                         Wrap Circuit
    ┌────────────────────────────┐      ┌────────────────────────────┐
    │ 1. Partially verify wrap   │      │ 1. Receive unfinalized     │
    │    proof                   │      │ 2. Verify deferred values  │
    │ 2. Create Unfinalized.t    │ ───► │ 3. Complete IPA check      │
    │    with deferred values    │      │ 4. Assert consistency      │
    │ 3. Pass to wrap prover     │      │                            │
    └────────────────────────────┘      └────────────────────────────┘
    v}

    {2 Dummy Values}

    For base cases (genesis proofs) where no real predecessor exists, dummy
    unfinalized proofs are used. The [should_finalize] flag indicates whether
    the wrap circuit should actually verify the deferred values.

    @see {!Step_verifier} for creating unfinalized proofs
    @see {!Wrap_verifier.finalize_other_proof} for finalizing them
*)

(** Constant (out-of-circuit) representation of unfinalized proofs. *)
module Constant : sig
  type t = Impls.Step.unfinalized_proof

  (** Lazy dummy value for base cases. Contains valid-looking but meaningless
      data that passes structural checks when finalization is skipped. *)
  val dummy : t Lazy.t
end

(** Circuit variable representation of unfinalized proofs. *)
type t = Impls.Step.unfinalized_proof_var

(** Type for converting between circuit and constant representations.
    @param wrap_rounds The number of IPA rounds (determines challenge count)
*)
val typ : wrap_rounds:'a -> (t, Constant.t) Impls.Step.Typ.t

(** Create a dummy unfinalized proof variable for base cases. *)
val dummy : unit -> t
