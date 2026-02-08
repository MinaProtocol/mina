(** Product: benchmarks — Mina inline benchmarks runner. *)

open Manifest
open Externals

let register () =
  executable "mina-benchmarks" ~internal_name:"benchmarks"
    ~path:"src/app/benchmarks"
    ~deps:
      [ base
      ; core
      ; core_bench_inline_benchmarks
      ; core_kernel
      ; local "data_hash_lib"
      ; local "mina_base"
      ; local "mina_stdlib"
      ; local "vrf_lib_tests"
      ]
    ~link_flags:[ "-linkall" ] ~modes:[ "native" ] ~ppx:Ppx.minimal ;

  ()
