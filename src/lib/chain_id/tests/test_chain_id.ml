let expected_chain_id =
  "b8241e7e1f80dc1bf9b7a8b0d377749ab96273b3cd22b6910ec964ba4c4c4a62"

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
