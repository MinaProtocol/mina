(* The chain id commits to the transaction snark verification key, so it
   changes whenever the transaction circuit does. On failure, Alcotest prints
   the computed value; copy it here. *)
let expected_chain_id =
  "ecaf827b4c80ea76fd65e526ae4068649549f87f084671636ea7aa74b62e860f"

let test_of_precomputed_values () =
  let pv = Lazy.force Precomputed_values.for_unit_tests in
  let chain_id = Lazy.force (Chain_id.of_precomputed_values pv) in
  Alcotest.(check string)
    "chain_id matches expected" expected_chain_id
    (Chain_id.to_string chain_id)

let () =
  let open Alcotest in
  run "Chain_id"
    [ ( "of_precomputed_values"
      , [ test_case "unit test params produce expected chain_id" `Quick
            test_of_precomputed_values
        ] )
    ]
