(** Mina kimchi layer: kimchi bindings, backends, and plonk primitives.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let plonkish_prelude =
  library "plonkish_prelude" ~path:"src/lib/crypto/plonkish_prelude"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ]
    ~modules_without_implementation:[ "sigs"; "poly_types" ]
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; result
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "kimchi_pasta_snarky_backend"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let pasta_bindings_backend =
  library "pasta_bindings.backend" ~internal_name:"pasta_bindings_backend"
    ~path:"src/lib/crypto/kimchi_bindings/stubs/pasta_bindings_backend"
    ~modules:[ "pasta_bindings_backend" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_inline_test ])
    ~virtual_modules:[ "pasta_bindings_backend" ]
    ~default_implementation:"pasta_bindings.backend.native"

let pasta_bindings_backend_none =
  library "pasta_bindings.backend.none"
    ~internal_name:"pasta_bindings_backend_none"
    ~path:"src/lib/crypto/kimchi_bindings/stubs/pasta_bindings_backend/none"
    ~inline_tests:true
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_inline_test ])
    ~implements:"pasta_bindings.backend"

let bindings_js =
  library "bindings_js" ~path:"src/lib/crypto/kimchi_bindings/js"
    ~ppx:Ppx.minimal
    ~js_of_ocaml:
      ( "js_of_ocaml"
      @: [ "javascript_files"
           @: [ atom "bindings/bigint256.js"
              ; atom "bindings/field.js"
              ; atom "bindings/curve.js"
              ; atom "bindings/vector.js"
              ; atom "bindings/gate-vector.js"
              ; atom "bindings/oracles.js"
              ; atom "bindings/pickles-test.js"
              ; atom "bindings/proof.js"
              ; atom "bindings/prover-index.js"
              ; atom "bindings/util.js"
              ; atom "bindings/srs.js"
              ; atom "bindings/verifier-index.js"
              ]
         ] )

let bindings_js_node_backend =
  library "bindings_js.node_backend" ~internal_name:"node_backend"
    ~path:"src/lib/crypto/kimchi_bindings/js/node_js"
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.js_of_ocaml_ppx ])
    ~js_of_ocaml:
      ( "js_of_ocaml"
      @: [ "flags" @: [ list [ atom ":include"; atom "flags.sexp" ] ]
         ; "javascript_files" @: [ atom "node_backend.js" ]
         ] )
    ~extra_stanzas:
      [ "rule"
        @: [ "targets"
             @: [ atom "plonk_wasm_bg.wasm.d.ts"
                ; atom "plonk_wasm_bg.wasm"
                ; atom "plonk_wasm.d.ts"
                ; atom "plonk_wasm.js"
                ; atom "flags.sexp"
                ]
           ; "deps"
             @: [ atom "build.sh"
                ; atom "../../dune-build-root"
                ; list [ atom "source_tree"; atom "../../../proof-systems" ]
                ]
           ; "locks" @: [ atom "/cargo-lock" ]
           ; "action"
             @: [ list
                    [ atom "progn"
                    ; list
                        [ atom "setenv"
                        ; atom "CARGO_TARGET_DIR"
                        ; atom
                            {|%{read:../../dune-build-root}/cargo_kimchi_wasm|}
                        ; list [ atom "run"; atom "bash"; atom "build.sh" ]
                        ]
                    ; list [ atom "write-file"; atom "flags.sexp"; atom "()" ]
                    ]
                ]
           ]
      ]

let bindings_js_web_backend =
  library "bindings_js.web_backend" ~internal_name:"web_backend"
    ~path:"src/lib/crypto/kimchi_bindings/js/web"
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.js_of_ocaml_ppx ])
    ~js_of_ocaml:
      ( "js_of_ocaml"
      @: [ "flags" @: [ list [ atom ":include"; atom "flags.sexp" ] ]
         ; "javascript_files" @: [ atom "web_backend.js" ]
         ] )
    ~extra_stanzas:
      [ "rule"
        @: [ "targets"
             @: [ atom "plonk_wasm_bg.wasm.d.ts"
                ; atom "plonk_wasm_bg.wasm"
                ; atom "plonk_wasm.d.ts"
                ; atom "plonk_wasm.js"
                ; atom "flags.sexp"
                ]
           ; "deps"
             @: [ atom "build.sh"
                ; atom "../../dune-build-root"
                ; list [ atom "source_tree"; atom "../../../proof-systems" ]
                ]
           ; "locks" @: [ atom "/cargo-lock" ]
           ; "action"
             @: [ list
                    [ atom "progn"
                    ; list
                        [ atom "setenv"
                        ; atom "CARGO_TARGET_DIR"
                        ; atom
                            {|%{read:../../dune-build-root}/cargo_kimchi_wasm|}
                        ; list [ atom "run"; atom "bash"; atom "build.sh" ]
                        ]
                    ; list [ atom "write-file"; atom "flags.sexp"; atom "()" ]
                    ]
                ]
           ]
      ]

let kimchi_bindings_pasta_fp_poseidon =
  library "kimchi_bindings.pasta_fp_poseidon"
    ~internal_name:"kimchi_pasta_fp_poseidon"
    ~path:"src/lib/crypto/kimchi_bindings/pasta_fp_poseidon"
    ~deps:[ local "kimchi_bindings" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_inline_test ])

let kimchi_bindings_pasta_fq_poseidon =
  library "kimchi_bindings.pasta_fq_poseidon"
    ~internal_name:"kimchi_pasta_fq_poseidon"
    ~path:"src/lib/crypto/kimchi_bindings/pasta_fq_poseidon"
    ~deps:[ local "kimchi_bindings" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_inline_test ])

let kimchi_backend_common =
  library "kimchi_backend_common" ~path:"src/lib/crypto/kimchi_backend/common"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ async_kernel
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; digestif
      ; integers
      ; plonkish_prelude
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; zarith
      ; Layer_base.allocation_functor
      ; Layer_base.hex
      ; Layer_base.mina_stdlib
      ; Layer_concurrency.promise
      ; Layer_logging.logger
      ; Layer_logging.logger_context_logger
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarky_intf
      ; Snarky_lib.sponge
      ; Snarky_lib.tuple_lib
      ; local "bignum_bigint"
      ; local "key_cache"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_snarky_backend"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.h_list_ppx
         ] )

let kimchi_pasta =
  library "kimchi_pasta" ~path:"src/lib/crypto/kimchi_backend/pasta"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; kimchi_backend_common
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_concurrency.promise
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarkette
      ; Snarky_lib.sponge
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_basic"
      ; local "kimchi_pasta_constraint_system"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_std
         ] )

let kimchi_pasta_basic =
  library "kimchi_pasta.basic" ~internal_name:"kimchi_pasta_basic"
    ~path:"src/lib/crypto/kimchi_backend/pasta/basic"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; kimchi_backend_common
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_concurrency.promise
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarkette
      ; Snarky_lib.sponge
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_std
         ] )

let kimchi_pasta_constraint_system =
  library "kimchi_pasta.constraint_system"
    ~internal_name:"kimchi_pasta_constraint_system"
    ~path:"src/lib/crypto/kimchi_backend/pasta/constraint_system"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; kimchi_backend_common
      ; kimchi_pasta_basic
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_concurrency.promise
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarkette
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.sponge
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_std
         ] )
    ~virtual_modules:[ "pallas_constraint_system"; "vesta_constraint_system" ]
    ~default_implementation:"kimchi_pasta.constraint_system.caml"

let kimchi_pasta_constraint_system_caml =
  library "kimchi_pasta.constraint_system.caml"
    ~internal_name:"kimchi_pasta_constraint_system_caml"
    ~path:"src/lib/crypto/kimchi_backend/pasta/constraint_system/caml"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core_kernel
      ; kimchi_backend_common
      ; kimchi_pasta_basic
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_concurrency.promise
      ; Layer_ppx.ppx_version_runtime
      ; Snarky_lib.snarkette
      ; Snarky_lib.sponge
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_std
         ] )
    ~implements:"kimchi_pasta.constraint_system"

let kimchi_backend =
  library "kimchi_backend" ~path:"src/lib/crypto/kimchi_backend"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; integers
      ; kimchi_backend_common
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; kimchi_pasta_constraint_system
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.hex
      ; Snarky_lib.snarkette
      ; Snarky_lib.snarky_intf
      ; Snarky_lib.sponge
      ; local "key_cache"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ] )

let kimchi_backend_gadgets =
  library "kimchi_backend.gadgets" ~internal_name:"kimchi_gadgets"
    ~path:"src/lib/crypto/kimchi_backend/gadgets" ~inline_tests:true
    ~deps:
      [ core_kernel
      ; digestif
      ; kimchi_backend_common
      ; kimchi_pasta
      ; ppx_inline_test_config
      ; zarith
      ; Layer_base.mina_stdlib
      ; Snarky_lib.snarky_backendless
      ; local "bignum_bigint"
      ; local "kimchi_gadgets_test_runner"
      ]
    ~ppx:Ppx.standard

let kimchi_backend_gadgets_test_runner =
  library "kimchi_backend.gadgets_test_runner"
    ~internal_name:"kimchi_gadgets_test_runner"
    ~path:"src/lib/crypto/kimchi_backend/gadgets/runner"
    ~deps:
      [ async_kernel
      ; base
      ; base64
      ; base_caml
      ; bin_prot_shape
      ; core_kernel
      ; digestif
      ; integers
      ; kimchi_backend
      ; kimchi_backend_common
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; kimchi_pasta_constraint_system
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; stdio
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_base.mina_wire_types
      ; Layer_concurrency.promise
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snark_keys_header
      ; Layer_snarky.snarky_group_map
      ; Layer_snarky.snarky_log
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.group_map
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.snarky_curve
      ; Snarky_lib.snarky_intf
      ; Snarky_lib.sponge
      ; Snarky_lib.tuple_lib
      ; local "bignum_bigint"
      ; local "key_cache"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "random_oracle_input"
      ]
    ~ppx:Ppx.mina_rich
