open Pickles_types

(** [wrap_main] is the SNARK function for wrapping any proof coming from the given set of
    keys **)
val wrap_main :
     feature_flags:Opt.Flag.t Plonk_types.Features.Full.t
  -> ( 'max_proofs_verified
     , 'branches
     , 'max_local_max_proofs_verifieds )
     Full_signature.t
  -> ('prev_varss, 'branches) Pickles_types.Hlist.Length.t
  -> ( ( Wrap_main_inputs.Inner_curve.Constant.t (* commitments *)
       , Wrap_main_inputs.Inner_curve.Constant.t option
       (* commitments to optional gates *) )
       Wrap_verifier.index'
     , 'branches )
     Pickles_types.Vector.t
     Core_kernel.Lazy.t
     (* All the commitments, include commitments to optional gates, saved in a
        vector of size ['branches] *)
  -> (int, 'branches) Pickles_types.Vector.t
  -> (Import.Domains.t, 'branches) Pickles_types.Vector.t
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
           , 'b
           , ( Impls.Wrap.Field.t Import.Scalar_challenge.t
               Import.Types.Bulletproof_challenge.t
             , 'c )
             Pickles_types.Vector.t
           , Wrap_main_inputs.Impl.Field.t )
           Import.Types.Wrap.Statement.In_circuit.t
        -> unit )
