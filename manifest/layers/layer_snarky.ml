(** Mina snarky layer: snarky-specific utility libraries.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let register () =
  (* -- snark_bits ------------------------------------------------- *)
  library "snark_bits" ~path:"src/lib/crypto/snark_bits"
    ~synopsis:"Snark parameters" ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ core_kernel
      ; integers
      ; base
      ; local "fold_lib"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_snarky"
         ; "ppx_let"
         ; "ppx_inline_test"
         ; "ppx_compare"
         ] ) ;

  ()
