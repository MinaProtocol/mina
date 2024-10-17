val get_verification_keys :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> Pickles.Verification_key.t Async.Deferred.t Lazy.t
     * Pickles.Verification_key.t Async.Deferred.t Lazy.t

val get_verification_keys_eagerly :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> proof_level:Genesis_constants.Proof_level.t
  -> (Pickles.Verification_key.t * Pickles.Verification_key.t) Async.Deferred.t
