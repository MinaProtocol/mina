open Core_kernel
open Random_oracle_input
open Alcotest

(* Simple tests converted from inline tests *)

(* Test 1: Basic Legacy functionality *)
let test_legacy_append () =
  let input1 = Legacy.field_elements [| [ true; false ] |] in
  let input2 = Legacy.field_elements [| [ false; true ] |] in
  let result = Legacy.append input1 input2 in
  check bool "legacy append should combine field elements" true
    (Array.length result.field_elements = 2)

(* Test 2: Basic Chunked functionality *)
let test_chunked_append () =
  let input1 = Chunked.field_elements [| [ true; false ] |] in
  let input2 = Chunked.field_elements [| [ false; true ] |] in
  let result = Chunked.append input1 input2 in
  check bool "chunked append should combine field elements" true
    (Array.length result.field_elements = 2)

(* Test 3: Legacy to_bits preserves data structure *)
let test_legacy_to_bits_basic () =
  let input_fields = Legacy.field_elements [| [ true; false; true; false ] |] in
  let input_bits = Legacy.bitstrings [| [ true; true ] |] in
  let input = Legacy.append input_fields input_bits in

  let bits = Legacy.to_bits ~unpack:Fn.id input in

  (* Should have field bits followed by bitstring bits *)
  let expected_length = 4 + 2 in
  (* 4 field bits + 2 bitstring bits *)
  check bool "to_bits should preserve bit count" true
    (List.length bits = expected_length)

(* Test 4: Legacy pack_to_fields basic functionality *)
let test_legacy_pack_to_fields_basic () =
  let input_fields = Legacy.field_elements [| [ true; false; true ] |] in
  let input_bits = Legacy.bitstrings [| [ true; false ] |] in
  let input = Legacy.append input_fields input_bits in

  let fields = Legacy.pack_to_fields ~size_in_bits:8 ~pack:Fn.id input in

  (* Should have at least the original field elements *)
  check bool "pack_to_fields should preserve field elements" true
    (Array.length fields >= Array.length input.field_elements)

(* Test 5: Chunked field_elements constructor *)
let test_chunked_field_elements () =
  let fields = [| [ true; false ]; [ false; true ] |] in
  let input = Chunked.field_elements fields in

  check bool "field_elements constructor should set fields correctly" true
    (Array.length input.field_elements = Array.length fields) ;
  check bool "field_elements constructor should have empty packeds" true
    (Array.length input.packeds = 0)

(* Test 6: Chunked packeds constructor *)
let test_chunked_packeds () =
  let packeds = [| ([ true; false ], 2); ([ false; true ], 2) |] in
  let input = Chunked.packeds packeds in

  check bool "packeds constructor should set packeds correctly" true
    (Array.length input.packeds = Array.length packeds) ;
  check bool "packeds constructor should have empty field_elements" true
    (Array.length input.field_elements = 0)

(* Test 7: Legacy field_elements constructor *)
let test_legacy_field_elements () =
  let fields = [| [ true; false ]; [ false; true ] |] in
  let input = Legacy.field_elements fields in

  check bool "field_elements constructor should set fields correctly" true
    (Array.length input.field_elements = Array.length fields) ;
  check bool "field_elements constructor should have empty bitstrings" true
    (Array.length input.bitstrings = 0)

(* Test 8: Legacy bitstrings constructor *)
let test_legacy_bitstrings () =
  let bitstrings = [| [ true; false ]; [ false; true ] |] in
  let input = Legacy.bitstrings bitstrings in

  check bool "bitstrings constructor should set bitstrings correctly" true
    (Array.length input.bitstrings = Array.length bitstrings) ;
  check bool "bitstrings constructor should have empty field_elements" true
    (Array.length input.field_elements = 0)

(* Main test runner *)
let () =
  run "Random_oracle_input tests"
    [ ( "Legacy module tests"
      , [ test_case "append functionality" `Quick test_legacy_append
        ; test_case "to_bits basic functionality" `Quick
            test_legacy_to_bits_basic
        ; test_case "pack_to_fields basic functionality" `Quick
            test_legacy_pack_to_fields_basic
        ; test_case "field_elements constructor" `Quick
            test_legacy_field_elements
        ; test_case "bitstrings constructor" `Quick test_legacy_bitstrings
        ] )
    ; ( "Chunked module tests"
      , [ test_case "append functionality" `Quick test_chunked_append
        ; test_case "field_elements constructor" `Quick
            test_chunked_field_elements
        ; test_case "packeds constructor" `Quick test_chunked_packeds
        ] )
    ]
