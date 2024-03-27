(* Testing
   -------

   Component: Pickles
   Subject: Test Step_verifier
   Invocation: \
    dune exec src/lib/pickles/test/main.exe -- test "Step verifier"
*)

module Step_main_inputs = Pickles__Step_main_inputs
open Step_main_inputs.Impl

let run k =
  let y =
    run_and_check (fun () ->
        let y = k () in
        fun () -> As_prover.read_var y )
    |> Or_error.ok_exn
  in
  y

let test_side_loaded_domains () =
  let module O = One_hot_vector.Make (Impl) in
  let open Pickles__Side_loaded_verification_key in
  let domains = [ { Domains.h = 10 }; { h = 15 } ] in
  let pt = Field.Constant.random () in
  List.iter domains ~f:(fun ds ->
      let d_unchecked =
        Plonk_checks.domain
          (module Field.Constant)
          (Pow_2_roots_of_unity ds.h) ~shifts:Common.tick_shifts
          ~domain_generator:Backend.Tick.Field.domain_generator
      in
      let checked_domain () =
        Pickles__Step_verifier.For_tests_only.side_loaded_domain
          ~log2_size:(Field.of_int ds.h)
      in
      let pp ppf cst =
        Format.pp_print_string ppf (Field.Constant.to_string cst)
      in
      (Alcotest.check (Alcotest.testable pp Field.Constant.equal))
        "side loaded domains"
        (d_unchecked#vanishing_polynomial pt)
        (run (fun () ->
             (checked_domain ())#vanishing_polynomial (Field.constant pt) ) ) )

let tests =
  let open Alcotest in
  [ ( "Step verifier"
    , [ test_case "side loaded domains" `Quick test_side_loaded_domains ] )
  ]
