(** Testing
    -------
    Component: Kimchi gadgets - Lookup
    Subject: Testing lookup gadgets
    Invocation: dune exec \
      src/lib/crypto/kimchi_backend/gadgets/tests/test_lookup.exe *)

open Kimchi_gadgets
open Kimchi_gadgets_test_runner

let () =
  try Kimchi_pasta.Vesta_based_plonk.Keypair.set_urs_info [] with _ -> ()

(** Test lookup less_than_bits gadget for both variables and constants. *)
let test_lookup ?cs ~bits value =
  let cs, _proof_keypair, _proof =
    Runner.generate_and_verify_proof ?cs (fun () ->
        let open Runner.Impl in
        let const = Field.constant @@ Field.Constant.of_int value in
        let value =
          exists Field.typ ~compute:(fun () -> Field.Constant.of_int value)
        in
        Lookup.less_than_bits ~bits value ;
        Lookup.less_than_bits ~bits const ;
        (* Use a dummy range check to load the table *)
        Range_check.bits64 Field.zero ;
        () )
  in
  cs

let test_lookup_positive () =
  let cs12 = test_lookup ~bits:12 4095 in
  let _cs8 = test_lookup ~bits:8 255 in
  let cs1 = test_lookup ~bits:1 0 in
  let _cs = test_lookup ~cs:cs1 ~bits:1 1 in
  ignore cs12 ; ()

let test_lookup_negative () =
  let cs12 = test_lookup ~bits:12 4095 in
  let cs8 = test_lookup ~bits:8 255 in
  let cs1 = test_lookup ~bits:1 0 in
  Alcotest.(check bool)
    "4096 with 12 bits should fail" true
    (Common.is_error (fun () -> test_lookup ~cs:cs12 ~bits:12 4096)) ;
  Alcotest.(check bool)
    "-1 with 12 bits should fail" true
    (Common.is_error (fun () -> test_lookup ~cs:cs12 ~bits:12 (-1))) ;
  Alcotest.(check bool)
    "256 with 8 bits should fail" true
    (Common.is_error (fun () -> test_lookup ~cs:cs8 ~bits:8 256)) ;
  Alcotest.(check bool)
    "2 with 1 bit should fail" true
    (Common.is_error (fun () -> test_lookup ~cs:cs1 ~bits:1 2))

let () =
  let open Alcotest in
  run "Lookup gadgets"
    [ ( "less_than_bits"
      , [ test_case "positive tests" `Quick test_lookup_positive
        ; test_case "negative tests" `Quick test_lookup_negative
        ] )
    ]
