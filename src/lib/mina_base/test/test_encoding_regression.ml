(** Testing
    -------
    Component:  Mina base
    Invocation: dune exec src/lib/mina_base/test/main.exe -- \
                  test '^base58 encoding regression$'
    Subject:    Regression tests for base58 encoding of core types.
 *)

open Core_kernel
open Mina_base

(* Signature.dummy = (Field.one, Inner_curve.Scalar.one) *)
let test_signature_dummy_encoding () =
  let expected =
    "7mWxjLYgbJUkZNcGouvhVj5tJ8yu9hoexb9ntvPK8t5LHqzmrL6QJjjKtf5SgmxB4QWkDw7qoMMbbNGtHVpsbJHPyTy2EzRQ"
  in
  let got = Signature.to_base58_check Signature.dummy in
  Alcotest.(check string) "Signature.dummy encoding is stable" expected got

(* Token_id.default = Field.one *)
let test_token_id_default_encoding () =
  let expected = "wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf" in
  let got = Token_id.to_string Token_id.default in
  Alcotest.(check string) "Token_id.default encoding is stable" expected got

(* State_hash.dummy = of_hash Outside_hash_image.t (= Field.zero) *)
let test_state_hash_dummy_encoding () =
  let expected = "3NK2tkzqqK5spR2sZ7tujjqPksL45M3UUrcA4WhCkeiPtnugyE2x" in
  let got = State_hash.to_base58_check State_hash.dummy in
  Alcotest.(check string) "State_hash.dummy encoding is stable" expected got

(* State_body_hash of Field.zero *)
let test_state_body_hash_field_zero_encoding () =
  let expected = "3WtfTvMk1U11nw3e7CHoXuvt1JXhumKCeJEHcy3JF8U7B85vFaXf" in
  let t = State_body_hash.of_hash Snark_params.Tick.Field.zero in
  let got = State_body_hash.to_base58_check t in
  Alcotest.(check string)
    "State_body_hash(Field.zero) encoding is stable" expected got

(* Ledger_hash of Field.zero *)
let test_ledger_hash_field_zero_encoding () =
  let expected = "jw6bz2wud1N6itRUHZ5ypo3267stk4UgzkiuWtAMPRZo9g4Udyd" in
  let t = Ledger_hash.of_hash Snark_params.Tick.Field.zero in
  let got = Ledger_hash.to_base58_check t in
  Alcotest.(check string)
    "Ledger_hash(Field.zero) encoding is stable" expected got

(* Ledger_hash of Field.one *)
let test_ledger_hash_field_one_encoding () =
  let expected = "jw73XZp5bcaVCnVTK7qr817gnCfLxfkjuwyCJhmrN4eL3sqWXkX" in
  let t = Ledger_hash.of_hash Snark_params.Tick.Field.one in
  let got = Ledger_hash.to_base58_check t in
  Alcotest.(check string)
    "Ledger_hash(Field.one) encoding is stable" expected got

(* Receipt.Chain_hash.empty = hash of "CodaReceiptEmpty" salt *)
let test_receipt_chain_hash_empty_encoding () =
  let expected = "2mzbV7WevxLuchs2dAMY4vQBS6XttnCUF8Hvks4XNBQ5qiSGGBQe" in
  let got = Receipt.Chain_hash.to_base58_check Receipt.Chain_hash.empty in
  Alcotest.(check string)
    "Receipt.Chain_hash.empty encoding is stable" expected got

(* Epoch_seed of Field.zero *)
let test_epoch_seed_field_zero_encoding () =
  let expected = "2va9BGv9JrLTtrzZttiEMDYw1Zj6a6EHzXjmP9evHDTG3oEquURA" in
  let t = Epoch_seed.of_hash Snark_params.Tick.Field.zero in
  let got = Epoch_seed.to_base58_check t in
  Alcotest.(check string)
    "Epoch_seed(Field.zero) encoding is stable" expected got

(* Signed_command_memo.empty = create_from_string_exn "" *)
let test_signed_command_memo_empty_encoding () =
  let expected = "E4YM2vTHhWEg66xpj52JErHUBU4pZ1yageL4TVDDpTTSsv8mK6YaH" in
  let got = Signed_command_memo.to_base58_check Signed_command_memo.empty in
  Alcotest.(check string)
    "Signed_command_memo.empty encoding is stable" expected got

(* Staged_ledger_hash.Aux_hash.dummy = 32 zero bytes *)
let test_staged_ledger_hash_aux_hash_dummy_encoding () =
  let expected = "UDRUFHSvxUAtV8sh7gzMVPqpbd46roG1wzWR6dYvB6RunPihom" in
  let got =
    Staged_ledger_hash.Aux_hash.to_base58_check
      Staged_ledger_hash.Aux_hash.dummy
  in
  Alcotest.(check string)
    "Staged_ledger_hash.Aux_hash.dummy encoding is stable" expected got

(* Staged_ledger_hash.Pending_coinbase_aux.dummy = 32 zero bytes *)
let test_staged_ledger_hash_pending_coinbase_aux_dummy_encoding () =
  let expected = "WAAeUjUnP9Q2JiabhJzJozcjiEmkZe8ob4cfFKSuq6pQSNmHh7" in
  let got =
    Staged_ledger_hash.Pending_coinbase_aux.to_base58_check
      Staged_ledger_hash.Pending_coinbase_aux.dummy
  in
  Alcotest.(check string)
    "Staged_ledger_hash.Pending_coinbase_aux.dummy encoding is stable" expected
    got

(* Pending_coinbase.Hash.empty_hash = hash of "PendingCoinbaseMerkleTree" salt *)
let test_pending_coinbase_hash_empty_encoding () =
  let expected = "2mzubwAM7FXeL6KyiCwTE4ZXMrH4gtfugfwPLu3HNdNVUkzBDTJy" in
  let got =
    Pending_coinbase.Hash.to_base58_check Pending_coinbase.Hash.empty_hash
  in
  Alcotest.(check string)
    "Pending_coinbase.Hash.empty_hash encoding is stable" expected got

(* Coinbase: receiver = Public_key from sk=1, amount = 1 MINA *)
let test_coinbase_encoding () =
  let expected =
    "Kw31TqNVMsSNE1e59HHuMhv9zbLAKXfLowbrot2t1RKjb42Nb5rFiaSRybQ"
  in
  let sk = Signature_lib.Private_key.of_string_exn "1" in
  let pk =
    Signature_lib.Public_key.compress
      (Signature_lib.Public_key.of_private_key_exn sk)
  in
  let t =
    Coinbase.create ~receiver:pk
      ~amount:(Currency.Amount.of_nanomina_int_exn 1_000_000_000)
      ~fee_transfer:None
    |> Or_error.ok_exn
  in
  let got = Coinbase.to_base58_check t in
  Alcotest.(check string)
    "Coinbase(pk=sk1,amount=1mina) encoding is stable" expected got

(* Fee_transfer.Single: receiver = Public_key from sk=1, fee = 1 MINA *)
let test_fee_transfer_single_encoding () =
  let expected =
    "4p8SpCfcwojr4GDHbkojwrMAMviNNZKAbPoaSDbsfiTdsJPy9GdzB8MKcRtNRqETjt4U7un5JPtBJHdv8zgPXuVDmPUwc8J2W4k1W6"
  in
  let sk = Signature_lib.Private_key.of_string_exn "1" in
  let pk =
    Signature_lib.Public_key.compress
      (Signature_lib.Public_key.of_private_key_exn sk)
  in
  let t =
    Fee_transfer.Single.create ~receiver_pk:pk
      ~fee:(Currency.Fee.of_nanomina_int_exn 1_000_000_000)
      ~fee_token:Token_id.default
  in
  let got = Fee_transfer.Single.to_base58_check t in
  Alcotest.(check string)
    "Fee_transfer.Single(pk=sk1,fee=1mina) encoding is stable" expected got

(* Transaction_hash: Blake2 digest of empty string *)
let test_transaction_hash_empty_encoding () =
  let expected = "5Jtbief8xNFRyCFfuivdBdXZyKiW8LgfgTttqbLpwkGEscLnUMuH" in
  let t = Mina_transaction.Transaction_hash.digest_string "" in
  let got = Mina_transaction.Transaction_hash.to_base58_check t in
  Alcotest.(check string)
    "Transaction_hash(digest \"\") encoding is stable" expected got
