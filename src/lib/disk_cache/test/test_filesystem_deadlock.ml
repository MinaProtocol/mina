(* Filesystem cache control test - should not deadlock *)
open! Core
open Async

let () =
  printf "Running Filesystem cache control test...\n%!" ;
  Thread_safe.block_on_async_exn (fun () ->
    Test_cache_deadlock_lib.Test_cache_deadlock.test_cache_deadlock (module Disk_cache)
  )