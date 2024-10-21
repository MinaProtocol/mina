let get_verification_keys_eagerly ~constraint_constants ~proof_level =
  let module T = Transaction_snark.Make (struct
    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    let constraint_constants = constraint_constants

    let proof_level = proof_level
  end) in
  let open Async.Deferred.Let_syntax in
  let%bind blockchain_vk = Lazy.force B.Proof.verification_key in
  let%bind transaction_vk = Lazy.force T.verification_key in
  return (`Blockchain blockchain_vk, `Transaction transaction_vk)
