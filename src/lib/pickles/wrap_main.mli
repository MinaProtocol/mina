(** {1 Wrap Main - Wrap Circuit Entry Point}

    This module defines the main SNARK function for "wrap" circuits in the
    Pickles recursive proof system.

    {2 Overview}

    A wrap circuit:
    1. Verifies a step proof from the Tick (Vesta) curve
    2. Completes deferred scalar-field computations from predecessors
    3. Produces a uniform proof format that step circuits can verify

    Wrap circuits operate over the {b Tock (Pallas)} curve. They verify step
    proofs and produce wrap proofs that can be recursively verified by step
    circuits.

    {2 Tick/Tock Cycle Context}

    Since Tock's base field equals Tick's scalar field:
    - Wrap circuits can efficiently verify Tick scalar field computations
    - Wrap circuits finalize the "deferred values" from step circuits
    - The wrap proof becomes input to the next step circuit

    {2 Deferred Values}

    When a step circuit partially verifies a wrap proof, it cannot perform
    certain scalar-field operations efficiently. These are "deferred":

    - [combined_inner_product]: Batched polynomial evaluation result
    - [b]: Challenge polynomial evaluation
    - PLONK linearization scalars ([zeta_to_srs_length], [perm], etc.)

    The wrap circuit receives these deferred values in its public input
    and verifies they were computed correctly.

    {2 Data Flow}

    {v
    Inputs:                              Outputs:
    ┌────────────────────────────┐      ┌─────────────────────────────────┐
    │ Step proof                 │      │ Wrap proof containing:          │
    │ Step statement             │  ──► │  - proof_state.deferred_values  │
    │ Step verification keys     │      │  - messages_for_next_step_proof │
    │ Branch selection           │      │  - messages_for_next_wrap_proof │
    └────────────────────────────┘      └─────────────────────────────────┘
    v}

    {2 Verification Process}

    The wrap circuit:
    1. Determines which branch was taken (one-hot encoding)
    2. Selects the appropriate step verification key
    3. Verifies branch_data matches actual proofs_verified count
    4. For each unfinalized proof from step, calls [finalize_other_proof]
    5. Runs [incrementally_verify_proof] on the step proof
    6. Asserts bulletproof success and challenge consistency
    7. Hashes messages for next proofs

    {2 Implementation Notes for Rust Port}

    - Returns a tuple of (request handlers, circuit main function)
    - The circuit function takes a [Wrap.Statement.In_circuit.t]
    - Uses [Opt.t] for optional commitments (lookups, optional gates)
    - Shifted values ([Type1]) handle the field element representation
    - [num_chunks] parameter handles polynomial chunking for large circuits

    @see <../GLOSSARY.md> for terminology definitions
    @see {!Wrap_verifier} for the verification logic used within wrap
    @see {!Step_main} for the corresponding step circuit
*)

open Pickles_types

(** [wrap_main] constructs the main circuit function for a wrap proof.

    This function creates both the request handlers and the circuit main
    function for wrap proofs. The circuit verifies a step proof and produces
    a wrap proof that can be verified by subsequent step circuits.

    {3 Key Parameters}

    @param num_chunks Number of polynomial chunks (for large circuits)
    @param feature_flags PLONK feature flags (lookups, range checks, etc.)
    @param full_signature Describes padding across all branches
    @param pi_branches Length witness for number of branches
    @param step_keys Verification keys for step circuits (lazy/promised)
    @param step_widths Proof widths (proofs_verified) for each branch
    @param step_domains Domain configurations for each branch
    @param srs Structured Reference String for polynomial commitments
    @param max_proofs_verified Module witnessing the maximum width

    @return Tuple of:
    - Request handlers for witness data
    - Promise of the circuit main function

    {3 Circuit Main Function}

    The returned circuit function takes a [Wrap.Statement.In_circuit.t]
    which contains:
    - [proof_state.deferred_values]: PLONK challenges, IPA data, branch info
    - [proof_state.sponge_digest_before_evaluations]: Fiat-Shamir state
    - [proof_state.messages_for_next_wrap_proof]: Hash of accumulator data
    - [messages_for_next_step_proof]: Hash of app state and challenges

    The function asserts all verification constraints and returns unit
    (constraints are added to the circuit).

    BEWARE: The lazy/promised structure means keys must remain valid
    until the promise is forced during proving.
*)
val wrap_main :
     num_chunks:int
  -> feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
  -> ( 'max_proofs_verified
     , 'branches
     , 'max_local_max_proofs_verifieds )
     Full_signature.t
  -> ('prev_varss, 'branches) Pickles_types.Hlist.Length.t
  -> ( ( Wrap_main_inputs.Inner_curve.Constant.t array
       (* commitments *)
       , Wrap_main_inputs.Inner_curve.Constant.t array option
       (* commitments to optional gates *) )
       Wrap_verifier.index'
     , 'branches )
     Pickles_types.Vector.t
     Promise.t
     Lazy.t
     (* All the commitments, include commitments to optional gates, saved in a
        vector of size ['branches] *)
  -> (int, 'branches) Pickles_types.Vector.t
  -> (Import.Domains.t, 'branches) Pickles_types.Vector.t Promise.t
  -> srs:Kimchi_bindings.Protocol.SRS.Fp.t
  -> (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
  -> ('max_proofs_verified, 'max_local_max_proofs_verifieds) Requests.Wrap.t
     * (   ( Wrap_main_inputs.Impl.Field.t
           , Wrap_verifier.Scalar_challenge.t
           , Wrap_verifier.Other_field.Packed.t
             Pickles_types.Shifted_value.Type1.t
           , ( Wrap_verifier.Other_field.Packed.t
               Pickles_types.Shifted_value.Type1.t
             , Wrap_main_inputs.Impl.Boolean.var )
             Pickles_types.Opt.t
           , ( Wrap_verifier.Scalar_challenge.t
             , Wrap_main_inputs.Impl.Boolean.var )
             Pickles_types.Opt.t
           , Impls.Wrap.Boolean.var
           , Impls.Wrap.Field.t
           , Impls.Wrap.Field.t
           , Impls.Wrap.Field.t
           , ( Impls.Wrap.Field.t Import.Scalar_challenge.t
               Import.Types.Bulletproof_challenge.t
             , 'c )
             Pickles_types.Vector.t
           , Wrap_main_inputs.Impl.Field.t )
           Import.Types.Wrap.Statement.In_circuit.t
        -> unit )
       Promise.t
       Lazy.t
