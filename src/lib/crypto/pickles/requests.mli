(** {1 Requests - Snarky Witness Request Types}

    This module defines the snarky request types that step and wrap circuits
    use to obtain non-deterministic witness data from the prover.

    {2 Overview}

    Snarky circuits operate in two phases:
    1. {b Circuit generation}: Defines constraints, requests witness data
    2. {b Proving}: Prover responds to requests with actual values

    Requests are the mechanism for circuits to ask for witness data.

    {2 Step Requests}

    Step circuits request:
    - [Compute_prev_proof_parts]: Predecessor proof data
    - [Proof_with_datas]: Full predecessor proof witnesses
    - [Wrap_index]: Wrap circuit verification key
    - [App_state]: Application-specific public input
    - [Return_value]: Output value to return
    - [Auxiliary_value]: Prover-only auxiliary data
    - [Unfinalized_proofs]: Deferred proof data
    - [Messages_for_next_wrap_proof]: Data for next wrap proof
    - [Wrap_domain_indices]: Domain configuration

    {2 Wrap Requests}

    Wrap circuits request:
    - [Evals]: Polynomial evaluation vectors
    - [Which_branch]: Index of active branch
    - [Step_accs]: Challenge polynomial commitments
    - [Old_bulletproof_challenges]: Previous IPA challenges
    - [Proof_state]: Step proof state data
    - [Messages]: Prover messages (commitments)
    - [Openings_proof]: IPA opening proof data
    - [Wrap_domain_indices]: Domain configuration

    {2 See also}
    - {!module:Step_main} for step circuit request handling
    - {!module:Wrap_main} for wrap circuit request handling *)

open Pickles_types

(** Request types for step circuits.

    @param Inductive_rule The inductive rule interface, which determines the
      structure of predecessor proof statements. *)
module Step (Inductive_rule : Inductive_rule.Intf) : sig
  (** Signature for step circuit requests. Each step circuit gets its own
      first-class module implementing this signature with concrete types. *)
  module type S = sig
    (** The application statement type (public input). *)
    type statement

    (** The return value type from the rule's main function. *)
    type return_value

    (** HList of predecessor proof value types. This is a heterogeneous list
        because each predecessor proof may come from a different proof system
        with its own statement type. For example, a rule might verify both a
        "transaction proof" and a "merge proof" which have different public
        input types. *)
    type prev_values

    (** Type-level nat for the number of proofs this rule verifies. *)
    type proofs_verified

    (** Type-level nat for the maximum proofs verified across all rules. *)
    type max_proofs_verified

    (** HList encoding the "signature" (proof widths) of predecessor proofs. *)
    type local_signature

    (** HList encoding the branch counts of predecessor proof systems. *)
    type local_branches

    (** Prover-only auxiliary data returned by the rule. *)
    type auxiliary_value

    type _ Snarky_backendless.Request.t +=
      | Compute_prev_proof_parts :
          ( prev_values
          , local_signature )
          Hlist.H2.T(Inductive_rule.Previous_proof_statement.Constant).t
          -> unit Promise.t Snarky_backendless.Request.t
            (** Request to compute derived values from predecessor proofs.
                The prover responds with the proof statements and triggers
                asynchronous computation of proof parts. *)
      | Proof_with_datas :
          ( prev_values
          , local_signature
          , local_branches )
          Hlist.H3.T(Per_proof_witness.Constant.No_app_state).t
          Snarky_backendless.Request.t
            (** Request for full predecessor proof witness data. This includes
                polynomial commitments (succinct representations of the execution
                trace and constraints), evaluations at challenge points, and
                accumulator state - the "data" that proofs carry in the
                Proof-Carrying Data paradigm. *)
      | Wrap_index :
          Backend.Tock.Curve.Affine.t array Plonk_verification_key_evals.t
          Snarky_backendless.Request.t
            (** Request for the wrap circuit's verification key evaluations.
                Used to verify that predecessor proofs will pass wrap. *)
      | App_state : statement Snarky_backendless.Request.t
            (** Request for the application-specific public input value. *)
      | Return_value : return_value -> unit Snarky_backendless.Request.t
            (** Provide the return value from the rule's main function.
                This is a "write" request - the circuit provides the value. *)
      | Auxiliary_value : auxiliary_value -> unit Snarky_backendless.Request.t
            (** Provide the auxiliary (prover-only) value from main.
                This is a "write" request - the circuit provides the value. *)
      | Unfinalized_proofs :
          (Unfinalized.Constant.t, proofs_verified) Vector.t
          Snarky_backendless.Request.t
            (** Request for unfinalized proof data - the deferred scalar field
                computations from predecessor wrap proofs. *)
      | Messages_for_next_wrap_proof :
          (Import.Types.Digest.Constant.t, max_proofs_verified) Vector.t
          Snarky_backendless.Request.t
            (** Request for message digests to pass to the next wrap proof.
                These link the step proof to its subsequent wrap. *)
      | Wrap_domain_indices :
          (Pickles_base.Proofs_verified.t, proofs_verified) Vector.t
          Snarky_backendless.Request.t
            (** Request for domain indices indicating which wrap domain size
                each predecessor proof used (based on proofs_verified count). *)
  end

  (** Create a fresh first-class module of step requests with the given types.
      Each step circuit branch gets its own request module to ensure type safety
      between different branches. *)
  val create :
    'proofs_verified 'local_signature 'local_branches 'statement 'return_value
    'auxiliary_value 'prev_values 'max_proofs_verified.
       unit
    -> (module S
          with type auxiliary_value = 'auxiliary_value
           and type local_branches = 'local_branches
           and type local_signature = 'local_signature
           and type max_proofs_verified = 'max_proofs_verified
           and type prev_values = 'prev_values
           and type proofs_verified = 'proofs_verified
           and type return_value = 'return_value
           and type statement = 'statement )
end

(** Request types for wrap circuits. Wrap circuits verify step proofs and
    produce the uniform proof format for recursion. *)
module Wrap : sig
  (** Signature for wrap circuit requests. *)
  module type S = sig
    (** Type-level nat for maximum proofs verified by the step circuit. *)
    type max_proofs_verified

    (** HList of type-level nats for the max proofs verified by each
        predecessor proof system (nested recursion depth). *)
    type max_local_max_proofs_verifieds

    type _ Snarky_backendless.Request.t +=
      | Evals :
          ( ( Impls.Wrap.Field.Constant.t
            , Impls.Wrap.Field.Constant.t array )
            Plonk_types.All_evals.t
          , max_proofs_verified )
          Vector.t
          Snarky_backendless.Request.t
            (** Request for polynomial evaluation vectors from the step proof.
                Contains evaluations at zeta and zeta*omega for all columns. *)
      | Which_branch : int Snarky_backendless.Request.t
            (** Request for the branch index - which rule was used to create
                the step proof being wrapped. *)
      | Step_accs :
          (Backend.Tock.Inner_curve.Affine.t, max_proofs_verified) Vector.t
          Snarky_backendless.Request.t
            (** Request for step accumulator points (sg commitments).
                These are the challenge polynomial commitments from predecessor
                step proofs' IPA protocols. *)
      | Old_bulletproof_challenges :
          max_local_max_proofs_verifieds
          Hlist.H1.T(Import.Types.Challenges_vector.Constant).t
          Snarky_backendless.Request.t
            (** Request for bulletproof challenges from all predecessor proofs.
                These are absorbed into the sponge for challenge derivation. *)
      | Proof_state :
          ( ( ( Impls.Wrap.Challenge.Constant.t
              , Impls.Wrap.Challenge.Constant.t Import.Types.Scalar_challenge.t
              , Impls.Wrap.Field.Constant.t Shifted_value.Type2.t
              , ( Impls.Wrap.Challenge.Constant.t Import.Types.Scalar_challenge.t
                  Import.Types.Bulletproof_challenge.t
                , Backend.Tock.Rounds.n )
                Vector.t
              , Impls.Wrap.Digest.Constant.t
              , bool )
              Import.Types.Step.Proof_state.Per_proof.In_circuit.t
            , max_proofs_verified )
            Vector.t
          , Impls.Wrap.Digest.Constant.t )
          Import.Types.Step.Proof_state.t
          Snarky_backendless.Request.t
            (** Request for the step proof's proof state containing deferred
                values (xi, combined inner product, etc.) and per-proof data. *)
      | Messages :
          Backend.Tock.Inner_curve.Affine.t Plonk_types.Messages.t
          Snarky_backendless.Request.t
            (** Request for prover messages - the polynomial commitments
                sent during the step proof protocol. *)
      | Openings_proof :
          ( Backend.Tock.Inner_curve.Affine.t
          , Backend.Tick.Field.t )
          Plonk_types.Openings.Bulletproof.t
          Snarky_backendless.Request.t
            (** Request for the IPA opening proof data including the
                L/R commitment vectors and final values. *)
      | Wrap_domain_indices :
          (Impls.Wrap.Field.Constant.t, max_proofs_verified) Vector.t
          Snarky_backendless.Request.t
            (** Request for domain indices as field elements, indicating
                wrap circuit domain sizes for each verified proof. *)
  end

  (** First-class module type for wrap requests, parameterized by:
      - ['mb]: max_proofs_verified type-level nat
      - ['ml]: max_local_max_proofs_verifieds HList *)
  type ('mb, 'ml) t =
    (module S
       with type max_local_max_proofs_verifieds = 'ml
        and type max_proofs_verified = 'mb )

  (** Create a fresh first-class module of wrap requests. *)
  val create : unit -> ('mb, 'ml) t
end
