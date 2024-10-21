val get_verification_keys_eagerly :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> ( [ `Blockchain of Pickles.Verification_key.t ]
     * [ `Transaction of Pickles.Verification_key.t ] )
     Async.Deferred.t
