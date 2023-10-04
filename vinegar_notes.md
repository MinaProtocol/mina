## Pickles overview

The kimchi verifier can broadly be broken down into the following stages:
* Absorb commitments to the polynomials and squeeze challenges, over several rounds as needed.
* Sample an evaluation point, absorb the evaluations, and check that the evaluations satisfy the 'combined constraint polynomial'.
* Verify that the evaluations and the polynomial commitments are consistent by checking the 'opening proof'.

In order to recursively verify a kimchi proof, we would like to efficiently run these steps in a circuit. However, the since some of the operations we need to run are on elliptic curve points -- represented in the 'base field' -- and others are run against the scalar field. To handle these without an expensive simulation of foreign field arithmetic in the verifier circuit, instead we generate a pair of circuits, where each shares some of the work.

Pickles is our current implementation of a recursive verifier for the kimchi proof system, implemented as a pair of circuits `step` and `wrap` implemented on top of kimchi.

The `step` circuit is a kimchi proof over the vesta curve; the `wrap` circuit is a kimchi proof over the pallas curve.

### Verifying a proof in a circuit

We assume that we're trying to verify a 'vesta' proof, but the below applies equivalently to 'pallas'.

* The logic for absorbing the commitments is run inside a 'pallas' proof.
* The 'combined constraint polynomial' is checked inside a 'vesta' proof.
* The 'opening proof' is run inside a 'pallas' proof.

Since we have 2 proofs in parallel, we need to 'communicate state' between them. We use the public input as the communication mechanism. For example, the 'pallas' proof will expose the challenges from the first step, as well as the random oracle's state imported into the opening proof.

### Verification structure

Pickles verifies proofs as a DAG, at every stage emitting a 'partially verified proof' and an 'unverified proof'. This structure looks roughly like:
```
step -> wrap -\
              +-> step -> wrap
step -> wrap -/
```
where every step proof may have 0, 1, or 2 previous wrap proofs, and each wrap proof has exactly 1 previous step proof. A 'pickles proof' is one of the wrap proofs.

## Goals of vinegar

Presently, the pickles verifier is hard-coded to use the 'berkeley' configuration. However, as we create new proof systems on top of kimchi (e.g. the MIPS zkVM), we would like to have a way to 'import' those proofs into the pickles recursion system. Also, since the proof systems will not necessarily have a 'public input' feature -- and almost certainly will not have the public input structured as pickles would expect -- we need to take a different approach towards importing them.

Broadly then, the goal is to create 2 new 'generic' circuits, which we will call 'co-step' and 'vinegar-wrap' (please suggest better names). The structure of these proofs will look like:
```
kimchi proof -\
              +-> vinegar-wrap
co-step      -/
```

The responsibilities of co-step will be to
* run the 'scalar field' checks for the kimchi proof
* ingest the 'recursion bulletproof challenges' generated from the kimchi proof
* expose the states before and after the scalar field checks as its public input, for access by vinegar-wrap.

vinegar-wrap's responsibilities will then be to
* verify the remainder of the kimchi proof over the 'base field'
* perform initial verification of the 'co-step' proof over the 'base field'
* expose the remaining unverified information from 'co-step' in the public input, so that it can be finalized by a pickles step proof
* expose a public input compatible with the pickles format, so that pickles recursion can operate over the proof.

The operations needed are conceptually very similar to the operations in the existing pickles circuits. However, because we want to avoid hard-coding the particular details of the kimchi proof into the circuit, we will need to be careful to construct 'co-step' and 'vinegar-wrap' in a generic way, with some mechanism to describe the verification steps required for a particular kimchi-style proof.

#### Scratch space; incomplete/draft notes

* In a loop, as many times as required:
  - Absorb (into the random oracle sponge) any polynomial commitments to columns that can be computed using the information available so far.
  - Squeeze (from the random oracle sponge) any challenges required to compute further columns (e.g. challenges for the lookup / permutation arguments)
* Generate a commitment representing the 'constraints' that the proof satisfies:
  - Squeeze a 'constraint combiner' challenge (we call this alpha in kimchi).
  - Compute the 

The kimchi verifier runs the following sequence of operations:
* absorb the commitments to the fixed columns (aka the 'verifier index' or 'verifier key') into a random oracle
* absorb the commitments to any 'witness' columns in the proof (including the public input, which the verifier explicitly computes) into the same random oracle
* squeeze one or more challenges for use in the constraints
* absorb the commitments that depend on those commitments

The [Halo2-style IPA](src/lib/crypto/proof-systems/poly-commitment/src/commitment.rs:667) used by the kimchi proof system (and by pickles for recursion) is 
