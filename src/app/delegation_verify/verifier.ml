let verify_functions ~constraint_constants ~proof_level ~signature_kind () =
  let module T = Transaction_snark.Make (struct
    let signature_kind = signature_kind

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  (B.Proof.verify, T.verify)
