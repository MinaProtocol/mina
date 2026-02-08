(** Mina ledger layer: Merkle trees, ledger implementations, and masks.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let sparse_ledger_lib =
  library "sparse_ledger_lib" ~path:"src/lib/sparse_ledger_lib"
    ~inline_tests:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ base
      ; base_caml
      ; bin_prot_shape
      ; core_kernel
      ; ppx_inline_test_config
      ; ppx_version_runtime
      ; result
      ; sexplib0
      ; Layer_base.mina_stdlib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"sparse Ledger implementation"

let merkle_address =
  library "merkle_address" ~path:"src/lib/merkle_address" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; bitstring
      ; core_kernel
      ; ppx_inline_test_config
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_ppx.ppx_version_runtime
      ; Layer_test.test_util
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_bitstring
         ] )
    ~synopsis:"Address for merkle database representations"

let merkle_list_prover =
  library "merkle_list_prover" ~path:"src/lib/merkle_list_prover"
    ~deps:[ core_kernel ] ~ppx:Ppx.standard

let merkle_list_verifier =
  library "merkle_list_verifier" ~path:"src/lib/merkle_list_verifier"
    ~deps:[ core_kernel; Layer_base.mina_stdlib ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version; Ppx_lib.ppx_jane; Ppx_lib.ppx_compare ] )

let merkle_ledger =
  library "merkle_ledger" ~path:"src/lib/merkle_ledger"
    ~flags:[ list [ atom ":standard"; atom "-warn-error"; atom "+a" ] ]
    ~library_flags:[ "-linkall" ]
    ~modules_without_implementation:[ "location_intf" ]
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; bitstring
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; integers
      ; merkle_address
      ; rocks
      ; sexplib0
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_stdlib_unix
      ; Layer_base.visualization
      ; Layer_ppx.ppx_version_runtime
      ; Layer_storage.cache_dir
      ; Layer_storage.key_value_database
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ] )
    ~synopsis:"Implementation of different account databases"

let merkle_ledger_tests =
  library "merkle_ledger_tests" ~path:"src/lib/merkle_ledger/test"
    ~flags:[ list [ atom ":standard"; atom "-warn-error"; atom "+a" ] ]
    ~modules_exclude:[ "test" ]
    ~deps:
      [ alcotest
      ; async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; merkle_address
      ; merkle_ledger
      ; result
      ; sexplib0
      ; Layer_base.base58_check
      ; Layer_base.codable
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_crypto.signature_lib
      ; Layer_domain.data_hash_lib
      ; Layer_ppx.ppx_version_runtime
      ; Layer_storage.key_value_database
      ; local "merkle_mask"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let () =
  test "test" ~package:"merkle_ledger_tests" ~path:"src/lib/merkle_ledger/test"
    ~modules:[ "test" ]
    ~flags:[ list [ atom ":standard"; atom "-warn-error"; atom "+a" ] ]
    ~deps:[ alcotest; merkle_ledger_tests ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ] )

let merkle_mask =
  library "merkle_mask" ~path:"src/lib/merkle_mask"
    ~flags:
      [ list
          [ atom ":standard"
          ; atom "-w"
          ; atom "+a-40..42-44"
          ; atom "-warn-error"
          ; atom "+a"
          ]
      ]
    ~library_flags:[ "-linkall" ]
    ~modules_without_implementation:
      [ "base_merkle_tree_intf"
      ; "inputs_intf"
      ; "mask_maps_intf"
      ; "maskable_merkle_tree_intf"
      ; "masking_merkle_tree_intf"
      ]
    ~deps:
      [ async
      ; async_kernel
      ; base_caml
      ; base_internalhash_types
      ; bitstring
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; core_uuid
      ; integers
      ; merkle_ledger
      ; sexplib0
      ; stdio
      ; yojson
      ; Layer_base.mina_stdlib
      ; Layer_base.visualization
      ; Layer_logging.logger
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )
    ~synopsis:"Implementation of Merkle tree masks"

let mina_ledger =
  library "mina_ledger" ~path:"src/lib/mina_ledger" ~inline_tests:true
    ~deps:
      [ async
      ; async_kernel
      ; base
      ; base_caml
      ; base_internalhash_types
      ; bin_prot_shape
      ; core
      ; core_kernel
      ; core_kernel_uuid
      ; integers
      ; merkle_address
      ; merkle_ledger
      ; merkle_mask
      ; ppx_inline_test_config
      ; rocks
      ; sexplib0
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_crypto.random_oracle
      ; Layer_crypto.sgn
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.data_hash_lib
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_backend
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.o1trace
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ; Layer_ppx.ppx_version_runtime
      ; Layer_storage.key_value_database
      ; Layer_storage.rocksdb
      ; Layer_test.quickcheck_lib
      ; Snarky_lib.snarky_backendless
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "syncable_ledger"
      ; local "zkapp_command_builder"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_version
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_mina
         ] )

let mina_ledger_test_helpers =
  private_library "mina_ledger_test_helpers"
    ~path:"src/lib/mina_ledger/test/helpers"
    ~deps:
      [ base
      ; base_caml
      ; core
      ; core_kernel
      ; integers
      ; mina_ledger
      ; sexplib0
      ; yojson
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_numbers
      ; Layer_base.monad_lib
      ; Layer_crypto.signature_lib
      ; Layer_domain.mina_base_test_helpers
      ; Layer_kimchi.kimchi_backend_common
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_pickles.pickles_types
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_version
         ] )

let staged_ledger_diff =
  library "staged_ledger_diff" ~path:"src/lib/staged_ledger_diff"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base_caml
      ; bin_prot_shape
      ; blake2
      ; core_kernel
      ; ppx_inline_test_config
      ; sexplib0
      ; splittable_random
      ; stdint
      ; stdio
      ; Layer_base.allocation_functor
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_ppx.ppx_version_runtime
      ; local "consensus"
      ; local "transaction_snark_work"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppx_deriving_std
         ; Ppx_lib.ppx_deriving_yojson
         ] )
