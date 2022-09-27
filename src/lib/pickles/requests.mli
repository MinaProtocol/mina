(* Requests *)

module Step : sig
  module type S = sig
    type statement

    type return_value

    type prev_values

    type max_proofs_verified

    type local_signature

    type local_branches

    type auxiliary_value

    type _ Snarky_backendless.Request.t +=
      | Compute_prev_proof_parts :
          ( prev_values
          , local_signature )
          Pickles_types.Hlist.H2.T
            (Inductive_rule.Previous_proof_statement.Constant)
          .t
          -> unit Snarky_backendless.Request.t
      | Proof_with_datas :
          ( prev_values
          , local_signature
          , local_branches )
          Pickles_types.Hlist.H3.T(Per_proof_witness.Constant.No_app_state).t
          Snarky_backendless.Request.t
      | Wrap_index :
          Backend.Tock.Curve.Affine.t
          Pickles_types.Plonk_verification_key_evals.t
          Snarky_backendless.Request.t
      | App_state : statement Snarky_backendless.Request.t
      | Return_value : return_value -> unit Snarky_backendless.Request.t
      | Auxiliary_value : auxiliary_value -> unit Snarky_backendless.Request.t
      | Unfinalized_proofs :
          (Unfinalized.Constant.t, max_proofs_verified) Pickles_types.Vector.t
          Snarky_backendless.Request.t
      | Messages_for_next_wrap_proof :
          ( Import.Types.Digest.Constant.t
          , max_proofs_verified )
          Pickles_types.Vector.t
          Snarky_backendless.Request.t
  end

  val create :
       unit
    -> (module S
          with type auxiliary_value = 'auxiliary_value
           and type local_branches = 'local_branches
           and type local_signature = 'local_signature
           and type max_proofs_verified = 'max_proofs_verified
           and type prev_values = 'prev_values
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
            Pickles_types.Plonk_types.All_evals.t
          , max_proofs_verified )
          Pickles_types.Vector.t
          Snarky_backendless.Request.t
      | Which_branch : int Snarky_backendless.Request.t
      | Step_accs :
          ( Backend.Tock.Inner_curve.Affine.t
          , max_proofs_verified )
          Pickles_types.Vector.t
          Snarky_backendless.Request.t
      | Old_bulletproof_challenges :
          max_local_max_proofs_verifieds
          Pickles_types.Hlist.H1.T(Import.Types.Challenges_vector.Constant).t
          Snarky_backendless.Request.t
      | Proof_state :
          ( ( ( Impls.Wrap.Challenge.Constant.t
              , Impls.Wrap.Challenge.Constant.t Import.Types.Scalar_challenge.t
              , Impls.Wrap.Field.Constant.t Pickles_types.Shifted_value.Type2.t
              , ( Impls.Wrap.Challenge.Constant.t Import.Types.Scalar_challenge.t
                , Impls.Wrap.Field.Constant.t
                  Pickles_types.Shifted_value.Type2.t )
                Import.Types.Step.Proof_state.Deferred_values.Plonk.In_circuit
                .Lookup
                .t
                option
              , ( Impls.Wrap.Challenge.Constant.t Import.Types.Scalar_challenge.t
                  Import.Types.Bulletproof_challenge.t
                , Backend.Tock.Rounds.n )
                Pickles_types.Vector.t
              , Impls.Wrap.Digest.Constant.t
              , bool )
              Import.Types.Step.Proof_state.Per_proof.In_circuit.t
            , max_proofs_verified )
            Pickles_types.Vector.t
          , Impls.Wrap.Digest.Constant.t )
          Import.Types.Step.Proof_state.t
          Snarky_backendless.Request.t
      | Messages :
          Backend.Tock.Inner_curve.Affine.t Pickles_types.Plonk_types.Messages.t
          Snarky_backendless.Request.t
      | Openings_proof :
          ( Backend.Tock.Inner_curve.Affine.t
          , Backend.Tick.Field.t )
          Pickles_types.Plonk_types.Openings.Bulletproof.t
          Snarky_backendless.Request.t
      | Wrap_domain_indices :
          ( Impls.Wrap.Field.Constant.t
          , max_proofs_verified )
          Pickles_types.Vector.t
          Snarky_backendless.Request.t
  end

  type ('mb, 'ml) t =
    (module S
       with type max_local_max_proofs_verifieds = 'ml
        and type max_proofs_verified = 'mb )

  val create : unit -> ('mb, 'ml) t
end
