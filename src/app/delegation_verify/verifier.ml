let verify_functions ~constraint_constants () =
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants
  end) in
  (B.Proof.verify, T.verify)
