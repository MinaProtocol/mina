(** Mina snark worker layer: snark work processing, ledger proofs, scan state.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let ledger_proof =
  library "ledger_proof" ~path:"src/lib/ledger_proof"
    ~deps:
      [ core_kernel
      ; Layer_protocol.transaction_snark
      ; Layer_base.mina_base
      ; Layer_consensus.mina_state
      ; Layer_transaction.mina_transaction_logic
      ; Layer_ppx.ppx_version_runtime
      ; Layer_crypto.proof_cache_tag
      ; Layer_domain.proof_carrying_data
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let transaction_snark_work =
  library "transaction_snark_work" ~path:"src/lib/transaction_snark_work"
    ~deps:
      [ core_kernel
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; base_internalhash_types
      ; core
      ; Layer_base.currency
      ; Layer_protocol.transaction_snark
      ; Layer_consensus.mina_state
      ; Layer_base.one_or_two
      ; ledger_proof
      ; Layer_crypto.signature_lib
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.mina_wire_types
      ; Layer_crypto.pickles_backend
      ; Layer_crypto.snark_params
      ; Layer_crypto.pickles
      ; Layer_crypto.kimchi_pasta
      ; Layer_crypto.kimchi_pasta_basic
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let transaction_snark_scan_state =
  library "transaction_snark_scan_state"
    ~path:"src/lib/transaction_snark_scan_state" ~library_flags:[ "-linkall" ]
    ~deps:
      [ base_internalhash_types
      ; async_kernel
      ; core
      ; ppx_deriving_yojson_runtime
      ; sexplib0
      ; base_caml
      ; digestif
      ; base
      ; core_kernel
      ; async
      ; yojson
      ; bin_prot_shape
      ; async_unix
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_base_import
      ; Layer_domain.data_hash_lib
      ; Layer_consensus.mina_state
      ; Layer_transaction.transaction_witness
      ; Layer_protocol.transaction_snark
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; local "snark_work_lib"
      ; Layer_base.one_or_two
      ; Layer_ledger.mina_ledger
      ; Layer_ledger.merkle_ledger
      ; Layer_base.currency
      ; Layer_infra.logger
      ; transaction_snark_work
      ; Layer_domain.parallel_scan
      ; Layer_crypto.sgn
      ; ledger_proof
      ; Layer_domain.genesis_constants
      ; Layer_infra.o1trace
      ; Layer_base.with_hash
      ; Layer_ppx.ppx_version_runtime
      ; Layer_base.mina_wire_types
      ; Layer_tooling.internal_tracing
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~synopsis:"Transaction-snark specialization of the parallel scan state"

let snark_work_lib =
  library "snark_work_lib" ~path:"src/lib/snark_work_lib" ~inline_tests:true
    ~modules_without_implementation:[ "combined_result" ]
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; sexplib0
      ; Layer_base.currency
      ; ledger_proof
      ; Layer_consensus.mina_state
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_ppx.ppx_version_runtime
      ; Layer_crypto.signature_lib
      ; Layer_protocol.transaction_snark
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Snark work types"

let snark_worker =
  library "snark_worker" ~path:"src/lib/snark_worker"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async
      ; async_command
      ; async_rpc
      ; async_kernel
      ; async_rpc_kernel
      ; async_unix
      ; base
      ; base_internalhash_types
      ; base_caml
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; core_kernel_hash_heap
      ; ppx_hash_runtime_lib
      ; ppx_version_runtime
      ; result
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; local "cli_lib"
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_domain.genesis_constants
      ; ledger_proof
      ; Layer_infra.logger
      ; Layer_infra.logger_file_system
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_ledger.mina_ledger
      ; Layer_tooling.mina_metrics
      ; Layer_node.mina_node_config_unconfigurable_constants
      ; Layer_consensus.mina_state
      ; Layer_transaction.mina_transaction
      ; Layer_base.one_or_two
      ; Layer_base.perf_histograms
      ; Layer_crypto.signature_lib
      ; snark_work_lib
      ; local "work_partitioner"
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; transaction_snark_work
      ; Layer_transaction.transaction_witness
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_register_event
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Lib powering the snark_worker interactions with the daemon"

let work_selector =
  library "work_selector" ~path:"src/lib/work_selector"
    ~library_flags:[ "-linkall" ] ~inline_tests:true
    ~deps:
      [ bin_prot_shape
      ; sexplib0
      ; core
      ; async
      ; core_kernel
      ; base
      ; base_caml
      ; base_internalhash_types
      ; async_kernel
      ; ppx_inline_test_config
      ; async_unix
      ; Layer_protocol.transaction_protocol_state
      ; transaction_snark_work
      ; local "transition_frontier_base"
      ; Layer_base.error_json
      ; ledger_proof
      ; Layer_consensus.precomputed_values
      ; Layer_transaction.transaction_witness
      ; snark_work_lib
      ; Layer_consensus.mina_state
      ; Layer_base.mina_base
      ; Layer_transaction.mina_transaction
      ; local "network_pool"
      ; local "staged_ledger"
      ; Layer_infra.logger
      ; Layer_base.currency
      ; Layer_base.one_or_two
      ; Layer_protocol.transaction_snark
      ; Layer_concurrency.pipe_lib
      ; local "transition_frontier"
      ; Layer_base.with_hash
      ; Layer_tooling.mina_metrics
      ; local "transition_frontier_extensions"
      ; Layer_ledger.mina_ledger
      ; Layer_ppx.ppx_version_runtime
      ; Layer_infra.o1trace
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~synopsis:"Selecting work to distribute"

let work_partitioner =
  library "work_partitioner" ~path:"src/lib/work_partitioner"
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async
      ; core_kernel
      ; Layer_base.mina_base
      ; snark_work_lib
      ; Layer_protocol.transaction_snark
      ; Layer_transaction.transaction_witness
      ; work_selector
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:
      "Partition work returned by Work_selector and issue them to real Snark \
       Worker"
