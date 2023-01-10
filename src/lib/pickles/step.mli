module Make
    (A : Pickles_types.Poly_types.T0) (A_value : sig
      type t
    end)
    (Max_proofs_verified : Pickles_types.Nat.Add.Intf_transparent) : sig
  val f :
       ?handler:
         (   Snarky_backendless.Request.request
          -> Snarky_backendless.Request.response )
    -> ( A.t
       , A_value.t
       , 'ret_var
       , 'ret_value
       , 'auxiliary_var
       , 'auxiliary_value
       , Max_proofs_verified.n
       , 'self_branches
       , 'prev_vars
       , 'prev_values
       , 'local_widths
       , 'local_heights )
       Step_branch_data.t
    -> A_value.t
    -> maxes:
         (module Pickles_types.Hlist.Maxes.S
            with type length = Max_proofs_verified.n
             and type ns = 'max_local_max_proof_verifieds )
    -> prevs_length:('prev_vars, 'prevs_length) Pickles_types.Hlist.Length.t
    -> self:('a, 'b, 'c, 'd) Tag.t
    -> step_domains:(Import.Domains.t, 'self_branches) Pickles_types.Vector.t
    -> uses_lookup:Pickles_types.Plonk_types.Opt.Flag.t
    -> self_dlog_plonk_index:
         Backend.Tick.Inner_curve.Affine.t
         Pickles_types.Plonk_verification_key_evals.t
    -> public_input:
         ( 'var
         , 'value
         , A.t
         , A_value.t
         , 'ret_var
         , 'ret_value )
         Inductive_rule.public_input
    -> auxiliary_typ:('auxiliary_var, 'auxiliary_value) Impls.Step.Typ.t
    -> Kimchi_pasta.Vesta_based_plonk.Keypair.t
    -> Impls.Wrap.Verification_key.t
    -> ( ( 'value
         , ( Unfinalized.Constant.t
           , Max_proofs_verified.n )
           Pickles_types.Vector.t
         , (Backend.Tock.Curve.Affine.t, 'prevs_length) Pickles_types.Vector.t
         , ( Import.Challenge.Constant.t Import.Types.Scalar_challenge.t
             Import.Types.Bulletproof_challenge.t
             Import.Types.Step_bp_vec.t
           , 'prevs_length )
           Pickles_types.Vector.t
         , 'local_widths
           Pickles_types.Hlist.H1.T
             (Proof.Base.Messages_for_next_proof_over_same_field.Wrap)
           .t
         , ( ( Backend.Tock.Field.t
             , Backend.Tock.Field.t array )
             Pickles_types.Plonk_types.All_evals.t
           , Max_proofs_verified.n )
           Pickles_types.Vector.t )
         Proof.Base.Step.t
       * 'ret_value
       * 'auxiliary_value
       * (int, 'prevs_length) Pickles_types.Vector.t )
       Promise.t
end
