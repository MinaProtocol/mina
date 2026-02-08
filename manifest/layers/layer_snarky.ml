(** Mina snarky layer: snarky-specific utility libraries.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let snarky_taylor =
  library "snarky_taylor" ~path:"src/lib/crypto/snarky_taylor"
    ~deps:
      [ bignum
      ; bignum_bigint
      ; core_kernel
      ; sexplib0
      ; local "snarky.backendless"
      ; local "snarky_integer"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )

let snark_bits =
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
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_compare
         ] )
