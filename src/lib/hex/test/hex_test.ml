open Core_kernel

(* Create a fixed random string to avoid different test behaviors *)
let create_test_string length seed =
  Random.init seed ;
  String.init length ~f:(fun _ -> Char.of_int_exn (Random.int 256))

(* Test Hex.encode and Hex.decode *)
module Basic_encoding_tests = struct
  (* Standard decode test *)
  let test_decode () =
    let open Hex in
    let t = create_test_string 10 42 in
    let h = encode t in
    let result = decode ~init:String.init h in
    Alcotest.(check string) "decode matches original" t result

  (* Reversed decode test *)
  let test_decode_reversed () =
    let open Hex in
    let t = create_test_string 10 43 in
    let result =
      decode ~reverse:true ~init:String.init (encode ~reverse:true t)
    in
    Alcotest.(check string) "reversed decode matches original" t result

  (* Sequence_be test *)
  let test_sequence_be () =
    let open Hex in
    let t = create_test_string 10 44 in
    let h = encode t in
    let result = Sequence_be.(to_string (decode h)) in
    Alcotest.(check string) "Sequence_be decode matches original" t result
end

(* Test Hex.Safe module *)
module Safe_encoding_tests = struct
  (* Safe.to_hex test *)
  let test_to_hex () =
    let open Hex.Safe in
    let start = "a" in
    let hexified = to_hex start in
    let expected = "61" in
    Alcotest.(check string) "Safe.to_hex works correctly" expected hexified

  (* Safe isomorphism test with specific examples *)
  let test_specific_isomorphism () =
    let open Hex.Safe in
    let test_case label s =
      let hexified = to_hex s in
      let actual = Option.value_exn (of_hex hexified) in
      Alcotest.(check string) label s actual
    in
    test_case "special character" "\243" ;
    test_case "simple ascii" "abc"

  (* Safe isomorphism test with random strings *)
  let test_random_isomorphism () =
    let open Hex.Safe in
    let seed = 45 in
    Random.init seed ;
    for i = 1 to 5 do
      let random_length = Random.int 20 + 1 in
      let random_string =
        String.init random_length ~f:(fun _ ->
            Char.of_int_exn (Random.int 256) )
      in
      let label = Printf.sprintf "random string %d" i in
      let hexified = to_hex random_string in
      let actual = Option.value_exn (of_hex hexified) in
      Alcotest.(check string) label random_string actual
    done
end

(* Main test runner *)
let () =
  let open Alcotest in
  run "Hex"
    [ ( "basic encoding"
      , [ test_case "decode" `Quick Basic_encoding_tests.test_decode
        ; test_case "decode reversed" `Quick
            Basic_encoding_tests.test_decode_reversed
        ; test_case "sequence_be" `Quick Basic_encoding_tests.test_sequence_be
        ] )
    ; ( "safe encoding"
      , [ test_case "to_hex" `Quick Safe_encoding_tests.test_to_hex
        ; test_case "specific isomorphism" `Quick
            Safe_encoding_tests.test_specific_isomorphism
        ; test_case "random isomorphism" `Quick
            Safe_encoding_tests.test_random_isomorphism
        ] )
    ]
