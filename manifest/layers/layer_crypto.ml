(** Mina cryptographic layer: low-level utilities, kimchi, pickles,
  and signature libraries.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let blake2 =
  library "blake2" ~path:"src/lib/crypto/blake2" ~inline_tests:true
    ~deps:
      [ base_internalhash_types
      ; base_caml
      ; bigarray_compat
      ; bin_prot_shape
      ; core_kernel
      ; digestif
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let bignum_bigint =
  library "bignum_bigint" ~path:"src/lib/crypto/bignum_bigint"
    ~synopsis:"Bignum's bigint re-exported as Bignum_bigint"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:[ core_kernel; async_kernel; bignum_bigint; local "fold_lib" ]
    ~ppx:Ppx.standard

let string_sign =
  library "string_sign" ~path:"src/lib/crypto/string_sign"
    ~synopsis:"Schnorr signatures for strings"
    ~deps:
      [ core_kernel
      ; result
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta_basic"
      ; Layer_base.mina_base
      ; local "mina_signature_kind"
      ; local "pickles"
      ; local "pickles_backend"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "signature_lib"
      ; local "snark_params"
      ]
    ~ppx:Ppx.mina

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
      ; local "kimchi_pasta_snarky_backend"
      ; Layer_base.mina_wire_types
      ; Layer_ppx.ppx_version_runtime
      ; local "snarky.backendless"
      ; local "tuple_lib"
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

let random_oracle_input =
  library "random_oracle_input" ~path:"src/lib/crypto/random_oracle_input"
    ~inline_tests:true
    ~deps:[ core_kernel; sexplib0; base_caml; ppx_inline_test_config ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let outside_hash_image =
  library "outside_hash_image" ~path:"src/lib/crypto/outside_hash_image"
    ~deps:[ local "snark_params" ]
    ~ppx:Ppx.minimal

let hash_prefixes =
  library "hash_prefixes" ~path:"src/lib/hash_prefixes"
    ~deps:[ local "mina_signature_kind" ]
    ~ppx:Ppx.minimal

let sgn =
  library "sgn" ~path:"src/lib/sgn" ~synopsis:"sgn library"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ ppx_deriving_yojson_runtime
      ; core_kernel
      ; yojson
      ; sexplib0
      ; base
      ; bin_prot_shape
      ; base_caml
      ; local "snark_params"
      ; Layer_base.sgn_type
      ; local "pickles"
      ; local "snarky.backendless"
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
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
      [ result
      ; async_kernel
      ; sexplib0
      ; bin_prot_shape
      ; integers
      ; digestif
      ; core_kernel
      ; base_caml
      ; ppx_inline_test_config
      ; bignum_bigint
      ; zarith
      ; base_internalhash_types
      ; local "tuple_lib"
      ; local "key_cache"
      ; Layer_base.hex
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_snarky_backend"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; plonkish_prelude
      ; local "sponge"
      ; Layer_base.allocation_functor
      ; local "snarky.intf"
      ; Layer_concurrency.promise
      ; Layer_infra.logger
      ; Layer_infra.logger_context_logger
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.mina_stdlib
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
      [ ppx_inline_test_config
      ; sexplib0
      ; core_kernel
      ; bin_prot_shape
      ; base_caml
      ; local "sponge"
      ; kimchi_backend_common
      ; Layer_concurrency.promise
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_basic"
      ; Layer_base.mina_stdlib
      ; local "kimchi_pasta_constraint_system"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; Layer_ppx.ppx_version_runtime
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
      [ ppx_inline_test_config
      ; sexplib0
      ; core_kernel
      ; bin_prot_shape
      ; base_caml
      ; local "sponge"
      ; kimchi_backend_common
      ; Layer_concurrency.promise
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; Layer_base.mina_stdlib
      ; local "pasta_bindings"
      ; local "snarkette"
      ; Layer_ppx.ppx_version_runtime
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
      [ ppx_inline_test_config
      ; sexplib0
      ; core_kernel
      ; bin_prot_shape
      ; base_caml
      ; local "sponge"
      ; kimchi_backend_common
      ; Layer_concurrency.promise
      ; local "kimchi_bindings"
      ; kimchi_pasta_basic
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; Layer_ppx.ppx_version_runtime
      ; local "snarky.backendless"
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
      [ ppx_inline_test_config
      ; sexplib0
      ; core_kernel
      ; bin_prot_shape
      ; base_caml
      ; local "sponge"
      ; kimchi_backend_common
      ; Layer_concurrency.promise
      ; local "kimchi_bindings"
      ; kimchi_pasta_basic
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; Layer_ppx.ppx_version_runtime
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
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.hex
      ; local "key_cache"
      ; kimchi_backend_common
      ; local "kimchi_bindings"
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; kimchi_pasta_constraint_system
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarky.intf"
      ; local "snarkette"
      ; local "sponge"
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
      [ bignum_bigint
      ; core_kernel
      ; digestif
      ; ppx_inline_test_config
      ; zarith
      ; kimchi_backend_common
      ; kimchi_pasta
      ; local "kimchi_gadgets_test_runner"
      ; Layer_base.mina_stdlib
      ; local "snarky.backendless"
      ]
    ~ppx:Ppx.standard

let kimchi_backend_gadgets_test_runner =
  library "kimchi_backend.gadgets_test_runner"
    ~internal_name:"kimchi_gadgets_test_runner"
    ~path:"src/lib/crypto/kimchi_backend/gadgets/runner"
    ~deps:
      [ stdio
      ; integers
      ; result
      ; base_caml
      ; bignum_bigint
      ; core_kernel
      ; base64
      ; digestif
      ; ppx_inline_test_config
      ; sexplib0
      ; base
      ; async_kernel
      ; bin_prot_shape
      ; Layer_base.mina_wire_types
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; kimchi_pasta_constraint_system
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; kimchi_backend
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; random_oracle_input
      ; local "snarky_log"
      ; local "group_map"
      ; local "snarky_curve"
      ; local "key_cache"
      ; snark_keys_header
      ; local "tuple_lib"
      ; Layer_concurrency.promise
      ; kimchi_backend_common
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:Ppx.mina_rich

let crypto_params =
  library "crypto_params" ~path:"src/lib/crypto/crypto_params"
    ~synopsis:"Cryptographic parameters"
    ~flags:
      [ atom ":standard"; atom "-short-paths"; atom "-warn-error"; atom "-58" ]
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ bin_prot_shape
      ; core_kernel
      ; sexplib0
      ; local "cache_dir"
      ; local "group_map"
      ; kimchi_backend
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; local "pickles"
      ; local "pickles_backend"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ]
    ~ppx:
      (Ppx.custom [ Ppx_lib.h_list_ppx; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ])
    ~extra_stanzas:
      [ "rule"
        @: [ "targets" @: [ atom "group_map_params.ml" ]
           ; "deps" @: [ list [ atom ":<"; atom "gen/gen.exe" ] ]
           ; "action" @: [ list [ atom "run"; atom "%{<}"; atom "%{targets}" ] ]
           ]
      ]

let pickles_base =
  library "pickles_base" ~path:"src/lib/crypto/pickles_base"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ]
    ~deps:
      [ base_internalhash_types
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; ppxlib
      ; core_kernel
      ; Layer_base.mina_wire_types
      ; local "snarky.backendless"
      ; random_oracle_input
      ; local "pickles_types"
      ; local "pickles_base_one_hot_vector"
      ; plonkish_prelude
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.h_list_ppx
         ] )

let pickles_base_one_hot_vector =
  library "pickles_base.one_hot_vector" ~internal_name:"one_hot_vector"
    ~path:"src/lib/crypto/pickles_base/one_hot_vector"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:[ core_kernel; local "snarky.backendless"; local "pickles_types" ]
    ~ppx:Ppx.standard

let pickles_types =
  library "pickles_types" ~path:"src/lib/crypto/pickles_types"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ]
    ~deps:
      [ sexplib0
      ; result
      ; core_kernel
      ; base_caml
      ; bin_prot_shape
      ; local "kimchi_types"
      ; kimchi_backend_common
      ; local "kimchi_pasta_snarky_backend"
      ; plonkish_prelude
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.h_list_ppx
         ] )

let snark_params =
  library "snark_params" ~path:"src/lib/crypto/snark_params"
    ~synopsis:"Snark parameters" ~library_flags:[ "-linkall" ]
    ~deps:
      [ base_internalhash_types
      ; core_kernel
      ; digestif
      ; base
      ; sexplib0
      ; Layer_base.mina_wire_types
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; bignum_bigint
      ; local "pickles_backend"
      ; local "snarky_curves"
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; local "group_map"
      ; local "fold_lib"
      ; local "bitstring_lib"
      ; Layer_snarky.snark_bits
      ; local "pickles"
      ; crypto_params
      ; local "snarky_field_extensions"
      ; local "snarky.intf"
      ; kimchi_backend
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_bench
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_snarky
         ] )

let random_oracle =
  library "random_oracle" ~path:"src/lib/crypto/random_oracle"
    ~inline_tests:true
    ~deps:
      [ ppx_inline_test_config
      ; base
      ; core_kernel
      ; sexplib0
      ; snark_params
      ; local "pickles_backend"
      ; local "sponge"
      ; local "pickles"
      ; random_oracle_input
      ; local "snarky.backendless"
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; local "fold_lib"
      ; local "random_oracle_permutation"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ] )

let random_oracle_permutation =
  library "random_oracle.permutation" ~internal_name:"random_oracle_permutation"
    ~path:"src/lib/crypto/random_oracle/permutation"
    ~deps:[ local "sponge"; kimchi_backend; kimchi_pasta; kimchi_pasta_basic ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "random_oracle_permutation" ]
    ~default_implementation:"random_oracle.permutation.external"

let random_oracle_permutation_external =
  library "random_oracle.permutation.external"
    ~internal_name:"random_oracle_permutation_external"
    ~path:"src/lib/crypto/random_oracle/permutation/external" ~inline_tests:true
    ~deps:
      [ ppx_inline_test_config
      ; base
      ; core_kernel
      ; sexplib0
      ; local "sponge"
      ; local "pickles"
      ; local "pickles_backend"
      ; kimchi_bindings_pasta_fp_poseidon
      ; local "kimchi_bindings"
      ; kimchi_backend
      ; kimchi_backend_common
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_inline_test; Ppx_lib.ppx_assert ] )
    ~implements:"random_oracle.permutation"

let random_oracle_permutation_ocaml =
  library "random_oracle.permutation.ocaml"
    ~internal_name:"random_oracle_permutation_ocaml"
    ~path:"src/lib/crypto/random_oracle/permutation/ocaml"
    ~deps:
      [ base
      ; core_kernel
      ; local "sponge"
      ; local "pickles"
      ; local "pickles_backend"
      ; kimchi_backend
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ]
    ~ppx:Ppx.minimal ~implements:"random_oracle.permutation"

let non_zero_curve_point =
  library "non_zero_curve_point" ~path:"src/lib/crypto/non_zero_curve_point"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ ppx_inline_test_config
      ; base_caml
      ; sexplib0
      ; core_kernel
      ; bin_prot_shape
      ; base
      ; base_internalhash_types
      ; Layer_base.mina_wire_types
      ; local "snarky.backendless"
      ; random_oracle_input
      ; local "pickles_backend"
      ; local "pickles"
      ; Layer_base.codable
      ; snark_params
      ; local "fold_lib"
      ; Layer_base.base58_check
      ; random_oracle
      ; local "bitstring_lib"
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; Layer_test.test_util
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_custom_printf
         ] )

let signature_lib =
  library "signature_lib" ~path:"src/lib/crypto/signature_lib"
    ~synopsis:"Schnorr signatures using the tick and tock curves"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ bignum_bigint
      ; ppx_inline_test_config
      ; base
      ; sexplib0
      ; yojson
      ; core_kernel
      ; bin_prot_shape
      ; base_caml
      ; result
      ; Layer_base.mina_wire_types
      ; crypto_params
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; random_oracle_input
      ; local "bitstring_lib"
      ; Layer_base.codable
      ; snark_params
      ; local "mina_debug"
      ; blake2
      ; local "hash_prefix_states"
      ; non_zero_curve_point
      ; random_oracle
      ; local "snarky.backendless"
      ; bignum_bigint
      ; Layer_base.base58_check
      ; local "snarky_curves"
      ; local "pickles"
      ; local "fold_lib"
      ; local "pickles_backend"
      ; kimchi_backend
      ; local "h_list"
      ; Layer_test.test_util
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ] )

let secrets =
  library "secrets" ~path:"src/lib/crypto/secrets"
    ~synopsis:"Managing secrets including passwords and keypairs"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ result
      ; base_caml
      ; bignum_bigint
      ; async_kernel
      ; async
      ; core
      ; async_unix
      ; sodium
      ; ppx_deriving_yojson_runtime
      ; yojson
      ; core_kernel
      ; sexplib0
      ; base58
      ; ppx_inline_test_config
      ; Layer_base.mina_stdlib_unix
      ; random_oracle
      ; local "pickles"
      ; Layer_infra.logger
      ; snark_params
      ; Layer_base.mina_stdlib
      ; local "mina_net2"
      ; Layer_base.mina_base
      ; Layer_base.base58_check
      ; signature_lib
      ; local "network_peer"
      ; Layer_base.mina_numbers
      ; local "snarky.backendless"
      ; Layer_base.error_json
      ; Layer_base.mina_base_import
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_deriving_make
         ] )

let key_gen =
  library "key_gen" ~path:"src/lib/crypto/key_gen"
    ~deps:[ core_kernel; signature_lib ]
    ~ppx:Ppx.minimal

let bowe_gabizon_hash =
  library "bowe_gabizon_hash" ~path:"src/lib/crypto/bowe_gabizon_hash"
    ~inline_tests:true ~deps:[ core_kernel ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )

let pickles_limb_vector =
  library "pickles.limb_vector" ~internal_name:"limb_vector"
    ~path:"src/lib/crypto/pickles/limb_vector"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~modules_without_implementation:[ "limb_vector" ]
    ~deps:
      [ bin_prot_shape
      ; sexplib0
      ; core_kernel
      ; base_caml
      ; result
      ; local "snarky.backendless"
      ; local "pickles_backend"
      ; pickles_types
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:Ppx.mina_rich

let pickles_pseudo =
  library "pickles.pseudo" ~internal_name:"pseudo"
    ~path:"src/lib/crypto/pickles/pseudo"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ core_kernel
      ; pickles_types
      ; local "pickles_plonk_checks"
      ; pickles_base_one_hot_vector
      ; local "snarky.backendless"
      ; pickles_base
      ]
    ~ppx:Ppx.mina_rich

let pickles_composition_types =
  library "pickles.composition_types" ~internal_name:"composition_types"
    ~path:"src/lib/crypto/pickles/composition_types"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a-70-27"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ sexplib0
      ; bin_prot_shape
      ; core_kernel
      ; base_caml
      ; Layer_base.mina_wire_types
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; local "snarky.backendless"
      ; pickles_types
      ; pickles_limb_vector
      ; kimchi_backend
      ; pickles_base
      ; local "pickles_backend"
      ; kimchi_backend_common
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.h_list_ppx
         ] )

let pickles_plonk_checks =
  library "pickles.plonk_checks" ~internal_name:"plonk_checks"
    ~path:"src/lib/crypto/pickles/plonk_checks"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a-4-70"
          ]
      ; atom "-open"
      ; atom "Core_kernel"
      ]
    ~deps:
      [ sexplib0
      ; ppxlib_ast
      ; core_kernel
      ; ocaml_migrate_parsetree
      ; base_internalhash_types
      ; pickles_types
      ; pickles_base
      ; pickles_composition_types
      ; kimchi_backend
      ; local "kimchi_types"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~extra_stanzas:
      [ "rule"
        @: [ "target" @: [ atom "scalars.ml" ]
           ; "mode" @: [ atom "promote" ]
           ; "deps"
             @: [ list [ atom ":<"; atom "gen_scalars/gen_scalars.exe" ] ]
           ; "action"
             @: [ list
                    [ atom "progn"
                    ; list [ atom "run"; atom "%{<}"; atom "%{target}" ]
                    ; list
                        [ atom "run"
                        ; atom "ocamlformat"
                        ; atom "-i"
                        ; atom "scalars.ml"
                        ]
                    ]
                ]
           ]
      ]

let pickles_backend =
  library "pickles.backend" ~internal_name:"backend"
    ~path:"src/lib/crypto/pickles/backend"
    ~deps:[ kimchi_backend; kimchi_pasta; kimchi_pasta_basic ]
    ~ppx:Ppx.mina_rich

let pickles =
  library "pickles" ~path:"src/lib/crypto/pickles" ~inline_tests:true
    ~modules_without_implementation:
      [ "full_signature"; "type"; "intf"; "pickles_intf" ]
    ~flags:[ atom "-open"; atom "Core_kernel" ]
    ~deps:
      [ stdio
      ; integers
      ; result
      ; base_caml
      ; bignum_bigint
      ; core_kernel
      ; base64
      ; digestif
      ; ppx_inline_test_config
      ; sexplib0
      ; base
      ; async_kernel
      ; bin_prot_shape
      ; Layer_base.mina_wire_types
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; kimchi_pasta
      ; kimchi_pasta_basic
      ; kimchi_pasta_constraint_system
      ; local "kimchi_pasta_snarky_backend"
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ; pickles_backend
      ; pickles_types
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; pickles_pseudo
      ; pickles_limb_vector
      ; pickles_base
      ; plonkish_prelude
      ; kimchi_backend
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; random_oracle_input
      ; pickles_composition_types
      ; pickles_plonk_checks
      ; pickles_base_one_hot_vector
      ; local "snarky_log"
      ; local "group_map"
      ; local "snarky_curve"
      ; local "key_cache"
      ; snark_keys_header
      ; local "tuple_lib"
      ; Layer_concurrency.promise
      ; kimchi_backend_common
      ; Layer_infra.logger
      ; Layer_infra.logger_context_logger
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.error_json
      ; Layer_base.mina_stdlib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.h_list_ppx
         ] )

let proof_cache_tag =
  library "proof_cache_tag" ~path:"src/lib/proof_cache_tag"
    ~deps:
      [ core_kernel; async_kernel; local "logger"; local "disk_cache"; pickles ]
    ~ppx:Ppx.standard
