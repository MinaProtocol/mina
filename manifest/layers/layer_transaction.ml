(** Mina transaction layer: transaction types, logic, witnesses, and scan state.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let register () =
  (* -- mina_transaction --------------------------------------------- *)
  library "mina_transaction" ~path:"src/lib/transaction" ~inline_tests:true
    ~deps:
      [ base_caml
      ; base
      ; base_internalhash_types
      ; bin_prot_shape
      ; core_kernel
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; base64
      ; local "base58_check"
      ; local "blake2"
      ; local "codable"
      ; local "currency"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_numbers"
      ; local "one_or_two"
      ; local "pickles"
      ; local "random_oracle"
      ; local "signature_lib"
      ; local "sgn"
      ; local "snark_params"
      ; local "snarky.backendless"
      ; local "ppx_version.runtime"
      ; local "with_hash"
      ; local "mina_wire_types"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_mina"
         ; "ppx_inline_test"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_hash"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  (* -- mina_transaction_logic --------------------------------------- *)
  library "mina_transaction_logic" ~path:"src/lib/transaction_logic"
    ~deps:
      [ async_kernel
      ; result
      ; bin_prot_shape
      ; ppx_inline_test_config
      ; sexplib0
      ; yojson
      ; sexp_diff_kernel
      ; core_kernel
      ; base_caml
      ; base
      ; base_internalhash_types
      ; integers
      ; base_quickcheck
      ; local "mina_stdlib"
      ; local "mina_wire_types"
      ; local "block_time"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "kimchi_bindings"
      ; local "kimchi_types"
      ; local "pasta_bindings"
      ; local "kimchi_backend_common"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_numbers"
      ; local "mina_transaction"
      ; local "one_or_two"
      ; local "pickles_types"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "signature_lib"
      ; local "sgn"
      ; local "snarky.backendless"
      ; local "snark_params"
      ; local "unsigned_extended"
      ; local "ppx_version.runtime"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_assert"
         ; "ppx_compare"
         ; "ppx_custom_printf"
         ; "ppx_deriving_yojson"
         ; "ppx_fields_conv"
         ; "ppx_let"
         ; "ppx_hash"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] ) ;

  (* -- transaction_logic_tests -------------------------------------- *)
  private_library "transaction_logic_tests"
    ~path:"src/lib/transaction_logic/test" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ async_kernel
      ; async_unix
      ; base
      ; base_internalhash_types
      ; core
      ; core_kernel
      ; integers
      ; ppx_inline_test_config
      ; sexplib0
      ; yojson
      ; local "currency"
      ; local "data_hash_lib"
      ; local "genesis_constants"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_stdlib"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_base.test_helpers"
      ; local "mina_ledger"
      ; local "mina_ledger_test_helpers"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "mina_numbers"
      ; local "mina_wire_types"
      ; local "monad_lib"
      ; local "pasta_bindings"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "random_oracle"
      ; local "sgn"
      ; local "sgn_type"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "zkapp_command_builder"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_snarky"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_sexp_conv"
         ; "ppx_inline_test"
         ; "ppx_assert"
         ] ) ;

  (* -- transaction_witness ------------------------------------------ *)
  library "transaction_witness" ~path:"src/lib/transaction_witness"
    ~inline_tests:true
    ~deps:
      [ base_caml
      ; bin_prot_shape
      ; sexplib0
      ; core_kernel
      ; core
      ; local "currency"
      ; local "signature_lib"
      ; local "mina_ledger"
      ; local "mina_state"
      ; local "mina_base"
      ; local "mina_numbers"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "sgn"
      ; local "with_hash"
      ; local "ppx_version.runtime"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_version"; "ppx_mina" ] ) ;

  (* -- transaction_snark_work --------------------------------------- *)
  library "transaction_snark_work" ~path:"src/lib/transaction_snark_work"
    ~deps:
      [ core_kernel
      ; sexplib0
      ; bin_prot_shape
      ; base_caml
      ; base_internalhash_types
      ; core
      ; local "currency"
      ; local "transaction_snark"
      ; local "mina_state"
      ; local "one_or_two"
      ; local "ledger_proof"
      ; local "signature_lib"
      ; local "ppx_version.runtime"
      ; local "mina_wire_types"
      ; local "pickles.backend"
      ; local "snark_params"
      ; local "pickles"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_version"; "ppx_compare"; "ppx_deriving_yojson" ] ) ;

  (* -- transaction_snark_scan_state --------------------------------- *)
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
      ; local "mina_stdlib"
      ; local "mina_base.import"
      ; local "data_hash_lib"
      ; local "mina_state"
      ; local "transaction_witness"
      ; local "transaction_snark"
      ; local "mina_base"
      ; local "mina_numbers"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "snark_work_lib"
      ; local "one_or_two"
      ; local "mina_ledger"
      ; local "merkle_ledger"
      ; local "currency"
      ; local "logger"
      ; local "transaction_snark_work"
      ; local "parallel_scan"
      ; local "sgn"
      ; local "ledger_proof"
      ; local "genesis_constants"
      ; local "o1trace"
      ; local "with_hash"
      ; local "ppx_version.runtime"
      ; local "mina_wire_types"
      ; local "internal_tracing"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_base"
         ; "ppx_mina"
         ; "ppx_version"
         ; "ppx_let"
         ; "ppx_sexp_conv"
         ; "ppx_bin_prot"
         ; "ppx_custom_printf"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ] )
    ~synopsis:"Transaction-snark specialization of the parallel scan state" ;

  ()
