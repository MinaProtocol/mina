(** Property-based tests for zkApp signature verification.

    These tests use Quickcheck to verify properties of the signature verification
    system that should hold for arbitrary inputs.

    Invocation: dune exec src/lib/mina_base/test/main.exe -- test '^zkApp signature PBT'
*)

open Core
open Mina_base
open Signature_lib
open Base_quickcheck

(* Random seed for Quickcheck tests - deterministic within a single test run *)
let quickcheck_seed =
  let () = Random.self_init () in
  let seed_phrase = List.init 32 ~f:(fun _ -> Random.int 256) in
  let seed_str =
    List.map seed_phrase ~f:Char.of_int_exn |> String.of_char_list
  in
  `Deterministic seed_str

(** Property test: Verify different nonces produce different signatures,
    and that Verifier.Common correctly validates each one independently. *)
let test_pbt_nonce_affects_signature () =
  let fee_payer_sk =
    Private_key.of_base58_check_exn
      "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N"
  in
  let fee_payer_kp = Keypair.of_private_key_exn fee_payer_sk in
  let fee_payer_pk = Public_key.compress fee_payer_kp.public_key in
  let memo = Signed_command_memo.create_from_string_exn "nonce test" in
  let make_and_sign_command ~signature_kind nonce =
    let fee_payer : Account_update.Fee_payer.t =
      Account_update.Fee_payer.make
        ~body:
          { public_key = fee_payer_pk
          ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000_000
          ; valid_until = None
          ; nonce = Mina_numbers.Account_nonce.of_int nonce
          }
        ~authorization:Signature.dummy
    in
    let unsigned =
      Zkapp_command.write_all_proofs_to_disk ~signature_kind
        ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
        { Zkapp_command.Poly.fee_payer; memo; account_updates = [] }
    in
    Zkapp_command_builder.sign_zkapp_command ~signature_kind ~fee_payer_sk
      ~account_update_keys:Public_key.Compressed.Map.empty unsigned
  in
  (* Generate signature kind and pairs of distinct nonces *)
  let test_input_gen =
    let open Generator in
    let open Let_syntax in
    let%bind signature_kind =
      Mina_signature_kind_type.signature_kind_gen quickcheck_seed
    in
    let%bind nonce_a = int_inclusive 0 1_000_000 in
    let%map nonce_b = int_inclusive 0 1_000_000 in
    (signature_kind, nonce_a, nonce_b)
  in
  Quickcheck.test ~seed:quickcheck_seed ~trials:10 test_input_gen
    ~f:(fun (signature_kind, nonce_a, nonce_b) ->
      if nonce_a <> nonce_b then (
        let signed_a = make_and_sign_command ~signature_kind nonce_a in
        let signed_b = make_and_sign_command ~signature_kind nonce_b in
        (* Both should be accepted by Verifier.Common *)
        let result_a =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            signed_a
        in
        let result_b =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            signed_b
        in
        Alcotest.(check bool)
          (Printf.sprintf "Verifier.Common accepts nonce %d" nonce_a)
          true (Result.is_ok result_a) ;
        Alcotest.(check bool)
          (Printf.sprintf "Verifier.Common accepts nonce %d" nonce_b)
          true (Result.is_ok result_b) ;
        (* Verify the signatures are different (sanity check) *)
        Alcotest.(check bool)
          (Printf.sprintf
             "different nonces (%d, %d) produce different fee_payer signatures"
             nonce_a nonce_b )
          false
          (Signature.equal signed_a.fee_payer.authorization
             signed_b.fee_payer.authorization ) ) )

(** Property test: Verify different fee payers produce different signatures,
    ensuring the fee payer public key is part of the signed data. *)
let test_pbt_fee_payer_affects_signature () =
  let memo = Signed_command_memo.create_from_string_exn "fee payer test" in
  let make_and_sign_command ~signature_kind keypair =
    let fee_payer_pk = Public_key.compress keypair.Keypair.public_key in
    let fee_payer : Account_update.Fee_payer.t =
      Account_update.Fee_payer.make
        ~body:
          { public_key = fee_payer_pk
          ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000_000
          ; valid_until = None
          ; nonce = Mina_numbers.Account_nonce.zero
          }
        ~authorization:Signature.dummy
    in
    let unsigned =
      Zkapp_command.write_all_proofs_to_disk ~signature_kind
        ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
        { Zkapp_command.Poly.fee_payer; memo; account_updates = [] }
    in
    Zkapp_command_builder.sign_zkapp_command ~signature_kind
      ~fee_payer_sk:keypair.private_key
      ~account_update_keys:Public_key.Compressed.Map.empty unsigned
  in
  (* Generate signature kind and two distinct keypairs *)
  let test_input_gen =
    let open Generator in
    let open Let_syntax in
    let%bind signature_kind =
      Mina_signature_kind_type.signature_kind_gen quickcheck_seed
    in
    let%bind keypair_a = Keypair.gen in
    let%map keypair_b = Keypair.gen in
    (signature_kind, keypair_a, keypair_b)
  in
  Quickcheck.test ~seed:quickcheck_seed ~trials:10 test_input_gen
    ~f:(fun (signature_kind, keypair_a, keypair_b) ->
      let pk_a = Public_key.compress keypair_a.public_key in
      let pk_b = Public_key.compress keypair_b.public_key in
      if not (Public_key.Compressed.equal pk_a pk_b) then (
        let signed_a = make_and_sign_command ~signature_kind keypair_a in
        let signed_b = make_and_sign_command ~signature_kind keypair_b in
        (* Both should be accepted by Verifier.Common *)
        let result_a =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            signed_a
        in
        let result_b =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            signed_b
        in
        Alcotest.(check bool)
          "Verifier.Common accepts keypair_a" true (Result.is_ok result_a) ;
        Alcotest.(check bool)
          "Verifier.Common accepts keypair_b" true (Result.is_ok result_b) ;
        (* Verify the signatures are different (sanity check) *)
        Alcotest.(check bool)
          "different fee payers produce different signatures" false
          (Signature.equal signed_a.fee_payer.authorization
             signed_b.fee_payer.authorization ) ) )

(** Property test: Verify different fee amounts produce different signatures,
    ensuring the fee is part of the signed data. *)
let test_pbt_fee_amount_affects_signature () =
  let fee_payer_sk =
    Private_key.of_base58_check_exn
      "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N"
  in
  let fee_payer_kp = Keypair.of_private_key_exn fee_payer_sk in
  let fee_payer_pk = Public_key.compress fee_payer_kp.public_key in
  let memo = Signed_command_memo.create_from_string_exn "fee amount test" in
  let make_and_sign_command ~signature_kind fee_nanomina =
    let fee_payer : Account_update.Fee_payer.t =
      Account_update.Fee_payer.make
        ~body:
          { public_key = fee_payer_pk
          ; fee = Currency.Fee.of_nanomina_int_exn fee_nanomina
          ; valid_until = None
          ; nonce = Mina_numbers.Account_nonce.zero
          }
        ~authorization:Signature.dummy
    in
    let unsigned =
      Zkapp_command.write_all_proofs_to_disk ~signature_kind
        ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
        { Zkapp_command.Poly.fee_payer; memo; account_updates = [] }
    in
    Zkapp_command_builder.sign_zkapp_command ~signature_kind ~fee_payer_sk
      ~account_update_keys:Public_key.Compressed.Map.empty unsigned
  in
  (* Generate signature kind and two distinct fee amounts *)
  let test_input_gen =
    let open Generator in
    let open Let_syntax in
    let%bind signature_kind =
      Mina_signature_kind_type.signature_kind_gen quickcheck_seed
    in
    (* Fee must be at least 1 nanomina, use reasonable range *)
    let%bind fee_a = int_inclusive 1_000_000 10_000_000_000 in
    let%map fee_b = int_inclusive 1_000_000 10_000_000_000 in
    (signature_kind, fee_a, fee_b)
  in
  Quickcheck.test ~seed:quickcheck_seed ~trials:10 test_input_gen
    ~f:(fun (signature_kind, fee_a, fee_b) ->
      if fee_a <> fee_b then (
        let signed_a = make_and_sign_command ~signature_kind fee_a in
        let signed_b = make_and_sign_command ~signature_kind fee_b in
        (* Both should be accepted by Verifier.Common *)
        let result_a =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            signed_a
        in
        let result_b =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            signed_b
        in
        Alcotest.(check bool)
          (Printf.sprintf "Verifier.Common accepts fee %d" fee_a)
          true (Result.is_ok result_a) ;
        Alcotest.(check bool)
          (Printf.sprintf "Verifier.Common accepts fee %d" fee_b)
          true (Result.is_ok result_b) ;
        (* Verify the signatures are different (sanity check) *)
        Alcotest.(check bool)
          (Printf.sprintf
             "different fees (%d, %d) produce different fee_payer signatures"
             fee_a fee_b )
          false
          (Signature.equal signed_a.fee_payer.authorization
             signed_b.fee_payer.authorization ) ) )

(** Property test: Verify signing with wrong key produces invalid signature.
    This ensures the public key in the account update body is actually used for
    verification, as enforced by transaction_snark.ml. *)
let test_pbt_wrong_key_signature_fails () =
  let memo = Signed_command_memo.create_from_string_exn "wrong key test" in
  let make_command ~signature_kind keypair =
    let fee_payer_pk = Public_key.compress keypair.Keypair.public_key in
    let fee_payer : Account_update.Fee_payer.t =
      Account_update.Fee_payer.make
        ~body:
          { public_key = fee_payer_pk
          ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000_000
          ; valid_until = None
          ; nonce = Mina_numbers.Account_nonce.zero
          }
        ~authorization:Signature.dummy
    in
    Zkapp_command.write_all_proofs_to_disk ~signature_kind
      ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
      { Zkapp_command.Poly.fee_payer; memo; account_updates = [] }
  in
  (* Generate signature kind and two distinct keypairs *)
  let test_input_gen =
    let open Generator in
    let open Let_syntax in
    let%bind signature_kind =
      Mina_signature_kind_type.signature_kind_gen quickcheck_seed
    in
    let%bind keypair_correct = Keypair.gen in
    let%map keypair_wrong = Keypair.gen in
    (signature_kind, keypair_correct, keypair_wrong)
  in
  Quickcheck.test ~seed:quickcheck_seed ~trials:10 test_input_gen
    ~f:(fun (signature_kind, keypair_correct, keypair_wrong) ->
      let pk_correct = Public_key.compress keypair_correct.public_key in
      let pk_wrong = Public_key.compress keypair_wrong.public_key in
      if not (Public_key.Compressed.equal pk_correct pk_wrong) then (
        let unsigned = make_command ~signature_kind keypair_correct in
        (* Sign with correct key - should pass *)
        let correctly_signed =
          Zkapp_command_builder.sign_zkapp_command ~signature_kind
            ~fee_payer_sk:keypair_correct.private_key
            ~account_update_keys:Public_key.Compressed.Map.empty unsigned
        in
        let correct_result =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            correctly_signed
        in
        Alcotest.(check bool)
          "Verifier.Common accepts correctly signed command" true
          (Result.is_ok correct_result) ;
        (* Sign with wrong key - should fail *)
        let wrongly_signed =
          Zkapp_command_builder.sign_zkapp_command ~signature_kind
            ~fee_payer_sk:keypair_wrong.private_key
            ~account_update_keys:Public_key.Compressed.Map.empty unsigned
        in
        let wrong_result =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            wrongly_signed
        in
        Alcotest.(check bool)
          "Verifier.Common rejects command signed with wrong key" true
          (Result.is_error wrong_result) ;
        (* Check it's specifically an Invalid_signature error *)
        match wrong_result with
        | Error (`Invalid_signature _) ->
            ()
        | Error _ ->
            Alcotest.fail "expected Invalid_signature error"
        | Ok () ->
            Alcotest.fail "expected verification to fail" ) )

(** Property test: Verify different valid_until values produce different signatures,
    ensuring valid_until is part of the signed data. *)
let test_pbt_valid_until_affects_signature () =
  let fee_payer_sk =
    Private_key.of_base58_check_exn
      "EKE2M5q5afTtdzZTzyKu89Pzc7274BD6fm2fsDLgLt5zy34TAN5N"
  in
  let fee_payer_kp = Keypair.of_private_key_exn fee_payer_sk in
  let fee_payer_pk = Public_key.compress fee_payer_kp.public_key in
  let memo = Signed_command_memo.create_from_string_exn "valid_until test" in
  let make_and_sign_command ~signature_kind valid_until =
    let fee_payer : Account_update.Fee_payer.t =
      Account_update.Fee_payer.make
        ~body:
          { public_key = fee_payer_pk
          ; fee = Currency.Fee.of_nanomina_int_exn 1_000_000_000
          ; valid_until
          ; nonce = Mina_numbers.Account_nonce.zero
          }
        ~authorization:Signature.dummy
    in
    let unsigned =
      Zkapp_command.write_all_proofs_to_disk ~signature_kind
        ~proof_cache_db:(Proof_cache_tag.For_tests.create_db ())
        { Zkapp_command.Poly.fee_payer; memo; account_updates = [] }
    in
    Zkapp_command_builder.sign_zkapp_command ~signature_kind ~fee_payer_sk
      ~account_update_keys:Public_key.Compressed.Map.empty unsigned
  in
  (* Generate signature kind and two distinct valid_until values *)
  let test_input_gen =
    let open Generator in
    let open Let_syntax in
    let%bind signature_kind =
      Mina_signature_kind_type.signature_kind_gen quickcheck_seed
    in
    let%bind slot_a = int_inclusive 0 1_000_000 in
    let%map slot_b = int_inclusive 0 1_000_000 in
    let valid_until_a =
      Some (Mina_numbers.Global_slot_since_genesis.of_int slot_a)
    in
    let valid_until_b =
      Some (Mina_numbers.Global_slot_since_genesis.of_int slot_b)
    in
    (signature_kind, valid_until_a, valid_until_b, slot_a, slot_b)
  in
  Quickcheck.test ~seed:quickcheck_seed ~trials:10 test_input_gen
    ~f:(fun (signature_kind, valid_until_a, valid_until_b, slot_a, slot_b) ->
      if slot_a <> slot_b then (
        let signed_a = make_and_sign_command ~signature_kind valid_until_a in
        let signed_b = make_and_sign_command ~signature_kind valid_until_b in
        (* Both should be accepted by Verifier.Common *)
        let result_a =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            signed_a
        in
        let result_b =
          Verifier.Common.check_signatures_of_zkapp_command ~signature_kind
            signed_b
        in
        Alcotest.(check bool)
          (Printf.sprintf "Verifier.Common accepts valid_until %d" slot_a)
          true (Result.is_ok result_a) ;
        Alcotest.(check bool)
          (Printf.sprintf "Verifier.Common accepts valid_until %d" slot_b)
          true (Result.is_ok result_b) ;
        (* Verify the signatures are different (sanity check) *)
        Alcotest.(check bool)
          (Printf.sprintf
             "different valid_until (%d, %d) produce different fee_payer \
              signatures"
             slot_a slot_b )
          false
          (Signature.equal signed_a.fee_payer.authorization
             signed_b.fee_payer.authorization ) ) )
