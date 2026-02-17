(** Mina GraphQL layer: GraphQL wrappers, scalars, and query generation.

  Each declaration corresponds to a dune file in src/.
  The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let graphql_wrapper =
  library "graphql_wrapper" ~path:"src/lib/graphql_wrapper"
    ~deps:[ graphql; graphql_async; graphql_parser ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_deriving_show
         ; Ppx_lib.ppx_deriving_yojson
         ; Ppx_lib.ppx_version
         ] )

let graphql_basic_scalars =
  library "graphql_basic_scalars" ~path:"src/lib/graphql_basic_scalars"
    ~deps:
      [ async
      ; async_kernel
      ; async_unix
      ; core
      ; core_kernel
      ; graphql
      ; graphql_async
      ; graphql_parser
      ; integers
      ; sexplib0
      ; yojson
      ; Layer_test.quickcheck_lib
      ; local "base_quickcheck"
      ; local "graphql_wrapper"
      ; local "unix"
      ]
    ~ppx:Ppx.standard ~inline_tests:true

let fields_derivers_graphql =
  library "fields_derivers.graphql" ~internal_name:"fields_derivers_graphql"
    ~path:"src/lib/fields_derivers_graphql" ~inline_tests:true
    ~deps:
      [ async_kernel
      ; core_kernel
      ; fieldslib
      ; graphql
      ; graphql_async
      ; graphql_parser
      ; ppx_inline_test_config
      ; yojson
      ; Layer_domain.fields_derivers
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_annot
         ; Ppx_lib.ppx_custom_printf
         ; Ppx_lib.ppx_fields_conv
         ; Ppx_lib.ppx_inline_test
         ; Ppx_lib.ppx_jane
         ; Ppx_lib.ppx_let
         ; Ppx_lib.ppx_version
         ] )

let generated_graphql_queries =
  library "generated_graphql_queries" ~path:"src/lib/generated_graphql_queries"
    ~preprocessor_deps:
      [ "../../../graphql_schema.json"; "../../graphql-ppx-config.inc" ]
    ~deps:
      [ async
      ; base
      ; cohttp
      ; cohttp_async
      ; core
      ; graphql_async
      ; graphql_cohttp
      ; yojson
      ; Layer_base.mina_base
      ; local "graphql_lib"
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_version
         ; Ppx_lib.graphql_ppx
         ; "--"
         ; {|%{read-lines:../../graphql-ppx-config.inc}|}
         ] )
    ~extra_stanzas:
      [ Dune_s_expr.parse_string
          {|(rule
 (targets generated_graphql_queries.ml)
 (deps
(:< gen/gen.exe))
 (action
(run %{<} %{targets})))|}
        |> List.hd
      ]

let () =
  private_executable ~path:"src/lib/generated_graphql_queries/gen"
    ~modes:[ "native" ]
    ~deps:
      [ base
      ; base_caml
      ; compiler_libs
      ; core_kernel
      ; ocaml_migrate_parsetree
      ; ppxlib
      ; ppxlib_ast
      ; ppxlib_astlib
      ; stdio
      ; yojson
      ; Layer_base.mina_base
      ]
    ~ppx:
      (Ppx.custom
         [ Ppx_lib.ppx_base
         ; Ppx_lib.ppx_version
         ; Ppx_lib.ppxlib_metaquot
         ; Ppx_lib.graphql_ppx
         ] )
    "gen"
