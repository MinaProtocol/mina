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

    {2 Implementation Notes for Rust Port}

    - Requests use OCaml's extensible variant type mechanism
    - Each request type includes its expected response type
    - The [create] functions generate fresh request modules
    - Request handling is done via pattern matching in the prover

    @see {!Step_main} for step circuit request handling
    @see {!Wrap_main} for wrap circuit request handling
*)

open Pickles_types

module Step (Inductive_rule : Inductive_rule.Intf) : sig
  module type S = sig
    type statement

    type return_value

    type prev_values

    type proofs_verified

    type max_proofs_verified

    type local_signature

    type local_branches

    type auxiliary_value

    type _ Snarky_backendless.Request.t +=
      | Compute_prev_proof_parts :
          ( prev_values
          , local_signature )
          Hlist.H2.T(Inductive_rule.Previous_proof_statement.Constant).t
          -> unit Promise.t Snarky_backendless.Request.t
      | Proof_with_datas :
          ( prev_values
          , local_signature
          , local_branches )
          Hlist.H3.T(Per_proof_witness.Constant.No_app_state).t
          Snarky_backendless.Request.t
      | Wrap_index :
          Backend.Tock.Curve.Affine.t array Plonk_verification_key_evals.t
          Snarky_backendless.Request.t
      | App_state : statement Snarky_backendless.Request.t
      | Return_value : return_value -> unit Snarky_backendless.Request.t
      | Auxiliary_value : auxiliary_value -> unit Snarky_backendless.Request.t
      | Unfinalized_proofs :
          (Unfinalized.Constant.t, proofs_verified) Vector.t
          Snarky_backendless.Request.t
      | Messages_for_next_wrap_proof :
          (Import.Types.Digest.Constant.t, max_proofs_verified) Vector.t
          Snarky_backendless.Request.t
      | Wrap_domain_indices :
          (Pickles_base.Proofs_verified.t, proofs_verified) Vector.t
          Snarky_backendless.Request.t
  end

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

module Wrap : sig
  module type S = sig
    type max_proofs_verified

    type max_local_max_proofs_verifieds

    type _ Snarky_backendless.Request.t +=
      | Evals :
          ( ( Impls.Wrap.Field.Constant.t
            , Impls.Wrap.Field.Constant.t array )
            Plonk_types.All_evals.t
          , max_proofs_verified )
          Vector.t
          Snarky_backendless.Request.t
      | Which_branch : int Snarky_backendless.Request.t
      | Step_accs :
          (Backend.Tock.Inner_curve.Affine.t, max_proofs_verified) Vector.t
          Snarky_backendless.Request.t
      | Old_bulletproof_challenges :
          max_local_max_proofs_verifieds
          Hlist.H1.T(Import.Types.Challenges_vector.Constant).t
          Snarky_backendless.Request.t
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
      | Messages :
          Backend.Tock.Inner_curve.Affine.t Plonk_types.Messages.t
          Snarky_backendless.Request.t
      | Openings_proof :
          ( Backend.Tock.Inner_curve.Affine.t
          , Backend.Tick.Field.t )
          Plonk_types.Openings.Bulletproof.t
          Snarky_backendless.Request.t
      | Wrap_domain_indices :
          (Impls.Wrap.Field.Constant.t, max_proofs_verified) Vector.t
          Snarky_backendless.Request.t
  end

  type ('mb, 'ml) t =
    (module S
       with type max_local_max_proofs_verifieds = 'ml
        and type max_proofs_verified = 'mb )

  val create : unit -> ('mb, 'ml) t
end
