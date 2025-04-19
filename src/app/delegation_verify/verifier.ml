let verify_functions ~constraint_constants ~proof_level () =
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level

    let chain = Mina_signature_kind.t_DEPRECATED
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  (B.Proof.verify, T.verify)
