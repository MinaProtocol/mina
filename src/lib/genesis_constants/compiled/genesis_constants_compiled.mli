type t =
  { proof_level : Genesis_constants.Proof_level.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  ; genesis_constants : Genesis_constants.t
  }

val compiled_config : t
