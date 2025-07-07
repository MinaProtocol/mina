(* LMDB-specific deadlock test *)
open Async

let () =
  printf "Running LMDB cache deadlock test...\n" ;
  Thread_safe.block_on_async_exn (fun () ->
      let%bind res =
        Test_cache_deadlock_lib.Test_cache_deadlock.test_cache_deadlock
          (module Disk_cache)
      in
      match res with
      | `Timeout ->
          printf
            "It is expected that LMDB cache times out for now. This should be \
             fixed." ;
          Deferred.unit
      | `Success ->
          failwith "The process should time out" )
