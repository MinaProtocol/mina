open Async
open Core

module Tests = struct
  include Disk_cache_test_lib.Make_extended (Disk_cache.Make)

  let test_remove_data_on_gc () =
    Alcotest.test_case "remove data on gc" `Quick (fun () ->
        remove_data_on_gc () )

  let test_simple_read_write_with_iteration () =
    Alcotest.test_case "simple read/write (with iteration)" `Quick (fun () ->
        simple_write_with_iteration () )

  let test_initialization_special_cases () =
    Alcotest.test_case "initialization special cases" `Quick (fun () ->
        initialization_special_cases () )

  let tests =
    [ test_remove_data_on_gc ()
    ; test_simple_read_write_with_iteration ()
    ; test_initialization_special_cases ()
    ]
end

let () = Alcotest.run "Disk_cache_lmdb" [ ("disk_cache lmdb", Tests.tests) ]
