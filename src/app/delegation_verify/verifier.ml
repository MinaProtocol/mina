let verify_functions =
  lazy
    (let module T = Transaction_snark.Make (struct
       let constraint_constants =
         Genesis_constants.Constraint_constants.compiled

       let proof_level = Genesis_constants.Proof_level.compiled
     end) in
    let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
      let tag = T.tag

      let constraint_constants = Genesis_constants.Constraint_constants.compiled

      let proof_level = Genesis_constants.Proof_level.compiled
    end) in
    (B.Proof.verify, T.verify))
