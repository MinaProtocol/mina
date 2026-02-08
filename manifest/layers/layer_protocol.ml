(** Mina protocol layer: protocol versioning, snarks, and proving.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Dune_s_expr

let register_protocol () =
  (* -- protocol_version --------------------------------------------- *)
  library "protocol_version" ~path:"src/lib/protocol_version"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "core_kernel"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "base"
      ; opam "ppx_version.runtime"
      ; local "mina_wire_types"
      ; local "mina_node_config.version"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_bin_prot"
         ; "ppx_fields_conv"
         ; "ppx_sexp_conv"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ] )
    ~synopsis:"Protocol version representation" ;

  (* -- transaction_protocol_state ---------------------------------- *)
  library "transaction_protocol_state"
    ~path:"src/lib/transaction_protocol_state" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "sexplib0"
      ; opam "core_kernel"
      ; opam "core"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; local "pickles"
      ; local "genesis_constants"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "mina_state"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_snarky"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ] )
    ~synopsis:"Transaction protocol state library" ;

  (* -- zkapp_command_builder ---------------------------------------- *)
  library "zkapp_command_builder" ~path:"src/lib/zkapp_command_builder"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "async_kernel"
      ; opam "async_unix"
      ; opam "core_kernel"
      ; local "mina_base"
      ; local "currency"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "signature_lib"
      ; local "sgn"
      ; local "snark_params"
      ; local "snarky.backendless"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"
         ; "ppx_annot"
         ; "ppx_snarky"
         ; "ppx_here"
         ; "ppx_mina"
         ; "ppx_version"
         ] )
    ~synopsis:"Builder Zkapp_command.t via combinators" ;

  ()

let register_transaction_snark () =
  (* -- transaction_snark -------------------------------------------- *)
  library "transaction_snark" ~path:"src/lib/transaction_snark"
    ~inline_tests:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "async"
      ; opam "async_unix"
      ; opam "bignum"
      ; opam "core"
      ; opam "splittable_random"
      ; local "bitstring_lib"
      ; local "mina_stdlib"
      ; local "cache_dir"
      ; local "coda_genesis_ledger"
      ; local "consensus"
      ; local "crypto_params"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "hash_prefix_states"
      ; local "kimchi_backend"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "logger"
      ; local "merkle_ledger"
      ; local "mina_base"
      ; local "mina_base.util"
      ; local "mina_ledger"
      ; local "mina_numbers"
      ; local "mina_signature_kind"
      ; local "mina_state"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "mina_wire_types"
      ; local "o1trace"
      ; local "one_or_two"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_base"
      ; local "pickles_types"
      ; local "ppx_version.runtime"
      ; local "proof_carrying_data"
      ; local "quickcheck_lib"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "sgn"
      ; local "sgn_type"
      ; local "signature_lib"
      ; local "snarky.backendless"
      ; local "snarky_integer"
      ; local "snark_keys_header"
      ; local "snark_params"
      ; local "test_util"
      ; local "transaction_protocol_state"
      ; local "transaction_witness"
      ; local "tuple_lib"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_snarky"
         ; "ppx_version"
         ] )
    ~synopsis:"Transaction state transition snarking library" ;

  (* -- blockchain_snark --------------------------------------------- *)
  library "blockchain_snark" ~path:"src/lib/blockchain_snark" ~inline_tests:true
    ~flags:[ atom ":standard"; atom "-warn-error"; atom "+a" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "base.caml"
      ; opam "base.md5"
      ; opam "bin_prot.shape"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; local "allocation_functor"
      ; local "cache_dir"
      ; local "consensus"
      ; local "crypto_params"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_state"
      ; local "mina_transaction_logic"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_base"
      ; local "pickles_types"
      ; local "ppx_version.runtime"
      ; local "random_oracle"
      ; local "sgn"
      ; local "snarky.backendless"
      ; local "snark_keys_header"
      ; local "snark_params"
      ; local "transaction_snark"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"; "ppx_jane"; "ppx_mina"; "ppx_snarky"; "ppx_version" ] )
    ~synopsis:"blockchain state transition snarking library" ;

  (* -- print_blockchain_snark_vk ------------------------------------ *)
  private_executable
    ~path:"src/lib/blockchain_snark/tests/print_blockchain_snark_vk"
    ~deps:
      [ local "blockchain_snark"
      ; local "genesis_constants"
      ; local "mina_node_config"
      ]
    ~ppx:(Ppx.custom [ "ppx_version" ])
    ~extra_stanzas:
      [ "rule"
        @: [ "deps" @: [ atom "print_blockchain_snark_vk.exe" ]
           ; "targets"
             @: [ atom "%{profile}_blockchain_snark_vk.json.computed" ]
           ; "action"
             @: [ "with-stdout-to"
                  @: [ atom "%{targets}"; "run" @: [ atom "%{deps}" ] ]
                ]
           ]
      ; "rule"
        @: [ "deps"
             @: [ list
                    [ atom ":orig"; atom "%{profile}_blockchain_snark_vk.json" ]
                ; list
                    [ atom ":computed"
                    ; atom "%{profile}_blockchain_snark_vk.json.computed"
                    ]
                ]
           ; "alias" @: [ atom "runtest" ]
           ; "action" @: [ "diff" @: [ atom "%{orig}"; atom "%{computed}" ] ]
           ]
      ]
    "print_blockchain_snark_vk" ;

  (* -- print_transaction_snark_vk ----------------------------------- *)
  private_executable
    ~path:"src/lib/transaction_snark/test/print_transaction_snark_vk"
    ~deps:
      [ local "genesis_constants"
      ; local "mina_node_config"
      ; local "transaction_snark"
      ]
    ~ppx:(Ppx.custom [ "ppx_version" ])
    ~extra_stanzas:
      [ "rule"
        @: [ "deps" @: [ atom "print_transaction_snark_vk.exe" ]
           ; "targets"
             @: [ atom "%{profile}_transaction_snark_vk.json.computed" ]
           ; "action"
             @: [ "with-stdout-to"
                  @: [ atom "%{targets}"; "run" @: [ atom "%{deps}" ] ]
                ]
           ]
      ; "rule"
        @: [ "deps"
             @: [ list
                    [ atom ":orig"
                    ; atom "%{profile}_transaction_snark_vk.json"
                    ]
                ; list
                    [ atom ":computed"
                    ; atom "%{profile}_transaction_snark_vk.json.computed"
                    ]
                ]
           ; "alias" @: [ atom "runtest" ]
           ; "action" @: [ "diff" @: [ atom "%{orig}"; atom "%{computed}" ] ]
           ]
      ]
    "print_transaction_snark_vk" ;

  ()

let register_transaction_snark_tests_a () =
  (* -- transaction_snark_tests (main test library) ------------------ *)
  library "transaction_snark_tests" ~path:"src/lib/transaction_snark/test"
    ~inline_tests:true ~inline_tests_deps:[ "proof_cache.json" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "base64"
      ; opam "yojson"
      ; opam "integers"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_stdlib"
      ; local "logger"
      ; local "random_oracle_input"
      ; local "pickles.backend"
      ; local "mina_base.import"
      ; local "crypto_params"
      ; local "kimchi_backend"
      ; local "with_hash"
      ; local "pickles"
      ; local "pickles_base"
      ; local "consensus"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "snarky.backendless"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "coda_genesis_ledger"
      ; local "pickles_types"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "cache_dir"
      ; local "data_hash_lib"
      ; local "mina_numbers"
      ; local "random_oracle"
      ; local "sgn"
      ; local "sgn_type"
      ; local "sexplib0"
      ; local "test_util"
      ; local "transaction_witness"
      ; local "staged_ledger_diff"
      ; local "mina_wire_types"
      ; local "block_time"
      ; local "zkapps_examples"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_snarky"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_sexp_conv"
         ] ) ;

  (* -- constraint_count --------------------------------------------- *)
  file_stanzas ~path:"src/lib/transaction_snark/test/constraint_count"
    [ "tests"
      @: [ "names" @: [ atom "test_constraint_count" ]
         ; "libraries"
           @: [ atom "alcotest"
              ; atom "core_kernel"
              ; atom "genesis_constants"
              ; atom "mina_signature_kind"
              ; atom "node_config"
              ; atom "snark_params"
              ; atom "transaction_snark"
              ]
         ; "preprocess" @: [ "pps" @: [ atom "ppx_jane" ] ]
         ]
    ] ;

  (* -- access_permission -------------------------------------------- *)
  private_library "transaction_snark_tests_access_permission"
    ~path:"src/lib/transaction_snark/test/access_permission" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "ppx_inline_test.config"
      ; opam "sexplib0"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "cache_dir"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "pasta_bindings"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_ledger"
      ; local "mina_numbers"
      ; local "mina_state"
      ; local "mina_transaction_logic"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "random_oracle_input"
      ; local "random_oracle"
      ; local "sgn"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "transaction_protocol_state"
      ; local "transaction_snark"
      ; local "transaction_snark_tests"
      ; local "with_hash"
      ; local "zkapps_empty_update"
      ; local "zkapps_examples"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane"; "ppx_sexp_conv" ]) ;

  (* -- account_timing ----------------------------------------------- *)
  private_library "account_timing_tests"
    ~path:"src/lib/transaction_snark/test/account_timing" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "yojson"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "data_hash_lib"
      ; local "coda_genesis_proof"
      ; local "mina_stdlib"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction"
      ; local "mina_compile_config"
      ; local "precomputed_values"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "random_oracle"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "with_hash"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "test_util"
      ; local "consensus"
      ; local "one_or_two"
      ; local "coda_genesis_ledger"
      ; local "snarky.backendless"
      ; local "mina_transaction_logic"
      ; local "mina_wire_types"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- account_update_network_id ------------------------------------ *)
  private_library "account_update_network_id"
    ~path:"src/lib/transaction_snark/test/account_update_network_id"
    ~inline_tests:true ~inline_tests_bare:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "sexplib0"
      ; local "logger"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "mina_signature_kind"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "test_util"
      ; local "mina_transaction_logic"
      ; local "mina_transaction"
      ; local "mina_stdlib"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane"; "ppx_mina" ]) ;

  ()

let register_transaction_snark_tests_b () =
  (* -- app_state ---------------------------------------------------- *)
  private_library "app_state_tests"
    ~path:"src/lib/transaction_snark/test/app_state" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- delegate ----------------------------------------------------- *)
  private_library "delegate_tests"
    ~path:"src/lib/transaction_snark/test/delegate" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "currency"
      ; local "mina_state"
      ; local "mina_transaction_logic"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- fee_payer ---------------------------------------------------- *)
  private_library "fee_payer_tests"
    ~path:"src/lib/transaction_snark/test/fee_payer" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "sexplib0"
      ; opam "integers"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- multisig_account --------------------------------------------- *)
  private_library "multisig_tests"
    ~path:"src/lib/transaction_snark/test/multisig_account" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_wire_types"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_base"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "kimchi_backend_common"
      ; local "kimchi_backend"
      ; local "cache_dir"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "crypto_params"
      ; local "snarky.backendless"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "currency"
      ; local "mina_state"
      ; local "mina_transaction_logic"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "with_hash"
      ; local "data_hash_lib"
      ; local "mina_stdlib"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- permissions -------------------------------------------------- *)
  private_library "permissions_tests"
    ~path:"src/lib/transaction_snark/test/permissions" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- token_symbol ------------------------------------------------- *)
  private_library "token_symbol_tests"
    ~path:"src/lib/transaction_snark/test/token_symbol" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_stdlib"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  ()

let register_transaction_snark_tests_c () =
  (* -- transaction_union -------------------------------------------- *)
  private_library "transaction_union_tests"
    ~path:"src/lib/transaction_snark/test/transaction_union" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; local "mina_base.import"
      ; local "mina_stdlib"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "data_hash_lib"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "test_util"
      ; local "consensus"
      ; local "one_or_two"
      ; local "coda_genesis_ledger"
      ; local "sexplib0"
      ; local "quickcheck_lib"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "staged_ledger_diff"
      ; local "mina_wire_types"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- verification_key --------------------------------------------- *)
  private_library "verification_key_tests"
    ~path:"src/lib/transaction_snark/test/verification_key" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "pickles"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "mina_transaction_logic"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "with_hash"
      ; local "random_oracle"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- verification_key_permission ---------------------------------- *)
  private_library "verification_key_permission_tests"
    ~path:"src/lib/transaction_snark/test/verification_key_permission"
    ~inline_tests:true ~inline_tests_deps:[ "proof_cache.json" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "protocol_version"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- verify-simple-test ------------------------------------------- *)
  private_library "transaction_snark_tests_verify_simple_test"
    ~path:"src/lib/transaction_snark/test/verify-simple-test" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "base64"
      ; opam "yojson"
      ; local "random_oracle_input"
      ; local "pickles.backend"
      ; local "mina_base.import"
      ; local "crypto_params"
      ; local "kimchi_backend"
      ; local "with_hash"
      ; local "pickles"
      ; local "pickles_base"
      ; local "consensus"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "snarky.backendless"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "coda_genesis_ledger"
      ; local "pickles_types"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "cache_dir"
      ; local "data_hash_lib"
      ; local "mina_numbers"
      ; local "random_oracle"
      ; local "sgn"
      ; local "sgn_type"
      ; local "sexplib0"
      ; local "test_util"
      ; local "transaction_witness"
      ; local "staged_ledger_diff"
      ; local "mina_wire_types"
      ; local "block_time"
      ]
    ~ppx:
      (Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane"; "ppx_sexp_conv" ]) ;

  (* -- voting_for --------------------------------------------------- *)
  private_library "voting_for_tests"
    ~path:"src/lib/transaction_snark/test/voting_for" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "pickles"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "with_hash"
      ; local "random_oracle"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  ()

let register_transaction_snark_tests_d () =
  (* -- zkapp_deploy ------------------------------------------------- *)
  private_library "zkapp_deploy_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_deploy" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- zkapp_fuzzy (executable) ------------------------------------- *)
  private_executable ~path:"src/lib/transaction_snark/test/zkapp_fuzzy"
    ~link_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "async.async_command"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "splittable_random"
      ; local "logger"
      ; local "mina_base.import"
      ; local "data_hash_lib"
      ; local "mina_generators"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "test_util"
      ; local "mina_transaction_logic"
      ; local "with_hash"
      ; local "random_oracle"
      ; local "sexplib0"
      ; local "zkapp_command_builder"
      ; local "mina_stdlib"
      ]
    ~ppx:(Ppx.custom [ "ppx_mina"; "ppx_snarky"; "ppx_version"; "ppx_jane" ])
    "zkapp_fuzzy" ;

  (* -- zkapp_payments ----------------------------------------------- *)
  private_library "zkapp_payments_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_payments" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "sexplib0"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "logger"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "test_util"
      ; local "mina_transaction_logic"
      ; local "mina_transaction"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane"; "ppx_mina" ]) ;

  (* -- zkapp_preconditions ------------------------------------------ *)
  private_library "account_update_precondition_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_preconditions"
    ~inline_tests:true ~inline_tests_deps:[ "proof_cache.json" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "data_hash_lib"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "kimchi_backend"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "transaction_snark"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_generators"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "zkapp_command_builder"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  (* -- zkapp_tokens ------------------------------------------------- *)
  private_library "zkapp_tokens_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_tokens" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "transaction_snark"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_generators"
      ; local "currency"
      ; local "pickles"
      ; local "mina_numbers"
      ; local "zkapp_command_builder"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ; local "test_util"
      ; local "mina_transaction_logic"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane"; "ppx_mina" ]) ;

  (* -- zkapp_uri ---------------------------------------------------- *)
  private_library "zkapp_uri_tests"
    ~path:"src/lib/transaction_snark/test/zkapp_uri" ~inline_tests:true
    ~inline_tests_deps:[ "proof_cache.json" ] ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "ppx_inline_test.config"
      ; opam "async_unix"
      ; opam "async"
      ; opam "core"
      ; opam "base"
      ; opam "core_kernel"
      ; opam "yojson"
      ; opam "ppx_deriving_yojson.runtime"
      ; opam "result"
      ; local "mina_base.import"
      ; local "pickles"
      ; local "transaction_snark"
      ; local "mina_stdlib"
      ; local "snark_params"
      ; local "mina_ledger"
      ; local "mina_base"
      ; local "mina_transaction_logic"
      ; local "currency"
      ; local "mina_state"
      ; local "signature_lib"
      ; local "genesis_constants"
      ; local "transaction_protocol_state"
      ; local "pickles_types"
      ; local "mina_numbers"
      ; local "sgn"
      ; local "transaction_snark_tests"
      ]
    ~ppx:(Ppx.custom [ "ppx_snarky"; "ppx_version"; "ppx_jane" ]) ;

  ()

let register () =
  register_protocol () ;
  register_transaction_snark () ;
  register_transaction_snark_tests_a () ;
  register_transaction_snark_tests_b () ;
  register_transaction_snark_tests_c () ;
  register_transaction_snark_tests_d () ;
  ()
