(** Mina snark worker layer: snark work processing, ledger proofs, scan state.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let ledger_proof =
  library "ledger_proof" ~path:"src/lib/ledger_proof"
    ~deps:
      [ core_kernel
      ; Layer_base.mina_base
      ; Layer_consensus.mina_state
      ; Layer_domain.proof_carrying_data
      ; Layer_pickles.proof_cache_tag
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.transaction_snark
      ; Layer_transaction.mina_transaction_logic
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
      [ base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; ledger_proof
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.transaction_snark
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
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; digestif
      ; ledger_proof
      ; ppx_deriving_yojson_runtime
      ; sexplib0
      ; transaction_snark_work
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.with_hash
      ; Layer_consensus.mina_state
      ; Layer_crypto.sgn
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_domain.parallel_scan
      ; Layer_ledger.merkle_ledger
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.transaction_snark
      ; Layer_tooling.internal_tracing
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.mina_transaction_logic
      ; Layer_transaction.transaction_witness
      ; local "snark_work_lib"
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
      ; ledger_proof
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_ppx.ppx_version_runtime
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
      ; async_kernel
      ; async_rpc
      ; async_rpc_kernel
      ; async_unix
      ; base
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; core_kernel_hash_heap
      ; ledger_proof
      ; ppx_hash_runtime_lib
      ; ppx_version_runtime
      ; result
      ; sexplib0
      ; snark_work_lib
      ; transaction_snark_work
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_stdlib
      ; Layer_base.one_or_two
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.genesis_constants
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.logger_file_system
      ; Layer_node.mina_node_config_unconfigurable_constants
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_tooling.mina_metrics
      ; Layer_tooling.perf_histograms
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.transaction_witness
      ; local "cli_lib"
      ; local "work_partitioner"
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
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; ledger_proof
      ; ppx_inline_test_config
      ; sexplib0
      ; snark_work_lib
      ; transaction_snark_work
      ; Layer_base.currency
      ; Layer_base.error_json
      ; Layer_base.mina_base
      ; Layer_base.one_or_two
      ; Layer_base.with_hash
      ; Layer_concurrency.pipe_lib
      ; Layer_consensus.mina_state
      ; Layer_consensus.precomputed_values
      ; Layer_ledger.mina_ledger
      ; Layer_logging.logger
      ; Layer_logging.o1trace
      ; Layer_ppx.ppx_version_runtime
      ; Layer_protocol.transaction_protocol_state
      ; Layer_protocol.transaction_snark
      ; Layer_tooling.mina_metrics
      ; Layer_transaction.mina_transaction
      ; Layer_transaction.transaction_witness
      ; local "network_pool"
      ; local "staged_ledger"
      ; local "transition_frontier"
      ; local "transition_frontier_base"
      ; local "transition_frontier_extensions"
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
      ; snark_work_lib
      ; work_selector
      ; Layer_base.mina_base
      ; Layer_protocol.transaction_snark
      ; Layer_transaction.transaction_witness
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
