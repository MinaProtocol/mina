let expected_chain_id =
  "6b85faf1acaf4ce3b5483bc48913970ef7a9241d5b8337cbc416aa2bfb1b6ff1"

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
