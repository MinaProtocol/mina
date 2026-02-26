open Core_kernel
open Snarky_blake2

(* Module for Blake2 Snarky implementation tests
   These tests verify that our constraint-based implementation using Snarky
   produces the same results as the regular Blake2 implementation
   and stays within constraint limits for performance reasons *)
module Blake2_tests = struct
  (* Using Tick implementation from Snark_params *)
  module Impl = Snark_params.Tick
  include Make (Impl)

  (* Helper to convert constraint-based checked computation to unchecked result *)
  let checked_to_unchecked typ1 typ2 checked input =
    let open Impl in
    let checked_result =
      run_and_check
        (let%bind input = exists typ1 ~compute:(As_prover.return input) in
         let%map result = checked input in
         As_prover.read typ2 result )
      |> Or_error.ok_exn
    in
    checked_result

  (* Test if constraint-based and native implementations produce equal results *)
  let test_equal ?(sexp_of_t = sexp_of_opaque) ?(equal = Poly.( = )) typ1 typ2
      checked unchecked input =
    let checked_result = checked_to_unchecked typ1 typ2 checked input in
    let unchecked_result = unchecked input in
    let equal_results = equal checked_result unchecked_result in
    if not equal_results then
      Printf.printf "Checked: %s\nUnchecked: %s\n"
        (Sexp.to_string (sexp_of_t checked_result))
        (Sexp.to_string (sexp_of_t unchecked_result)) ;
    equal_results

  (* Native Blake2 implementation for comparison *)
  let blake2_unchecked s =
    Blake2.string_to_bits
      Digestif.BLAKE2S.(
        digest_string (Blake2.bits_to_string s) |> to_raw_string)

  (* Utility to convert bit array to string representation *)
  let to_bitstring bits =
    String.init (Array.length bits) ~f:(fun i -> if bits.(i) then '1' else '0')

  (* Test 1: Verify constraint count stays within acceptable limits
     This is crucial for SNARK performance in Mina *)
  let test_constraint_count () =
    let constraint_count =
      Impl.constraint_count (fun () ->
          let open Impl in
          let%bind bits =
            exists
              (Typ.array ~length:512 Boolean.typ_unchecked)
              ~compute:(As_prover.return (Array.create ~len:512 true))
          in
          blake2s bits )
    in
    Alcotest.(check bool)
      "constraint count is within limit (<=21278)" true
      (constraint_count <= 21278) ;
    Printf.printf "Blake2s constraint count: %d\n" constraint_count

  (* Test 2: Verify Snarky implementation matches native Blake2
     This ensures our constraint system correctly implements the hash function *)
  let test_blake2_equality () =
    let input =
      let open Quickcheck.Let_syntax in
      let%bind n = Int.gen_incl 0 (1024 / 8) in
      let%map x = String.gen_with_length n Char.quickcheck_generator in
      (n, Blake2.string_to_bits x)
    in
    let output_typ =
      Impl.Typ.array ~length:digest_length_in_bits Impl.Boolean.typ
    in
    let success = ref true in
    let total_tests = 20 in
    let passed_tests = ref 0 in

    Quickcheck.test ~trials:total_tests input ~f:(fun (n, input) ->
        let input_typ = Impl.Typ.array ~length:(8 * n) Impl.Boolean.typ in
        let result =
          test_equal
            ~sexp_of_t:(Fn.compose [%sexp_of: string] to_bitstring)
            input_typ output_typ
            (blake2s ?personalization:None)
            blake2_unchecked input
        in
        if result then incr passed_tests else success := false ) ;

    Printf.printf "Blake2 equality tests: %d/%d passed\n" !passed_tests
      total_tests ;

    Alcotest.(check bool)
      "blake2 equality matches for all test cases" true !success
end

(* Run Alcotest *)
let () =
  Alcotest.run "Snarky_blake2"
    [ ( "Blake2 SNARK Implementation"
      , [ Alcotest.test_case "Constraint count efficiency" `Quick
            Blake2_tests.test_constraint_count
        ; Alcotest.test_case "Matches native Blake2 implementation" `Quick
            Blake2_tests.test_blake2_equality
        ] )
    ]
