(** Product: rosetta — Mina Rosetta API implementation.

  Provides the Coinbase Rosetta API for Mina, with testnet/mainnet
  signature variants, a signing library, and an indexer test. *)

open Manifest
open Externals

let () =
  executable "rosetta" ~package:"rosetta" ~path:"src/app/rosetta"
    ~modules:[ "rosetta" ] ~modes:[ "native" ]
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; base
      ; core
      ; core_kernel
      ; Layer_domain.genesis_constants
      ; local "lib"
      ]
    ~ppx:Ppx.minimal

let () =
  executable "rosetta-testnet" ~internal_name:"rosetta_testnet_signatures"
    ~package:"rosetta" ~path:"src/app/rosetta"
    ~modules:[ "rosetta_testnet_signatures" ]
    ~modes:[ "native" ]
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; base
      ; core
      ; core_kernel
      ; Layer_domain.genesis_constants
      ; Layer_protocol.mina_signature_kind_testnet
      ; local "lib"
      ]
    ~ppx:Ppx.minimal

let () =
  executable "rosetta-mainnet" ~internal_name:"rosetta_mainnet_signatures"
    ~package:"rosetta" ~path:"src/app/rosetta"
    ~modules:[ "rosetta_mainnet_signatures" ]
    ~modes:[ "native" ]
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; base
      ; core
      ; core_kernel
      ; Layer_domain.genesis_constants
      ; Layer_protocol.mina_signature_kind_mainnet
      ; local "lib"
      ]
    ~ppx:Ppx.minimal

let lib =
  library "lib" ~path:"src/app/rosetta/lib" ~inline_tests:true
    ~deps:
      [ archive_lib
      ; async
      ; async_kernel
      ; async_unix
      ; base
      ; base_caml
      ; caqti
      ; caqti_async
      ; cohttp
      ; cohttp_async
      ; core
      ; core_kernel
      ; integers
      ; ppx_inline_test_config
      ; result
      ; sexplib0
      ; uri
      ; Layer_base.currency
      ; Layer_base.hex
      ; Layer_base.interpolator_lib
      ; Layer_base.mina_base
      ; Layer_base.mina_base_import
      ; Layer_base.mina_compile_config
      ; Layer_base.mina_numbers
      ; Layer_base.mina_version
      ; Layer_base.mina_wire_types
      ; Layer_base.unsigned_extended
      ; Layer_crypto.random_oracle
      ; Layer_crypto.random_oracle_input
      ; Layer_crypto.secrets
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_domain.genesis_constants
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_logging.logger
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_protocol.mina_signature_kind
      ; Layer_rosetta.rosetta_coding
      ; Layer_rosetta.rosetta_lib
      ; Layer_rosetta.rosetta_models
      ; Layer_transaction.mina_transaction
      ; local "cli_lib"
      ; local "graphql_lib"
      ; local "mina_caqti"
      ; local "mina_runtime_config"
      ]
    ~preprocessor_deps:
      [ "../../../graphql-ppx-config.inc"; "../../../../graphql_schema.json" ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.graphql_ppx
         ; Ppx_lib.h_list_ppx
         ; Ppx_lib.ppx_assert
         ; Ppx_lib.ppx_bin_prot
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_deriving_make
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_hash
         ; Ppx_lib.ppx_here
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_sexp_conv
         ; Ppx_lib.ppx_string
         ; Ppx_lib.ppx_version
         ; "--"
         ; "%{read-lines:../../../graphql-ppx-config.inc}"
         ] )

let signer_cli =
  library "signer.cli" ~internal_name:"signer_cli"
    ~path:"src/app/rosetta/ocaml-signer" ~modules:[ "signer_cli" ]
    ~deps:
      [ async
      ; async_command
      ; async_kernel
      ; async_unix
      ; base
      ; core
      ; core_kernel
      ; lib
      ; Layer_base.mina_base
      ; Layer_crypto.secrets
      ; Layer_crypto.signature_lib
      ; Layer_crypto.snark_params
      ; Layer_crypto.string_sign
      ; Layer_kimchi.kimchi_pasta
      ; Layer_kimchi.kimchi_pasta_basic
      ; Layer_pickles.pickles
      ; Layer_pickles.pickles_backend
      ; Layer_rosetta.rosetta_coding
      ; Layer_rosetta.rosetta_lib
      ; local "cli_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.graphql_ppx
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let () =
  executable "signer" ~package:"signer" ~path:"src/app/rosetta/ocaml-signer"
    ~modules:[ "signer" ] ~modes:[ "native" ]
    ~deps:[ async; base; core_kernel; signer_cli ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.graphql_ppx
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let () =
  executable "signer-testnet" ~internal_name:"signer_testnet_signatures"
    ~package:"signer" ~path:"src/app/rosetta/ocaml-signer"
    ~modules:[ "signer_testnet_signatures" ]
    ~modes:[ "native" ]
    ~deps:[ async; base; core_kernel; signer_cli ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.graphql_ppx
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let () =
  executable "signer-mainnet" ~internal_name:"signer_mainnet_signatures"
    ~package:"signer" ~path:"src/app/rosetta/ocaml-signer"
    ~modules:[ "signer_mainnet_signatures" ]
    ~modes:[ "native" ]
    ~deps:[ async; base; core_kernel; signer_cli ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.graphql_ppx
         ; Ppx_lib.ppx_base
         ; Ppx_lib.ppx_compare
         ; Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_version
         ] )

let () =
  test "indexer_test" ~path:"src/app/rosetta/indexer_test" ~enabled_if:"false"
    ~deps:
      [ alcotest
      ; alcotest_async
      ; async
      ; async_command
      ; async_kernel
      ; base
      ; cmdliner
      ; core
      ; core_kernel
      ; lib
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_make
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_mina
         ; Ppx_lib.ppx_string
         ] )
