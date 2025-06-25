include Disk_cache_test_lib.Make_extended (Make)

let test_remove_data_on_gc () = remove_data_on_gc ()

let () =
  let open Alcotest in
  run "Disk Cache Tests"
    [ ( "disk_cache_lmdb"
      , [ test_case "remove data on gc" `Quick test_remove_data_on_gc
        ; test_case "simple read/write (with iteration)" `Quick
            test_simple_write_with_iteration
        ; test_case "initialization special cases" `Quick
            test_initialization_special_cases
        ] )
    ]
