(** {1 Pickles - Recursive Zero-Knowledge Proof System}

    Pickles is a recursive SNARK composition system built on top of the Kimchi
    proof system and the Pasta curve cycle. It enables efficient incremental
    verification of computations.

    {2 Glossary}

    This glossary defines key terminology used throughout the Pickles recursive
    proof system. Understanding these terms is essential for working with or
    reimplementing Pickles.

    {3 Curve Terminology}

    {4 Tick (Vesta Curve)}

    The "inner" curve in Pickles' two-cycle. Corresponds to the {b Vesta} curve
    in the Pasta curve cycle. {b Step circuits} operate over Tick.

    - {b Base field (Fp):} The field over which curve points are defined
    - {b Scalar field (Fq):} The field of curve point scalars
    - {b Key property:} Tick's scalar field equals Tock's base field

    In code: {!module:Backend.Tick}, {!module:Impls.Step}

    {4 Tock (Pallas Curve)}

    The "outer" curve in Pickles' two-cycle. Corresponds to the {b Pallas} curve
    in the Pasta curve cycle. {b Wrap circuits} operate over Tock.

    - {b Base field (Fq):} The field over which curve points are defined
    - {b Scalar field (Fp):} The field of curve point scalars
    - {b Key property:} Tock's scalar field equals Tick's base field

    In code: {!module:Backend.Tock}, {!module:Impls.Wrap}

    {4 Pasta Curves}

    The pair of elliptic curves (Pallas and Vesta) that form a 2-cycle, meaning
    each curve's scalar field is the other's base field. This property enables
    efficient recursive proof composition without expensive non-native field
    arithmetic.

    {3 Circuit Terminology}

    {4 Step Circuit}

    A SNARK circuit that:
    + Executes application logic (the user's "inductive rule")
    + Partially verifies predecessor wrap proofs
    + Operates over the {b Tick (Vesta)} curve
    + Produces "unfinalized" proof data for the wrap circuit

    Step circuits handle the group operations for verifying wrap proofs but
    defer scalar-field computations to the wrap circuit (since Tick's scalar
    field = Tock's base field, those computations are native in wrap).

    In code: {!module:Step}, {!module:Step_main}, {!module:Step_verifier}

    {4 Wrap Circuit}

    A SNARK circuit that:
    + Verifies a step proof
    + Completes deferred scalar-field computations
    + Operates over the {b Tock (Pallas)} curve
    + Produces a proof that step circuits can verify

    Wrap circuits "wrap" step proofs into a uniform format suitable for
    recursive verification.

    In code: {!module:Wrap}, {!module:Wrap_main}, {!module:Wrap_verifier}

    {4 Why Constraint Generation?}

    In recursive SNARKs, we cannot simply "run" a verifier inside a circuit.
    Instead, we express the verification algorithm as arithmetic constraints
    over field elements. The {!module:Step_verifier} and {!module:Wrap_verifier}
    modules generate these constraints during circuit construction. The actual
    verification happens when a prover generates a proof - satisfying these
    constraints proves that the embedded proof was valid.

    {4 Correspondence with Kimchi Verifier}

    The IVC (incremental verifiable computation) steps in {!module:Step_verifier}
    and {!module:Wrap_verifier} essentially reimplement the Kimchi verifier as
    circuit constraints. The order and structure of these steps should match
    the Kimchi verifier implementation in Rust ([kimchi/src/verifier.rs]).
    Maintaining this correspondence is critical for correctness: any divergence
    between the in-circuit verifier and the native Kimchi verifier would break
    the recursive proof system.

    {4 Inductive Rule}

    User-defined circuit logic that specifies what a step circuit should
    compute and verify. An inductive rule:
    - Takes public input (app state)
    - Optionally references predecessor proofs
    - Produces public output
    - May produce auxiliary (private) output

    In code: {!module:Inductive_rule}, {!type:Inductive_rule.t}

    {4 Branch}

    A specific inductive rule within a proof system. A proof system with N
    different rules has N "branches." Each branch may verify different numbers
    of predecessor proofs.

    Example: A blockchain proof system might have:
    - Branch 0: Genesis (no predecessors)
    - Branch 1: Normal block (1 predecessor)
    - Branch 2: Merge (2 predecessors)

    {3 Proof Terminology}

    {4 Proofs Verified / Max Proofs Verified}

    - {b Proofs Verified:} The number of predecessor proofs a specific branch
      actually verifies (0, 1, or 2)
    - {b Max Proofs Verified:} The maximum across all branches in a proof system

    Current Pickles supports max_proofs_verified up to 2 (N0, N1, N2).

    In code: {!module:Pickles_base.Proofs_verified}, {!type:Nat.N2}

    {4 Unfinalized Proof}

    A step proof before being wrapped. Contains "deferred values" - scalar-field
    computations that could not be efficiently performed in the step circuit.
    The wrap circuit finalizes these computations.

    In code: {!type:Unfinalized.t}, [should_finalize] flag

    {4 Deferred Values}

    Scalar-field computations that are deferred from one circuit to another
    because they would require expensive non-native field arithmetic.

    When a step circuit (Tick) verifies a wrap proof (Tock), operations in
    Tock's scalar field (= Tick's base field) are native. But operations in
    Tick's scalar field would be non-native, so they are "deferred" to the
    wrap circuit where they become native.

    Deferred values include:
    - [combined_inner_product]: Batched polynomial evaluation result
    - [b]: Challenge polynomial evaluation
    - PlonK linearization scalars

    In code: {!module:Wrap.Proof_state.Deferred_values}

    {4 Messages for Next Step/Wrap Proof}

    Data passed between recursion layers, hashed to minimize public input size:

    - {b messages_for_next_step_proof:} Contains app state, verification key
      commitments, challenge polynomial commitments, old bulletproof challenges
    - {b messages_for_next_wrap_proof:} Contains the challenge polynomial
      commitment (sg) and old bulletproof challenges

    In code: {!module:Messages_for_next_proof_over_same_field.Step},
    {!module:Messages_for_next_proof_over_same_field.Wrap}

    {3 Accumulator / IPA Terminology}

    {4 Inner Product Argument (IPA)}

    The polynomial commitment opening protocol used by Pickles. Also called
    "Bulletproofs" in some contexts. The IPA allows proving that a committed
    polynomial evaluates to a claimed value at a given point.

    {b Deferred verification.} In recursive SNARKs, fully verifying an IPA
    opening proof inside a circuit would be prohibitively expensive. Instead,
    Pickles uses {e deferred} (or {e incremental}) verification: the in-circuit
    verifier does {b not} fully verify the polynomial opening proof. Rather,
    it:

    + Accumulates the IPA challenges into a new challenge polynomial [b(X)]
    + Produces a commitment [sg] to this polynomial
    + Passes [sg] (and associated challenges) to the next layer of recursion

    The actual verification of the IPA is "accumulated" across recursion layers
    rather than being performed in full at each step. This accumulation via the
    challenge polynomial is what makes Pickles efficient. See
    {!module:Step_verifier.incrementally_verify_proof} and
    {!module:Wrap_verifier.incrementally_verify_proof} for the in-circuit
    verifiers, and {!module:Step_verifier.finalize_other_proof} and
    {!module:Wrap_verifier.finalize_other_proof} for the deferred checks.

    {4 Bulletproof Challenges}

    The challenges generated during the IPA protocol. In each round of the
    IPA, a challenge is squeezed from the Fiat-Shamir transcript. These
    challenges are accumulated across recursive proof steps.

    In code: {!type:Bulletproof_challenge.t}, {!type:Step_bp_vec.t}

    {4 Challenge Polynomial b(X) - The Core of Recursion}

    The polynomial [b(X) = prod_i (1 + u_i * X^{2^{n-1-i}})] where [u_i] are the
    bulletproof challenges from the IPA. This polynomial is {b the key to
    efficient recursive verification}:

    + It encodes all IPA challenges as coefficients of a single polynomial
    + Its commitment [sg] serves as a compact "accumulator" of verification state
    + Evaluating [b(zeta)] and [b(zeta*omega)] replaces expensive in-circuit IPA
      verification with simple polynomial evaluation

    The challenge polynomial enables {e incremental verification}: rather than
    fully verifying each IPA inside a circuit (which would be too expensive),
    the verifier:

    1. Reconstructs [b(X)] from the bulletproof challenges
    2. Evaluates it at the required points ([zeta] and [zeta * omega])
    3. Checks that the evaluations are consistent with the combined inner
       product

    This deferred approach is what makes Pickles practical. Without it, each
    recursion layer would need to perform O(n) curve operations for IPA
    verification inside the circuit.

    In code: [challenge_polynomial] in {!module:Wrap_verifier},
    see also {!module:Step_verifier.finalize_other_proof}

    {4 Challenge Polynomial Commitment sg / sg_old - The Recursion Accumulator}

    The commitment to the challenge polynomial [b(X)], often called [sg] in the
    code. This is {b the fundamental accumulator} that carries IPA verification
    state across recursive proof layers:

    + [sg]: The challenge polynomial commitment from the {e current} proof
    + [sg_old]: Challenge polynomial commitments from {e previous} proofs being
      verified (one per predecessor proof)

    The [sg_old] values are absorbed into the Fiat-Shamir transcript at the
    beginning of verification, binding the current proof to its predecessors.
    This creates a chain of accumulated IPA state through the recursion.

    {b Why sg is critical:} Without [sg], each recursive step would need to
    fully re-verify all previous IPA proofs. Instead, [sg] compresses all
    previous IPA verification into a single curve point, enabling constant-size
    recursive proofs regardless of recursion depth.

    In code: [challenge_polynomial_commitment] in opening proofs,
    [sg_old] parameter in {!module:Step_verifier.verify} and
    {!module:Wrap_verifier.incrementally_verify_proof}

    {4 Combined Inner Product}

    The result of batching multiple polynomial evaluations using random
    challenges (xi and r):

    {[
    combined = sum_i (xi^i * f_i(zeta)) + r * sum_i (xi^i * f_i(zeta * omega))
    ]}

    This combines evaluations at two points (zeta and zeta*omega) into one
    value. Verification of this value is part of the deferred checks performed
    by {!module:Step_verifier.finalize_other_proof} and
    {!module:Wrap_verifier.finalize_other_proof}.

    {3 PlonK Terminology}

    {4 Alpha}

    The challenge used to combine constraint polynomials in PlonK. Different
    constraint types (gates, permutation, lookup) are combined as:

    {[
    combined = gate + alpha * permutation + alpha^2 * lookup + ...
    ]}

    {4 Beta and Gamma}

    Challenges used in the permutation argument. They randomize the permutation
    polynomial to ensure soundness.

    {4 Zeta}

    The evaluation point for polynomials. The prover evaluates all polynomials
    at zeta and zeta*omega (where omega is a root of unity).

    {4 Xi}

    The challenge used to batch polynomial openings. Multiple polynomial
    evaluations are combined into one opening using powers of xi.

    {4 Joint Combiner}

    Additional challenge used when lookup arguments are enabled, to combine
    lookup-related polynomials.

    {4 Shifted Value}

    A field element representation that shifts values to avoid certain
    problematic values (like 0). Two types exist:
    - {b Type1:} Used for Tick field elements in Wrap circuit. Simple shift.
    - {b Type2:} Used for Tock field elements in Step circuit. Split into
      high bits and low bit for efficient range checking.

    In code: {!type:Shifted_value.Type1}, {!type:Shifted_value.Type2}

    {3 Polynomial Commitment Notation}

    The verifiers ({!module:Step_verifier}, {!module:Wrap_verifier}) use specific
    notation for polynomial commitments and related values:

    {4 Prover Commitments}

    - {b w_comm:} Witness polynomial commitments. Contains the committed
      witness columns (w0 through w14 in Kimchi).
    - {b z_comm:} Permutation polynomial commitment. The commitment to the
      permutation accumulator polynomial used in the copy constraint argument.
    - {b t_comm:} Quotient polynomial commitment. The commitment to the
      quotient polynomial t(X) = (constraint polynomial) / Z_H(X) where Z_H
      is the vanishing polynomial.
    - {b lookup_sorted:} Sorted lookup polynomial commitments (when lookups
      are enabled).
    - {b lookup_aggreg:} Lookup aggregation polynomial commitment.
    - {b runtime_tables:} Runtime lookup table commitments (for dynamic lookups).

    {4 Derived Commitments}

    - {b x_hat:} Public input polynomial commitment. Computed from the public
      inputs using Lagrange basis commitments. Includes a blinding factor
      (adding generator H) to match the commitment format.
    - {b ft_comm:} Linearization polynomial commitment. A linear combination
      of verification key commitments and prover commitments that, when
      evaluated at zeta, gives the linearization evaluation. Computed from
      the verification key and sampled challenges.

    {4 IPA-Related Values}

    - {b sg:} Challenge polynomial commitment. The commitment to the
      challenge polynomial b(X), serving as the IPA accumulator across
      recursive steps.
    - {b sg_old:} Previous challenge polynomial commitments from predecessor
      proofs. These are absorbed into the Fiat-Shamir transcript.
    - {b L, R:} Left and right commitments from IPA rounds. Each round of the
      inner product argument produces one L and one R commitment.

    {4 Evaluation Values}

    - {b ft_eval1:} Evaluation of the linearization polynomial at zeta*omega.
      Part of the deferred values passed between circuits.
    - {b evals:} All polynomial evaluations at both zeta and zeta*omega.
      Includes witness, permutation, lookup, and verification key polynomial
      evaluations.

    See {!module:Step_verifier} and {!module:Wrap_verifier} for the complete
    verification flows using these values.

    {3 Type-Level Terminology}

    A key design principle of Pickles is to leverage OCaml's type system
    extensively. By encoding invariants at the type level (vector lengths,
    proof counts, circuit configurations), Pickles catches errors at compile
    time rather than runtime. This eliminates entire classes of bugs and makes
    the code more robust, though it results in complex type signatures.

    {4 MLMB (Max Local Max Proofs Verified)}

    The maximum [max_proofs_verified] across all predecessor proof systems
    referenced by all branches. Used for padding to create uniform proof sizes.

    {4 Nat, Nat.z, Nat.N2}

    Type-level natural numbers using Peano encoding:
    - [z] = zero (uninhabited type)
    - ['n s] = successor of n
    - [N2] = [z s s] (the number 2 at the type level)

    Used for compile-time verification of vector lengths and proof counts.

    {4 HList (H1, H2, H4)}

    Heterogeneous lists that can hold elements of different types. The number
    indicates how many type parameters each element has:
    - [H1.T(F)]: Elements have type ['a F.t]
    - [H4.T(F)]: Elements have type [('a, 'b, 'c, 'd) F.t]

    Used for type-safe operations on collections of predecessor proofs with
    different type parameters.

    {4 Vector.t}

    Length-indexed vectors: [('a, 'n) Vector.t] is a vector of ['a] with
    statically-known length ['n]. Enables compile-time length checking.

    {3 Statement Patterns}

    {4 Minimal vs In_circuit}

    Many types have two representations:
    - {b Minimal:} Compact format with only essential data (for serialization)
    - {b In_circuit:} Expanded format with derived values (for circuit use)

    The minimal form stores raw challenges; in_circuit form includes
    precomputed powers, linearization scalars, etc.

    {4 Stable vs Checked}

    - {b Stable:} Serialization-stable format for wire protocol
    - {b Checked:} Circuit variable representation with constraint checking

    {3 Challenge and Hash Flow Between Circuits}

    {4 Fiat-Shamir Transcript Flow}

    Pickles uses the Fiat-Shamir heuristic to make the interactive PlonK/IPA
    protocol non-interactive. A cryptographic sponge (Poseidon) absorbs
    commitments, public inputs, and prover messages, then squeezes out
    challenges. The general pattern involves:

    - Initializing the sponge with the verification key
    - Absorbing public inputs and prover commitments
    - Squeezing challenges (beta, gamma, alpha, zeta, xi)
    - Saving a checkpoint ([sponge_digest_before_evaluations])
    - Absorbing polynomial evaluations
    - Squeezing IPA challenges

    The specific transcript structure differs between Step and Wrap circuits
    due to the field crossing problem. See {!module:Step_verifier} and
    {!module:Wrap_verifier} for the IVC step diagrams showing the precise
    transcript flows in each circuit.

    {b Important:} Challenges from previous proof rounds are verified within
    the Step and Wrap circuits. Each circuit reconstructs the expected
    challenges by replaying the Fiat-Shamir transcript and asserts they match
    the challenges provided in the proof statement. This ensures the prover
    cannot manipulate challenges to break soundness.

    {4 Field Crossing Problem}

    The key challenge: when a step circuit (Tick) verifies a wrap proof (Tock),
    the challenges were computed in Tock's scalar field (= Tick's base field).
    But Tick's native field is its base field, so Tock's scalar field operations
    would be expensive non-native arithmetic.

    {b Solution:} The step circuit receives the challenges as witnesses (from the
    wrap proof's statement) and defers verification to the wrap circuit.

    {4 What Gets Passed vs Recomputed}

    {b Passed from Wrap to Step:}
    - [sponge_digest_before_evaluations]: Hash state at a checkpoint
    - [plonk] challenges: beta, gamma, alpha, zeta, xi (128-bit challenges)
    - [bulletproof_challenges]: IPA challenges from the wrap proof
    - [combined_inner_product] and [b]: Deferred scalar-field values

    {b Recomputed in Step:}
    The step circuit does not recompute the wrap proof's challenges. Instead:
    + It uses the challenges from the wrap statement
    + It verifies that these challenges are consistent with the proof
    + Group operations (native in step) are verified directly
    + Scalar operations (non-native) are deferred to wrap

    {b Passed from Step to Wrap:}
    - [sponge_digest_before_evaluations]: For transcript consistency
    - Unfinalized proof data for predecessor verification
    - [messages_for_next_step_proof]: Hash of accumulated data

    {b Recomputed in Wrap:}
    The wrap circuit recomputes step's challenges because Tick's scalar field
    operations are native in wrap (Tick scalar = Tock base). It:
    + Reconstructs the sponge from the step verification key
    + Absorbs the public input and prover messages
    + Squeezes challenges and verifies they match
    + Completes the deferred scalar-field checks

    See {!module:Step_verifier.finalize_other_proof} for deferred value
    verification and {!module:Wrap_verifier.incrementally_verify_proof} for
    the Fiat-Shamir transcript reconstruction.

    {4 The sponge_digest_before_evaluations Checkpoint}

    This digest captures the sponge state just before polynomial evaluations
    are absorbed. It serves as:
    + A commitment to the transcript up to that point
    + A checkpoint for resuming the sponge in the verifying circuit
    + Part of the proof's public input (statement)

    When verifying, the circuit:
    + Initializes a fresh sponge
    + Absorbs verification key, public input, prover messages
    + Squeezes challenges (beta, gamma, alpha, zeta, xi)
    + Asserts the sponge state equals [sponge_digest_before_evaluations]
    + Continues absorbing evaluations and squeezing IPA challenges

    {4 Hash Function Compatibility}

    Pickles uses Poseidon hash over the native field of each circuit:
    - Step circuits: Poseidon over Tick base field (Fp)
    - Wrap circuits: Poseidon over Tock base field (Fq)

    The [Messages_for_next_step_proof] and [Messages_for_next_wrap_proof] are
    hashed to single field elements to minimize public input size. The receiving
    circuit verifies this hash matches the expanded data.

    {3 Recursion Structure: Base Case, Induction, and Final Proofs}

    {v
    BASE CASE (Genesis)
    -------------------

                    +-------------+
       (no input)   |    Step     |   Unfinalized
          --------->|   Circuit   |------------------+
                    |  (Tick)     |                  |
                    +-------------+                  |
                                                     v
                                              +-------------+
                                              |    Wrap     |   Wrap Proof
                                              |   Circuit   |-------------->
                                              |  (Tock)     |
                                              +-------------+


    INDUCTION STEP
    --------------

     Wrap Proof(s)  +-------------+
      from prev     |    Step     |   Unfinalized
          --------->|   Circuit   |------------------+
                    |  (Tick)     |                  |
                    +-------------+                  |
                          |                         |
                          | Verifies prev           |
                          | wrap proof(s)           v
                          |                   +-------------+
                          |                   |    Wrap     |   Wrap Proof
                          +------------------>|   Circuit   |-------------->
                            Deferred values   |  (Tock)     |
                                              +-------------+
                                                     |
                                                     |
                    +--------------------------------+
                    | Can be verified at any point,
                    | or fed into next iteration
                    v
    v}

    For the detailed circuit implementations, see {!module:Step_main} for the
    Step circuit and {!module:Wrap_main} for the Wrap circuit.

    {4 Base Case (Genesis / Initial Step)}

    When a proof system starts, there are no predecessor proofs to verify. This
    is handled by:

    + {b proofs_verified = 0:} The rule specifies no predecessor proofs
    + {b Dummy proofs:} Placeholder proofs that "pass" verification trivially
    + {b proof_must_verify = false:} Tells the circuit to skip verification

    The step circuit has special handling:
    - When [is_base_case = true], verification is skipped
    - Dummy bulletproof challenges are used (all zeros)
    - The wrap proof still contains the dummy accumulator data

    {4 Induction Step}

    After the base case, each new proof verifies 1 or 2 predecessor proofs:
    + The rule's [prevs] specifies which proof systems to verify
    + The step circuit verifies wrap proofs from those systems
    + Deferred computations are passed to the wrap circuit
    + The wrap circuit produces a new wrap proof for the next iteration

    {4 What is the Final Proof?}

    There is no "final" proof in the traditional sense - recursion can continue
    indefinitely. At any point, you have:

    {b A wrap proof} (type ['n Proof.t]) containing:
    - [statement]: The public input/output (app state, challenges, digests)
    - [prev_evals]: Polynomial evaluations at zeta and zeta*omega
    - [proof]: The kimchi wrap proof (commitments + opening proof) *)

include
  Pickles_intf.S
    with type Side_loaded.Verification_key.Stable.V2.t =
      Mina_wire_types.Pickles.Side_loaded.Verification_key.V2.t
     and type 'a Proof.t = 'a Mina_wire_types.Pickles.Proof.t
