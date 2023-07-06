let test_with_one_runtime_table_no_fixed_lookup_table () =
  let open Kimchi_pasta.Pallas_based_plonk in
  ()

let () =
  let open Alcotest in
  run "Runtime table"
    [ ( "Scenarii"
      , [ test_case "One runtime table, no fixed lookup table" `Quick
            test_with_one_runtime_table_no_fixed_lookup_table
        ] )
    ]
