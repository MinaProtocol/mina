(** Product: benchmarks — Mina inline benchmarks runner. *)

open Manifest
open Externals

let () =
  executable "mina-benchmarks" ~internal_name:"benchmarks"
    ~path:"src/app/benchmarks"
    ~deps:
      [ base
      ; core
      ; core_bench_inline_benchmarks
      ; core_kernel
      ; Layer_base.mina_base
      ; Layer_base.mina_stdlib
      ; Layer_domain.data_hash_lib
      ; Layer_network.vrf_lib_tests
      ]
    ~link_flags:[ "-linkall" ] ~modes:[ "native" ] ~ppx:Ppx.minimal
