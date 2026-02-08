(** Mina Core domain libraries: base types, hashing, genesis, fields.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Dune_s_expr

let register () =
  (* ================================================================ *)
  (* Core Domain Libraries                                            *)
  (* ================================================================ *)

  (* -- hash_prefix_states ------------------------------------------ *)
  library "hash_prefix_states" ~path:"src/lib/hash_prefix_states"
    ~inline_tests:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "core_kernel"
      ; opam "base"
      ; local "snark_params"
      ; local "random_oracle"
      ; local "mina_signature_kind"
      ; local "hash_prefixes"
      ; local "hash_prefix_create"
      ; local "pickles"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_custom_printf"
         ; "ppx_snarky"
         ; "ppx_version"
         ; "ppx_inline_test"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ] )
    ~synopsis:
      "Values corresponding to the internal state of the Pedersen hash \
       function on the prefixes used in Coda" ;

  (* -- hash_prefix_create (virtual) -------------------------------- *)
  library "hash_prefix_create"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create"
    ~deps:[ local "hash_prefixes"; local "random_oracle" ]
    ~virtual_modules:[ "hash_prefix_create" ]
    ~default_implementation:"hash_prefix_create.native" ~ppx:Ppx.minimal ;

  (* -- hash_prefix_create.native ----------------------------------- *)
  library "hash_prefix_create.native" ~internal_name:"hash_prefix_create_native"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create/native"
    ~deps:[ local "random_oracle" ]
    ~implements:"hash_prefix_create" ~ppx:Ppx.minimal ;

  (* -- hash_prefix_create.js --------------------------------------- *)
  library "hash_prefix_create.js" ~internal_name:"hash_prefix_create_js"
    ~path:"src/lib/hash_prefix_states/hash_prefix_create/js"
    ~deps:
      [ opam "js_of_ocaml"
      ; opam "base"
      ; opam "core_kernel"
      ; local "pickles"
      ; local "random_oracle"
      ]
    ~implements:"hash_prefix_create" ~ppx:Ppx.minimal ;

  (* -- data_hash_lib ----------------------------------------------- *)
  library "data_hash_lib" ~path:"src/lib/data_hash_lib" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base"
      ; opam "core_kernel"
      ; opam "ppx_inline_test.config"
      ; local "base58_check"
      ; local "bignum_bigint"
      ; local "bitstring_lib"
      ; local "codable"
      ; local "fields_derivers"
      ; local "fields_derivers.graphql"
      ; local "fields_derivers.json"
      ; local "fields_derivers.zkapps"
      ; local "fold_lib"
      ; local "mina_wire_types"
      ; local "outside_hash_image"
      ; local "pickles"
      ; local "ppx_version.runtime"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "snark_bits"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "snarky.intf"
      ; local "test_util"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_bench"
         ; "ppx_compare"
         ; "ppx_hash"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_snarky"
         ; "ppx_version"
         ] )
    ~synopsis:"Data hash" ;

  (* -- block_time -------------------------------------------------- *)
  library "block_time" ~path:"src/lib/block_time" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "integers"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "sexplib0"
      ; opam "async_kernel"
      ; opam "core_kernel"
      ; opam "base"
      ; opam "base.base_internalhash_types"
      ; local "mina_wire_types"
      ; local "bitstring_lib"
      ; local "pickles"
      ; local "unsigned_extended"
      ; local "snark_params"
      ; local "mina_numbers"
      ; local "logger"
      ; local "snark_bits"
      ; local "timeout_lib"
      ; local "crypto_params"
      ; local "snarky.backendless"
      ; local "random_oracle_input"
      ; local "random_oracle"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ; "ppx_bin_prot"
         ; "ppx_compare"
         ; "ppx_sexp_conv"
         ; "ppx_compare"
         ; "ppx_inline_test"
         ] )
    ~synopsis:"Block time" ;

  (* -- proof_carrying_data ----------------------------------------- *)
  library "proof_carrying_data" ~path:"src/lib/proof_carrying_data"
    ~deps:
      [ opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "base"
      ; opam "base.caml"
      ; opam "sexplib0"
      ; local "mina_wire_types"
      ; local "ppx_version.runtime"
      ]
    ~ppx:(Ppx.custom [ "ppx_deriving_yojson"; "ppx_version"; "ppx_jane" ]) ;

  (* -- genesis_constants ------------------------------------------- *)
  library "genesis_constants" ~path:"src/lib/genesis_constants"
    ~inline_tests:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "bin_prot.shape"
      ; opam "core_kernel"
      ; opam "base.caml"
      ; opam "sexplib0"
      ; opam "integers"
      ; local "mina_node_config.intf"
      ; local "mina_node_config.for_unit_tests"
      ; local "mina_node_config"
      ; local "mina_wire_types"
      ; local "unsigned_extended"
      ; local "mina_numbers"
      ; local "pickles"
      ; local "currency"
      ; local "blake2"
      ; local "data_hash_lib"
      ; local "pickles.backend"
      ; local "snark_keys_header"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "test_util"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_bin_prot"
         ; "ppx_compare"
         ; "ppx_hash"
         ; "ppx_fields_conv"
         ; "ppx_compare"
         ; "ppx_deriving.ord"
         ; "ppx_sexp_conv"
         ; "ppx_let"
         ; "ppx_custom_printf"
         ; "ppx_deriving_yojson"
         ; "h_list.ppx"
         ; "ppx_inline_test"
         ] )
    ~synopsis:"Coda genesis constants" ;

  (* -- network_peer ------------------------------------------------ *)
  library "network_peer" ~path:"src/lib/network_peer"
    ~deps:
      [ opam "core"
      ; opam "async"
      ; opam "async.async_rpc"
      ; opam "async_rpc_kernel"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "base.base_internalhash_types"
      ; opam "result"
      ; opam "async_kernel"
      ; opam "mina_metrics"
      ; opam "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving_yojson"
         ] ) ;

  (* -- node_addrs_and_ports ---------------------------------------- *)
  library "node_addrs_and_ports" ~path:"src/lib/node_addrs_and_ports"
    ~inline_tests:true
    ~deps:
      [ opam "core"
      ; opam "async"
      ; opam "yojson"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "bin_prot.shape"
      ; local "network_peer"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"; "ppx_jane"; "ppx_let"; "ppx_deriving_yojson" ] ) ;

  (* -- user_command_input ------------------------------------------ *)
  library "user_command_input" ~path:"src/lib/user_command_input"
    ~deps:
      [ opam "bin_prot.shape"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "async_kernel"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "async"
      ; local "logger"
      ; local "genesis_constants"
      ; local "currency"
      ; local "unsigned_extended"
      ; local "participating_state"
      ; local "secrets"
      ; local "signature_lib"
      ; local "mina_base"
      ; local "mina_numbers"
      ; local "mina_base.import"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_deriving.make"
         ] ) ;

  (* -- fields_derivers --------------------------------------------- *)
  library "fields_derivers" ~path:"src/lib/fields_derivers" ~inline_tests:true
    ~deps:
      [ opam "core_kernel"; opam "fieldslib"; opam "ppx_inline_test.config" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"
         ; "ppx_custom_printf"
         ; "ppx_fields_conv"
         ; "ppx_inline_test"
         ; "ppx_jane"
         ; "ppx_let"
         ; "ppx_version"
         ] ) ;

  (* -- fields_derivers.json ---------------------------------------- *)
  library "fields_derivers.json" ~internal_name:"fields_derivers_json"
    ~path:"src/lib/fields_derivers_json" ~inline_tests:true
    ~deps:
      [ opam "core_kernel"
      ; opam "fieldslib"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "yojson"
      ; local "fields_derivers"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"
         ; "ppx_custom_printf"
         ; "ppx_deriving_yojson"
         ; "ppx_fields_conv"
         ; "ppx_inline_test"
         ; "ppx_jane"
         ; "ppx_let"
         ; "ppx_version"
         ] ) ;

  (* -- fields_derivers.graphql ------------------------------------- *)
  library "fields_derivers.graphql" ~internal_name:"fields_derivers_graphql"
    ~path:"src/lib/fields_derivers_graphql" ~inline_tests:true
    ~deps:
      [ opam "async_kernel"
      ; opam "core_kernel"
      ; opam "fieldslib"
      ; opam "graphql"
      ; opam "graphql-async"
      ; opam "graphql_parser"
      ; opam "ppx_inline_test.config"
      ; opam "yojson"
      ; local "fields_derivers"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"
         ; "ppx_custom_printf"
         ; "ppx_fields_conv"
         ; "ppx_inline_test"
         ; "ppx_jane"
         ; "ppx_let"
         ; "ppx_version"
         ] ) ;

  (* -- fields_derivers.zkapps -------------------------------------- *)
  library "fields_derivers.zkapps" ~internal_name:"fields_derivers_zkapps"
    ~path:"src/lib/fields_derivers_zkapps"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "fieldslib"
      ; opam "graphql"
      ; opam "graphql_parser"
      ; opam "integers"
      ; opam "result"
      ; opam "sexplib0"
      ; local "currency"
      ; local "fields_derivers"
      ; local "fields_derivers.graphql"
      ; local "fields_derivers.json"
      ; local "mina_numbers"
      ; local "pickles"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_annot"
         ; "ppx_assert"
         ; "ppx_base"
         ; "ppx_custom_printf"
         ; "ppx_deriving_yojson"
         ; "ppx_fields_conv"
         ; "ppx_let"
         ; "ppx_version"
         ] ) ;

  (* -- parallel_scan ----------------------------------------------- *)
  library "parallel_scan" ~path:"src/lib/parallel_scan" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "async"
      ; opam "digestif"
      ; opam "core"
      ; opam "lens"
      ; opam "async_kernel"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "async_unix"
      ; local "mina_metrics"
      ; local "mina_stdlib"
      ; local "pipe_lib"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_compare"
         ; "lens.ppx_deriving"
         ] )
    ~synopsis:"Parallel scan over an infinite stream (incremental map-reduce)" ;

  (* -- dummy_values ------------------------------------------------ *)
  library "dummy_values" ~path:"src/lib/dummy_values"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~deps:
      [ opam "core_kernel"
      ; local "crypto_params"
      ; local "snarky.backendless"
      ; local "pickles"
      ]
    ~ppx_runtime_libraries:[ "base" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppxlib.metaquot" ])
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
      ] ;

  (* -- gen_values (executable) ------------------------------------- *)
  private_executable ~path:"src/lib/dummy_values/gen_values"
    ~deps:
      [ opam "async_unix"
      ; opam "stdio"
      ; opam "base.caml"
      ; opam "ocaml-migrate-parsetree"
      ; opam "core"
      ; opam "async"
      ; opam "ppxlib"
      ; opam "ppxlib.ast"
      ; opam "ppxlib.astlib"
      ; opam "core_kernel"
      ; opam "compiler-libs"
      ; opam "async_kernel"
      ; opam "ocaml-compiler-libs.common"
      ; local "pickles_types"
      ; local "pickles"
      ; local "crypto_params"
      ; local "mina_metrics.none"
      ; local "logger.fake"
      ]
    ~forbidden_libraries:[ "mina_node_config"; "protocol_version" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppxlib.metaquot" ])
    ~link_flags:[ "-linkall" ] ~modes:[ "native" ] "gen_values" ;

  (* -- mina_base.test_helpers -------------------------------------- *)
  library "mina_base.test_helpers" ~internal_name:"mina_base_test_helpers"
    ~path:"src/lib/mina_base/test/helpers"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "sexplib0"
      ; opam "yojson"
      ; local "currency"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_numbers"
      ; local "monad_lib"
      ; local "signature_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_base"; "ppx_let"; "ppx_assert"; "ppx_version" ]) ;

  ()
