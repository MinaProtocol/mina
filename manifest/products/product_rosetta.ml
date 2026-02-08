(** Product: rosetta — Mina Rosetta API implementation.

    Provides the Coinbase Rosetta API for Mina, with testnet/mainnet
    signature variants, a signing library, and an indexer test. *)

open Manifest

let register () =
  (* -- rosetta (executable) ------------------------------------------- *)
  executable "rosetta" ~package:"rosetta" ~path:"src/app/rosetta"
    ~modules:[ "rosetta" ] ~modes:[ "native" ]
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; local "genesis_constants"
      ; local "lib"
      ]
    ~ppx:Ppx.minimal ;

  (* -- rosetta-testnet (executable) ----------------------------------- *)
  executable "rosetta-testnet" ~internal_name:"rosetta_testnet_signatures"
    ~package:"rosetta" ~path:"src/app/rosetta"
    ~modules:[ "rosetta_testnet_signatures" ]
    ~modes:[ "native" ]
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; local "genesis_constants"
      ; local "lib"
      ; local "mina_signature_kind.testnet"
      ]
    ~ppx:Ppx.minimal ;

  (* -- rosetta-mainnet (executable) ----------------------------------- *)
  executable "rosetta-mainnet" ~internal_name:"rosetta_mainnet_signatures"
    ~package:"rosetta" ~path:"src/app/rosetta"
    ~modules:[ "rosetta_mainnet_signatures" ]
    ~modes:[ "native" ]
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; local "genesis_constants"
      ; local "lib"
      ; local "mina_signature_kind.mainnet"
      ]
    ~ppx:Ppx.minimal ;

  (* -- lib (rosetta library) ------------------------------------------ *)
  library "lib" ~path:"src/app/rosetta/lib" ~inline_tests:true
    ~deps:
      [ opam "archive_lib"
      ; opam "async"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "base.caml"
      ; opam "caqti"
      ; opam "caqti-async"
      ; opam "cohttp"
      ; opam "cohttp-async"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "integers"
      ; opam "ppx_inline_test.config"
      ; opam "result"
      ; opam "sexplib0"
      ; opam "uri"
      ; local "cli_lib"
      ; local "currency"
      ; local "genesis_constants"
      ; local "graphql_lib"
      ; local "hex"
      ; local "interpolator_lib"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "logger"
      ; local "mina_base"
      ; local "mina_base.import"
      ; local "mina_caqti"
      ; local "mina_compile_config"
      ; local "mina_numbers"
      ; local "mina_runtime_config"
      ; local "mina_signature_kind"
      ; local "mina_transaction"
      ; local "mina_version"
      ; local "mina_wire_types"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "random_oracle"
      ; local "random_oracle_input"
      ; local "rosetta_coding"
      ; local "rosetta_lib"
      ; local "rosetta_models"
      ; local "secrets"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "unsigned_extended"
      ]
    ~preprocessor_deps:
      [ "../../../graphql-ppx-config.inc"; "../../../../graphql_schema.json" ]
    ~ppx:
      (Ppx.custom
         [ "graphql_ppx"
         ; "h_list.ppx"
         ; "ppx_assert"
         ; "ppx_bin_prot"
         ; "ppx_compare"
         ; "ppx_compare"
         ; "ppx_custom_printf"
         ; "ppx_deriving.make"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ; "ppx_fields_conv"
         ; "ppx_hash"
         ; "ppx_here"
         ; "ppx_inline_test"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_sexp_conv"
         ; "ppx_string"
         ; "ppx_version"
         ; "--"
         ; "%{read-lines:../../../graphql-ppx-config.inc}"
         ] ) ;

  (* -- signer_cli (library) ------------------------------------------- *)
  library "signer.cli" ~internal_name:"signer_cli"
    ~path:"src/app/rosetta/ocaml-signer" ~modules:[ "signer_cli" ]
    ~deps:
      [ opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "async_unix"
      ; opam "base"
      ; opam "core"
      ; opam "core_kernel"
      ; opam "lib"
      ; local "cli_lib"
      ; local "kimchi_pasta"
      ; local "kimchi_pasta.basic"
      ; local "mina_base"
      ; local "pickles"
      ; local "pickles.backend"
      ; local "rosetta_coding"
      ; local "rosetta_lib"
      ; local "secrets"
      ; local "signature_lib"
      ; local "snark_params"
      ; local "string_sign"
      ]
    ~ppx:
      (Ppx.custom
         [ "graphql_ppx"
         ; "ppx_base"
         ; "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* -- signer (executable) -------------------------------------------- *)
  executable "signer" ~package:"signer" ~path:"src/app/rosetta/ocaml-signer"
    ~modules:[ "signer" ] ~modes:[ "native" ]
    ~deps:[ opam "async"; opam "base"; opam "core_kernel"; local "signer_cli" ]
    ~ppx:
      (Ppx.custom
         [ "graphql_ppx"
         ; "ppx_base"
         ; "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* -- signer-testnet (executable) ------------------------------------ *)
  executable "signer-testnet" ~internal_name:"signer_testnet_signatures"
    ~package:"signer" ~path:"src/app/rosetta/ocaml-signer"
    ~modules:[ "signer_testnet_signatures" ]
    ~modes:[ "native" ]
    ~deps:[ opam "async"; opam "base"; opam "core_kernel"; local "signer_cli" ]
    ~ppx:
      (Ppx.custom
         [ "graphql_ppx"
         ; "ppx_base"
         ; "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* -- signer-mainnet (executable) ------------------------------------ *)
  executable "signer-mainnet" ~internal_name:"signer_mainnet_signatures"
    ~package:"signer" ~path:"src/app/rosetta/ocaml-signer"
    ~modules:[ "signer_mainnet_signatures" ]
    ~modes:[ "native" ]
    ~deps:[ opam "async"; opam "base"; opam "core_kernel"; local "signer_cli" ]
    ~ppx:
      (Ppx.custom
         [ "graphql_ppx"
         ; "ppx_base"
         ; "ppx_compare"
         ; "ppx_deriving.show"
         ; "ppx_deriving_yojson"
         ; "ppx_let"
         ; "ppx_mina"
         ; "ppx_version"
         ] ) ;

  (* -- indexer_test (test, disabled) ---------------------------------- *)
  test "indexer_test" ~path:"src/app/rosetta/indexer_test" ~enabled_if:"false"
    ~deps:
      [ opam "alcotest"
      ; opam "alcotest-async"
      ; opam "async"
      ; opam "async.async_command"
      ; opam "async_kernel"
      ; opam "base"
      ; opam "cmdliner"
      ; opam "core"
      ; opam "core_kernel"
      ; local "lib"
      ]
    ~ppx:
      (Ppx.custom
         [ "ppx_deriving.make"; "ppx_jane"; "ppx_mina"; "ppx_string" ] ) ;

  ()
