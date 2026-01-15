# Pickles Glossary

This glossary defines key terminology used throughout the Pickles recursive
proof system. Understanding these terms is essential for working with or
reimplementing Pickles.

## Curve Terminology

### Tick (Vesta Curve)

The "inner" curve in Pickles' two-cycle. Corresponds to the **Vesta** curve
in the Pasta curve cycle. **Step circuits** operate over Tick.

- **Base field (Fp):** The field over which curve points are defined
- **Scalar field (Fq):** The field of curve point scalars
- **Key property:** Tick's scalar field equals Tock's base field

In code: `Backend.Tick`, `Impls.Step`

### Tock (Pallas Curve)

The "outer" curve in Pickles' two-cycle. Corresponds to the **Pallas** curve
in the Pasta curve cycle. **Wrap circuits** operate over Tock.

- **Base field (Fq):** The field over which curve points are defined
- **Scalar field (Fp):** The field of curve point scalars
- **Key property:** Tock's scalar field equals Tick's base field

In code: `Backend.Tock`, `Impls.Wrap`

### Pasta Curves

The pair of elliptic curves (Pallas and Vesta) that form a 2-cycle, meaning
each curve's scalar field is the other's base field. This property enables
efficient recursive proof composition without expensive non-native field
arithmetic.

## Circuit Terminology

### Step Circuit

A SNARK circuit that:
1. Executes application logic (the user's "inductive rule")
2. Partially verifies predecessor wrap proofs
3. Operates over the **Tick (Vesta)** curve
4. Produces "unfinalized" proof data for the wrap circuit

Step circuits handle the group operations for verifying wrap proofs but
defer scalar-field computations to the wrap circuit (since Tick's scalar
field = Tock's base field, those computations are native in wrap).

In code: `step.ml`, `step_main.ml`, `step_verifier.ml`

### Wrap Circuit

A SNARK circuit that:
1. Verifies a step proof
2. Completes deferred scalar-field computations
3. Operates over the **Tock (Pallas)** curve
4. Produces a proof that step circuits can verify

Wrap circuits "wrap" step proofs into a uniform format suitable for
recursive verification.

In code: `wrap.ml`, `wrap_main.ml`, `wrap_verifier.ml`

### Inductive Rule

User-defined circuit logic that specifies what a step circuit should
compute and verify. An inductive rule:
- Takes public input (app state)
- Optionally references predecessor proofs
- Produces public output
- May produce auxiliary (private) output

In code: `inductive_rule.ml`, `Inductive_rule.t`

### Branch

A specific inductive rule within a proof system. A proof system with N
different rules has N "branches." Each branch may verify different numbers
of predecessor proofs.

Example: A blockchain proof system might have:
- Branch 0: Genesis (no predecessors)
- Branch 1: Normal block (1 predecessor)
- Branch 2: Merge (2 predecessors)

## Proof Terminology

### Proofs Verified / Max Proofs Verified

- **Proofs Verified:** The number of predecessor proofs a specific branch
  actually verifies (0, 1, or 2)
- **Max Proofs Verified:** The maximum across all branches in a proof system

Current Pickles supports max_proofs_verified up to 2 (N0, N1, N2).

In code: `Pickles_base.Proofs_verified`, `Nat.N2`

### Unfinalized Proof

A step proof before being wrapped. Contains "deferred values" - scalar-field
computations that could not be efficiently performed in the step circuit.
The wrap circuit finalizes these computations.

In code: `Unfinalized.t`, `should_finalize` flag

### Deferred Values

Scalar-field computations that are deferred from one circuit to another
because they would require expensive non-native field arithmetic.

When a step circuit (Tick) verifies a wrap proof (Tock), operations in
Tock's scalar field (= Tick's base field) are native. But operations in
Tick's scalar field would be non-native, so they are "deferred" to the
wrap circuit where they become native.

Deferred values include:
- `combined_inner_product`: Batched polynomial evaluation result
- `b`: Challenge polynomial evaluation
- PLONK linearization scalars

In code: `Wrap.Proof_state.Deferred_values`

### Messages for Next Step/Wrap Proof

Data passed between recursion layers, hashed to minimize public input size:

- **messages_for_next_step_proof:** Contains app state, verification key
  commitments, challenge polynomial commitments, old bulletproof challenges
- **messages_for_next_wrap_proof:** Contains the challenge polynomial
  commitment (sg) and old bulletproof challenges

In code: `Messages_for_next_proof_over_same_field.Step`, `.Wrap`

## Accumulator / IPA Terminology

### Inner Product Argument (IPA)

The polynomial commitment opening protocol used by Pickles. Also called
"Bulletproofs" in some contexts. The IPA allows proving that a committed
polynomial evaluates to a claimed value at a given point.

### Bulletproof Challenges

The challenges generated during the IPA protocol. In each round of the
IPA, a challenge is squeezed from the Fiat-Shamir transcript. These
challenges are accumulated across recursive proof steps.

In code: `Bulletproof_challenge.t`, `Step_bp_vec.t`

### Challenge Polynomial

The polynomial b(X) = prod_i (1 + u_i * X^{2^{n-1-i}}) where u_i are the
bulletproof challenges. Evaluating this polynomial is part of IPA
verification.

In code: `challenge_polynomial` function in `wrap_verifier.ml`

### Challenge Polynomial Commitment (sg)

The commitment to the challenge polynomial, often called "sg" in the code
(for "scalar group element"). This commitment is the "accumulator" that
carries IPA state across recursive proof steps.

In code: `challenge_polynomial_commitment`, `sg`

### Combined Inner Product

The result of batching multiple polynomial evaluations using random
challenges (xi and r):

```
combined = sum_i (xi^i * f_i(zeta)) + r * sum_i (xi^i * f_i(zeta * omega))
```

This combines evaluations at two points (zeta and zeta*omega) into one
value.

## PLONK Terminology

### Alpha

The challenge used to combine constraint polynomials in PLONK. Different
constraint types (gates, permutation, lookup) are combined as:

```
combined = gate + alpha * permutation + alpha^2 * lookup + ...
```

### Beta and Gamma

Challenges used in the permutation argument. They randomize the permutation
polynomial to ensure soundness.

### Zeta

The evaluation point for polynomials. The prover evaluates all polynomials
at zeta and zeta*omega (where omega is a root of unity).

### Xi

The challenge used to batch polynomial openings. Multiple polynomial
evaluations are combined into one opening using powers of xi.

### Joint Combiner

Additional challenge used when lookup arguments are enabled, to combine
lookup-related polynomials.

### Shifted Value

A field element representation that shifts values to avoid certain
problematic values (like 0). Two types exist:
- **Type1:** Used for Tick field elements in Wrap circuit. Simple shift.
- **Type2:** Used for Tock field elements in Step circuit. Split into
  high bits and low bit for efficient range checking.

In code: `Shifted_value.Type1`, `Shifted_value.Type2`

## Type-Level Terminology

### MLMB (Max Local Max Proofs Verified)

The maximum `max_proofs_verified` across all predecessor proof systems
referenced by all branches. Used for padding to create uniform proof sizes.

### Nat, Nat.z, Nat.N2

Type-level natural numbers using Peano encoding:
- `z` = zero (uninhabited type)
- `'n s` = successor of n
- `N2` = `z s s` (the number 2 at the type level)

Used for compile-time verification of vector lengths and proof counts.

### HList (H1, H2, H4)

Heterogeneous lists that can hold elements of different types. The number
indicates how many type parameters each element has:
- `H1.T(F)`: Elements have type `'a F.t`
- `H4.T(F)`: Elements have type `('a, 'b, 'c, 'd) F.t`

Used for type-safe operations on collections of predecessor proofs with
different type parameters.

### Vector.t

Length-indexed vectors: `('a, 'n) Vector.t` is a vector of 'a with
statically-known length 'n. Enables compile-time length checking.

## Statement Patterns

### Minimal vs In_circuit

Many types have two representations:
- **Minimal:** Compact format with only essential data (for serialization)
- **In_circuit:** Expanded format with derived values (for circuit use)

The minimal form stores raw challenges; in_circuit form includes
precomputed powers, linearization scalars, etc.

### Stable vs Checked

- **Stable:** Serialization-stable format for wire protocol
- **Checked:** Circuit variable representation with constraint checking

## Challenge and Hash Flow Between Circuits

### Fiat-Shamir Transcript Flow

Pickles uses the Fiat-Shamir heuristic to make the interactive PLONK/IPA
protocol non-interactive. A cryptographic sponge (Poseidon) absorbs messages
and squeezes challenges. The transcript state flows between circuits:

```
Step Circuit                          Wrap Circuit
┌────────────────────────────────┐   ┌────────────────────────────────┐
│ 1. Initialize sponge           │   │ 1. Initialize sponge           │
│ 2. Absorb verification key     │   │ 2. Absorb verification key     │
│ 3. Absorb public input         │   │ 3. Absorb public input         │
│ 4. Absorb prover messages      │   │ 4. Absorb prover messages      │
│ 5. Squeeze challenges:         │   │ 5. Squeeze challenges:         │
│    beta, gamma, alpha,         │   │    beta, gamma, alpha,         │
│    zeta, xi                    │   │    zeta, xi                    │
│ 6. Save sponge_digest_before_  │   │ 6. Save sponge_digest_before_  │
│    evaluations                 │   │    evaluations                 │
│ 7. Absorb polynomial evals     │   │ 7. Absorb polynomial evals     │
│ 8. Squeeze IPA challenges      │   │ 8. Squeeze IPA challenges      │
└────────────────────────────────┘   └────────────────────────────────┘
```

### Field Crossing Problem

The key challenge: when a step circuit (Tick) verifies a wrap proof (Tock),
the challenges were computed in Tock's scalar field (= Tick's base field).
But Tick's native field is its base field, so Tock's scalar field operations
would be expensive non-native arithmetic.

**Solution:** The step circuit receives the challenges as witnesses (from the
wrap proof's statement) and defers verification to the wrap circuit.

### What Gets Passed vs Recomputed

**Passed from Wrap to Step:**
- `sponge_digest_before_evaluations`: Hash state at a checkpoint
- `plonk` challenges: beta, gamma, alpha, zeta, xi (128-bit challenges)
- `bulletproof_challenges`: IPA challenges from the wrap proof
- `combined_inner_product` and `b`: Deferred scalar-field values

**Recomputed in Step:**
The step circuit does NOT recompute the wrap proof's challenges. Instead:
1. It uses the challenges from the wrap statement
2. It verifies that these challenges are consistent with the proof
3. Group operations (native in step) are verified directly
4. Scalar operations (non-native) are deferred to wrap

**Passed from Step to Wrap:**
- `sponge_digest_before_evaluations`: For transcript consistency
- Unfinalized proof data for predecessor verification
- `messages_for_next_step_proof`: Hash of accumulated data

**Recomputed in Wrap:**
The wrap circuit recomputes step's challenges because Tick's scalar field
operations are native in wrap (Tick scalar = Tock base). It:
1. Reconstructs the sponge from the step verification key
2. Absorbs the public input and prover messages
3. Squeezes challenges and verifies they match
4. Completes the deferred scalar-field checks

### The sponge_digest_before_evaluations Checkpoint

This digest captures the sponge state just before polynomial evaluations
are absorbed. It serves as:
1. A commitment to the transcript up to that point
2. A checkpoint for resuming the sponge in the verifying circuit
3. Part of the proof's public input (statement)

When verifying, the circuit:
1. Initializes a fresh sponge
2. Absorbs verification key, public input, prover messages
3. Squeezes challenges (beta, gamma, alpha, zeta, xi)
4. Asserts the sponge state equals `sponge_digest_before_evaluations`
5. Continues absorbing evaluations and squeezing IPA challenges

### 128-bit Challenge Representation and Security

**Challenge Size:** 128 bits (not full field size)

**Why 128 bits instead of 255?**
1. **Security:** 128 bits provides adequate security against guessing attacks.
   The probability of guessing a challenge is 2^-128, which is computationally
   infeasible.
2. **Efficiency:** Smaller challenges mean fewer constraints for range checks
   and more efficient circuit representation.
3. **Soundness:** PLONK soundness requires challenges to be sampled uniformly.
   128 bits provides statistical security against bias.

**Field Element Size:** ~255 bits (Pasta fields are 255-bit primes)

**Representation in Code:**
- **Challenge.Constant.t:** The raw 128-bit challenge value
- **Scalar_challenge.t:** A scalar challenge using endomorphism encoding
- **Limb_vector.Challenge:** Challenge as vector of 64-bit limbs (2 limbs)
- In circuits, challenges are range-checked to fit in 128 bits

**Security Analysis:**
- Fiat-Shamir security: 128-bit challenges provide 128-bit computational
  security assuming the hash function (Poseidon) behaves as a random oracle
- Knowledge soundness: The extractor can recover witnesses with overwhelming
  probability (1 - 2^-128)
- For proofs with T constraint checks, overall soundness error is ~T/2^128

**Endomorphism Encoding:**
The endomorphism encoding uses the curve endomorphism to efficiently convert
128-bit challenges into scalar multiplications. A scalar challenge (a, b)
represents the value a + b*endo where endo is the curve endomorphism scalar.
This allows computing [s]P as [a]P + [b](endo*P) using two half-size scalar
multiplications.

In code: `Limb_vector.Challenge`, `Scalar_challenge.Make`, `Endo.Step_inner_curve`

### Hash Function Compatibility

Pickles uses Poseidon hash over the native field of each circuit:
- Step circuits: Poseidon over Tick base field (Fp)
- Wrap circuits: Poseidon over Tock base field (Fq)

The `Messages_for_next_step_proof` and `Messages_for_next_wrap_proof` are
hashed to single field elements to minimize public input size. The receiving
circuit verifies this hash matches the expanded data.

## Recursion Structure: Base Case, Induction, and Final Proofs

### Base Case (Genesis / Initial Step)

When a proof system starts, there are no predecessor proofs to verify. This
is handled by:

1. **proofs_verified = 0:** The rule specifies no predecessor proofs
2. **Dummy proofs:** Placeholder proofs that "pass" verification trivially
3. **proof_must_verify = false:** Tells the circuit to skip verification

Example base case rule:
```ocaml
let genesis_rule =
  { identifier = "genesis"
  ; prevs = []  (* No predecessors *)
  ; main = fun _ ->
      { previous_proof_statements = []
      ; public_output = initial_state
      ; auxiliary_output = ()
      }
  ; feature_flags = Plonk_types.Features.none_bool
  }
```

The step circuit has special handling:
- When `is_base_case = true`, verification is skipped
- Dummy bulletproof challenges are used (all zeros)
- The wrap proof still contains the dummy accumulator data

### Induction Step

After the base case, each new proof verifies 1 or 2 predecessor proofs:
1. The rule's `prevs` specifies which proof systems to verify
2. The step circuit verifies wrap proofs from those systems
3. Deferred computations are passed to the wrap circuit
4. The wrap circuit produces a new wrap proof for the next iteration

### What is the Final Proof?

There is no "final" proof in the traditional sense - recursion can continue
indefinitely. At any point, you have:

**A wrap proof** (type `'n Proof.t`) containing:
- `statement`: The public input/output (app state, challenges, digests)
- `prev_evals`: Polynomial evaluations at zeta and zeta*omega
- `proof`: The kimchi wrap proof (commitments + opening proof)

### Blockchain Proof Example

For Mina's blockchain:

**Proof Type:** `Nat.N2 Proof.t` (max 2 proofs verified)

**Statement Contains:**
- Application state: blockchain state hash (~32 bytes when hashed)
- Deferred values: PLONK challenges, scalars (~several field elements)
- Bulletproof challenges: 15-17 challenges per predecessor
- Branch data: Which rule was used, domain size

**Proof Size Breakdown:**
- Wrap proof commitments: ~15 group elements (~900 bytes)
- Opening proof: ~17 group elements + scalars (~1200 bytes)
- Polynomial evaluations: ~50 field elements (~1600 bytes)
- Statement data: ~100 field elements (~3200 bytes)

**Total Size:** Approximately 7-10 KB for a Mina blockchain proof

The proof is constant-size regardless of how many transactions or blocks
have been processed - this is the key benefit of recursive SNARKs.

### Verification of Final Proof

To verify a proof at any point:
```ocaml
let result = Proof_module.verify [(statement, proof)] in
match result with
| Ok () -> (* Proof is valid *)
| Error e -> (* Proof is invalid *)
```

The verifier:
1. Checks the wrap proof against the wrap verification key
2. Does NOT recursively verify all predecessor proofs
3. Relies on the inductive structure: if this proof is valid, all
   predecessors must have been valid

### Proof Verification Key

The verification key is also constant-size (~2-3 KB) containing:
- Polynomial commitments for the wrap circuit
- Domain configuration
- Feature flags

In code: `Verification_key.t`, `Proof.t`, `Proof.Proofs_verified_2`
