(** Product: benchmarks — Mina inline benchmarks runner. *)

open Manifest

let register () =
  executable "mina-benchmarks" ~internal_name:"benchmarks"
    ~path:"src/app/benchmarks"
    ~deps:
      [ opam "base"
      ; opam "core"
      ; opam "core_bench.inline_benchmarks"
      ; opam "core_kernel"
      ; local "data_hash_lib"
      ; local "mina_base"
      ; local "mina_stdlib"
      ; local "vrf_lib_tests"
      ]
    ~link_flags:[ "-linkall" ] ~modes:[ "native" ] ~ppx:Ppx.minimal ;

  ()
