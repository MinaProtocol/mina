(** Mina cryptographic layer: low-level utilities, kimchi, pickles,
    and signature libraries.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Dune_s_expr

let register_low_level () =
  (* ============================================================ *)
  (* Tier 2: Low-level crypto & utilities                         *)
  (* ============================================================ *)

  (* -- blake2 ----------------------------------------------------- *)
  library "blake2" ~path:"src/lib/crypto/blake2" ~inline_tests:true
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "bigarray-compat"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; local "mina_stdlib"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* -- bignum_bigint ---------------------------------------------- *)
  library "bignum_bigint" ~path:"src/lib/crypto/bignum_bigint"
    ~synopsis:"Bignum's bigint re-exported as Bignum_bigint"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "async_kernel"
      ; opam "bignum.bigint"
      ; local "fold_lib"
      ]
    ~ppx:Ppx.standard ;

  (* -- string_sign ------------------------------------------------ *)
  library "string_sign" ~path:"src/lib/crypto/string_sign"
    ~synopsis:"Schnorr signatures for strings"
    ~deps:
      [ opam "core_kernel"
      ; opam "result"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base"
      ; local "mina_signature_kind"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "signature_lib"
      ; local "snark_params"
      ]
    ~ppx:Ppx.mina ;

  (* -- snark_keys_header ------------------------------------------ *)
  library "snark_keys_header" ~path:"src/lib/crypto/snark_keys_header"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "stdio"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_deriving.ord"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  (* -- plonkish_prelude ------------------------------------------- *)
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
      [ opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "result"
      ; opam "sexplib0"
      ; local "mina_stdlib"
      ; local "kimchi_pasta_snarky_backend"
      ; local "mina_wire_types"
      ; local "ppx_version.runtime"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* -- random_oracle_input ---------------------------------------- *)
  library "random_oracle_input" ~path:"src/lib/crypto/random_oracle_input"
    ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "ppx_inline_test.config"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"
         ; "ppx_sexp_conv"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ] ) ;

  (* -- outside_hash_image ----------------------------------------- *)
  library "outside_hash_image" ~path:"src/lib/crypto/outside_hash_image"
    ~deps:[ local "snark_params" ]
    ~ppx:Ppx.minimal ;

  (* -- hash_prefixes ---------------------------------------------- *)
  library "hash_prefixes" ~path:"src/lib/hash_prefixes"
    ~deps:[ local "mina_signature_kind" ]
    ~ppx:Ppx.minimal ;

  (* -- sgn -------------------------------------------------------- *)
  library "sgn" ~path:"src/lib/sgn" ~synopsis:"sgn library"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_deriving_yojson.runtime"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "snark_params"
      ; local "sgn_type"
      ; local "pickles"
      ; local "snarky.backendless"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_bin_prot"
         ; "ppx_sexp_conv"
         ; "ppx_compare"
         ; "ppx_hash"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ] ) ;

  ()

let register_backends () =
  (* ============================================================ *)
  (* Tier 4: Crypto layer                                          *)
  (* ============================================================ *)

  (* -- pasta_bindings.backend (virtual) --------------------------- *)
  library "pasta_bindings.backend" ~internal_name:"pasta_bindings_backend"
    ~path:"src/lib/crypto/kimchi_bindings/stubs/pasta_bindings_backend"
    ~modules:[ "pasta_bindings_backend" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test" ])
    ~virtual_modules:[ "pasta_bindings_backend" ]
    ~default_implementation:"pasta_bindings.backend.native" ;

  (* -- pasta_bindings.backend.none -------------------------------- *)
  library "pasta_bindings.backend.none"
    ~internal_name:"pasta_bindings_backend_none"
    ~path:"src/lib/crypto/kimchi_bindings/stubs/pasta_bindings_backend/none"
    ~inline_tests:true
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test" ])
    ~implements:"pasta_bindings.backend" ;

  (* -- bindings_js ------------------------------------------------ *)
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
         ] ) ;

  (* -- bindings_js.node_backend ----------------------------------- *)
  library "bindings_js.node_backend" ~internal_name:"node_backend"
    ~path:"src/lib/crypto/kimchi_bindings/js/node_js"
    ~ppx:(Ppx.custom [ "ppx_version"; "js_of_ocaml-ppx" ])
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
      ] ;

  (* -- bindings_js.web_backend ------------------------------------ *)
  library "bindings_js.web_backend" ~internal_name:"web_backend"
    ~path:"src/lib/crypto/kimchi_bindings/js/web"
    ~ppx:(Ppx.custom [ "ppx_version"; "js_of_ocaml-ppx" ])
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
      ] ;

  (* -- kimchi_bindings.pasta_fp_poseidon -------------------------- *)
  library "kimchi_bindings.pasta_fp_poseidon"
    ~internal_name:"kimchi_pasta_fp_poseidon"
    ~path:"src/lib/crypto/kimchi_bindings/pasta_fp_poseidon"
    ~deps:[ local "kimchi_bindings" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test" ]) ;

  (* -- kimchi_bindings.pasta_fq_poseidon -------------------------- *)
  library "kimchi_bindings.pasta_fq_poseidon"
    ~internal_name:"kimchi_pasta_fq_poseidon"
    ~path:"src/lib/crypto/kimchi_bindings/pasta_fq_poseidon"
    ~deps:[ local "kimchi_bindings" ]
    ~inline_tests:true
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test" ]) ;

  (* -- kimchi_backend_common -------------------------------------- *)
  library "kimchi_backend_common" ~path:"src/lib/crypto/kimchi_backend/common"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "result"
      ; opam "async_kernel"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "integers"
      ; opam "digestif"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; opam "ppx_inline_test.config"
      ; opam "bignum.bigint"
      ; opam "zarith"
      ; opam "base.base_internalhash_types"
      ; local "tuple_lib"
      ; local "key_cache"
      ; local "hex"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_snarky_backend"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "plonkish_prelude"
      ; local "sponge"
      ; local "allocation_functor"
      ; local "snarky.intf"
      ; local "promise"
      ; local "logger"
      ; local "logger.context_logger"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_mina"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ; "h_list.ppx"
         ] ) ;

  (* -- kimchi_pasta ----------------------------------------------- *)
  library "kimchi_pasta" ~path:"src/lib/crypto/kimchi_backend/pasta"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "sponge"
      ; local "kimchi_backend_common"
      ; local "promise"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_basic"
      ; local "mina_stdlib"
      ; local "kimchi_pasta_constraint_system"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ] ) ;

  (* -- kimchi_pasta.basic ----------------------------------------- *)
  library "kimchi_pasta.basic" ~internal_name:"kimchi_pasta_basic"
    ~path:"src/lib/crypto/kimchi_backend/pasta/basic"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "sponge"
      ; local "kimchi_backend_common"
      ; local "promise"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "mina_stdlib"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ] ) ;

  (* -- kimchi_pasta.constraint_system (virtual) ------------------- *)
  library "kimchi_pasta.constraint_system"
    ~internal_name:"kimchi_pasta_constraint_system"
    ~path:"src/lib/crypto/kimchi_backend/pasta/constraint_system"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "sponge"
      ; local "kimchi_backend_common"
      ; local "promise"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_basic"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; local "ppx_version.runtime"
      ; local "snarky.backendless"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ] )
    ~virtual_modules:[ "pallas_constraint_system"; "vesta_constraint_system" ]
    ~default_implementation:"kimchi_pasta.constraint_system.caml" ;

  (* -- kimchi_pasta.constraint_system.caml ------------------------ *)
  library "kimchi_pasta.constraint_system.caml"
    ~internal_name:"kimchi_pasta_constraint_system_caml"
    ~path:"src/lib/crypto/kimchi_backend/pasta/constraint_system/caml"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "sponge"
      ; local "kimchi_backend_common"
      ; local "promise"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta_basic"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarkette"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.std"
         ] )
    ~implements:"kimchi_pasta.constraint_system" ;

  (* -- kimchi_backend --------------------------------------------- *)
  library "kimchi_backend" ~path:"src/lib/crypto/kimchi_backend"
    ~flags:[ atom "-warn-error"; atom "-27" ]
    ~inline_tests:true
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; local "hex"
      ; local "key_cache"
      ; local "kimchi_backend_common"
      ; local "kimchi_bindings"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "kimchi_pasta.constraint_system"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "snarky.intf"
      ; local "snarkette"
      ; local "sponge"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_version"
         ] ) ;

  (* -- kimchi_backend.gadgets ------------------------------------- *)
  library "kimchi_backend.gadgets" ~internal_name:"kimchi_gadgets"
    ~path:"src/lib/crypto/kimchi_backend/gadgets" ~inline_tests:true
    ~deps:
      [ opam "bignum.bigint"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ; opam "zarith"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_gadgets_test_runner"
      ; local "mina_stdlib"
      ; local "snarky.backendless"
      ]
    ~ppx:Ppx.standard ;

  (* -- kimchi_backend.gadgets_test_runner ------------------------- *)
  library "kimchi_backend.gadgets_test_runner"
    ~internal_name:"kimchi_gadgets_test_runner"
    ~path:"src/lib/crypto/kimchi_backend/gadgets/runner"
    ~deps:
      [ opam "stdio"
      ; opam "integers"
      ; opam "result"
      ; opam "base.caml"
      ; opam "bignum.bigint"
      ; opam "core_kernel"
      ; opam "base64"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "async_kernel"
      ; opam "bin_prot.shape"
      ; local "mina_wire_types"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "kimchi_pasta.constraint_system"
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; local "kimchi_backend"
      ; local "base58_check"
      ; local "codable"
      ; local "random_oracle_input"
      ; local "snarky_log"
      ; local "group_map"
      ; local "snarky_curve"
      ; local "key_cache"
      ; local "snark_keys_header"
      ; local "tuple_lib"
      ; local "promise"
      ; local "kimchi_backend_common"
      ; local "ppx_version.runtime"
      ]
    ~ppx:Ppx.mina_rich ;

  (* -- crypto_params ---------------------------------------------- *)
  library "crypto_params" ~path:"src/lib/crypto/crypto_params"
    ~synopsis:"Cryptographic parameters"
    ~flags:
      [ atom ":standard"; atom "-short-paths"; atom "-warn-error"; atom "-58" ]
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "cache_dir"
      ; local "group_map"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ]
    ~ppx:(Ppx.custom [ "h_list.ppx"; "ppx_jane"; "ppx_version" ])
    ~extra_stanzas:
      [ "rule"
        @: [ "targets" @: [ atom "group_map_params.ml" ]
           ; "deps" @: [ list [ atom ":<"; atom "gen/gen.exe" ] ]
           ; "action" @: [ list [ atom "run"; atom "%{<}"; atom "%{targets}" ] ]
           ]
      ] ;

  (* -- pickles_base ----------------------------------------------- *)
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
      [ opam "base.base_internalhash_types"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "ppxlib"
      ; opam "core_kernel"
      ; local "mina_wire_types"
      ; local "snarky.backendless"
      ; local "random_oracle_input"
      ; local "pickles_types"
      ; local "pickles_base.one_hot_vector"
      ; local "plonkish_prelude"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_version"
         ; "ppx_mina"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "h_list.ppx"
         ] ) ;

  (* -- pickles_base.one_hot_vector -------------------------------- *)
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
    ~deps:
      [ opam "core_kernel"; local "snarky.backendless"; local "pickles_types" ]
    ~ppx:Ppx.standard ;

  (* -- pickles_types ---------------------------------------------- *)
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
      [ opam "sexplib0"
      ; opam "result"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; local "kimchi_types"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta_snarky_backend"
      ; local "plonkish_prelude"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "h_list.ppx"
         ] ) ;

  (* -- snark_params ----------------------------------------------- *)
  library "snark_params" ~path:"src/lib/crypto/snark_params"
    ~synopsis:"Snark parameters" ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "core_kernel"
      ; opam "digestif"
      ; opam "base"
      ; opam "sexplib0"
      ; local "mina_wire_types"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "bignum_bigint"
      ; local "pickles.backend"
      ; local "snarky_curves"
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; local "group_map"
      ; local "fold_lib"
      ; local "bitstring_lib"
      ; local "snark_bits"
      ; local "pickles"
      ; local "crypto_params"
      ; local "snarky_field_extensions"
      ; local "snarky.intf"
      ; local "kimchi_backend"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_assert"
         ; "ppx_base"
         ; "ppx_bench"
         ; "ppx_let"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_sexp_conv"
         ; "ppx_bin_prot"
         ; "ppx_custom_printf"
         ; "ppx_snarky"
         ] ) ;

  (* -- random_oracle ---------------------------------------------- *)
  library "random_oracle" ~path:"src/lib/crypto/random_oracle"
    ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "snark_params"
      ; local "pickles.backend"
      ; local "sponge"
      ; local "pickles"
      ; local "random_oracle_input"
      ; local "snarky.backendless"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "fold_lib"
      ; local "random_oracle.permutation"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_sexp_conv"
         ; "ppx_compare"
         ; "ppx_inline_test"
         ; "ppx_assert"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ] ) ;

  (* -- random_oracle.permutation (virtual) ------------------------ *)
  library "random_oracle.permutation" ~internal_name:"random_oracle_permutation"
    ~path:"src/lib/crypto/random_oracle/permutation"
    ~deps:
      [ local "sponge"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:Ppx.minimal
    ~virtual_modules:[ "random_oracle_permutation" ]
    ~default_implementation:"random_oracle.permutation.external" ;

  (* -- random_oracle.permutation.external ------------------------- *)
  library "random_oracle.permutation.external"
    ~internal_name:"random_oracle_permutation_external"
    ~path:"src/lib/crypto/random_oracle/permutation/external" ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "sponge"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_bindings.pasta_fp_poseidon"
      ; local "kimchi_bindings"
      ; local "kimchi_backend"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_inline_test"; "ppx_assert" ])
    ~implements:"random_oracle.permutation" ;

  (* -- random_oracle.permutation.ocaml ---------------------------- *)
  library "random_oracle.permutation.ocaml"
    ~internal_name:"random_oracle_permutation_ocaml"
    ~path:"src/lib/crypto/random_oracle/permutation/ocaml"
    ~deps:
      [ opam "base"
      ; opam "core_kernel"
      ; local "sponge"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:Ppx.minimal ~implements:"random_oracle.permutation" ;

  (* -- non_zero_curve_point --------------------------------------- *)
  library "non_zero_curve_point" ~path:"src/lib/crypto/non_zero_curve_point"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base.caml"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; local "mina_wire_types"
      ; local "snarky.backendless"
      ; local "random_oracle_input"
      ; local "pickles.backend"
      ; local "pickles"
      ; local "codable"
      ; local "snark_params"
      ; local "fold_lib"
      ; local "base58_check"
      ; local "random_oracle"
      ; local "bitstring_lib"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_snarky"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_let"
         ; "ppx_hash"
         ; "ppx_compare"
         ; "ppx_sexp_conv"
         ; "ppx_bin_prot"
         ; "ppx_inline_test"
         ; "ppx_deriving_yojson"
         ; "ppx_compare"
         ; "h_list.ppx"
         ; "ppx_custom_printf"
         ] ) ;

  (* -- signature_lib --------------------------------------------- *)
  library "signature_lib" ~path:"src/lib/crypto/signature_lib"
    ~synopsis:"Schnorr signatures using the tick and tock curves"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ opam "bignum.bigint"
      ; opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "sexplib0"
      ; opam "yojson"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "result"
      ; local "mina_wire_types"
      ; local "crypto_params"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "random_oracle_input"
      ; local "bitstring_lib"
      ; local "codable"
      ; local "snark_params"
      ; local "mina_debug"
      ; local "blake2"
      ; local "hash_prefix_states"
      ; local "non_zero_curve_point"
      ; local "random_oracle"
      ; local "snarky.backendless"
      ; local "bignum_bigint"
      ; local "base58_check"
      ; local "snarky_curves"
      ; local "pickles"
      ; local "fold_lib"
      ; local "pickles.backend"
      ; local "kimchi_backend"
      ; local "h_list"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_snarky"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_custom_printf"
         ; "ppx_sexp_conv"
         ; "ppx_bin_prot"
         ; "ppx_hash"
         ; "ppx_compare"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_inline_test"
         ; "ppx_let"
         ] ) ;

  (* -- secrets ---------------------------------------------------- *)
  library "secrets" ~path:"src/lib/crypto/secrets"
    ~synopsis:"Managing secrets including passwords and keypairs"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ opam "result"
      ; opam "base.caml"
      ; opam "bignum.bigint"
      ; opam "async_kernel"
      ; opam "async"
      ; opam "core"
      ; opam "async_unix"
      ; opam "sodium"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "yojson"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "base58"
      ; opam "ppx_inline_test.config"
      ; local "mina_stdlib_unix"
      ; local "random_oracle"
      ; local "pickles"
      ; local "logger"
      ; local "snark_params"
      ; local "mina_stdlib"
      ; local "mina_net2"
      ; local "mina_base"
      ; local "base58_check"
      ; local "signature_lib"
      ; local "network_peer"
      ; local "mina_numbers"
      ; local "snarky.backendless"
      ; local "error_json"
      ; local "mina_base.import"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ; "ppx_deriving.make"
         ] ) ;

  (* -- key_gen ---------------------------------------------------- *)
  library "key_gen" ~path:"src/lib/crypto/key_gen"
    ~deps:[ opam "core_kernel"; local "signature_lib" ]
    ~ppx:Ppx.minimal ;

  (* -- bowe_gabizon_hash ------------------------------------------ *)
  library "bowe_gabizon_hash" ~path:"src/lib/crypto/bowe_gabizon_hash"
    ~inline_tests:true
    ~deps:[ opam "core_kernel" ]
    ~ppx:(Ppx.custom [ "ppx_compare"; "ppx_jane"; "ppx_version" ]) ;

  (* -- pickles.limb_vector ---------------------------------------- *)
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
      [ opam "bin_prot.shape"
      ; opam "sexplib0"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; opam "result"
      ; local "snarky.backendless"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "ppx_version.runtime"
      ]
    ~ppx:Ppx.mina_rich ;

  (* -- pickles.pseudo --------------------------------------------- *)
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
      [ opam "core_kernel"
      ; local "pickles_types"
      ; local "pickles.plonk_checks"
      ; local "pickles_base.one_hot_vector"
      ; local "snarky.backendless"
      ; local "pickles_base"
      ]
    ~ppx:Ppx.mina_rich ;

  (* -- pickles.composition_types ---------------------------------- *)
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
      [ opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; local "mina_wire_types"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "snarky.backendless"
      ; local "pickles_types"
      ; local "pickles.limb_vector"
      ; local "kimchi_backend"
      ; local "pickles_base"
      ; local "pickles.backend"
      ; local "kimchi_backend_common"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_mina"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "h_list.ppx"
         ] ) ;

  (* -- pickles.plonk_checks -------------------------------------- *)
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
      [ opam "sexplib0"
      ; opam "ppxlib.ast"
      ; opam "core_kernel"
      ; opam "ocaml-migrate-parsetree"
      ; opam "base.base_internalhash_types"
      ; local "pickles_types"
      ; local "pickles_base"
      ; local "pickles.composition_types"
      ; local "kimchi_backend"
      ; local "kimchi_types"
      ; local "snarky.backendless"
      ; local "tuple_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
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
      ] ;

  (* -- pickles.backend -------------------------------------------- *)
  library "pickles.backend" ~internal_name:"backend"
    ~path:"src/lib/crypto/pickles/backend"
    ~deps:
      [ local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:Ppx.mina_rich ;

  (* -- pickles ---------------------------------------------------- *)
  library "pickles" ~path:"src/lib/crypto/pickles" ~inline_tests:true
    ~modules_without_implementation:
      [ "full_signature"; "type"; "intf"; "pickles_intf" ]
    ~flags:[ atom "-open"; atom "Core_kernel" ]
    ~deps:
      [ opam "stdio"
      ; opam "integers"
      ; opam "result"
      ; opam "base.caml"
      ; opam "bignum.bigint"
      ; opam "core_kernel"
      ; opam "base64"
      ; opam "digestif"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "async_kernel"
      ; opam "bin_prot.shape"
      ; local "mina_wire_types"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "kimchi_pasta.constraint_system"
      ; local "kimchi_pasta_snarky_backend"
      ; local "bitstring_lib"
      ; local "snarky.intf"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "snarky.backendless"
      ; local "snarky_group_map"
      ; local "sponge"
      ; local "pickles.pseudo"
      ; local "pickles.limb_vector"
      ; local "pickles_base"
      ; local "plonkish_prelude"
      ; local "kimchi_backend"
      ; local "base58_check"
      ; local "codable"
      ; local "random_oracle_input"
      ; local "pickles.composition_types"
      ; local "pickles.plonk_checks"
      ; local "pickles_base.one_hot_vector"
      ; local "snarky_log"
      ; local "group_map"
      ; local "snarky_curve"
      ; local "key_cache"
      ; local "snark_keys_header"
      ; local "tuple_lib"
      ; local "promise"
      ; local "kimchi_backend_common"
      ; local "logger"
      ; local "logger.context_logger"
      ; local "ppx_version.runtime"
      ; local "error_json"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_mina"
         ; "ppx_jane"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "h_list.ppx"
         ] ) ;

  ()

let register () = register_low_level () ; register_backends ()
