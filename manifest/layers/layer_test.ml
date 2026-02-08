(** Mina test layer: testing utilities and helpers.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let quickcheck_lib =
  library "quickcheck_lib" ~path:"src/lib/testing/quickcheck_lib"
    ~inline_tests:true
    ~deps:
      [ core_kernel
      ; base
      ; ppx_inline_test_config
      ; local "currency"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_custom_printf
         ] )

let test_util =
  library "test_util" ~path:"src/lib/testing/test_util" ~synopsis:"test utils"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ core_kernel
      ; base_caml
      ; bin_prot
      ; local "snark_params"
      ; local "fold_lib"
      ; local "snarky.backendless"
      ; local "pickles"
      ; local "crypto_params"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ] )
