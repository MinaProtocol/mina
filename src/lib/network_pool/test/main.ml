open Alcotest

let () =
  run "Test the network pool."
    [ Indexed_pool_tests.
      ("indexed pool",
       [ test_case "Test invariants hold on empty data structure." `Quick empty_invariants
      ])
    ]
