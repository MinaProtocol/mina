open Core_kernel
open Rosetta_coding.Coding
module Field = Snark_params.Tick.Field
module Scalar = Snark_params.Tick.Inner_curve.Scalar
open Signature_lib

let field_hex_roundtrip_test () =
  let field0 = Field.of_int 123123 in
  let hex = of_field field0 in
  let field1 = to_field hex in
  Alcotest.(check bool) "field hex roundtrip" true (Field.equal field0 field1)

let pk_roundtrip_test () =
  let pk =
    { Public_key.Compressed.Poly.x = Field.of_int 123123; is_odd = true }
  in
  let hex = of_public_key_compressed pk in
  let pk' = to_public_key_compressed hex in
  Alcotest.(check bool)
    "public key roundtrip" true
    (Public_key.Compressed.equal pk pk')

let hex_key_odd =
  "fad1d3e31aede102793fb2cce62b4f1e71a214c94ce18ad5756eba67ef398390"

let hex_key_even =
  "7e406ca640115a8c44ece6ef5d0c56af343b1a993d8c871648ab7980ecaf8230"

let pk_compressed_roundtrip_test hex_key () =
  let pk = to_public_key hex_key in
  let hex' = of_public_key pk in
  Alcotest.(check string)
    "public key compressed roundtrip" (String.lowercase hex_key)
    (String.lowercase hex')

let pk_compressed_roundtrip_odd_test () =
  pk_compressed_roundtrip_test hex_key_odd ()

let pk_compressed_roundtrip_even_test () =
  pk_compressed_roundtrip_test hex_key_even ()

let tests =
  [ ("field_hex_roundtrip", `Quick, field_hex_roundtrip_test)
  ; ("pk_roundtrip", `Quick, pk_roundtrip_test)
  ; ("pk_compressed_roundtrip_odd", `Quick, pk_compressed_roundtrip_odd_test)
  ; ("pk_compressed_roundtrip_even", `Quick, pk_compressed_roundtrip_even_test)
  ]

let () =
  let open Alcotest in
  run "Rosetta_coding" [ ("roundtrip_tests", tests) ]
