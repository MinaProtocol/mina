open Core

module T = Transaction_snark.Make (struct
  let constraint_constants = Genesis_constants.Constraint_constants.compiled

  let proof_level = Genesis_constants.Proof_level.compiled
end)

module B = Blockchain_snark.Blockchain_snark_state.Make (struct
  let tag = T.tag

  let constraint_constants = Genesis_constants.Constraint_constants.compiled

  let proof_level = Genesis_constants.Proof_level.compiled
end)

let verify_blockchain_snarks (chains : Blockchain_snark.Blockchain.t list) =
  B.Proof.verify
  @@ List.map chains ~f:(fun snark ->
         ( Blockchain_snark.Blockchain.state snark
         , Blockchain_snark.Blockchain.proof snark ))

let verify_transaction_snarks ts = T.verify ts
