let get_verification_keys_eagerly ~constraint_constants ~proof_level =
  let open Async.Deferred.Let_syntax in
  let `Blockchain blockchain_vk, `Transaction transaction_vk =
    get_verification_keys ~constraint_constants ~proof_level
  in
  let%bind blockchain_vk = Lazy.force blockchain_vk in
  let%bind transaction_vk = Lazy.force transaction_vk in
  return (`Blockchain blockchain_vk, `Transaction transaction_vk)
