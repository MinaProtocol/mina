(** Mina snarky layer: snarky-specific utility libraries.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let snark_keys_header =
  library "snark_keys_header" ~path:"src/lib/crypto/snark_keys_header"
    ~deps:[ base; base_caml; core_kernel; integers; result; sexplib0; stdio ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_ord
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )

let snarky_blake2 =
  library "snarky_blake2" ~path:"src/lib/crypto/snarky_blake2"
    ~deps:
      [ core_kernel
      ; digestif
      ; integers
      ; Snarky_lib.snarky_backendless
      ; local "blake2"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )

let snarky_field_extensions =
  library "snarky_field_extensions"
    ~path:"src/lib/crypto/snarky_field_extensions" ~inline_tests:true
    ~deps:
      [ bignum_bigint
      ; core_kernel
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; Snarky_lib.snarkette
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let snarky_curves =
  library "snarky_curves" ~path:"src/lib/crypto/snarky_curves"
    ~deps:
      [ bignum_bigint
      ; core_kernel
      ; sexplib0
      ; snarky_field_extensions
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ] )

let snarky_group_map =
  library "snarky_group_map" ~path:"src/lib/crypto/snarky_group_map"
    ~inline_tests:true
    ~deps:
      [ core_kernel
      ; Snarky_lib.group_map
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ] )

let snarky_log =
  library "snarky_log" ~path:"src/lib/crypto/snarky_log"
    ~deps:
      [ yojson
      ; Snarky_lib.snarky_backendless
      ; local "webkit_trace_event"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version ])

let snarky_taylor =
  library "snarky_taylor" ~path:"src/lib/crypto/snarky_taylor"
    ~deps:
      [ bignum
      ; bignum_bigint
      ; core_kernel
      ; sexplib0
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.snarky_integer
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )

let snark_bits =
  library "snark_bits" ~path:"src/lib/crypto/snark_bits"
    ~synopsis:"Snark parameters" ~library_flags:[ "-linkall" ]
    ~inline_tests:true
    ~deps:
      [ base
      ; core_kernel
      ; integers
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.snarky_intf
      ; Snarky_lib.tuple_lib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_compare
         ] )
