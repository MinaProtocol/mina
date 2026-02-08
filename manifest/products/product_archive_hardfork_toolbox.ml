(** Product: archive_hardfork_toolbox — Tooling for hard fork
    archive database migrations. *)

open Manifest
open Externals

let register () =
  (* -- archive_hardfork_toolbox.lib (library) ------------------------- *)
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
      ; local "archive_lib"
      ; local "block_time"
      ; local "consensus"
      ; local "consensus_vrf"
      ; local "currency"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_block"
      ; local "mina_caqti"
      ; local "mina_numbers"
      ; local "mina_state"
      ; local "mina_transaction"
      ; local "mina_wire_types"
      ; local "one_or_two"
      ; local "protocol_version"
      ; local "runtime_config"
      ; local "signature_lib"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_string"
         ; "ppx_version"
         ] ) ;

  (* -- archive_hardfork_toolbox (executable) -------------------------- *)
  executable "archive_hardfork_toolbox" ~package:"archive_hardfork_toolbox"
    ~path:"src/app/archive_hardfork_toolbox"
    ~modules:[ "archive_hardfork_toolbox" ]
    ~deps:
      [ async
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
      ; local "archive_hardfork_toolbox_lib"
      ; local "archive_lib"
      ; local "block_time"
      ; local "consensus"
      ; local "consensus_vrf"
      ; local "currency"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_block"
      ; local "mina_caqti"
      ; local "mina_numbers"
      ; local "mina_state"
      ; local "mina_transaction"
      ; local "mina_wire_types"
      ; local "one_or_two"
      ; local "protocol_version"
      ; local "runtime_config"
      ; local "signature_lib"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_compare"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_string"
         ; "ppx_version"
         ] ) ;

  (* -- test_convert_canonical (test) ---------------------------------- *)
  test "test_convert_canonical" ~path:"src/app/archive_hardfork_toolbox/tests"
    ~modules:[ "test_convert_canonical" ]
    ~deps:
      [ alcotest
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
      ; local "archive_hardfork_toolbox_lib"
      ; local "archive_lib"
      ; local "block_time"
      ; local "consensus"
      ; local "consensus_vrf"
      ; local "currency"
      ; local "genesis_constants"
      ; local "genesis_ledger_helper"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_block"
      ; local "mina_caqti"
      ; local "mina_numbers"
      ; local "mina_state"
      ; local "mina_transaction"
      ; local "mina_wire_types"
      ; local "one_or_two"
      ; local "protocol_version"
      ; local "runtime_config"
      ; local "signature_lib"
      ; local "unsigned_extended"
      ; local "with_hash"
      ]
    ~ppx:
      (Ppx.custom
         [ "h_list.ppx"
         ; "ppx_compare"
         ; "ppx_hash"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_version"
         ] )
    ~no_instrumentation:true ;

  ()
