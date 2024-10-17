let get_verification_keys ~constraint_constants ~proof_level =
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  (B.Proof.verification_key, T.verification_key)

let get_verification_keys_eagerly ~constraint_constants ~proof_level =
  let blockchain, transaction =
    get_verification_keys ~constraint_constants ~proof_level
  in
  Async.Deferred.both (Lazy.force blockchain) (Lazy.force transaction)
