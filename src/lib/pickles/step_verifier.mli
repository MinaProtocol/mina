module Challenge : module type of Import.Challenge.Make (Step_main_inputs.Impl)

module Digest : module type of Import.Digest.Make (Step_main_inputs.Impl)

module Scalar_challenge :
    module type of
      Scalar_challenge.Make
        (Step_main_inputs.Impl)
        (Step_main_inputs.Inner_curve)
        (Challenge)
        (Endo.Step_inner_curve)

module Pseudo : module type of Pseudo.Make (Step_main_inputs.Impl)

module Inner_curve : sig
  type t = Step_main_inputs.Inner_curve.t

  val typ :
    ( t
    , Step_main_inputs.Inner_curve.Inputs.Constant.t )
    Step_main_inputs.Inner_curve.Inputs.Impl.Typ.t
end

module Other_field : sig
  type t = Step_main_inputs.Impl.Other_field.t

  val size_in_bits : int

  val typ :
    ( t
    , Impls.Step.Other_field.Constant.t
    , Impls.Step.Internal_Basic.field )
    Snarky_backendless.Typ.t
end

val assert_n_bits :
  n:int -> Pasta_bindings.Fp.t Snarky_backendless.Cvar.t -> unit

val finalize_other_proof :
     (module Pickles_types.Nat.Add.Intf with type n = 'b)
  -> step_domains:
       [ `Known of (Import.Domains.t, 'branches) Pickles_types.Vector.t
       | `Side_loaded ]
  -> sponge:Step_main_inputs.Sponge.t
  -> prev_challenges:
       ( (Step_main_inputs.Impl.Field.t, 'a) Pickles_types.Vector.t
       , 'b )
       Pickles_types.Vector.t
  -> ( Step_main_inputs.Impl.Field.t
     , Step_main_inputs.Impl.field Snarky_backendless.Cvar.t
       Import.Scalar_challenge.t
     , Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
     , ( Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
       , Step_main_inputs.Impl.Boolean.var )
       Composition_types.Opt.t
     , ( Step_main_inputs.Impl.field Snarky_backendless.Cvar.t
         Import.Scalar_challenge.t
       , Step_main_inputs.Impl.Boolean.var )
       Composition_types.Opt.t
     , ( Step_main_inputs.Impl.field Snarky_backendless.Cvar.t
         Import.Scalar_challenge.t
         Import.Bulletproof_challenge.t
       , 'c )
       Pickles_types.Vector.t
     , Step_main_inputs.Impl.Field.Constant.t Import.Branch_data.Checked.t
     , Step_main_inputs.Impl.Boolean.var )
     Import.Types.Wrap.Proof_state.Deferred_values.In_circuit.t
  -> ( Step_main_inputs.Impl.Field.t
     , Step_main_inputs.Impl.Field.t Core_kernel.Array.t
     , Step_main_inputs.Impl.Boolean.var )
     Pickles_types.Plonk_types.All_evals.In_circuit.t
  -> Step_main_inputs.Impl.Boolean.var
     * ( Step_main_inputs.Impl.field Snarky_backendless.Cvar.t
       , 'c )
       Pickles_types.Vector.t

(** [hash_messages_for_next_step_proof idx state_to_field_element] computes a
    challenge for the next proof using a random oracle simulated by a sponge
    hash function (i.e. Fiat Shamir transformation). It takes the index of the proof
    [idx] and a function which converts the communication transcript (i.e. the
    state) to field elements to be used by the random oracle *)
val hash_messages_for_next_step_proof :
     index:
       Step_main_inputs.Inner_curve.t
       Pickles_types.Plonk_verification_key_evals.t
  -> ('s -> Step_main_inputs.Impl.Field.t array)
  -> (   ( 'a
         , 's
         , (Inner_curve.t, 'b) Pickles_types.Vector.t
         , ( (Step_main_inputs.Impl.Field.t, 'c) Pickles_types.Vector.t
           , 'b )
           Pickles_types.Vector.t )
         Import.Types.Step.Proof_state.Messages_for_next_step_proof.t
      -> Step_main_inputs.Impl.Field.t )
     Core_kernel.Staged.t

val hash_messages_for_next_step_proof_opt :
     index:
       Step_main_inputs.Inner_curve.t
       Pickles_types.Plonk_verification_key_evals.t
  -> ('s -> Step_main_inputs.Impl.Field.t array)
  -> Step_main_inputs.Sponge.t
     * (   ( 'a
           , 's
           , (Inner_curve.t, 'b) Pickles_types.Vector.t
           , ( (Step_main_inputs.Impl.Field.t, 'c) Pickles_types.Vector.t
             , 'b )
             Pickles_types.Vector.t )
           Import.Types.Step.Proof_state.Messages_for_next_step_proof.t
        -> widths:'d
        -> max_width:'e
        -> proofs_verified_mask:
             ( Step_main_inputs.Impl.Field.t Snarky_backendless.Boolean.t
             , 'b )
             Pickles_types.Vector.t
        -> Step_main_inputs.Impl.Field.t )
       Core_kernel.Staged.t

(** Actual verification using cryptographic tools. Returns [true] (encoded as a
    in-circuit boolean variable) if the verification is successfull *)
val verify :
     proofs_verified:(module Pickles_types.Nat.Add.Intf with type n = 'a)
  -> is_base_case:Step_main_inputs.Impl.Boolean.var
  -> sg_old:(Impls.Step.Field.t Tuple_lib.Double.t, 'a) Pickles_types.Vector.t
  -> sponge_after_index:Step_main_inputs.Sponge.t
  -> lookup_parameters:
       ( Limb_vector.Challenge.Constant.t
       , Step_main_inputs.Impl.field Limb_vector.Challenge.t
       , 'b Pickles_types.Hlist0.Id.t
       , Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
         Pickles_types.Hlist0.Id.t )
       Composition_types.Wrap.Lookup_parameters.t
       (* lookup arguments parameters *)
  -> feature_flags:Pickles_types.Opt.Flag.t Pickles_types.Plonk_types.Features.t
  -> proof:Wrap_proof.Checked.t
  -> srs:Kimchi_bindings.Protocol.SRS.Fq.t
  -> wrap_domain:
       [ `Known of Import.Domain.t
       | `Side_loaded of
         Step_main_inputs.Impl.field
         Composition_types.Branch_data.Proofs_verified.One_hot.Checked.t ]
  -> wrap_verification_key:
       Step_main_inputs.Inner_curve.t
       Pickles_types.Plonk_verification_key_evals.t
  -> ( Step_main_inputs.Impl.field Limb_vector.Challenge.t
     , Step_main_inputs.Impl.field Limb_vector.Challenge.t
       Composition_types.Scalar_challenge.t
     , Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
     , ( Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
       , Step_main_inputs.Impl.Boolean.var )
       Pickles_types.Opt.t
     , ( Step_main_inputs.Impl.field Limb_vector.Challenge.t
         Composition_types.Scalar_challenge.t
       , Step_main_inputs.Impl.field Snarky_backendless.Cvar.t
         Snarky_backendless.Snark_intf.Boolean0.t )
       Pickles_types.Opt.t
     , Step_main_inputs.Impl.Boolean.var
     , Step_main_inputs.Impl.field Snarky_backendless.Cvar.t
     , Step_main_inputs.Impl.field Snarky_backendless.Cvar.t
     , Step_main_inputs.Impl.field Snarky_backendless.Cvar.t
     , ( Step_main_inputs.Impl.field Limb_vector.Challenge.t
         Kimchi_backend_common.Scalar_challenge.t
         Composition_types.Bulletproof_challenge.t
       , Pickles_types.Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
       Pickles_types.Hlist0.Id.t
     , Step_main_inputs.Impl.field Composition_types.Branch_data.Checked.t )
     Import.Types.Wrap.Statement.In_circuit.t
     (* statement *)
  -> ( Step_main_inputs.Impl.Field.t
     , Step_main_inputs.Impl.Field.t Import.Scalar_challenge.t
     , Other_field.t Pickles_types.Shifted_value.Type2.t
     , ( Step_main_inputs.Impl.Field.t Import.Scalar_challenge.t
         Import.Bulletproof_challenge.t
       , 'd )
       Pickles_types.Vector.t
     , Step_main_inputs.Impl.Field.t
     , Step_main_inputs.Impl.Boolean.var )
     Import.Types.Step.Proof_state.Per_proof.In_circuit.t
     (* unfinalized *)
  -> Step_main_inputs.Impl.Boolean.var
