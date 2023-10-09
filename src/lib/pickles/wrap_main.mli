open Pickles_types

(** [wrap_main] is the SNARK function for wrapping any proof coming from the given set of keys.

   The arguments are:
    - [feature_flags] TODO
    - [full_signature] TODO
    - [pi_branches] TODO
    - [step_keys] are the verifications keys for each step proofs. The size of
      the vector is given by [`branches].
    - [step_widths] TODO
    - [step_domains] are the domains for each verification keys. The size of the
      vector is given by [`branches].
    - [~srs] TODO
    - [max_proofs_verified] TODO

    The output of the function is a tuple (req, main_fn) where:
    - [req] TODO
    - [main_fn] is the main function that will be used by the wrap prover and
      wrap verifier.
*)
val wrap_main :
     feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
  -> ( 'max_proofs_verified
     , 'branches
     (* number of step proofs *)
     , 'max_local_max_proofs_verifieds )
     Full_signature.t
     (* full_signature *)
  -> ('prev_varss, 'branches) Pickles_types.Hlist.Length.t (* pi_branches *)
  -> ( ( Wrap_main_inputs.Inner_curve.Constant.t (* commitments *)
       , Wrap_main_inputs.Inner_curve.Constant.t option
       (* optional commitments *) )
       Wrap_verifier.index'
     , 'branches
     (* number of vk *) )
     Pickles_types.Vector.t
     Core_kernel.Lazy.t
     (* step_keys, verification keys for the wrap proofs *)
  -> (int, 'branches) Pickles_types.Vector.t (* step_widths *)
  -> (Import.Domains.t, 'branches) Pickles_types.Vector.t (* step_domains *)
  -> srs:Kimchi_bindings.Protocol.SRS.Fp.t (* srs *)
  -> (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
     (* max_proofs_verified *)
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
           , 'b
           , ( Impls.Wrap.Field.t Import.Scalar_challenge.t
               Import.Types.Bulletproof_challenge.t
             , 'c )
             Pickles_types.Vector.t
           , Wrap_main_inputs.Impl.Field.t )
           Import.Types.Wrap.Statement.In_circuit.t
        -> unit )
