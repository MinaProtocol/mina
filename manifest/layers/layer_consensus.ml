(** Mina consensus layer: state, consensus mechanisms, VRF, genesis ledger/proof.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

(* -- vrf_lib -------------------------------------------------------------- *)
let vrf_lib =
  library "vrf_lib" ~path:"src/lib/vrf_lib"
  ~flags:[ atom ":standard"; atom "-short-paths" ]
  ~library_flags:[ "-linkall" ]
  ~deps:
    [ zarith
    ; bignum_bigint
    ; bin_prot_shape
    ; base_caml
    ; core
    ; sexplib0
    ; core_kernel
    ; bignum
    ; ppx_inline_test_config
    ; local "snarky.backendless"
    ; Layer_domain.genesis_constants
    ; local "snarky_curves"
    ; local "bitstring_lib"
    ; Layer_ppx.ppx_version_runtime
    ]
  ~ppx:
    (Ppx.custom
       [ Ppx_lib.h_list_ppx; Ppx_lib.ppx_bench; Ppx_lib.ppx_compare; Ppx_lib.ppx_jane; Ppx_lib.ppx_version ] )
  ~synopsis:"VRF instantiation"

(* -- consensus_vrf -------------------------------------------------------- *)
let consensus_vrf =
  library "consensus.vrf" ~internal_name:"consensus_vrf"
  ~path:"src/lib/consensus/vrf"
  ~deps:
    [ ppx_inline_test_config
    ; bignum_bigint
    ; base_caml
    ; base
    ; base64
    ; core_kernel
    ; sexplib0
    ; result
    ; bignum
    ; integers
    ; bin_prot_shape
    ; Layer_base.mina_wire_types
    ; Layer_base.mina_base_util
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_domain.genesis_constants
    ; Layer_base.mina_stdlib
    ; Layer_crypto.crypto_params
    ; Layer_crypto.random_oracle
    ; Layer_crypto.blake2
    ; Layer_base.base58_check
    ; Layer_crypto.random_oracle_input
    ; Layer_base.unsigned_extended
    ; local "snarky.backendless"
    ; Layer_crypto.pickles
    ; local "snarky_taylor"
    ; Layer_infra.mina_numbers
    ; local "fold_lib"
    ; Layer_base.mina_base
    ; Layer_crypto.snark_params
    ; vrf_lib
    ; local "snarky_integer"
    ; Layer_test.test_util
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.non_zero_curve_point
    ; Layer_crypto.bignum_bigint
    ; Layer_base.codable
    ; Layer_crypto.signature_lib
    ; Layer_base.currency
    ; Layer_domain.hash_prefix_states
    ; Layer_crypto.kimchi_backend
    ; local "kimchi_bindings"
    ; local "kimchi_types"
    ; local "pasta_bindings"
    ; local "ppx_deriving_yojson.runtime"
    ; Layer_ppx.ppx_version_runtime
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

(* -- consensus ------------------------------------------------------------ *)
let consensus =
  library "consensus" ~path:"src/lib/consensus" ~inline_tests:true
  ~library_flags:[ "-linkall" ]
  ~modules_exclude:[ "proof_of_stake_fuzzer" ]
  ~deps:
    [ ppx_inline_test_config
    ; async_unix
    ; core_uuid
    ; async_kernel
    ; sexplib0
    ; base_caml
    ; integers
    ; async
    ; core
    ; yojson
    ; core_kernel
    ; bin_prot_shape
    ; base
    ; result
    ; core_kernel_uuid
    ; async_rpc_kernel
    ; sexp_diff_kernel
    ; Layer_base.mina_wire_types
    ; Layer_base.mina_base_util
    ; Layer_base.unsigned_extended
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; local "fold_lib"
    ; Layer_crypto.random_oracle_input
    ; Layer_crypto.outside_hash_image
    ; Layer_infra.logger
    ; Layer_domain.hash_prefix_states
    ; Layer_domain.genesis_constants
    ; Layer_base.error_json
    ; Layer_ledger.merkle_ledger
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.random_oracle
    ; Layer_base.pipe_lib
    ; Layer_crypto.bignum_bigint
    ; vrf_lib
    ; Layer_crypto.snark_params
    ; Layer_base.with_hash
    ; Layer_ledger.mina_ledger
    ; consensus_vrf
    ; local "snarky_taylor"
    ; Layer_base.mina_base
    ; Layer_transaction.mina_transaction_logic
    ; Layer_crypto.key_gen
    ; Layer_domain.block_time
    ; Layer_base.perf_histograms
    ; Layer_test.test_util
    ; Layer_crypto.non_zero_curve_point
    ; Layer_tooling.mina_metrics
    ; Layer_infra.mina_numbers
    ; Layer_base.mina_stdlib
    ; Layer_crypto.signature_lib
    ; local "snarky.backendless"
    ; Layer_crypto.blake2
    ; Layer_crypto.crypto_params
    ; Layer_domain.data_hash_lib
    ; Layer_base.currency
    ; Layer_infra.mina_stdlib_unix
    ; local "coda_genesis_ledger"

    ; Layer_concurrency.interruptible
    ; Layer_domain.network_peer
    ; Layer_crypto.pickles
    ; Layer_snarky.snark_bits
    ; Layer_ledger.sparse_ledger_lib
    ; local "syncable_ledger"
    ; Layer_infra.trust_system
    ; Layer_base.mina_base_import
    ; Layer_ppx.ppx_version_runtime
    ; Layer_tooling.internal_tracing
    ; Layer_infra.o1trace
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

(* -- consensus: proof_of_stake_fuzzer (disabled executable) --------------- *)
let () =
  private_executable ~path:"src/lib/consensus"
  ~modules:[ "proof_of_stake_fuzzer" ]
  ~deps:
    [ core_kernel
    ; Layer_crypto.signature_lib
    ; local "mina_state"

    ; local "mina_block"
    ; consensus
    ; local "prover"
    ; local "blockchain_snark"
    ; Layer_infra.logger_file_system
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane ])
  ~enabled_if:"false" "proof_of_stake_fuzzer"

(* -- mina_state ----------------------------------------------------------- *)
let mina_state =
  library "mina_state" ~path:"src/lib/mina_state" ~inline_tests:true
  ~deps:
    [ core
    ; Layer_crypto.signature_lib
    ; Layer_crypto.pickles_backend
    ; Layer_crypto.outside_hash_image
    ; Layer_crypto.pickles
    ; Layer_crypto.random_oracle_input
    ; Layer_crypto.random_oracle
    ; Layer_domain.genesis_constants
    ; Layer_domain.block_time
    ; Layer_base.mina_base
    ; local "mina_debug"
    ; Layer_transaction.mina_transaction_logic
    ; Layer_crypto.snark_params
    ; consensus
    ; local "bitstring_lib"
    ; local "fold_lib"
    ; local "tuple_lib"
    ; Layer_base.with_hash
    ; local "snarky.backendless"
    ; Layer_crypto.crypto_params
    ; Layer_domain.data_hash_lib
    ; Layer_base.currency
    ; Layer_base.visualization
    ; Layer_base.linked_tree
    ; Layer_infra.mina_numbers
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ; Layer_crypto.kimchi_backend
    ; Layer_base.mina_base_util
    ; Layer_ledger.mina_ledger
    ; Layer_base.unsigned_extended
    ; Layer_crypto.sgn
    ; Layer_base.sgn_type
    ; Layer_crypto.blake2
    ; Layer_ppx.ppx_version_runtime
    ; Layer_base.mina_wire_types
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

(* -- coda_genesis_ledger -------------------------------------------------- *)
let coda_genesis_ledger =
  library "coda_genesis_ledger" ~internal_name:"genesis_ledger"
  ~path:"src/lib/genesis_ledger"
  ~deps:
    [ core
    ; Layer_crypto.key_gen
    ; Layer_base.mina_base
    ; Layer_crypto.signature_lib
    ; Layer_base.currency
    ; Layer_infra.mina_numbers
    ; Layer_domain.genesis_constants
    ; Layer_domain.data_hash_lib
    ; Layer_ledger.mina_ledger
    ; Layer_base.mina_stdlib
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_let ])

(* -- precomputed_values --------------------------------------------------- *)
let precomputed_values =
  library "precomputed_values" ~path:"src/lib/precomputed_values"
  ~ppx_runtime_libraries:[ "base" ]
  ~deps:
    [ core
    ; core_kernel
    ; Layer_domain.genesis_constants
    ; mina_state
    ; local "coda_genesis_proof"

    ; Layer_crypto.crypto_params
    ; Layer_base.mina_base
    ; Layer_domain.dummy_values
    ; local "snarky.backendless"
    ; coda_genesis_ledger
    ; consensus
    ; local "mina_runtime_config"
    ; local "test_genesis_ledger"
    ; Layer_ledger.staged_ledger_diff
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppxlib_metaquot ])

(* -- coda_genesis_proof --------------------------------------------------- *)
let coda_genesis_proof =
  library "coda_genesis_proof" ~internal_name:"genesis_proof"
  ~path:"src/lib/genesis_proof"
  ~deps:
    [ base
    ; core_kernel
    ; base_md5
    ; core
    ; async
    ; async_kernel
    ; local "snarky.backendless"
    ; Layer_crypto.pickles_types
    ; Layer_base.currency
    ; Layer_crypto.pickles
    ; consensus
    ; local "mina_runtime_config"
    ; local "blockchain_snark"
    ; Layer_base.mina_base
    ; mina_state
    ; Layer_domain.genesis_constants
    ; Layer_base.with_hash
    ; coda_genesis_ledger
    ; local "transaction_snark"
    ; Layer_crypto.sgn
    ; Layer_crypto.snark_params
    ; Layer_base.mina_wire_types
    ; Layer_base.sgn_type
    ; Layer_crypto.pickles_backend
    ; Layer_transaction.mina_transaction_logic
    ; Layer_crypto.kimchi_backend
    ; Layer_infra.mina_numbers
    ; Layer_domain.block_time
    ; Layer_crypto.kimchi_pasta
    ; Layer_crypto.kimchi_pasta_basic
    ]
  ~ppx:(Ppx.custom [ Ppx_lib.ppx_version; Ppx_lib.ppx_let ])
