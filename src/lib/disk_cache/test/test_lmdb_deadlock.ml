(* LMDB-specific deadlock test *)
open! Core
open Async

let () =
  printf "Running LMDB cache deadlock test...\n%!" ;
  Thread_safe.block_on_async_exn (fun () ->
    Test_cache_deadlock_lib.Test_cache_deadlock.test_cache_deadlock (module Disk_cache)
  )