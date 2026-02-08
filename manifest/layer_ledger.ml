(** Mina ledger layer: Merkle trees, ledger implementations, and masks.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Dune_s_expr

let register () =
  (* -- sparse_ledger_lib -------------------------------------------- *)
  library "sparse_ledger_lib" ~path:"src/lib/sparse_ledger_lib"
    ~inline_tests:true ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base.caml"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "base"
      ; opam "ppx_inline_test.config"
      ; opam "bin_prot.shape"
      ; opam "result"
      ; opam "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_jane"; "ppx_compare"; "ppx_deriving_yojson"; "ppx_version" ] )
    ~synopsis:"sparse Ledger implementation" ;

  (* -- merkle_address ----------------------------------------------- *)
  library "merkle_address" ~path:"src/lib/merkle_address" ~inline_tests:true
    ~library_flags:[ "-linkall" ]
    ~deps:
      [ opam "base.base_internalhash_types"
      ; opam "bin_prot.shape"
      ; opam "bitstring"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "base.caml"
      ; opam "ppx_inline_test.config"
      ; local "mina_stdlib"
      ; local "ppx_version.runtime"
      ; local "test_util"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_hash"
         ; "ppx_compare"
         ; "ppx_deriving_yojson"
         ; "ppx_bitstring"
         ] )
    ~synopsis:"Address for merkle database representations" ;

  (* -- merkle_list_prover ------------------------------------------- *)
  library "merkle_list_prover" ~path:"src/lib/merkle_list_prover"
    ~deps:[ opam "core_kernel" ]
    ~ppx:Ppx.standard ;

  (* -- merkle_list_verifier ----------------------------------------- *)
  library "merkle_list_verifier" ~path:"src/lib/merkle_list_verifier"
    ~deps:[ opam "core_kernel"; local "mina_stdlib" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_jane"; "ppx_compare" ]) ;

  (* -- merkle_ledger ------------------------------------------------ *)
  library "merkle_ledger" ~path:"src/lib/merkle_ledger"
    ~flags:[ list [ atom ":standard"; atom "-warn-error"; atom "+a" ] ]
    ~library_flags:[ "-linkall" ]
    ~modules_without_implementation:[ "location_intf" ]
    ~deps:
      [ opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "bitstring"
      ; opam "core"
      ; opam "core.uuid"
      ; opam "core_kernel"
      ; opam "core_kernel.uuid"
      ; opam "integers"
      ; opam "rocks"
      ; opam "sexplib0"
      ; local "cache_dir"
      ; local "mina_stdlib"
      ; local "mina_stdlib_unix"
      ; local "key_value_database"
      ; local "merkle_address"
      ; local "ppx_version.runtime"
      ; local "visualization"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_version"
         ; "ppx_jane"
         ; "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ] )
    ~synopsis:"Implementation of different account databases" ;

  (* -- merkle_ledger_tests (library) -------------------------------- *)
  library "merkle_ledger_tests" ~path:"src/lib/merkle_ledger/test"
    ~flags:[ list [ atom ":standard"; atom "-warn-error"; atom "+a" ] ]
    ~modules_exclude:[ "test" ]
    ~deps:
      [ opam "alcotest"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "bin_prot.shape"
      ; opam "core"
      ; opam "core.uuid"
      ; opam "core_kernel"
      ; opam "core_kernel.uuid"
      ; opam "result"
      ; opam "sexplib0"
      ; local "base58_check"
      ; local "codable"
      ; local "currency"
      ; local "data_hash_lib"
      ; local "key_value_database"
      ; local "merkle_address"
      ; local "merkle_ledger"
      ; local "merkle_mask"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_numbers"
      ; local "mina_stdlib"
      ; local "ppx_version.runtime"
      ; local "signature_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ] ) ;

  (* -- merkle_ledger test (test stanza) ----------------------------- *)
  test "test" ~package:"merkle_ledger_tests" ~path:"src/lib/merkle_ledger/test"
    ~modules:[ "test" ]
    ~flags:[ list [ atom ":standard"; atom "-warn-error"; atom "+a" ] ]
    ~deps:[ opam "alcotest"; local "merkle_ledger_tests" ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_jane"
         ; "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ] ) ;

  (* -- merkle_mask -------------------------------------------------- *)
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
      [ opam "async"
      ; opam "async_kernel"
      ; opam "base.base_internalhash_types"
      ; opam "base.caml"
      ; opam "bitstring"
      ; opam "core"
      ; opam "core.uuid"
      ; opam "core_kernel"
      ; opam "core_kernel.uuid"
      ; opam "integers"
      ; opam "sexplib0"
      ; opam "stdio"
      ; opam "yojson"
      ; local "mina_stdlib"
      ; local "logger"
      ; local "merkle_ledger"
      ; local "visualization"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ; "ppx_jane"
         ; "ppx_mina"
         ; "ppx_version"
         ] )
    ~synopsis:"Implementation of Merkle tree masks" ;

  (* -- mina_ledger -------------------------------------------------- *)
  library "mina_ledger" ~path:"src/lib/mina_ledger" ~inline_tests:true
    ~deps:
      [ opam "rocks"
      ; opam "integers"
      ; opam "async_kernel"
      ; opam "base.caml"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "sexplib0"
      ; opam "bin_prot.shape"
      ; opam "base.base_internalhash_types"
      ; opam "async"
      ; opam "core_kernel.uuid"
      ; opam "ppx_inline_test.config"
      ; local "mina_wire_types"
      ; local "sgn"
      ; local "syncable_ledger"
      ; local "snark_params"
      ; local "zkapp_command_builder"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "mina_base.import"
      ; local "o1trace"
      ; local "rocksdb"
      ; local "random_oracle"
      ; local "currency"
      ; local "genesis_constants"
      ; local "kimchi_backend"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "merkle_mask"
      ; local "merkle_ledger"
      ; local "mina_base"
      ; local "mina_transaction"
      ; local "mina_transaction_logic"
      ; local "signature_lib"
      ; local "mina_numbers"
      ; local "merkle_address"
      ; local "key_value_database"
      ; local "data_hash_lib"
      ; local "quickcheck_lib"
      ; local "snarky.backendless"
      ; local "unsigned_extended"
      ; local "with_hash"
      ; local "ppx_version.runtime"
      ; local "mina_stdlib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_version"
         ; "ppx_let"
         ; "ppx_custom_printf"
         ; "ppx_base"
         ; "ppx_deriving_yojson"
         ; "ppx_inline_test"
         ; "ppx_assert"
         ; "ppx_mina"
         ] ) ;

  (* -- mina_ledger_test_helpers ------------------------------------- *)
  private_library "mina_ledger_test_helpers"
    ~path:"src/lib/mina_ledger/test/helpers"
    ~deps:
      [ opam "base"
      ; opam "base.caml"
      ; opam "core_kernel"
      ; opam "core"
      ; opam "integers"
      ; opam "sexplib0"
      ; opam "yojson"
      ; local "currency"
      ; local "kimchi_backend_common"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base"
      ; local "mina_base.test_helpers"
      ; local "mina_ledger"
      ; local "mina_numbers"
      ; local "monad_lib"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "pickles_types"
      ; local "signature_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_base"; "ppx_let"; "ppx_assert"; "ppx_version" ]) ;

  (* -- staged_ledger_diff ------------------------------------------- *)
  library "staged_ledger_diff" ~path:"src/lib/staged_ledger_diff"
    ~deps:
      [ opam "core_kernel"
      ; opam "sexplib0"
      ; opam "async"
      ; opam "bin_prot.shape"
      ; opam "base.caml"
      ; opam "blake2"
      ; opam "stdint"
      ; opam "ppx_inline_test.config"
      ; opam "splittable_random"
      ; opam "stdio"
      ; opam "async_unix"
      ; opam "async_kernel"
      ; local "mina_base"
      ; local "transaction_snark_work"
      ; local "genesis_constants"
      ; local "currency"
      ; local "allocation_functor"
      ; local "consensus"
      ; local "logger"
      ; local "ppx_version.runtime"
      ; local "mina_wire_types"
      ; local "mina_base.import"
      ; local "signature_lib"
      ; local "pickles.backend"
      ; local "snark_params"
      ; local "pickles"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_numbers"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_mina"
         ; "ppx_jane"
         ; "ppx_version"
         ; "ppx_deriving.std"
         ; "ppx_deriving_yojson"
         ] ) ;

  ()
