open Core_kernel
open Secrets.Secret_box

let test_successful_roundtrip () =
  (* 4 trials because password hashing is slow *)
  let bgen = Bytes.gen_with_length 16 Char.quickcheck_generator in
  Quickcheck.test
    Quickcheck.Generator.(tuple2 bgen bgen)
    ~trials:4
    ~f:(fun (password, plaintext) ->
      let enc = encrypt ~password:(Bytes.copy password) ~plaintext in
      let dec = Option.value_exn (decrypt enc ~password |> Result.ok) in
      Alcotest.(check bool)
        "Roundtrip decryption should succeed" true
        (Bytes.equal dec plaintext) )

let test_bad_password_fails () =
  let enc =
    encrypt ~password:(Bytes.of_string "foobar")
      ~plaintext:(Bytes.of_string "yo")
  in
  let result = decrypt ~password:(Bytes.of_string "barfoo") enc in
  Alcotest.(check bool) "Bad password should fail" true (Result.is_error result)

let () =
  Alcotest.run "Secret_box"
    [ ( "Encryption/Decryption"
      , [ Alcotest.test_case "Successful roundtrip" `Quick
            test_successful_roundtrip
        ; Alcotest.test_case "Bad password fails" `Quick test_bad_password_fails
        ] )
    ]
