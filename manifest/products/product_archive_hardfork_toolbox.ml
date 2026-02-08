(** Product: archive_hardfork_toolbox — Tooling for hard fork
  archive database migrations. *)

open Manifest
open Externals

let archive_hardfork_toolbox_lib =
  library "archive_hardfork_toolbox.lib"
    ~internal_name:"archive_hardfork_toolbox_lib"
    ~path:"src/app/archive_hardfork_toolbox" ~modules:[ "logic"; "sql" ]
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; caqti
      ; caqti_async
      ; caqti_driver_postgresql
      ; cli_lib
      ; core
      ; core_kernel
      ; integers
      ; result
      ; stdio
      ; uri
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_consensus.consensus
      ; Layer_consensus.consensus_vrf
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.block_time
      ; Layer_domain.genesis_constants
      ; Layer_logging.logger
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.mina_block
      ; Layer_protocol.protocol_version
      ; Layer_transaction.mina_transaction
      ; Product_archive.archive_lib
      ; local "mina_caqti"
      ; local "runtime_config"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_string
         ; Ppx_lib.ppx_version
         ] )

let () =
  executable "archive_hardfork_toolbox" ~package:"archive_hardfork_toolbox"
    ~path:"src/app/archive_hardfork_toolbox"
    ~modules:[ "archive_hardfork_toolbox" ]
    ~deps:
      [ archive_hardfork_toolbox_lib
      ; async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; caqti
      ; caqti_async
      ; caqti_driver_postgresql
      ; cli_lib
      ; core
      ; core_kernel
      ; integers
      ; result
      ; stdio
      ; uri
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_consensus.consensus
      ; Layer_consensus.consensus_vrf
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.block_time
      ; Layer_domain.genesis_constants
      ; Layer_logging.logger
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.mina_block
      ; Layer_protocol.protocol_version
      ; Layer_transaction.mina_transaction
      ; Product_archive.archive_lib
      ; local "mina_caqti"
      ; local "runtime_config"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_string
         ; Ppx_lib.ppx_version
         ] )

let () =
  test "test_convert_canonical" ~path:"src/app/archive_hardfork_toolbox/tests"
    ~modules:[ "test_convert_canonical" ]
    ~deps:
      [ alcotest
      ; archive_hardfork_toolbox_lib
      ; async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; caqti
      ; caqti_async
      ; caqti_driver_postgresql
      ; core
      ; core_kernel
      ; result
      ; stdio
      ; threads_posix
      ; uri
      ; Layer_base.currency
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_numbers
      ; Layer_base.mina_wire_types
      ; Layer_base.one_or_two
      ; Layer_base.unsigned_extended
      ; Layer_base.with_hash
      ; Layer_consensus.consensus
      ; Layer_consensus.consensus_vrf
      ; Layer_consensus.mina_state
      ; Layer_crypto.signature_lib
      ; Layer_domain.block_time
      ; Layer_domain.genesis_constants
      ; Layer_logging.logger
      ; Layer_network.genesis_ledger_helper
      ; Layer_network.mina_block
      ; Layer_protocol.protocol_version
      ; Layer_transaction.mina_transaction
      ; Product_archive.archive_lib
      ; local "mina_caqti"
      ; local "runtime_config"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_version
         ] )
    ~no_instrumentation:true
