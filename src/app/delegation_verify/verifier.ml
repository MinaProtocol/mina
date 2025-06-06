let verify_functions ~constraint_constants ~proof_level () =
  let module T = Transaction_snark.Make (struct
    let signature_kind = Mina_signature_kind.t_DEPRECATED

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  (B.Proof.verify, T.verify)
