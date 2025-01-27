module Impl := Step_main_inputs.Impl

module Challenge : module type of Import.Challenge.Make (Impl)

module Digest : module type of Import.Digest.Make (Impl)

module Scalar_challenge :
    module type of
      Scalar_challenge.Make (Impl) (Step_main_inputs.Inner_curve) (Challenge)
        (Endo.Step_inner_curve)

module Pseudo = Pseudo.Step

module Inner_curve : sig
  type t = Step_main_inputs.Inner_curve.t

  val typ : (t, Step_main_inputs.Inner_curve.Constant.t) Impl.Typ.t
end

module Other_field : sig
  type t = Impl.Other_field.t

  val size_in_bits : int

  val typ : (t, Impls.Step.Other_field.Constant.t) Impls.Step.Typ.t
end

val assert_n_bits : n:int -> Impl.Field.t -> unit

val finalize_other_proof :
     (module Pickles_types.Nat.Add.Intf with type n = 'b)
  -> step_domains:
       [ `Known of (Import.Domains.t, 'branches) Pickles_types.Vector.t
       | `Side_loaded ]
  -> zk_rows:int
  -> sponge:Step_main_inputs.Sponge.t
  -> prev_challenges:
       ((Impl.Field.t, 'a) Pickles_types.Vector.t, 'b) Pickles_types.Vector.t
  -> ( Impl.Field.t
     , Impl.Field.t Import.Scalar_challenge.t
     , Impl.Field.t Pickles_types.Shifted_value.Type1.t
     , ( Impl.Field.t Pickles_types.Shifted_value.Type1.t
       , Impl.Boolean.var )
       Composition_types.Opt.t
     , ( Impl.Field.t Import.Scalar_challenge.t
       , Impl.Boolean.var )
       Composition_types.Opt.t
     , ( Impl.Field.t Import.Scalar_challenge.t Import.Bulletproof_challenge.t
       , 'c )
       Pickles_types.Vector.t
     , Import.Branch_data.Checked.Step.t
     , Impl.Boolean.var )
     Import.Types.Wrap.Proof_state.Deferred_values.In_circuit.t
  -> ( Impl.Field.t
     , Impl.Field.t Core_kernel.Array.t
     , Impl.Boolean.var )
     Pickles_types.Plonk_types.All_evals.In_circuit.t
  -> Impl.Boolean.var * (Impl.Field.t, 'c) Pickles_types.Vector.t

val hash_messages_for_next_step_proof :
     index:
       Step_main_inputs.Inner_curve.t array
       Pickles_types.Plonk_verification_key_evals.t
  -> ('s -> Impl.Field.t array)
  -> (   ( 'a
         , 's
         , (Inner_curve.t, 'b) Pickles_types.Vector.t
         , ( (Impl.Field.t, 'c) Pickles_types.Vector.t
           , 'b )
           Pickles_types.Vector.t )
         Import.Types.Step.Proof_state.Messages_for_next_step_proof.t
      -> Impl.Field.t )
     Core_kernel.Staged.t

val hash_messages_for_next_step_proof_opt :
     index:
       Step_main_inputs.Inner_curve.t array
       Pickles_types.Plonk_verification_key_evals.t
  -> ('s -> Impl.Field.t array)
  -> Step_main_inputs.Sponge.t
     * (   ( 'a
           , 's
           , (Inner_curve.t, 'b) Pickles_types.Vector.t
           , ( (Impl.Field.t, 'c) Pickles_types.Vector.t
             , 'b )
             Pickles_types.Vector.t )
           Import.Types.Step.Proof_state.Messages_for_next_step_proof.t
        -> widths:'d
        -> max_width:'e
        -> proofs_verified_mask:
             ( Impl.Field.t Snarky_backendless.Boolean.t
             , 'b )
             Pickles_types.Vector.t
        -> Impl.Field.t )
       Core_kernel.Staged.t

(** Actual verification using cryptographic tools. Returns [true] (encoded as a
    in-circuit Boolean variable) if the verification is successful *)
val verify :
     proofs_verified:(module Pickles_types.Nat.Add.Intf with type n = 'a)
  -> is_base_case:Impl.Boolean.var
  -> sg_old:(Impls.Step.Field.t Tuple_lib.Double.t, 'a) Pickles_types.Vector.t
  -> sponge_after_index:Step_main_inputs.Sponge.t
  -> lookup_parameters:
       ( Limb_vector.Challenge.Constant.t
       , Impl.Field.t
       , 'b
       , Impl.Field.t Pickles_types.Shifted_value.Type1.t )
       Composition_types.Wrap.Lookup_parameters.t
       (* lookup arguments parameters *)
  -> feature_flags:Pickles_types.Opt.Flag.t Pickles_types.Plonk_types.Features.t
  -> proof:Wrap_proof.Checked.t
  -> srs:Kimchi_bindings.Protocol.SRS.Fq.t
  -> wrap_domain:
       [ `Known of Import.Domain.t
       | `Side_loaded of
         Composition_types.Branch_data.Proofs_verified.One_hot.Checked.t ]
  -> wrap_verification_key:
       Step_main_inputs.Inner_curve.t array
       Pickles_types.Plonk_verification_key_evals.t
  -> ( Impl.Field.t
     , Impl.Field.t Composition_types.Scalar_challenge.t
     , Impl.Field.t Pickles_types.Shifted_value.Type1.t
     , ( Impl.Field.t Pickles_types.Shifted_value.Type1.t
       , Impl.Boolean.var )
       Pickles_types.Opt.t
     , ( Impl.Field.t Composition_types.Scalar_challenge.t
       , Impl.Field.t Snarky_backendless.Boolean.t )
       Pickles_types.Opt.t
     , Impl.Boolean.var
     , Impl.Field.t
     , Impl.Field.t
     , Impl.Field.t
     , ( Impl.Field.t Kimchi_backend_common.Scalar_challenge.t
         Composition_types.Bulletproof_challenge.t
       , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
     , Composition_types.Branch_data.Checked.Step.t )
     Import.Types.Wrap.Statement.In_circuit.t
     (* statement *)
  -> Impls.Step.unfinalized_proof_var (* unfinalized *)
  -> Impl.Boolean.var

module For_tests_only : sig
  type field := Impl.Field.t

  val side_loaded_domain :
       log2_size:field
    -> < generator : field
       ; log2_size : field
       ; shifts : field Pickles_types.Plonk_types.Shifts.t
       ; vanishing_polynomial : field -> field >
end
