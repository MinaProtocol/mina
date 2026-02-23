open Core_kernel
open Snarky
open Snark
open Snarky_integer
open Util
open Snarky_taylor.Floating_point

let test_of_quotient () =
  let module M = Snark_params.Tick.Run in
  let m : _ m = (module M) in

  (* Setup a generator for test cases *)
  let gen =
    let open Quickcheck in
    let open Generator.Let_syntax in
    let m = B.((one lsl 32) - one) in
    let%bind a = B.(gen_incl zero (m - one)) in
    let%map b = B.(gen_incl (a + one) m) in
    (a, b)
  in

  (* Test function that checks a single case with Alcotest *)
  let test_case (a, b) =
    let precision = 32 in
    let res =
      assert (B.(a < b)) ;
      M.run_and_check (fun () ->
          let t =
            of_quotient ~m ~precision ~top:(Integer.constant ~m a)
              ~bottom:(Integer.constant ~m b) ~top_is_less_than_bottom:()
          in
          to_bignum ~m t )
      |> Or_error.ok_exn
    in
    let actual = Bignum.(of_bigint a / of_bigint b) in
    let expected_error_bound = Bignum.(one / of_bigint B.(one lsl precision)) in
    let actual_error = Bignum.(abs (res - actual)) in

    (* Make Alcotest check for this specific case *)
    Alcotest.(check bool)
      (Printf.sprintf "of_quotient %s/%s (error: %s < %s)" (B.to_string a)
         (B.to_string b)
         (Bignum.to_string_hum actual_error)
         (Bignum.to_string_hum expected_error_bound) )
      true
      Bignum.(actual_error < expected_error_bound)
  in

  (* Run with Quickcheck *)
  Quickcheck.test ~trials:5 gen ~f:test_case

(* Main test runner *)
let () =
  Alcotest.run "Floating_point"
    [ ( "Basic operations"
      , [ Alcotest.test_case "of_quotient" `Quick test_of_quotient ] )
    ]
