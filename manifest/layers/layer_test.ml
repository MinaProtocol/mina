(** Mina test layer: testing utilities and helpers.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let register () =
  (* -- quickcheck_lib --------------------------------------------- *)
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
         [ "ppx_version"; "ppx_let"; "ppx_inline_test"; "ppx_custom_printf" ] ) ;

  (* -- test_util -------------------------------------------------- *)
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
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_compare" ]) ;

  ()
