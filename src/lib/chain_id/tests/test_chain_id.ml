let expected_chain_id =
  "5a4fb27a8f753b1f2efd4c8ea10b212c19fa583e4d08154cfe61a2622b7ecc83"

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
