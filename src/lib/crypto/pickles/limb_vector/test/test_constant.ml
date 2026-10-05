(* Testing
   -------

   Component: Pickles / Limb_vector
   Subject: Test Constant (Hex64)
   Invocation: dune exec src/lib/pickles/limb_vector/test/test_constant.exe
*)

let test_hex_conversion () =
  let open Constant.Hex64 in
  Quickcheck.test (Int64.gen_incl zero max_value) ~f:(fun x ->
      assert (equal x (of_hex (to_hex x))) )

let test_hex_failure () =
  match Constant.Hex64.of_hex "ghi" with
  | exception Invalid_argument _ ->
      ()
  | _ ->
      assert false

let () =
  let open Alcotest in
  run "Limb_vector"
    [ ( "Constant:Hex64"
      , [ test_case "hex roundtrip" `Quick test_hex_conversion
        ; test_case "hex conversion failure" `Quick test_hex_failure
        ] )
    ]
