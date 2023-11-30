let test_hex_conversion () =
  let open Constant.Hex64 in
  Quickcheck.test (Int64.gen_incl zero max_value) ~f:(fun x ->
      assert (equal x (of_hex (to_hex x))) )

let () =
  let open Alcotest in
  run "Limb_vector"
    [ ("Constant", [ test_case "hex roundtrip" `Quick test_hex_conversion ]) ]
