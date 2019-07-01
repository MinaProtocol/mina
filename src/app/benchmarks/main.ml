(* main.ml -- run inline benchmarks for given libraries *)

open Core_kernel

let libraries = ["snark_params"]

let () =
  List.iter libraries ~f:(fun libname ->
      Core.printf "Running inline tests in library \"%s\"\n%!" libname ;
      Inline_benchmarks_public.Runner.main ~libname )
