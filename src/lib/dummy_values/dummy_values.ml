open Core_kernel

let blockchain_proof () =
  let decode = Core_kernel.Binable.of_string (module Pickles.Proof.Proofs_verified_2.Stable.Latest) in
  decode @@ In_channel.with_file "test_fixtures/blockchain_proof" ~f:In_channel.input_all

let transaction_proof () =
  let decode = Core_kernel.Binable.of_string (module Pickles.Proof.Proofs_verified_2.Stable.Latest) in
  decode @@ In_channel.with_file "test_fixtures/transaction_proof" ~f:In_channel.input_all
