(* Filesystem cache control test - should not deadlock *)
open Async

let () =
  printf "Running Filesystem cache control test...\n%!" ;
  Thread_safe.block_on_async_exn (fun () ->
      let%bind res =
        Test_cache_deadlock_lib.Test_cache_deadlock.test_cache_deadlock
          (module Disk_cache)
      in
      match res with
      | `Success ->
          printf "Success" ; Deferred.unit
      | `Timeout ->
          failwith "The process should not time out" )
