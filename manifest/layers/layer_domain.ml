(** Mina Core domain libraries: base types, hashing, genesis, fields.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

(* Core Domain Libraries                                            *)

let hash_prefix_states =
  library "hash_prefix_states" ~path:"src/lib/hash_prefix_states"
    ~inline_tests:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; core_kernel
      ; Layer_crypto.hash_prefixes
      ; Layer_crypto.random_oracle
      ; Layer_crypto.snark_params
      ; Layer_pickles.pickles
      ; local "hash_prefix_create"
      ; local "mina_signature_kind"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~synopsis:
      "Values corresponding to the internal state of the Pedersen hash \
       function on the prefixes used in Coda"

let hash_prefix_create =
  library "hash_prefix_create"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create"
    ~deps:[ Layer_crypto.hash_prefixes; Layer_crypto.random_oracle ]
    ~virtual_modules:[ "hash_prefix_create" ]
    ~default_implementation:"hash_prefix_create.native" ~ppx:Ppx.minimal

let hash_prefix_create_native =
  library "hash_prefix_create.native" ~internal_name:"hash_prefix_create_native"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create/native"
    ~deps:[ Layer_crypto.random_oracle ]
    ~implements:"hash_prefix_create" ~ppx:Ppx.minimal

let hash_prefix_create_js =
  library "hash_prefix_create.js" ~internal_name:"hash_prefix_create_js"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create/js"
    ~deps:
      [ base
      ; core_kernel
      ; js_of_ocaml
      ; Layer_crypto.random_oracle
      ; Layer_pickles.pickles
      ]
    ~implements:"hash_prefix_create" ~ppx:Ppx.minimal

let data_hash_lib =
  library "data_hash_lib" ~path:"src/lib/data_hash_lib" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; core_kernel
      ; ppx_inline_test_config
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_base.mina_wire_types
      ; Layer_crypto.bignum_bigint
      ; Layer_crypto.outside_hash_image
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.snark_params
      ; Layer_pickles.pickles
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snark_bits
      ; Layer_test.test_util
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.snarky_intf
      ; local "fields_derivers"
      ; local "fields_derivers_graphql"
      ; local "fields_derivers_json"
      ; local "fields_derivers_zkapps"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_bench
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Data hash"

let block_time =
  library "block_time" ~path:"src/lib/block_time" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async_kernel
      ; base
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; integers
      ; sexplib0
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_concurrency.timeout_lib
      ; Layer_crypto.crypto_params
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.snark_params
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snark_bits
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_inline_test
         ] )
    ~synopsis:"Block time"

let proof_carrying_data =
  library "proof_carrying_data" ~path:"src/lib/proof_carrying_data"
    ~deps:
      [ base
      ; base_caml
      ; bin_prot_shape
      ; core_kernel
      ; sexplib0
      ; Layer_base.mina_wire_types
      ; Layer_ppx.ppx_version_runtime
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ] )

let genesis_constants =
  library "genesis_constants" ~path:"src/lib/genesis_constants"
    ~inline_tests:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; base_caml
      ; bin_prot_shape
      ; core_kernel
      ; data_hash_lib
      ; integers
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_crypto.blake2
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_node.mina_node_config
      ; Layer_node.mina_node_config_for_unit_tests
      ; Layer_node.mina_node_config_intf
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snark_keys_header
      ; Layer_test.test_util
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_ord
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_inline_test
         ] )
    ~synopsis:"Coda genesis constants"

let node_addrs_and_ports =
  library "node_addrs_and_ports" ~path:"src/lib/node_addrs_and_ports"
    ~inline_tests:true
    ~deps:
      [ async
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; sexplib0
      ; yojson
      ; Layer_base.mina_stdlib
      ; Layer_ppx.ppx_version_runtime
      ; local "network_peer"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_deriving_yojson
         ] )


let fields_derivers =
  library "fields_derivers" ~path:"src/lib/fields_derivers" ~inline_tests:true
    ~deps:[ core_kernel; fieldslib; ppx_inline_test_config ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_version
         ] )

let fields_derivers_json =
  library "fields_derivers.json" ~internal_name:"fields_derivers_json"
    ~path:"src/lib/fields_derivers_json" ~inline_tests:true
    ~deps:
      [ core_kernel
      ; fields_derivers
      ; fieldslib
      ; ppx_inline_test_config
      ; result
      ; yojson
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_version
         ] )

let fields_derivers_graphql =
  library "fields_derivers.graphql" ~internal_name:"fields_derivers_graphql"
    ~path:"src/lib/fields_derivers_graphql" ~inline_tests:true
    ~deps:
      [ async_kernel
      ; core_kernel
      ; fields_derivers
      ; fieldslib
      ; graphql
      ; graphql_async
      ; graphql_parser
      ; ppx_inline_test_config
      ; yojson
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_version
         ] )

let fields_derivers_zkapps =
  library "fields_derivers.zkapps" ~internal_name:"fields_derivers_zkapps"
    ~path:"src/lib/fields_derivers_zkapps"
    ~deps:
      [ base
      ; base_caml
      ; core_kernel
      ; fields_derivers
      ; fields_derivers_graphql
      ; fields_derivers_json
      ; fieldslib
      ; graphql
      ; graphql_parser
      ; integers
      ; result
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.mina_numbers
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_pickles.pickles
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_version
         ] )

let parallel_scan =
  library "parallel_scan" ~path:"src/lib/parallel_scan" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; digestif
      ; lens
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_concurrency.pipe_lib
      ; Layer_ppx.ppx_version_runtime
      ; Layer_tooling.mina_metrics
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.lens_ppx_deriving
         ] )
    ~synopsis:"Parallel scan over an infinite stream (incremental map-reduce)"

let dummy_values =
  library "dummy_values" ~path:"src/lib/dummy_values"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~deps:
      [ core_kernel
      ; Layer_crypto.crypto_params
      ; Layer_pickles.pickles
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx_runtime_libraries:[ "base" ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppxlib_metaquot ] )
    ~extra_stanzas:
      [ list
          [ atom "rule"
          ; list [ atom "targets"; atom "dummy_values.ml" ]
          ; list
              [ atom "deps"
              ; list [ atom ":<"; atom "gen_values/gen_values.exe" ]
              ]
          ; list
              [ atom "action"
              ; list [ atom "run"; atom "%{<}"; atom "%{targets}" ]
              ]
          ]
      ]

let () =
  private_executable ~path:"src/lib/dummy_values/gen_values"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; compiler_libs
      ; core
      ; core_kernel
      ; ocaml_compiler_libs_common
      ; ocaml_migrate_parsetree
      ; ppxlib
      ; ppxlib_ast
      ; ppxlib_astlib
      ; stdio
      ; Layer_crypto.crypto_params
      ; Layer_logging.logger_fake
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_types
      ; Layer_tooling.mina_metrics_none
      ]
    ~forbidden_libraries:[ "mina_node_config"; "protocol_version" ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppxlib_metaquot ] )
    ~link_flags:[ "-linkall" ] ~modes:[ "native" ] "gen_values"

let mina_base_test_helpers =
  library "mina_base.test_helpers" ~internal_name:"mina_base_test_helpers"
    ~path:"src/lib/mina_base/test/helpers"
    ~deps:
      [ base
      ; base_caml
      ; core_kernel
      ; integers
      ; sexplib0
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.monad_lib
      ; Layer_crypto.signature_lib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_version
         ] )
