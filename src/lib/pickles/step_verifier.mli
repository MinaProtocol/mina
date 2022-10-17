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
  n:int -> Pasta_bindings.Fp.t Snarky_backendless__Cvar.t -> unit

type field := Step_main_inputs.Impl.Field.t

type snark_field := field Snarky_backendless__.Cvar.t

type ('a, 'b) vector := ('a, 'b) Pickles_types.Vector.t

val finalize_other_proof :
     (module Pickles_types.Nat.Add.Intf with type n = 'b)
  -> step_uses_lookup:Pickles_types.Plonk_types.Opt.Flag.t
  -> step_domains:
       [ `Known of
         (Pickles__.Import.Domains.t, 'branches) Pickles_types.Vector.t
       | `Side_loaded ]
  -> sponge:Step_main_inputs.Sponge.t
  -> prev_challenges:
       ( (Step_main_inputs.Impl.Field.t, 'a) Pickles_types.Vector.t
       , 'b )
       Pickles_types.Vector.t
  -> ( Step_main_inputs.Impl.Field.t
     , Step_main_inputs.Impl.field Snarky_backendless__.Cvar.t
       Pickles__.Import.Scalar_challenge.t
     , Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
     , ( ( Step_main_inputs.Impl.field Snarky_backendless__.Cvar.t
           Pickles__.Import.Scalar_challenge.t
         , Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t )
         Pickles__.Import.Types.Step.Proof_state.Deferred_values.Plonk
         .In_circuit
         .Lookup
         .t
       , Step_main_inputs.Impl.Boolean.var )
       Composition_types.Opt.t
     , ( Step_main_inputs.Impl.field Snarky_backendless__.Cvar.t
         Pickles__.Import.Scalar_challenge.t
         Pickles__.Import.Bulletproof_challenge.t
       , 'c )
       Pickles_types.Vector.t
     , Step_main_inputs.Impl.Field.Constant.t
       Pickles__.Import.Branch_data.Checked.t )
     Pickles__.Import.Types.Wrap.Proof_state.Deferred_values.In_circuit.t
  -> ( Step_main_inputs.Impl.Field.t
     , Step_main_inputs.Impl.Field.t Core_kernel.Array.t
     , Step_main_inputs.Impl.Boolean.var )
     Pickles_types.Plonk_types.All_evals.In_circuit.t
  -> Step_main_inputs.Impl.Boolean.var
     * ( Step_main_inputs.Impl.field Snarky_backendless__.Cvar.t
       , 'c )
       Pickles_types.Vector.t

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
         Pickles__.Import.Types.Step.Proof_state.Messages_for_next_step_proof.t
      -> Step_main_inputs.Impl.Field.t )
     Core_kernel__.Import.Staged.t

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
           Pickles__.Import.Types.Step.Proof_state.Messages_for_next_step_proof
           .t
        -> widths:'d
        -> max_width:'e
        -> proofs_verified_mask:
             ( Step_main_inputs.Impl.Field.t Snarky_backendless.Boolean.t
             , 'b )
             Pickles_types.Vector.t
        -> Step_main_inputs.Impl.Field.t )
       Core_kernel__.Import.Staged.t

val verify :
     proofs_verified:(module Pickles_types.Nat.Add.Intf with type n = 'a)
  -> is_base_case:Step_main_inputs.Impl.Boolean.var
  -> sg_old:
       ( Pickles__.Impls.Step.Field.t Tuple_lib.Double.t
       , 'a )
       Pickles_types.Vector.t
  -> sponge_after_index:Step_main_inputs.Sponge.t
  -> lookup_parameters:
       ( Limb_vector__Challenge.Constant.t
       , Step_main_inputs.Impl.field Limb_vector__Challenge.t
       , 'b Pickles_types__Hlist0.Id.t
       , Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
         Pickles_types__Hlist0.Id.t )
       Composition_types.Wrap.Lookup_parameters.t
  -> proof:Wrap_proof.Checked.t
  -> wrap_domain:
       [ `Known of Pickles__.Import.Domain.t
       | `Side_loaded of
         Step_main_inputs.Impl.field
         Composition_types.Branch_data.Proofs_verified.One_hot.Checked.t ]
  -> wrap_verification_key:
       Pickles__Step_main_inputs.Inner_curve.t
       Pickles_types.Plonk_verification_key_evals.t
  -> ( Step_main_inputs.Impl.field Limb_vector__Challenge.t
     , Step_main_inputs.Impl.field Limb_vector__Challenge.t
       Composition_types.Scalar_challenge.t
     , Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
     , ( ( Step_main_inputs.Impl.field Limb_vector__Challenge.t
           Composition_types.Scalar_challenge.t
           Pickles_types__Hlist0.Id.t
         , Step_main_inputs.Impl.Field.t Pickles_types.Shifted_value.Type1.t
           Pickles_types__Hlist0.Id.t )
         Composition_types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
         .Lookup
         .t
       , Step_main_inputs.Impl.field Snarky_backendless__.Cvar.t
         Snarky_backendless__Snark_intf.Boolean0.t )
       Pickles_types.Plonk_types.Opt.t
     , Step_main_inputs.Impl.field Snarky_backendless__.Cvar.t
     , Step_main_inputs.Impl.field Snarky_backendless__.Cvar.t
     , Step_main_inputs.Impl.field Snarky_backendless__.Cvar.t
     , ( Step_main_inputs.Impl.field Limb_vector__Challenge.t
         Kimchi_backend_common.Scalar_challenge.t
         Composition_types__.Bulletproof_challenge.t
       , Pickles_types__Nat.z Backend.Tick.Rounds.plus_n )
       Pickles_types.Vector.t
       Pickles_types__Hlist0.Id.t
     , Step_main_inputs.Impl.field Composition_types__.Branch_data.Checked.t )
     Pickles__.Import.Types.Wrap.Statement.In_circuit.t
  -> ( Step_main_inputs.Impl.Field.t
     , Step_main_inputs.Impl.Field.t Pickles__.Import.Scalar_challenge.t
     , Other_field.t Pickles_types.Shifted_value.Type2.t
     , 'c
     , ( Step_main_inputs.Impl.Field.t Pickles__.Import.Scalar_challenge.t
         Pickles__.Import.Bulletproof_challenge.t
       , 'd )
       Pickles_types.Vector.t
     , Step_main_inputs.Impl.Field.t
     , 'e )
     Pickles__.Import.Types.Step.Proof_state.Per_proof.In_circuit.t
  -> Step_main_inputs.Impl.Boolean.var
