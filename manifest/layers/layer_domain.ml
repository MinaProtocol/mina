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
    [ core_kernel
    ; base
    ; Layer_crypto.snark_params
    ; Layer_crypto.random_oracle
    ; Layer_infra.mina_signature_kind
    ; Layer_crypto.hash_prefixes
    ; local "hash_prefix_create"

    ; Layer_crypto.pickles
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
    [ js_of_ocaml; base; core_kernel; Layer_crypto.pickles; Layer_crypto.random_oracle ]
  ~implements:"hash_prefix_create" ~ppx:Ppx.minimal

let data_hash_lib =
  library "data_hash_lib" ~path:"src/lib/data_hash_lib" ~inline_tests:true
  ~library_flags:[ "-linkall" ]
  ~deps:
    [ base
    ; core_kernel
    ; ppx_inline_test_config
    ; Layer_base.base58_check
    ; Layer_crypto.bignum_bigint
    ; local "bitstring_lib"
    ; Layer_base.codable
    ; local "fields_derivers"

    ; local "fields_derivers_graphql"

    ; local "fields_derivers_json"

    ; local "fields_derivers_zkapps"

    ; local "fold_lib"
    ; Layer_base.mina_wire_types
    ; Layer_crypto.outside_hash_image
    ; Layer_crypto.pickles
    ; Layer_ppx.ppx_version_runtime
    ; Layer_crypto.random_oracle
    ; Layer_crypto.random_oracle_input
    ; Layer_snarky.snark_bits
    ; Layer_crypto.snark_params
    ; local "snarky.backendless"
    ; local "snarky.intf"
    ; Layer_test.test_util
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
    [ integers
    ; base_caml
    ; bin_prot_shape
    ; sexplib0
    ; async_kernel
    ; core_kernel
    ; base
    ; base_internalhash_types
    ; Layer_base.mina_wire_types
    ; local "bitstring_lib"
    ; Layer_crypto.pickles
    ; Layer_base.unsigned_extended
    ; Layer_crypto.snark_params
    ; Layer_infra.mina_numbers
    ; Layer_infra.logger
    ; Layer_snarky.snark_bits
    ; Layer_concurrency.timeout_lib
    ; Layer_crypto.crypto_params
    ; local "snarky.backendless"
    ; Layer_crypto.random_oracle_input
    ; Layer_crypto.random_oracle
    ; Layer_ppx.ppx_version_runtime
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
    [ core_kernel
    ; bin_prot_shape
    ; base
    ; base_caml
    ; sexplib0
    ; Layer_base.mina_wire_types
    ; Layer_ppx.ppx_version_runtime
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_deriving_yojson; Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])

let genesis_constants =
  library "genesis_constants" ~path:"src/lib/genesis_constants"
  ~inline_tests:true ~library_flags:[ "-linkall" ]
  ~deps:
    [ ppx_inline_test_config
    ; base
    ; bin_prot_shape
    ; core_kernel
    ; base_caml
    ; sexplib0
    ; integers
    ; Layer_node.mina_node_config_intf
    ; Layer_node.mina_node_config_for_unit_tests
    ; Layer_node.mina_node_config
    ; Layer_base.mina_wire_types
    ; Layer_base.unsigned_extended
    ; Layer_infra.mina_numbers
    ; Layer_crypto.pickles
    ; Layer_base.currency
    ; Layer_crypto.blake2
    ; data_hash_lib
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.snark_keys_header
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_test.test_util
    ; Layer_ppx.ppx_version_runtime
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

let network_peer =
  library "network_peer" ~path:"src/lib/network_peer"
  ~deps:
    [ core
    ; async
    ; async_rpc
    ; async_rpc_kernel
    ; core_kernel
    ; bin_prot_shape
    ; sexplib0
    ; base_caml
    ; base_internalhash_types
    ; result
    ; async_kernel
    ; mina_metrics
    ; ppx_version_runtime
    ; Layer_base.mina_stdlib
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_compare
       ; Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ; Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_deriving_yojson
       ] )

let node_addrs_and_ports =
  library "node_addrs_and_ports" ~path:"src/lib/node_addrs_and_ports"
  ~inline_tests:true
  ~deps:
    [ core
    ; async
    ; yojson
    ; sexplib0
    ; base_caml
    ; core_kernel
    ; bin_prot_shape
    ; network_peer
    ; Layer_ppx.ppx_version_runtime
    ; Layer_base.mina_stdlib
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_let; Ppx_lib.ppx_deriving_yojson ] )

let user_command_input =
  library "user_command_input" ~path:"src/lib/user_command_input"
  ~deps:
    [ bin_prot_shape
    ; core
    ; core_kernel
    ; async_kernel
    ; sexplib0
    ; base_caml
    ; async
    ; Layer_infra.logger
    ; genesis_constants
    ; Layer_base.currency
    ; Layer_base.unsigned_extended
    ; Layer_base.participating_state
    ; Layer_crypto.secrets
    ; Layer_crypto.signature_lib
    ; Layer_base.mina_base
    ; Layer_infra.mina_numbers
    ; Layer_base.mina_base_import
    ; Layer_ppx.ppx_version_runtime
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.ppx_mina
       ; Ppx_lib.ppx_version
       ; Ppx_lib.ppx_deriving_yojson
       ; Ppx_lib.ppx_jane
       ; Ppx_lib.ppx_deriving_make
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
    ; fieldslib
    ; ppx_inline_test_config
    ; result
    ; yojson
    ; fields_derivers
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
    ; fieldslib
    ; graphql
    ; graphql_async
    ; graphql_parser
    ; ppx_inline_test_config
    ; yojson
    ; fields_derivers
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
    ; fieldslib
    ; graphql
    ; graphql_parser
    ; integers
    ; result
    ; sexplib0
    ; Layer_base.currency
    ; fields_derivers
    ; fields_derivers_graphql
    ; fields_derivers_json
    ; Layer_infra.mina_numbers
    ; Layer_crypto.pickles
    ; Layer_crypto.sgn
    ; Layer_crypto.signature_lib
    ; Layer_crypto.snark_params
    ; Layer_base.unsigned_extended
    ; Layer_base.with_hash
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
    [ ppx_inline_test_config
    ; base
    ; core_kernel
    ; sexplib0
    ; async
    ; digestif
    ; core
    ; lens
    ; async_kernel
    ; bin_prot_shape
    ; base_caml
    ; async_unix
    ; Layer_tooling.mina_metrics
    ; Layer_base.mina_stdlib
    ; Layer_base.pipe_lib
    ; Layer_ppx.ppx_version_runtime
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
    ; local "snarky.backendless"
    ; Layer_crypto.pickles
    ]
  ~ppx_runtime_libraries:[ "base" ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppxlib_metaquot ])
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
    [ async_unix
    ; stdio
    ; base_caml
    ; ocaml_migrate_parsetree
    ; core
    ; async
    ; ppxlib
    ; ppxlib_ast
    ; ppxlib_astlib
    ; core_kernel
    ; compiler_libs
    ; async_kernel
    ; ocaml_compiler_libs_common
    ; Layer_crypto.pickles_types
    ; Layer_crypto.pickles
    ; Layer_crypto.crypto_params
    ; Layer_tooling.mina_metrics_none
    ; Layer_infra.logger_fake
    ]
  ~forbidden_libraries:[ "mina_node_config"; "protocol_version" ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppxlib_metaquot ])
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
    ; Layer_infra.mina_numbers
    ; Layer_base.monad_lib
    ; Layer_crypto.signature_lib
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_base; Ppx_lib.ppx_let; Ppx_lib.ppx_assert; Ppx_lib.ppx_version ])

