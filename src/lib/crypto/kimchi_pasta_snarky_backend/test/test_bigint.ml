open Core_kernel

let test_hex_conversion () =
  let module Bigint = Kimchi_pasta_snarky_backend.Bigint256 in
  let length_in_bytes = Bigint.length_in_bytes in
  let bytes =
    String.init length_in_bytes ~f:(fun _ -> Char.of_int_exn (Random.int 255))
  in
  let h = "0x" ^ Hex.encode bytes in
  Alcotest.(check string)
    "Hex conversion works correctly" (String.lowercase h)
    (String.lowercase (Bigint.to_hex_string (Bigint.of_hex_string h)))

let test_hex_conversion_failwith_raised () =
  let module Bigint = Kimchi_pasta_snarky_backend.Bigint256 in
  let length_in_bytes = Bigint.length_in_bytes in
  let bytes =
    String.init length_in_bytes ~f:(fun _ -> Char.of_int_exn (Random.int 255))
  in
  let h = Hex.encode bytes in
  try
    ignore @@ Bigint.of_hex_string h ;
    Alcotest.fail "Expected failure when not starting with 0x"
  with
  | Failure msg ->
      Alcotest.(check string)
        "Hex conversion failure raised correctly"
        "Bigint.of_hex_string: Hex string must start with 0x or 0X" msg
  | _ ->
      Alcotest.fail "Unexpected exception raised"

let () =
  let open Alcotest in
  run "Bigint256"
    [ ( "hex conversion"
      , [ test_case "hex conversion roundtrip" `Quick test_hex_conversion
        ; test_case "hex conversion failwith raised" `Quick
            test_hex_conversion_failwith_raised
        ] )
    ]
