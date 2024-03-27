module M = Base58_check.Make (struct
  let description = "Base58check tests"

  let version_byte = '\x53'
end)

open M

let helper_test_roundtrip payload =
  let encoded = encode payload in
  let payload' = decode_exn encoded in
  assert (String.equal payload payload')

let test_roundtrip_empty_string () = helper_test_roundtrip ""

let test_roundtrip_nonempty_string () =
  helper_test_roundtrip "Somewhere, over the rainbow, way up high"

let test_roundtrip_longer_string () =
  helper_test_roundtrip
    "Someday, I wish upon a star, wake up where the clouds are far behind me, \
     where trouble melts like lemon drops, High above the chimney top, that's \
     where you'll find me"

let test_invalid_checksum () =
  try
    let encoded = encode "Bluer than velvet were her eyes" in
    let bytes = Bytes.of_string encoded in
    let len = Bytes.length bytes in
    let last_ch = Bytes.get bytes (len - 1) in
    (* change last byte to invalidate checksum *)
    let new_last_ch =
      if Char.equal last_ch '\xFF' then '\x00'
      else Core_kernel.Char.of_int_exn (Core_kernel.Char.to_int last_ch + 1)
    in
    Bytes.set bytes (len - 1) new_last_ch ;
    let encoded_bad_checksum = Bytes.to_string bytes in
    let _payload = decode_exn encoded_bad_checksum in
    assert false
  with Base58_check.Invalid_base58_checksum _ -> assert true

let test_invalid_length () =
  try
    let _payload = decode_exn "abcd" in
    assert false
  with Base58_check.Invalid_base58_check_length _ -> assert true

let test_vectors () =
  let vectors =
    [ ("", "AR3b7Dr")
    ; ("vectors", "2aML9fKacueS1p5W3")
    ; ("test", "24cUQZMy5c7Mj")
    ]
  in
  assert (
    List.for_all
      (fun (inp, exp_output) ->
        let output = M.encode inp in
        String.equal output exp_output )
      vectors )

let () =
  let open Alcotest in
  run "Base58_check"
    [ ( "test_roundtrip"
      , [ test_case "empty string" `Quick test_roundtrip_empty_string
        ; test_case "non empty string" `Quick test_roundtrip_nonempty_string
        ; test_case "longer string" `Quick test_roundtrip_longer_string
        ] )
    ; ( "negative tests"
      , [ test_case "invalid checksym" `Quick test_invalid_checksum
        ; test_case "invalid length" `Quick test_invalid_length
        ] )
    ; ("test vectors", [ test_case "vectors" `Quick test_vectors ])
    ]
