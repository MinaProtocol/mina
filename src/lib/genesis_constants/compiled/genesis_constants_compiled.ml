type t =
  { proof_level : Genesis_constants.Proof_level.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  ; genesis_constants : Genesis_constants.t
  }

module M = Genesis_constants.Make (Node_config)

let compiled_config =
  { proof_level = M.Proof_level.t
  ; constraint_constants = M.Constraint_constants.t
  ; genesis_constants = M.t
  }
