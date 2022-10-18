(** [wrap_main] is the SNARK function for wrapping any proof coming from the given set of
    keys **)
val wrap_main :
     ( 'max_proofs_verified
     , 'branches
     , 'max_local_max_proofs_verifieds )
     Full_signature.t
  -> ('prev_varss, 'branches) Pickles_types.Hlist.Length.t
  -> ( Wrap_main_inputs.Inner_curve.Constant.t Wrap_verifier.index'
     , 'branches )
     Pickles_types.Vector.t
     Core_kernel.Lazy.t
  -> (int, 'branches) Pickles_types.Vector.t
  -> (Import.Domains.t, 'branches) Pickles_types.Vector.t
  -> (module Pickles_types.Nat.Add.Intf with type n = 'max_proofs_verified)
  -> ('max_proofs_verified, 'max_local_max_proofs_verifieds) Requests.Wrap.t
     * (   ( Wrap_main_inputs.Impl.Field.t
           , Wrap_verifier.Scalar_challenge.t
           , Wrap_verifier.Other_field.Packed.t
             Pickles_types.Shifted_value.Type1.t
           , 'a
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
