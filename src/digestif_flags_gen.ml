[%%import "config.mlh"]

open Printf
module C = Configurator.V1

[%%if fake_hash]
let () =
  C.Flags.write_sexp "digestif.flags" ["digestif.c"]
[%%else]
let () =
  C.Flags.write_sexp "digestif.flags" ["digestif.ocaml"]
[%%endif]
