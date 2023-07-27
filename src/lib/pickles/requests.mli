open Pickles_types

module Step : sig
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
          -> unit Snarky_backendless.Request.t
      | Proof_with_datas :
          ( prev_values
          , local_signature
          , local_branches )
          Hlist.H3.T(Per_proof_witness.Constant.No_app_state).t
          Snarky_backendless.Request.t
      | Wrap_index :
          Backend.Tock.Curve.Affine.t Plonk_verification_key_evals.out_circuit
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
