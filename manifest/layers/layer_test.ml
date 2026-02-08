(** Mina test layer: testing utilities and helpers.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let quickcheck_lib =
  library "quickcheck_lib" ~path:"src/lib/testing/quickcheck_lib"
    ~inline_tests:true
    ~deps:
      [ base
      ; core_kernel
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
      [ base_caml
      ; bin_prot
      ; core_kernel
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; local "crypto_params"
      ; local "pickles"
      ; local "snark_params"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ] )
