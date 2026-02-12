(** Mina consensus layer: state, consensus mechanisms, VRF, genesis ledger/proof.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let vrf_lib =
  library "vrf_lib" ~path:"src/lib/vrf_lib"
    ~flags:[ atom ":standard"; atom "-short-paths" ]
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ base_caml
      ; bignum
      ; bignum_bigint
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; ppx_inline_test_config
      ; sexplib0
      ; zarith
      ; Layer_domain.genesis_constants
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snarky_curves
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.snarky_backendless
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_bench
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"VRF instantiation"

let consensus_vrf =
  library "consensus.vrf" ~internal_name:"consensus_vrf"
    ~path:"src/lib/consensus/vrf"
    ~deps:
      [ base
      ; base64
      ; base_caml
      ; bignum
      ; bignum_bigint
      ; bin_prot_shape
      ; core_kernel
      ; integers
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; vrf_lib
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_util
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_crypto.bignum_bigint
      ; Layer_crypto.blake2
      ; Layer_crypto.crypto_params
      ; Layer_crypto.non_zero_curve_point
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.genesis_constants
      ; Layer_domain.hash_prefix_states
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snarky_taylor
      ; Layer_test.test_util
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.snarky_integer
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "ppx_deriving_yojson.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )

let consensus =
  library "consensus" ~path:"src/lib/consensus" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~modules_exclude:[ "proof_of_stake_fuzzer" ]
    ~deps:
      [ async
      ; async_kernel
      ; async_rpc_kernel
      ; async_unix
      ; base
      ; base_caml
      ; bin_prot_shape
      ; consensus_vrf
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; integers
      ; ppx_inline_test_config
      ; result
      ; sexp_diff_kernel
      ; sexplib0
      ; vrf_lib
      ; yojson
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_base_util
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_concurrency.interruptible
      ; Layer_concurrency.pipe_lib
      ; Layer_crypto.bignum_bigint
      ; Layer_crypto.blake2
      ; Layer_crypto.crypto_params
      ; Layer_crypto.key_gen
      ; Layer_crypto.non_zero_curve_point
      ; Layer_crypto.outside_hash_image
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.hash_prefix_states
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.sparse_ledger_lib
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; Layer_snarky.snark_bits
      ; Layer_snarky.snarky_taylor
      ; Layer_test.test_util
      ; Layer_tooling.internal_tracing
      ; Layer_tooling.mina_metrics
      ; Layer_tooling.perf_histograms
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; local "coda_genesis_ledger"
      ; local "network_peer"
      ; local "syncable_ledger"
      ; local "trust_system"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Consensus mechanisms"

let () =
  private_executable ~path:"src/lib/consensus"
    ~modules:[ "proof_of_stake_fuzzer" ]
    ~deps:
      [ consensus
      ; core_kernel
      ; Layer_crypto.signature_lib
      ; Layer_logging.logger_file_system
      ; local "blockchain_snark"
      ; local "mina_block"
      ; local "mina_state"
      ; local "prover"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])
    ~enabled_if:"false" "proof_of_stake_fuzzer"

let mina_state =
  library "mina_state" ~path:"src/lib/mina_state" ~inline_tests:true
    ~deps:
      [ consensus
      ; core
      ; Layer_base.currency
      ; Layer_base.linked_tree
      ; Layer_base.mina_base
      ; Layer_base.mina_base_util
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.sgn_type
      ; Layer_base.unsigned_extended
      ; Layer_base.visualization
      ; Layer_base.with_hash
      ; Layer_crypto.blake2
      ; Layer_crypto.crypto_params
      ; Layer_crypto.outside_hash_image
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_ledger.mina_ledger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.bitstring_lib
      ; Snarky_lib.fold_lib
      ; Snarky_lib.snarky_backendless
      ; Snarky_lib.tuple_lib
      ; local "mina_debug"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_snarky
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.h_list_ppx
         ] )

let coda_genesis_ledger =
  library "coda_genesis_ledger" ~internal_name:"genesis_ledger"
    ~path:"src/lib/genesis_ledger"
    ~deps:
      [ core
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_crypto.key_gen
      ; Layer_crypto.signature_lib
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_ledger.mina_ledger
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_let ])

let precomputed_values =
  library "precomputed_values" ~path:"src/lib/precomputed_values"
    ~ppx_runtime_libraries:[ "base" ]
    ~deps:
      [ coda_genesis_ledger
      ; consensus
      ; core
      ; core_kernel
      ; mina_state
      ; Layer_base.mina_base
      ; Layer_crypto.crypto_params
      ; Layer_domain.dummy_values
      ; Layer_domain.genesis_constants
      ; Layer_ledger.staged_ledger_diff
      ; Snarky_lib.snarky_backendless
      ; local "coda_genesis_proof"
      ; local "mina_runtime_config"
      ; local "test_genesis_ledger"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppxlib_metaquot ] )

let coda_genesis_proof =
  library "coda_genesis_proof" ~internal_name:"genesis_proof"
    ~path:"src/lib/genesis_proof"
    ~deps:
      [ async
      ; async_kernel
      ; base
      ; base_md5
      ; coda_genesis_ledger
      ; consensus
      ; core
      ; core_kernel
      ; mina_state
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.sgn_type
      ; Layer_base.with_hash
      ; Layer_crypto.sgn
      ; Layer_crypto.snark_params
      ; Layer_domain.block_time
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_transaction.mina_transaction_logic
      ; Snarky_lib.snarky_backendless
      ; local "blockchain_snark"
      ; local "mina_runtime_config"
      ; local "transaction_snark"
      ]
    ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_let ])
