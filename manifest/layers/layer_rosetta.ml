(** Mina Rosetta layer: encoding, models, and support code for Rosetta API.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let rosetta_coding =
  library "rosetta_coding" ~path:"src/lib/rosetta_coding"
    ~synopsis:"Encoders and decoders for Rosetta" ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; core_kernel
      ; Layer_base.mina_stdlib
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_assert; Ppx_lib.ppx_let ])

let rosetta_models =
  library "rosetta_models" ~path:"src/lib/rosetta_models"
    ~deps:[ ppx_deriving_yojson_runtime; yojson ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_eq
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_version
         ] )

let rosetta_lib =
  library "rosetta_lib" ~path:"src/lib/rosetta_lib"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async_kernel
      ; base
      ; base_caml
      ; caqti
      ; core_kernel
      ; integers
      ; result
      ; rosetta_models
      ; sexplib0
      ; uri
      ; Layer_base.currency
      ; Layer_base.hex
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ] )
    ~synopsis:"Rosetta-related support code"
